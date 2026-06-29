import 'package:flutter/material.dart';

import 'scan_protocol.dart';

/// Persisted, user-configurable app settings. Defaults below exactly match
/// this app's previously-hardcoded behavior, so adding this feature changes
/// nothing until a user touches a control.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
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
  final int monitorIntervalSeconds;
  final Set<ScanProtocol> enabledProtocols;
  final bool historyEnabled;
  final int historyRetention;
  final bool vendorDbAutoRefresh;
  final int vendorDbRefreshIntervalDays;

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? monitorIntervalSeconds,
    Set<ScanProtocol>? enabledProtocols,
    bool? historyEnabled,
    int? historyRetention,
    bool? vendorDbAutoRefresh,
    int? vendorDbRefreshIntervalDays,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
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
        monitorIntervalSeconds,
        enabledProtocols.length,
        historyEnabled,
        historyRetention,
        vendorDbAutoRefresh,
        vendorDbRefreshIntervalDays,
      );
}
