import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/device_identity.dart';
import '../export/scan_export.dart';
import '../model/device.dart';
import '../model/discovery_source.dart';
import '../model/network_info.dart';
import '../platform/wake_on_lan.dart';
import '../scan/well_known_ports.dart';
import '../state/network_selection.dart';
import '../state/providers.dart';
import 'device_visuals.dart';
import 'history_screen.dart';
import 'latency_sparkline.dart';

class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networksAsync = ref.watch(networksProvider);
    final scan = ref.watch(scanControllerProvider);

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
        const SnackBar(
          content: Text('Network changed — updating available networks…'),
          duration: Duration(seconds: 3),
        ),
      );
    });

    // Live-monitoring alert: when a re-scan finds devices that weren't there
    // before, surface them.
    ref.listen(scanControllerProvider.select((s) => s.lastNewDevices),
        (prev, next) {
      if (next.isEmpty) return;
      final names = next.map((d) => d.displayName).take(3).join(', ');
      final extra = next.length > 3 ? ' +${next.length - 3} more' : '';
      final plural = next.length == 1 ? '' : 's';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${next.length} new device$plural: $names$extra'),
          duration: const Duration(seconds: 5),
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const Icon(Icons.explore_outlined),
            const SizedBox(width: 8),
            const Text('Sextant'),
            const SizedBox(width: 24),
            Expanded(
              child: networksAsync.when(
                data: (networks) => _Toolbar(networks: networks),
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (e, _) => Text('Network error: $e'),
              ),
            ),
          ],
        ),
        bottom: scan.isScanning
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  // Determinate once we know the subnet size; indeterminate
                  // for the brief moment before the host count is known.
                  value: scan.total > 0 ? scan.progress : null,
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          _StatusBar(),
          const Divider(height: 1),
          const _DeviceTableHeader(),
          const Divider(height: 1),
          Expanded(
            child: scan.devices.isEmpty
                ? Center(
                    child: Text(
                      scan.isBusy
                          ? 'Scanning…'
                          : 'Press SCAN to discover devices on your network.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    itemCount: scan.devices.length,
                    itemBuilder: (context, i) => DeviceRow(
                      device: scan.devices[i],
                      tinted: i.isOdd,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.networks});

  final List<ScanNetwork> networks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedNetworkProvider);
    final scan = ref.watch(scanControllerProvider);
    final effective = effectiveNetwork(networks, selected);

    return Row(
      children: [
        if (networks.isEmpty)
          const Text('No active network found')
        else
          DropdownButton<ScanNetwork>(
            value: effective,
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
                      Text('${n.displayName}  '
                          '(${n.subnet.networkAddress.address}'
                          '/${n.subnet.prefixLength})'),
                    ],
                  ),
                ),
            ],
            onChanged: scan.isBusy
                ? null
                : (n) => ref
                    .read(selectedNetworkProvider.notifier)
                    .select(n),
          ),
        const SizedBox(width: 16),
        if (scan.isBusy)
          FilledButton.tonalIcon(
            onPressed: () =>
                ref.read(scanControllerProvider.notifier).stopScan(),
            icon: const Icon(Icons.stop),
            label: const Text('STOP'),
          )
        else
          FilledButton.icon(
            onPressed: effective == null
                ? null
                : () => ref
                    .read(scanControllerProvider.notifier)
                    .startScan(effective),
            icon: const Icon(Icons.radar),
            label: const Text('SCAN'),
          ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: scan.isMonitoring
              ? 'Stop live monitoring'
              : 'Live monitoring — re-scan and alert on new devices',
          isSelected: scan.isMonitoring,
          selectedIcon: const Icon(Icons.sensors),
          icon: const Icon(Icons.sensors_off_outlined),
          onPressed: effective == null
              ? null
              : () => ref
                  .read(scanControllerProvider.notifier)
                  .toggleMonitoring(effective),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<ExportFormat>(
          tooltip: 'Export scan',
          enabled: scan.devices.isNotEmpty && !scan.isBusy,
          icon: const Icon(Icons.download_outlined),
          onSelected: (format) => exportScan(context, scan.devices, format),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: ExportFormat.csv,
              child: Text('Export as CSV…'),
            ),
            PopupMenuItem(
              value: ExportFormat.json,
              child: Text('Export as JSON…'),
            ),
          ],
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Scan history',
          icon: const Icon(Icons.history),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const HistoryScreen(),
            ),
          ),
        ),
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
        content: Text('Exported ${devices.length} devices to ${location.path}'),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

class _StatusBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(scanControllerProvider);
    final style = Theme.of(context).textTheme.bodySmall;
    final online = scan.devices.where((d) => d.isOnline).length;
    final offline = scan.devices.length - online;
    // Suffix shown once at least one device has gone offline, so the counts
    // reflect devices coming back online (not just the unchanging total).
    final offlineSuffix = offline > 0 ? ', $offline offline' : '';
    final String status;
    if (scan.isScanning) {
      status = 'Scanning… ${scan.devices.length} found, '
          'scanned ${scan.scanned} of ${scan.total}';
    } else if (scan.enriching) {
      status = 'Resolving MAC addresses… ${scan.devices.length} found';
    } else if (scan.isMonitoring) {
      status = 'Monitoring… $online online$offlineSuffix';
    } else if (scan.devices.isNotEmpty) {
      status = '$online online$offlineSuffix';
    } else {
      status = 'Idle';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (scan.isMonitoring) ...[
            Icon(Icons.sensors,
                size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
          ],
          Text(status, style: style),
        ],
      ),
    );
  }
}

const _kIpWidth = 130.0;
const _kMacWidth = 150.0;
const _kIconWidth = 40.0;

class _DeviceTableHeader extends StatelessWidget {
  const _DeviceTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .labelMedium
        ?.copyWith(fontWeight: FontWeight.bold);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: _kIconWidth),
          SizedBox(width: _kIpWidth, child: Text('IP address', style: style)),
          Expanded(flex: 3, child: Text('Name', style: style)),
          SizedBox(width: _kMacWidth, child: Text('MAC', style: style)),
          Expanded(flex: 2, child: Text('Vendor', style: style)),
          Expanded(flex: 3, child: Text('Open ports', style: style)),
          SizedBox(width: 80, child: Text('Found via', style: style)),
          SizedBox(width: 56, child: Text('Latency', style: style)),
        ],
      ),
    );
  }
}

class DeviceRow extends ConsumerWidget {
  const DeviceRow({super.key, required this.device, this.tinted = false});

  final Device device;

  /// Whether this row gets the alternating (zebra) background tint.
  final bool tinted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: _kIconWidth,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusDot(online: device.isOnline, latencyMs: device.latencyMs),
                const SizedBox(width: 6),
                Tooltip(
                  message: device.isOnline
                      ? deviceTypeLabel(device.deviceType)
                      : '${deviceTypeLabel(device.deviceType)} · offline',
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
            width: _kIpWidth,
            child: Text(
              device.ip,
              style: TextStyle(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: offline ? muted : null,
              ),
            ),
          ),
          Expanded(
            flex: 3,
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
                decoration: offline ? TextDecoration.lineThrough : null,
                decorationColor: muted,
              ),
            ),
          ),
          SizedBox(
            width: _kMacWidth,
            child: Text(device.mac ?? '—', style: offline ? mutedSmall : small),
          ),
          Expanded(
            flex: 2,
            child: Text(
              device.vendor ?? '—',
              overflow: TextOverflow.ellipsis,
              style: offline ? mutedSmall : small,
            ),
          ),
          Expanded(
            flex: 3,
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
            width: 80,
            child: Wrap(
              spacing: 4,
              children: [
                for (final source in device.discoveredBy)
                  Tooltip(
                    message: discoverySourceLabel(source),
                    child: Icon(
                      discoverySourceIcon(source),
                      size: 16,
                      color: offline ? muted : null,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            child: ref.watch(latencyHistoryProvider(identity)).maybeWhen(
                  data: (values) => LatencySparkline(values: values),
                  orElse: () => const SizedBox.shrink(),
                ),
          ),
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

  Future<void> _showMenu(
    BuildContext context,
    WidgetRef ref,
    Offset? globalPosition,
  ) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = globalPosition ?? overlay.size.center(Offset.zero);
    final canOpenWeb = device.openPorts.contains(80) ||
        device.openPorts.contains(443);

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
                Text('Discovered via',
                    style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 4),
                for (final source in device.discoveredBy)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(discoverySourceIcon(source), size: 16),
                        const SizedBox(width: 8),
                        Text(discoverySourceLabel(source)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        if (canOpenWeb)
          const PopupMenuItem(
            value: 'open',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.open_in_browser),
              title: Text('Open in browser'),
            ),
          ),
        const PopupMenuItem(
          value: 'rename',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.drive_file_rename_outline),
            title: Text('Rename…'),
          ),
        ),
        PopupMenuItem(
          value: 'type',
          child: ListTile(
            dense: true,
            leading: Icon(deviceTypeIcon(device.deviceType)),
            title: const Text('Change type…'),
          ),
        ),
        const PopupMenuItem(
          value: 'copy_ip',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.copy),
            title: Text('Copy IP'),
          ),
        ),
        if (device.mac != null)
          const PopupMenuItem(
            value: 'copy_mac',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.copy_all),
              title: Text('Copy MAC'),
            ),
          ),
        if (device.mac != null)
          const PopupMenuItem(
            value: 'wake',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.flash_on_outlined),
              title: Text('Wake on LAN'),
            ),
          ),
      ],
    );
    if (selected == null) return;
    switch (selected) {
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      await const WakeOnLan().send(device.mac!);
      messenger.showSnackBar(
        SnackBar(content: Text('Magic packet sent to ${device.mac}')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not send magic packet: $e')),
      );
    }
  }

  Future<void> _renameDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: device.customName ?? '');
    final name = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename ${device.ip}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Device name',
            hintText: 'e.g. Office Printer',
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null) return; // cancelled
    await ref.read(scanControllerProvider.notifier).renameDevice(
          device,
          name.isEmpty ? null : name,
        );
  }

  Future<void> _changeTypeDialog(BuildContext context, WidgetRef ref) async {
    const sentinelAuto = 'auto';
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Device type · ${device.ip}'),
        children: [
          for (final type in DeviceType.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, type.name),
              child: Row(
                children: [
                  Icon(deviceTypeIcon(type), size: 20),
                  const SizedBox(width: 12),
                  Text(deviceTypeLabel(type)),
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
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, size: 20),
                SizedBox(width: 12),
                Text('Reset to automatic'),
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
    final latency = latencyMs == null
        ? ''
        : ' · ${latencyMs! < 1 ? '<1' : latencyMs!.toStringAsFixed(0)} ms';
    return Tooltip(
      message: (online ? 'Online' : 'Offline') + latency,
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
    final known = service != null;
    final label = kWellKnownPorts[port];
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: known
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$port', style: Theme.of(context).textTheme.labelSmall),
    );
    final tip = [
      if (label != null) '$port · $label' else '$port',
      if (service != null) '→ $service',
    ].join('  ');
    return Tooltip(message: tip, child: chip);
  }
}
