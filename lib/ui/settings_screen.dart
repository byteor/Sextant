import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/app_settings.dart';
import '../model/scan_protocol.dart';
import '../state/settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load settings: $e')),
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: const [
            _AppearanceSection(),
            _ScanningSection(),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(label, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider).value?.themeMode ??
        ThemeMode.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Appearance'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
            ],
            selected: {themeMode},
            onSelectionChanged: (selection) => ref
                .read(settingsProvider.notifier)
                .setThemeMode(selection.first),
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }
}

const _intervalPresets = [10, 30, 60, 120, 300];
String _intervalLabel(int seconds) =>
    seconds < 60 ? '${seconds}s' : '${seconds ~/ 60} min';

class _ScanningSection extends ConsumerWidget {
  const _ScanningSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Scanning'),
        ListTile(
          title: const Text('Auto-refresh interval'),
          trailing: DropdownButton<int>(
            value: settings.monitorIntervalSeconds,
            items: [
              for (final s in _intervalPresets)
                DropdownMenuItem(value: s, child: Text(_intervalLabel(s))),
            ],
            onChanged: (s) => s == null
                ? null
                : ref
                    .read(settingsProvider.notifier)
                    .setMonitorIntervalSeconds(s),
          ),
        ),
        for (final protocol in ScanProtocol.values)
          SwitchListTile(
            title: Text(protocol.label),
            subtitle: protocol.isAvailableOnThisPlatform
                ? null
                : const Text('Not available on this platform'),
            value: protocol.isAvailableOnThisPlatform &&
                settings.enabledProtocols.contains(protocol),
            onChanged: !protocol.isAvailableOnThisPlatform
                ? null
                : (v) => ref
                    .read(settingsProvider.notifier)
                    .setProtocolEnabled(protocol, v),
          ),
        const Divider(height: 24),
      ],
    );
  }
}
