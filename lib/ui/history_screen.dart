import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/scan_diff.dart';
import '../data/scan_history.dart';
import '../state/providers.dart';
import 'device_visuals.dart';

/// Browsable scan history grouped by network (most-recent network first), each
/// network showing a change log derived from diffing its consecutive scans.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(scanHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          historyAsync.maybeWhen(
            data: (groups) => groups.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Clear all history',
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: () => _confirmClear(context, ref),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load history: $e')),
        data: (groups) => groups.isEmpty
            ? const _EmptyHistory()
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final group in groups) _NetworkHistorySection(group),
                ],
              ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear scan history?'),
        content: const Text(
          'This permanently deletes all saved scan snapshots and their change '
          'logs. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(historyDatabaseProvider).clearHistory();
    ref.invalidate(scanHistoryProvider);
  }
}

class _NetworkHistorySection extends StatelessWidget {
  const _NetworkHistorySection(this.group);

  final NetworkScanHistory group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = changeLog(group.scans);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.lan_outlined),
        title: Text(group.networkLabel,
            style: theme.textTheme.titleMedium),
        subtitle: Text(
          '${group.scans.length} scan${group.scans.length == 1 ? '' : 's'} · '
          'latest ${_formatTime(group.latest.timestamp)} · '
          '${group.latest.deviceCount} devices',
        ),
        children: [
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('No changes recorded yet — this is the baseline.'),
              ),
            )
          else
            for (final entry in entries) _ChangeTile(entry),
        ],
      ),
    );
  }
}

class _ChangeTile extends StatelessWidget {
  const _ChangeTile(this.entry);

  final ScanChangeEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _kindVisual(entry.kind, theme);

    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 20),
      title: Row(
        children: [
          Icon(deviceTypeIcon(entry.device.deviceType),
              size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              entry.device.displayName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Text(_describe(entry)),
      trailing: Text(
        _formatTime(entry.timestamp),
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  static (IconData, Color) _kindVisual(ScanChangeKind kind, ThemeData theme) {
    switch (kind) {
      case ScanChangeKind.appeared:
        return (Icons.add_circle_outline, Colors.green.shade600);
      case ScanChangeKind.disappeared:
        return (Icons.remove_circle_outline, theme.colorScheme.outline);
      case ScanChangeKind.changed:
        return (Icons.sync_alt, theme.colorScheme.primary);
    }
  }

  String _describe(ScanChangeEntry entry) {
    final ip = entry.device.ip;
    switch (entry.kind) {
      case ScanChangeKind.appeared:
        return 'Appeared · $ip';
      case ScanChangeKind.disappeared:
        return 'Disappeared · last at $ip';
      case ScanChangeKind.changed:
        final what = entry.fields.map(_fieldLabel).join(', ');
        return 'Changed $what · $ip';
    }
  }

  static String _fieldLabel(DeviceChangeField field) {
    switch (field) {
      case DeviceChangeField.ip:
        return 'IP';
      case DeviceChangeField.hostname:
        return 'hostname';
      case DeviceChangeField.vendor:
        return 'vendor';
      case DeviceChangeField.deviceType:
        return 'type';
      case DeviceChangeField.openPorts:
        return 'open ports';
    }
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history,
              size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('No scan history yet.', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Run a scan or enable monitoring — snapshots are saved automatically.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Formats a timestamp as a compact local date-time, e.g. "Jun 22, 14:30".
String _formatTime(DateTime utc) {
  final t = utc.toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${months[t.month - 1]} ${t.day}, $hh:$mm';
}
