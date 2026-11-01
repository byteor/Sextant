import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/history_database.dart';
import '../l10n/gen/app_localizations.dart';
import '../state/providers.dart';
import 'device_visuals.dart';

/// Lists every device ever recorded as newly-discovered on [networkId],
/// newest first. Behaves like an inbox: entries unread when the dialog opens
/// are highlighted, and opening the dialog immediately marks them read (via
/// [acknowledgeNewDevices]) so they no longer show as new next time.
class NewDevicesDialog extends ConsumerStatefulWidget {
  const NewDevicesDialog({super.key, required this.networkId});

  final String networkId;

  @override
  ConsumerState<NewDevicesDialog> createState() => _NewDevicesDialogState();
}

class _NewDevicesDialogState extends ConsumerState<NewDevicesDialog> {
  late final Future<List<SeenDevice>> _entries;

  @override
  void initState() {
    super.initState();
    // Snapshot which entries are unread *before* acknowledging them, so this
    // one render can still highlight them — like opening an email, the
    // unread mark clears the moment the list is opened, not when it's
    // closed, but the just-opened view should still show what was new.
    final db = ref.read(historyDatabaseProvider);
    _entries = db.recentlySeenDevices(widget.networkId).then((entries) async {
      await acknowledgeNewDevices(ref, widget.networkId);
      return entries;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.newDevicesDialogTitle),
      content: SizedBox(
        width: 420,
        height: 420,
        child: FutureBuilder<List<SeenDevice>>(
          future: _entries,
          builder: (context, snapshot) {
            final entries = snapshot.data;
            if (entries == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (entries.isEmpty) {
              return Center(child: Text(l10n.noNewDevicesYet));
            }
            return ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _EntryTile(entries[i]),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile(this.entry);

  final SeenDevice entry;

  @override
  Widget build(BuildContext context) {
    final unread = !entry.acknowledged;
    final theme = Theme.of(context);
    return Container(
      color: unread ? Colors.green.withValues(alpha: 0.12) : null,
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.devices_other,
          color: unread ? theme.colorScheme.primary : null,
        ),
        title: Text(
          entry.label,
          style: TextStyle(
            fontWeight: unread ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          '${entry.ip} · ${formatScanTimestamp(entry.firstSeenAt)}',
        ),
      ),
    );
  }
}
