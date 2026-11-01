import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/device_identity.dart';
import '../export/scan_export.dart';
import '../l10n/gen/app_localizations.dart';
import '../model/device.dart';
import '../model/discovery_source.dart';
import '../model/network_info.dart';
import '../platform/wake_on_lan.dart';
import '../scan/well_known_ports.dart';
import '../state/column_widths.dart';
import '../state/network_selection.dart';
import '../state/providers.dart';
import '../version.dart';
import 'about_dialog.dart';
import 'device_visuals.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networksAsync = ref.watch(networksProvider);
    final scan = ref.watch(scanControllerProvider);
    final l10n = AppLocalizations.of(context);

    // When the host moves between networks, re-discover and stop any in-flight
    // scan AND any live monitoring of the now-stale subnet (unconditionally —
    // background monitor ticks never set isScanning/isBusy, by design, so they
    // wouldn't otherwise be caught here, and would keep re-scanning the wrong
    // network indefinitely). stopScan() is a no-op if nothing is running. The
    // selection survives by id (or re-defaults to Wi-Fi) via effectiveNetwork.
    ref.listen(networkChangeProvider, (prev, next) {
      ref.read(scanControllerProvider.notifier).stopScan();
      ref.invalidate(networksProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.networkChangedSnackbar),
          duration: const Duration(seconds: 3),
        ),
      );
    });

    // Live-monitoring alert: when a re-scan finds devices that weren't there
    // before, surface them.
    ref.listen(scanControllerProvider.select((s) => s.lastNewDevices), (
      prev,
      next,
    ) {
      if (next.isEmpty) return;
      final names = next.map((d) => d.displayName).take(3).join(', ');
      final countLabel = l10n.newDeviceCount(next.length);
      final extra = next.length > 3
          ? ' ${l10n.newDeviceMore(next.length - 3)}'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.newDeviceAlert(countLabel, names)}$extra'),
          duration: const Duration(seconds: 5),
        ),
      );
    });

    final compact = MediaQuery.sizeOf(context).width < _kCompactWidth;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        actions: compact ? const [_CompactOverflowMenu()] : null,
        title: Row(
          children: [
            Image.asset(
              'assets/icon/sextant_mark.png',
              width: 24,
              height: 24,
              color: IconTheme.of(context).color,
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(width: 8),
            // Baseline-aligned so "Sextant" and the version number sit on
            // the same line of text, rather than being centered against
            // each other's (different-height) bounding boxes.
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text('Sextant'),
                const SizedBox(width: 8),
                Text(
                  kToolbarVersion,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(width: 24),
              Expanded(
                child: networksAsync.when(
                  data: (networks) => _Toolbar(networks: networks),
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (e, _) => Text('Network error: $e'),
                ),
              ),
            ],
          ],
        ),
        bottom: scan.isScanning || scan.isBackgroundScanning
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  // Determinate once we know the subnet size; indeterminate
                  // for the brief moment before the host count is known. A
                  // background monitor re-scan shows the same bar, driven by
                  // its own progress so it doesn't disturb a foreground scan.
                  value: scan.isScanning
                      // Use the monotonic weighted progress (0→0.8 ICMP,
                      // 0.8→1.0 TCP). Switch to indeterminate once both phases
                      // finish and only background enrichment remains.
                      ? (scan.scanProgress < 1.0 ? scan.scanProgress : null)
                      : (scan.backgroundTotal > 0
                            ? scan.backgroundProgress
                            : null),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          if (compact)
            networksAsync.when(
              data: (networks) => _CompactControls(networks: networks),
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Network error: $e'),
              ),
            ),
          _StatusBar(),
          const Divider(height: 1),
          Expanded(
            child: _DeviceTable(devices: scan.devices, isBusy: scan.isBusy),
          ),
        ],
      ),
    );
  }
}

/// Below this width the desktop single-row toolbar and column table don't
/// fit, so the screen switches to the phone layout.
const _kCompactWidth = 600.0;

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.networks});

  final List<ScanNetwork> networks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        if (networks.isEmpty)
          Text(l10n.noActiveNetworkFound)
        else
          _NetworkDropdown(networks: networks),
        const SizedBox(width: 16),
        _ScanButton(networks: networks),
        const SizedBox(width: 8),
        _MonitorButton(networks: networks),
        const SizedBox(width: 8),
        const _ExportButton(),
        const SizedBox(width: 8),
        IconButton(
          tooltip: l10n.scanHistoryTooltip,
          icon: const Icon(Icons.history),
          onPressed: () => _openHistory(context),
        ),
        const Spacer(),
        IconButton(
          tooltip: l10n.aboutTooltip,
          icon: const Icon(Icons.info_outline),
          onPressed: () => showSextantAboutDialog(context),
        ),
        IconButton(
          tooltip: l10n.settingsTooltip,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => _openSettings(context),
        ),
      ],
    );
  }
}

void _openHistory(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const HistoryScreen()));

void _openSettings(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

/// Phone layout: the network picker on its own full-width line, with the scan,
/// monitor and export controls underneath.
class _CompactControls extends ConsumerWidget {
  const _CompactControls({required this.networks});

  final List<ScanNetwork> networks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (networks.isEmpty)
            Text(l10n.noActiveNetworkFound)
          else
            _NetworkDropdown(networks: networks, expanded: true),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _ScanButton(networks: networks)),
              const SizedBox(width: 8),
              _MonitorButton(networks: networks),
              const _ExportButton(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Phone layout's app-bar overflow menu: the actions the desktop toolbar shows
/// as individual icon buttons.
class _CompactOverflowMenu extends StatelessWidget {
  const _CompactOverflowMenu();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<VoidCallback>(
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: () => _openHistory(context),
          child: Text(l10n.scanHistoryTooltip),
        ),
        PopupMenuItem(
          value: () => _openSettings(context),
          child: Text(l10n.settingsTooltip),
        ),
        PopupMenuItem(
          value: () => showSextantAboutDialog(context),
          child: Text(l10n.aboutTooltip),
        ),
      ],
    );
  }
}

class _NetworkDropdown extends ConsumerWidget {
  const _NetworkDropdown({required this.networks, this.expanded = false});

  final List<ScanNetwork> networks;

  /// Fill the available width (and ellipsize long labels) instead of sizing to
  /// the selected entry.
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedNetworkProvider);
    final scan = ref.watch(scanControllerProvider);
    final effective = effectiveNetwork(networks, selected);
    final l10n = AppLocalizations.of(context);

    return DropdownButton<ScanNetwork>(
      value: effective,
      isExpanded: expanded,
      underline: const SizedBox.shrink(),
      items: [
        for (final n in networks)
          DropdownMenuItem(
            value: n,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  n.isWireless ? Icons.wifi : Icons.settings_ethernet,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.networkOption(
                      n.displayName,
                      n.subnet.networkAddress.address,
                      n.subnet.prefixLength,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      onChanged: scan.isBusy
          ? null
          : (n) => ref.read(selectedNetworkProvider.notifier).select(n),
    );
  }
}

class _ScanButton extends ConsumerWidget {
  const _ScanButton({required this.networks});

  final List<ScanNetwork> networks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedNetworkProvider);
    final scan = ref.watch(scanControllerProvider);
    final effective = effectiveNetwork(networks, selected);
    final l10n = AppLocalizations.of(context);

    if (scan.isBusy) {
      return FilledButton.tonalIcon(
        onPressed: () => ref.read(scanControllerProvider.notifier).stopScan(),
        icon: const Icon(Icons.stop),
        label: Text(l10n.stopButtonLabel),
      );
    }
    return FilledButton.icon(
      onPressed: effective == null
          ? null
          : () =>
                ref.read(scanControllerProvider.notifier).startScan(effective),
      icon: const Icon(Icons.radar),
      label: Text(l10n.scanButtonLabel),
    );
  }
}

class _MonitorButton extends ConsumerWidget {
  const _MonitorButton({required this.networks});

  final List<ScanNetwork> networks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedNetworkProvider);
    final scan = ref.watch(scanControllerProvider);
    final effective = effectiveNetwork(networks, selected);
    final l10n = AppLocalizations.of(context);

    return IconButton(
      tooltip: scan.isMonitoring
          ? l10n.monitoringStopTooltip
          : l10n.monitoringStartTooltip,
      isSelected: scan.isMonitoring,
      selectedIcon: const Icon(Icons.sensors),
      icon: const Icon(Icons.sensors_off_outlined),
      onPressed: effective == null
          ? null
          : () => ref
                .read(scanControllerProvider.notifier)
                .toggleMonitoring(effective),
    );
  }
}

class _ExportButton extends ConsumerWidget {
  const _ExportButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(scanControllerProvider);
    final l10n = AppLocalizations.of(context);

    return PopupMenuButton<ExportFormat>(
      tooltip: l10n.exportScanTooltip,
      enabled: scan.devices.isNotEmpty && !scan.isBusy,
      icon: const Icon(Icons.download_outlined),
      onSelected: (format) => exportScan(context, scan.devices, format),
      itemBuilder: (context) => [
        PopupMenuItem(value: ExportFormat.csv, child: Text(l10n.exportAsCsv)),
        PopupMenuItem(value: ExportFormat.json, child: Text(l10n.exportAsJson)),
      ],
    );
  }
}

/// Serialises the current [devices] in [format] and prompts the user for a save
/// location, writing the file and reporting the result via a snackbar.
Future<void> exportScan(
  BuildContext context,
  List<Device> devices,
  ExportFormat format,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final file = buildScanExport(devices, format);
  final ext = format == ExportFormat.csv ? 'csv' : 'json';
  try {
    final location = await getSaveLocation(
      suggestedName: file.suggestedName,
      acceptedTypeGroups: [
        XTypeGroup(label: ext.toUpperCase(), extensions: [ext]),
      ],
    );
    if (location == null) return; // user cancelled
    await File(location.path).writeAsString(file.content);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.exportedDevices(devices.length, location.path)),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.exportFailed(e.toString()))),
    );
  }
}

class _StatusBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(scanControllerProvider);
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.bodySmall;
    final online = scan.devices.where((d) => d.isOnline).length;
    final offline = scan.devices.length - online;
    // Suffix shown once at least one device has gone offline, so the counts
    // reflect devices coming back online (not just the unchanging total).
    final offlineSuffix = offline > 0 ? l10n.offlineSuffix(offline) : '';
    final String status;
    if (scan.isScanning) {
      status = l10n.scanningStatus(
        scan.devices.length,
        scan.scanned,
        scan.total,
      );
    } else if (scan.enriching) {
      status = l10n.resolvingMacAddresses(scan.devices.length);
    } else if (scan.isMonitoring) {
      status = l10n.monitoringStatus(online, offlineSuffix);
    } else if (scan.devices.isNotEmpty) {
      status = l10n.onlineStatus(online, offlineSuffix);
    } else {
      status = l10n.idleStatus;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (scan.isMonitoring) ...[
            Icon(
              Icons.sensors,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
          ],
          Text(status, style: style),
        ],
      ),
    );
  }
}

const _kIconWidth = 40.0;

/// Width of the (invisible, draggable) gap after each resizable column. Must
/// be identical between the header (where it's interactive) and each
/// [DeviceRow] (where it's an inert spacer) — see the alignment note in this
/// file's class docs above `_DeviceTableHeader`.
const _kHandleWidth = 8.0;

/// Fixed chrome around the table's seven text columns: the icon column, a
/// resize-handle gap after each of the six resizable columns, and the
/// header/row `Padding`'s combined left+right inset (12 each side).
const _kTableChromeWidth = _kIconWidth + 6 * _kHandleWidth + 24;

/// The header row's text style — shared between measuring each column's
/// minimum width and actually painting the labels, so the two never drift
/// out of sync.
TextStyle? _headerStyle(BuildContext context) => Theme.of(
  context,
).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold);

/// Measures the on-screen width of each column's header label in the current
/// locale/font — the floor [EffectiveColumnWidths.compute] shrinks columns
/// down to, so a header label is never clipped.
ColumnMinWidths _headerMinWidths(
  BuildContext context,
  AppLocalizations l10n,
  TextStyle? style,
) {
  final textScaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  double measure(String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      maxLines: 1,
      textDirection: direction,
      textScaler: textScaler,
    )..layout();
    return painter.width.ceilToDouble();
  }

  return (
    ip: measure(l10n.columnIp),
    name: measure(l10n.columnName),
    mac: measure(l10n.columnMac),
    vendor: measure(l10n.columnVendor),
    openPorts: measure(l10n.columnOpenPorts),
    foundVia: measure(l10n.columnFoundVia),
    latency: measure(l10n.columnLatency),
  );
}

/// The device table: header, a divider, and the device list (or an empty-
/// state hint), all fitted to the space actually available this frame.
///
/// Column widths shrink to fit a narrower window before anything overflows
/// — see [EffectiveColumnWidths]. Once every column is already at its
/// header-label minimum and the row still doesn't fit, this switches to
/// horizontal scrolling rather than clipping or overlapping content.
class _DeviceTable extends ConsumerWidget {
  const _DeviceTable({required this.devices, required this.isBusy});

  final List<Device> devices;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final preferred = ref.watch(columnWidthsProvider);
    final style = _headerStyle(context);
    final minWidths = _headerMinWidths(context, l10n, style);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _kCompactWidth;
        final empty = Center(
          child: Text(
            isBusy ? l10n.scanningEllipsis : l10n.pressScanHint,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );

        // Phone layout: one card per device instead of the column table.
        if (compact) {
          if (devices.isEmpty) return empty;
          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, i) =>
                DeviceRow.compact(device: devices[i], tinted: i.isOdd),
          );
        }

        final widths = EffectiveColumnWidths.compute(
          preferred: preferred,
          minWidths: minWidths,
          availableWidth: constraints.maxWidth - _kTableChromeWidth,
        );

        final body = devices.isEmpty
            ? empty
            : ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, i) => DeviceRow(
                  widths: widths,
                  device: devices[i],
                  tinted: i.isOdd,
                ),
              );

        final table = Column(
          children: [
            _DeviceTableHeader(widths: widths),
            const Divider(height: 1),
            Expanded(child: body),
          ],
        );

        if (!widths.overflows) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: widths.naturalWidth + _kTableChromeWidth,
            child: table,
          ),
        );
      },
    );
  }
}

/// The device table's column headers. A [ConsumerWidget] (not
/// [StatelessWidget], like the rest of this file's static widgets) because it
/// both reads [columnWidthsProvider] for current widths and renders the
/// draggable resize handles that write back to it.
///
/// IMPORTANT: every fixed-width child here must have an exact-width sibling
/// in [DeviceRow]'s row, in the same relative position, or the two rows will
/// drift out of alignment — see [_kHandleWidth]'s doc comment.
class _DeviceTableHeader extends ConsumerWidget {
  const _DeviceTableHeader({required this.widths});

  final EffectiveColumnWidths widths;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final style = _headerStyle(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      // IntrinsicHeight so the resize handles (whose own content is a
      // zero-height-by-default Center/Container) stretch to the row's
      // content height instead of collapsing to zero, which would leave
      // them with nothing to hit-test against.
      child: IntrinsicHeight(
        child: Row(
          children: [
            const SizedBox(width: _kIconWidth),
            SizedBox(
              width: widths.ip,
              child: _headerLabel(l10n.columnIp, style),
            ),
            const _ColumnResizeHandle(column: ResizableColumn.ip),
            SizedBox(
              width: widths.name,
              child: _headerLabel(l10n.columnName, style),
            ),
            const _ColumnResizeHandle(column: ResizableColumn.name),
            SizedBox(
              width: widths.mac,
              child: _headerLabel(l10n.columnMac, style),
            ),
            const _ColumnResizeHandle(column: ResizableColumn.mac),
            SizedBox(
              width: widths.vendor,
              child: _headerLabel(l10n.columnVendor, style),
            ),
            const _ColumnResizeHandle(column: ResizableColumn.vendor),
            SizedBox(
              width: widths.openPorts,
              child: _headerLabel(l10n.columnOpenPorts, style),
            ),
            SizedBox(
              width: widths.foundVia,
              child: _headerLabel(l10n.columnFoundVia, style),
            ),
            const _ColumnResizeHandle(column: ResizableColumn.foundVia),
            SizedBox(
              width: widths.latency,
              child: _headerLabel(l10n.columnLatency, style),
            ),
            const _ColumnResizeHandle(column: ResizableColumn.latency),
          ],
        ),
      ),
    );
  }
}

/// A label for the most recent reading in [values] (a device's latency
/// history, oldest-first), rounded to whole milliseconds — matching
/// [_StatusDot]'s "<1" convention for sub-millisecond latency. Returns null
/// when there's no reading yet.
String? latestLatencyLabel(List<double> values) {
  if (values.isEmpty) return null;
  final latest = values.last;
  return '${latest < 1 ? '<1' : latest.round()} ms';
}

/// A column header label that elides rather than wraps when the column is
/// narrower than its text — a header label wrapping to multiple lines would
/// (via this row's `IntrinsicHeight`) inflate every column to match, instead
/// of just truncating the one label that's too narrow.
Text _headerLabel(String label, TextStyle? style) =>
    Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);

/// A thin draggable strip after a resizable column's header cell: dragging it
/// horizontally grows or shrinks that column via [columnWidthsProvider].
/// [_kHandleWidth] wide, matching the inert spacer [DeviceRow] places in the
/// same position so header and rows stay aligned.
class _ColumnResizeHandle extends ConsumerWidget {
  const _ColumnResizeHandle({required this.column});

  final ResizableColumn column;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: _kHandleWidth,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: (details) => ref
              .read(columnWidthsProvider.notifier)
              .resize(column, details.delta.dx),
          child: Center(
            child: Container(width: 1, color: Theme.of(context).dividerColor),
          ),
        ),
      ),
    );
  }
}

class DeviceRow extends ConsumerWidget {
  const DeviceRow({
    super.key,
    required EffectiveColumnWidths this.widths,
    required this.device,
    this.tinted = false,
  });

  /// Phone layout: a two-line card with details and actions in a bottom sheet,
  /// instead of a row of fixed-width table columns.
  const DeviceRow.compact({
    super.key,
    required this.device,
    this.tinted = false,
  }) : widths = null;

  /// Column widths for the table row; null for the [DeviceRow.compact] card.
  final EffectiveColumnWidths? widths;
  final Device device;

  /// Whether this row gets the alternating (zebra) background tint.
  final bool tinted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // Offline devices (seen on a previous monitor pass but not the latest) stay
    // in the list but are clearly de-emphasised: a hollow status dot, muted
    // text, and a struck-through name.
    final offline = !device.isOnline;
    final muted = theme.colorScheme.onSurfaceVariant;
    final small = theme.textTheme.bodySmall;
    final mutedSmall = small?.copyWith(color: muted);
    final identity = deviceIdentity(
      mac: device.mac,
      hostname: device.hostname,
      openPorts: device.openPorts,
    );

    final widths = this.widths;
    if (widths == null) return _buildCard(context, ref);

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: _kIconWidth,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusDot(
                  online: device.isOnline,
                  latencyMs: device.latencyMs,
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: device.isOnline
                      ? deviceTypeLabel(l10n, device.deviceType)
                      : l10n.deviceTypeOfflineTooltip(
                          deviceTypeLabel(l10n, device.deviceType),
                        ),
                  child: Icon(
                    deviceIcon(device),
                    size: 20,
                    color: offline ? muted : null,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: widths.ip,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    device.ip,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: offline ? muted : null,
                    ),
                  ),
                ),
                if (device.additionalIps.isNotEmpty)
                  Tooltip(
                    message: l10n.alsoSeenAt(device.additionalIps.join(', ')),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '+${device.additionalIps.length}',
                        style: mutedSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: _kHandleWidth),
          SizedBox(
            width: widths.name,
            child: Text(
              device.displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                // Renamed devices are shown italic (and semibold) to mark the
                // user-assigned name as distinct from a discovered one.
                fontWeight: device.customName != null
                    ? FontWeight.w600
                    : FontWeight.normal,
                fontStyle: device.customName != null
                    ? FontStyle.italic
                    : FontStyle.normal,
                color: offline ? muted : null,
              ),
            ),
          ),
          const SizedBox(width: _kHandleWidth),
          SizedBox(
            width: widths.mac,
            child: Text(
              device.mac ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: offline ? mutedSmall : small,
            ),
          ),
          const SizedBox(width: _kHandleWidth),
          SizedBox(
            width: widths.vendor,
            child: Text(
              device.vendor ?? '—',
              overflow: TextOverflow.ellipsis,
              style: offline ? mutedSmall : small,
            ),
          ),
          const SizedBox(width: _kHandleWidth),
          SizedBox(
            width: widths.openPorts,
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                for (final port in device.openPorts)
                  _PortChip(port: port, service: device.services[port]),
              ],
            ),
          ),
          SizedBox(
            width: widths.foundVia,
            child: Wrap(
              spacing: 4,
              children: [
                for (final source in device.discoveredBy)
                  Tooltip(
                    message: discoverySourceLabel(l10n, source),
                    child: Icon(
                      discoverySourceIcon(source),
                      size: 16,
                      color: offline ? muted : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: _kHandleWidth),
          SizedBox(
            width: widths.latency,
            child: ref
                .watch(latencyHistoryProvider(identity))
                .maybeWhen(
                  data: (values) {
                    final label = latestLatencyLabel(values);
                    if (label == null) return const SizedBox.shrink();
                    return Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: offline ? mutedSmall : small,
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
          ),
          const SizedBox(width: _kHandleWidth),
        ],
      ),
    );

    return Material(
      color: tinted
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
          : Colors.transparent,
      child: InkWell(
        onSecondaryTapDown: (d) => _showMenu(context, ref, d.globalPosition),
        onLongPress: () => _showMenu(context, ref, null),
        child: row,
      ),
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final offline = !device.isOnline;
    final muted = theme.colorScheme.onSurfaceVariant;
    final identity = deviceIdentity(
      mac: device.mac,
      hostname: device.hostname,
      openPorts: device.openPorts,
    );
    final latency = ref
        .watch(latencyHistoryProvider(identity))
        .maybeWhen(data: latestLatencyLabel, orElse: () => null);
    final ip = device.additionalIps.isEmpty
        ? device.ip
        : '${device.ip} +${device.additionalIps.length}';

    return Material(
      color: tinted
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
          : Colors.transparent,
      child: ListTile(
        onTap: () => _showDetails(context, ref, latency),
        onLongPress: () => _showMenu(context, ref, null),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusDot(online: device.isOnline, latencyMs: device.latencyMs),
            const SizedBox(width: 8),
            Icon(deviceIcon(device), size: 22, color: offline ? muted : null),
          ],
        ),
        title: Text(
          device.displayName,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: device.customName != null
                ? FontWeight.w600
                : FontWeight.normal,
            fontStyle: device.customName != null
                ? FontStyle.italic
                : FontStyle.normal,
            color: offline ? muted : null,
          ),
        ),
        subtitle: Text(
          [ip, if (device.vendor != null) device.vendor!].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: latency == null
            ? null
            : Text(latency, style: theme.textTheme.bodySmall),
      ),
    );
  }

  /// The full set of per-device attributes the card leaves out, plus the same
  /// actions as the desktop context menu.
  Future<void> _showDetails(
    BuildContext context,
    WidgetRef ref,
    String? latency,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget field(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          Expanded(child: value),
        ],
      ),
    );

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(device.displayName, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              field(l10n.columnIp, Text(device.ip)),
              if (device.additionalIps.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(l10n.alsoSeenAt(device.additionalIps.join(', '))),
                ),
              field(l10n.columnMac, Text(device.mac ?? '—')),
              field(l10n.columnVendor, Text(device.vendor ?? '—')),
              if (latency != null) field(l10n.columnLatency, Text(latency)),
              if (device.openPorts.isNotEmpty)
                field(
                  l10n.columnOpenPorts,
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final port in device.openPorts)
                        _PortChip(port: port, service: device.services[port]),
                    ],
                  ),
                ),
              if (device.discoveredBy.isNotEmpty)
                field(
                  l10n.columnFoundVia,
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      for (final source in device.discoveredBy)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(discoverySourceIcon(source), size: 16),
                            const SizedBox(width: 4),
                            Text(discoverySourceLabel(l10n, source)),
                          ],
                        ),
                    ],
                  ),
                ),
              const Divider(),
              for (final action in _actions(l10n))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(action.icon),
                  title: Text(action.label),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (context.mounted) _perform(context, ref, action.value);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Per-device actions shared by the desktop context menu and the phone
  /// details sheet.
  List<({String value, IconData icon, String label})> _actions(
    AppLocalizations l10n,
  ) {
    final canOpenWeb =
        device.openPorts.contains(80) || device.openPorts.contains(443);
    return [
      if (canOpenWeb)
        (value: 'open', icon: Icons.open_in_browser, label: l10n.openInBrowser),
      (
        value: 'rename',
        icon: Icons.drive_file_rename_outline,
        label: l10n.renameEllipsis,
      ),
      (
        value: 'type',
        icon: deviceTypeIcon(device.deviceType),
        label: l10n.changeTypeEllipsis,
      ),
      (value: 'copy_ip', icon: Icons.copy, label: l10n.copyIp),
      if (device.mac != null)
        (value: 'copy_mac', icon: Icons.copy_all, label: l10n.copyMac),
      if (device.mac != null)
        (value: 'wake', icon: Icons.flash_on_outlined, label: l10n.wakeOnLan),
    ];
  }

  Future<void> _showMenu(
    BuildContext context,
    WidgetRef ref,
    Offset? globalPosition,
  ) async {
    final l10n = AppLocalizations.of(context);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = globalPosition ?? overlay.size.center(Offset.zero);

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: [
        if (device.discoveredBy.isNotEmpty) ...[
          PopupMenuItem(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.discoveredVia,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                for (final source in device.discoveredBy)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(discoverySourceIcon(source), size: 16),
                        const SizedBox(width: 8),
                        Text(discoverySourceLabel(l10n, source)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        for (final action in _actions(l10n))
          PopupMenuItem(
            value: action.value,
            child: ListTile(
              dense: true,
              leading: Icon(action.icon),
              title: Text(action.label),
            ),
          ),
      ],
    );
    if (selected == null || !context.mounted) return;
    await _perform(context, ref, selected);
  }

  Future<void> _perform(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    switch (action) {
      case 'open':
        final scheme = device.openPorts.contains(443) ? 'https' : 'http';
        await launchUrl(Uri.parse('$scheme://${device.ip}'));
      case 'rename':
        if (context.mounted) await _renameDialog(context, ref);
      case 'type':
        if (context.mounted) await _changeTypeDialog(context, ref);
      case 'copy_ip':
        await Clipboard.setData(ClipboardData(text: device.ip));
      case 'copy_mac':
        await Clipboard.setData(ClipboardData(text: device.mac ?? ''));
      case 'wake':
        if (context.mounted) await _wakeOnLan(context);
    }
  }

  Future<void> _wakeOnLan(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await const WakeOnLan().send(device.mac!);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.magicPacketSent(device.mac!))),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.magicPacketFailed(e.toString()))),
      );
    }
  }

  Future<void> _renameDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: device.customName ?? '');
    final name = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.renameDialogTitle(device.ip)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.deviceNameLabel,
            hintText: l10n.deviceNameHint,
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(l10n.clear),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (name == null) return; // cancelled
    await ref
        .read(scanControllerProvider.notifier)
        .renameDevice(device, name.isEmpty ? null : name);
  }

  Future<void> _changeTypeDialog(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    const sentinelAuto = 'auto';
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.deviceTypeDialogTitle(device.ip)),
        children: [
          for (final type in DeviceType.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, type.name),
              child: Row(
                children: [
                  Icon(deviceTypeIcon(type), size: 20),
                  const SizedBox(width: 12),
                  Text(deviceTypeLabel(l10n, type)),
                  if (type == device.deviceType) ...[
                    const Spacer(),
                    const Icon(Icons.check, size: 18),
                  ],
                ],
              ),
            ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, sentinelAuto),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 20),
                const SizedBox(width: 12),
                Text(l10n.resetToAutomatic),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected == null) return; // dismissed
    final type = selected == sentinelAuto
        ? null
        : DeviceType.values.firstWhere((t) => t.name == selected);
    await ref.read(scanControllerProvider.notifier).setDeviceType(device, type);
  }
}

/// A small status indicator: a filled green dot when online, a hollow grey ring
/// when the device is offline (kept in the list during monitoring).
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.online, this.latencyMs});

  final bool online;

  /// Round-trip ICMP latency from the most recent scan, if known.
  final double? latencyMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final latency = latencyMs == null
        ? ''
        : l10n.latencySuffix(
            latencyMs! < 1 ? '<1' : latencyMs!.toStringAsFixed(0),
          );
    return Tooltip(
      message: (online ? l10n.statusOnline : l10n.statusOffline) + latency,
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: online ? Colors.green.shade600 : Colors.transparent,
          border: online
              ? null
              : Border.all(color: theme.colorScheme.outline, width: 1.5),
        ),
      ),
    );
  }
}

class _PortChip extends StatelessWidget {
  const _PortChip({required this.port, this.service});
  final int port;

  /// Identified service for this port (e.g. "OpenSSH 9.6"), if known.
  final String? service;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final known = service != null;
    final label = kWellKnownPorts[port];
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: known ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$port', style: Theme.of(context).textTheme.labelSmall),
    );
    final tip = [
      if (label != null) l10n.portWithLabel(port, label) else '$port',
      if (service != null) l10n.portService(service!),
    ].join('  ');
    return Tooltip(message: tip, child: chip);
  }
}
