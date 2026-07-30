import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/gen/app_localizations.dart';
import '../l10n/supported_locales.dart';
import '../model/app_settings.dart';
import '../model/scan_protocol.dart';
import '../state/providers.dart';
import '../state/settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(l10n.settingsLoadError(e.toString()))),
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: const [
            _AppearanceSection(),
            _LanguageSection(),
            _ScanningSection(),
            _HistorySection(),
            _VendorDatabaseSection(),
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
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(settingsProvider).value?.themeMode ??
        ThemeMode.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(l10n.sectionAppearance),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                  value: ThemeMode.light, label: Text(l10n.appearanceLight)),
              ButtonSegment(
                  value: ThemeMode.dark, label: Text(l10n.appearanceDark)),
              ButtonSegment(
                  value: ThemeMode.system, label: Text(l10n.appearanceAuto)),
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

/// `null` represents "System default" — matches [AppSettings.locale]'s own
/// null-means-system convention.
class _LanguageSection extends ConsumerWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(settingsProvider).value?.locale;

    // Sorted by each language's own native name (not by locale code), so the
    // list reads alphabetically regardless of the order locales were added
    // to kSupportedLocales in. "System default" stays pinned above it — it's
    // a meta option, not a language.
    final sortedLocales = [...kSupportedLocales]..sort(
        (a, b) => _nativeName(a).compareTo(_nativeName(b)),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(l10n.sectionLanguage),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButton<Locale?>(
            value: locale,
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(l10n.languageSystemDefault),
              ),
              for (final supported in sortedLocales)
                DropdownMenuItem(
                  value: supported,
                  child: Text(_nativeName(supported)),
                ),
            ],
            onChanged: (selected) => ref
                .read(settingsProvider.notifier)
                .setLocale(selected),
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }

  static String _nativeName(Locale locale) =>
      kLocaleNativeNames[locale.languageCode] ?? locale.languageCode;
}

const _intervalPresets = [10, 30, 60, 120, 300];
String _intervalLabel(AppLocalizations l10n, int seconds) => seconds < 60
    ? l10n.durationSeconds(seconds)
    : l10n.durationMinutes(seconds ~/ 60);

class _ScanningSection extends ConsumerWidget {
  const _ScanningSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(l10n.sectionScanning),
        ListTile(
          title: Text(l10n.autoRefreshInterval),
          trailing: DropdownButton<int>(
            value: settings.monitorIntervalSeconds,
            items: [
              for (final s in _intervalPresets)
                DropdownMenuItem(value: s, child: Text(_intervalLabel(l10n, s))),
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
            title: Text(protocol.label(l10n)),
            subtitle: protocol.isAvailableOnThisPlatform
                ? null
                : Text(l10n.protocolNotAvailable),
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

const _retentionPresets = [100, 250, 500, 1000, 2000];

class _HistorySection extends ConsumerWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(l10n.sectionHistory),
        SwitchListTile(
          title: Text(l10n.saveScanHistory),
          value: settings.historyEnabled,
          onChanged: (v) =>
              ref.read(settingsProvider.notifier).setHistoryEnabled(v),
        ),
        ListTile(
          title: Text(l10n.retentionTitle),
          subtitle: Text(l10n.retentionSubtitle),
          enabled: settings.historyEnabled,
          trailing: DropdownButton<int>(
            value: settings.historyRetention,
            items: [
              for (final r in _retentionPresets)
                DropdownMenuItem(value: r, child: Text('$r')),
            ],
            onChanged: !settings.historyEnabled
                ? null
                : (r) => r == null
                    ? null
                    : ref
                        .read(settingsProvider.notifier)
                        .setHistoryRetention(r),
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }
}

const _vendorDbIntervalPresets = [7, 14, 30, 90];

class _VendorDatabaseSection extends ConsumerWidget {
  const _VendorDatabaseSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(l10n.sectionVendorDatabase),
        ListTile(
          title: Text(l10n.vendorDbUpdateTitle),
          subtitle: Text(l10n.vendorDbUpdateSubtitle),
          trailing: FilledButton(
            onPressed: () => _refreshNow(context, ref),
            child: Text(l10n.refreshNow),
          ),
        ),
        SwitchListTile(
          title: Text(l10n.vendorDbAutoRefresh),
          value: settings.vendorDbAutoRefresh,
          onChanged: (v) => ref
              .read(settingsProvider.notifier)
              .setVendorDbAutoRefresh(v),
        ),
        ListTile(
          title: Text(l10n.vendorDbAutoRefreshInterval),
          enabled: settings.vendorDbAutoRefresh,
          trailing: DropdownButton<int>(
            value: settings.vendorDbRefreshIntervalDays,
            items: [
              for (final d in _vendorDbIntervalPresets)
                DropdownMenuItem(
                    value: d, child: Text(l10n.vendorDbIntervalDays(d))),
            ],
            onChanged: !settings.vendorDbAutoRefresh
                ? null
                : (d) => d == null
                    ? null
                    : ref
                        .read(settingsProvider.notifier)
                        .setVendorDbRefreshIntervalDays(d),
          ),
        ),
      ],
    );
  }

  Future<void> _refreshNow(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final refreshed = await refreshVendorDatabaseNow(ref);
    messenger.showSnackBar(SnackBar(
      content: Text(refreshed
          ? l10n.vendorDbRefreshedSuccess
          : l10n.vendorDbRefreshFailed),
    ));
  }
}
