// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String settingsLoadError(String error) {
    return 'Could not load settings: $error';
  }

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get appearanceAuto => 'Auto';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get sectionScanning => 'Scanning';

  @override
  String get autoRefreshInterval => 'Auto-refresh interval';

  @override
  String durationSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String durationMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
      one: '$minutes min',
    );
    return '$_temp0';
  }

  @override
  String get protocolNotAvailable => 'Not available on this platform';

  @override
  String get protocolIcmp => 'ICMP ping sweep';

  @override
  String get protocolArp => 'ARP table';

  @override
  String get protocolTcp => 'TCP port scan';

  @override
  String get protocolMdns => 'mDNS / Bonjour';

  @override
  String get protocolNetbios => 'NetBIOS';

  @override
  String get protocolSsdp => 'SSDP / UPnP';

  @override
  String get sectionHistory => 'History';

  @override
  String get saveScanHistory => 'Save scan history';

  @override
  String get retentionTitle => 'Retention';

  @override
  String get retentionSubtitle => 'Maximum saved scan snapshots';

  @override
  String get sectionVendorDatabase => 'Vendor database';

  @override
  String get vendorDbUpdateTitle => 'Update from the IEEE registry';

  @override
  String get vendorDbUpdateSubtitle => 'Improves MAC-address vendor names';

  @override
  String get refreshNow => 'Refresh now';

  @override
  String get vendorDbAutoRefresh => 'Auto-refresh vendor database';

  @override
  String get vendorDbAutoRefreshInterval => 'Auto-refresh interval';

  @override
  String vendorDbIntervalDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '$days day',
    );
    return '$_temp0';
  }

  @override
  String get vendorDbRefreshedSuccess => 'Vendor database refreshed.';

  @override
  String get vendorDbRefreshFailed =>
      'Could not refresh vendor database — check your connection.';

  @override
  String get historyTitle => 'Scan History';

  @override
  String get clearAllHistoryTooltip => 'Clear all history';

  @override
  String historyLoadError(String error) {
    return 'Could not load history: $error';
  }

  @override
  String get clearHistoryDialogTitle => 'Clear scan history?';

  @override
  String get clearHistoryDialogBody =>
      'This permanently deletes all saved scan snapshots and their change logs. This cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get clear => 'Clear';

  @override
  String get noChangesRecorded =>
      'No changes recorded yet — this is the baseline.';

  @override
  String historyScanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# scans',
      one: '# scan',
    );
    return '$_temp0';
  }

  @override
  String historyDeviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# devices',
      one: '# device',
    );
    return '$_temp0';
  }

  @override
  String historySummaryLine(String scans, String time, String devices) {
    return '$scans · latest $time · $devices';
  }

  @override
  String get noScanHistoryYet => 'No scan history yet.';

  @override
  String get runScanHint =>
      'Run a scan or enable monitoring — snapshots are saved automatically.';

  @override
  String changeAppeared(String ip) {
    return 'Appeared · $ip';
  }

  @override
  String changeDisappeared(String ip) {
    return 'Disappeared · last at $ip';
  }

  @override
  String changeChanged(String fields, String ip) {
    return 'Changed $fields · $ip';
  }

  @override
  String get fieldIp => 'IP';

  @override
  String get fieldHostname => 'hostname';

  @override
  String get fieldVendor => 'vendor';

  @override
  String get fieldType => 'type';

  @override
  String get fieldOpenPorts => 'open ports';

  @override
  String get sourceTcp => 'TCP';

  @override
  String get sourceIcmp => 'ICMP';

  @override
  String get sourceArp => 'ARP';

  @override
  String get sourceMdns => 'mDNS';

  @override
  String get sourceBonjour => 'Bonjour';

  @override
  String get sourceNetbios => 'NetBIOS';

  @override
  String get sourceSsdp => 'SSDP';

  @override
  String get typeRouter => 'Router';

  @override
  String get typeComputer => 'Computer';

  @override
  String get typeLaptop => 'Laptop';

  @override
  String get typePhone => 'Phone';

  @override
  String get typeTablet => 'Tablet';

  @override
  String get typePrinter => 'Printer';

  @override
  String get typeTv => 'TV';

  @override
  String get typeSpeaker => 'Speaker';

  @override
  String get typeCamera => 'Camera';

  @override
  String get typeNas => 'NAS';

  @override
  String get typeServer => 'Server';

  @override
  String get typeIot => 'IoT';

  @override
  String get typeUnknown => 'Unknown';

  @override
  String get aboutTitle => 'Sextant';

  @override
  String get aboutBody =>
      'A lightweight LAN scanner for discovering and monitoring devices on your local network.';

  @override
  String get builtWithFlutter => 'Built with Flutter.';

  @override
  String get close => 'Close';

  @override
  String get networkChangedSnackbar =>
      'Network changed — updating available networks…';

  @override
  String newDeviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# new devices',
      one: '# new device',
    );
    return '$_temp0';
  }

  @override
  String newDeviceAlert(String countLabel, String names) {
    return '$countLabel: $names';
  }

  @override
  String newDeviceMore(int count) {
    return '+$count more';
  }

  @override
  String get noActiveNetworkFound => 'No active network found';

  @override
  String networkOption(String name, String address, int prefix) {
    return '$name  ($address/$prefix)';
  }

  @override
  String get scanButtonLabel => 'SCAN';

  @override
  String get stopButtonLabel => 'STOP';

  @override
  String get monitoringStopTooltip => 'Stop live monitoring';

  @override
  String get monitoringStartTooltip =>
      'Live monitoring — re-scan and alert on new devices';

  @override
  String get exportScanTooltip => 'Export scan';

  @override
  String get exportAsCsv => 'Export as CSV…';

  @override
  String get exportAsJson => 'Export as JSON…';

  @override
  String get scanHistoryTooltip => 'Scan history';

  @override
  String get aboutTooltip => 'About';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String exportedDevices(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Exported # devices to $path',
      one: 'Exported # device to $path',
    );
    return '$_temp0';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String scanningStatus(int found, int scanned, int total) {
    return 'Scanning… $found found, scanned $scanned of $total';
  }

  @override
  String resolvingMacAddresses(int found) {
    return 'Resolving MAC addresses… $found found';
  }

  @override
  String monitoringStatus(int online, String offlineSuffix) {
    return 'Monitoring… $online online$offlineSuffix';
  }

  @override
  String onlineStatus(int online, String offlineSuffix) {
    return '$online online$offlineSuffix';
  }

  @override
  String offlineSuffix(int count) {
    return ', $count offline';
  }

  @override
  String get idleStatus => 'Idle';

  @override
  String get scanningEllipsis => 'Scanning…';

  @override
  String get pressScanHint => 'Press SCAN to discover devices on your network.';

  @override
  String get columnIp => 'IP address';

  @override
  String get columnName => 'Name';

  @override
  String get columnMac => 'MAC';

  @override
  String get columnVendor => 'Vendor';

  @override
  String get columnOpenPorts => 'Open ports';

  @override
  String get columnFoundVia => 'Found via';

  @override
  String get columnLatency => 'Latency';

  @override
  String alsoSeenAt(String ips) {
    return 'Also seen at: $ips';
  }

  @override
  String get discoveredVia => 'Discovered via';

  @override
  String get openInBrowser => 'Open in browser';

  @override
  String get renameEllipsis => 'Rename…';

  @override
  String get changeTypeEllipsis => 'Change type…';

  @override
  String get copyIp => 'Copy IP';

  @override
  String get copyMac => 'Copy MAC';

  @override
  String get wakeOnLan => 'Wake on LAN';

  @override
  String magicPacketSent(String mac) {
    return 'Magic packet sent to $mac';
  }

  @override
  String magicPacketFailed(String error) {
    return 'Could not send magic packet: $error';
  }

  @override
  String renameDialogTitle(String ip) {
    return 'Rename $ip';
  }

  @override
  String get deviceNameLabel => 'Device name';

  @override
  String get deviceNameHint => 'e.g. Office Printer';

  @override
  String get save => 'Save';

  @override
  String deviceTypeDialogTitle(String ip) {
    return 'Device type · $ip';
  }

  @override
  String get resetToAutomatic => 'Reset to automatic';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusOffline => 'Offline';

  @override
  String deviceTypeOfflineTooltip(String type) {
    return '$type · offline';
  }

  @override
  String latencySuffix(String ms) {
    return ' · $ms ms';
  }

  @override
  String portWithLabel(int port, String label) {
    return '$port · $label';
  }

  @override
  String portService(String service) {
    return '→ $service';
  }
}
