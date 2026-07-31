import 'package:flutter/material.dart';

import 'scan_protocol.dart';

/// Persisted, user-configurable app settings. Defaults below exactly match
/// this app's previously-hardcoded behavior, so adding this feature changes
/// nothing until a user touches a control.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.locale,
    this.monitorIntervalSeconds = 30,
    this.enabledProtocols = const {
      ScanProtocol.icmp,
      ScanProtocol.arp,
      ScanProtocol.tcp,
      ScanProtocol.mdns,
      ScanProtocol.netbios,
      ScanProtocol.ssdp,
    },
    this.historyEnabled = true,
    this.historyRetention = 500,
    this.vendorDbAutoRefresh = true,
    this.vendorDbRefreshIntervalDays = 30,
  });

  final ThemeMode themeMode;

  /// The user's chosen display language, or null to follow the system locale.
  final Locale? locale;
  final int monitorIntervalSeconds;
  final Set<ScanProtocol> enabledProtocols;
  final bool historyEnabled;
  final int historyRetention;
  final bool vendorDbAutoRefresh;
  final int vendorDbRefreshIntervalDays;

  /// [locale] defaults to this sentinel (rather than being nullable in the
  /// signature) so callers can distinguish "leave unchanged" from "set back
  /// to system default" (an explicit `null`) — the same ambiguity
  /// [Locale]-as-null already carries in [AppSettings.locale] itself.
  static const _unsetLocale = Object();

  AppSettings copyWith({
    ThemeMode? themeMode,
    Object? locale = _unsetLocale,
    int? monitorIntervalSeconds,
    Set<ScanProtocol>? enabledProtocols,
    bool? historyEnabled,
    int? historyRetention,
    bool? vendorDbAutoRefresh,
    int? vendorDbRefreshIntervalDays,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: identical(locale, _unsetLocale) ? this.locale : locale as Locale?,
      monitorIntervalSeconds:
          monitorIntervalSeconds ?? this.monitorIntervalSeconds,
      enabledProtocols: enabledProtocols ?? this.enabledProtocols,
      historyEnabled: historyEnabled ?? this.historyEnabled,
      historyRetention: historyRetention ?? this.historyRetention,
      vendorDbAutoRefresh: vendorDbAutoRefresh ?? this.vendorDbAutoRefresh,
      vendorDbRefreshIntervalDays:
          vendorDbRefreshIntervalDays ?? this.vendorDbRefreshIntervalDays,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.locale == locale &&
      other.monitorIntervalSeconds == monitorIntervalSeconds &&
      other.enabledProtocols.length == enabledProtocols.length &&
      other.enabledProtocols.containsAll(enabledProtocols) &&
      other.historyEnabled == historyEnabled &&
      other.historyRetention == historyRetention &&
      other.vendorDbAutoRefresh == vendorDbAutoRefresh &&
      other.vendorDbRefreshIntervalDays == vendorDbRefreshIntervalDays;

  @override
  int get hashCode => Object.hash(
        themeMode,
        locale,
        monitorIntervalSeconds,
        enabledProtocols.length,
        historyEnabled,
        historyRetention,
        vendorDbAutoRefresh,
        vendorDbRefreshIntervalDays,
      );
}
