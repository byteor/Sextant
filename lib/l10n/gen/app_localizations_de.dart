// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String settingsLoadError(String error) {
    return 'Einstellungen konnten nicht geladen werden: $error';
  }

  @override
  String get sectionAppearance => 'Design';

  @override
  String get appearanceLight => 'Hell';

  @override
  String get appearanceDark => 'Dunkel';

  @override
  String get appearanceAuto => 'Automatisch';

  @override
  String get sectionLanguage => 'Sprache';

  @override
  String get languageSystemDefault => 'Systemstandard';

  @override
  String get sectionScanning => 'Scannen';

  @override
  String get autoRefreshInterval => 'Intervall für automatische Aktualisierung';

  @override
  String durationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String durationMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes Min.',
    );
    return '$_temp0';
  }

  @override
  String get protocolNotAvailable => 'Auf dieser Plattform nicht verfügbar';

  @override
  String get protocolIcmp => 'ICMP-Ping-Scan';

  @override
  String get protocolArp => 'ARP-Tabelle';

  @override
  String get protocolTcp => 'TCP-Port-Scan';

  @override
  String get protocolMdns => 'mDNS / Bonjour';

  @override
  String get protocolNetbios => 'NetBIOS';

  @override
  String get protocolSsdp => 'SSDP / UPnP';

  @override
  String get sectionHistory => 'Verlauf';

  @override
  String get saveScanHistory => 'Verlauf speichern';

  @override
  String get retentionTitle => 'Verlaufstiefe';

  @override
  String get retentionSubtitle => 'Maximale Anzahl gespeicherter Scans';

  @override
  String get sectionVendorDatabase => 'Hersteller-Datenbank';

  @override
  String get vendorDbUpdateTitle => 'Aus dem IEEE-Register aktualisieren';

  @override
  String get vendorDbUpdateSubtitle =>
      'Verbessert die Herstellernamen anhand der MAC-Adresse';

  @override
  String get refreshNow => 'Jetzt aktualisieren';

  @override
  String get vendorDbAutoRefresh =>
      'Automatische Aktualisierung der Hersteller-Datenbank';

  @override
  String get vendorDbAutoRefreshInterval =>
      'Intervall für automatische Aktualisierung';

  @override
  String vendorDbIntervalDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days Tage',
      one: '$days Tag',
    );
    return '$_temp0';
  }

  @override
  String get vendorDbRefreshedSuccess => 'Hersteller-Datenbank aktualisiert.';

  @override
  String get vendorDbRefreshFailed =>
      'Hersteller-Datenbank konnte nicht aktualisiert werden — Verbindung prüfen.';

  @override
  String get historyTitle => 'Scanverlauf';

  @override
  String get clearAllHistoryTooltip => 'Gesamten Verlauf löschen';

  @override
  String historyLoadError(String error) {
    return 'Verlauf konnte nicht geladen werden: $error';
  }

  @override
  String get clearHistoryDialogTitle => 'Scanverlauf löschen?';

  @override
  String get clearHistoryDialogBody =>
      'Dies löscht den gesamten Scanverlauf und das Änderungsprotokoll dauerhaft. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get clear => 'Löschen';

  @override
  String get noChangesRecorded =>
      'Noch keine Änderungen erfasst — dies ist der Ausgangszustand.';

  @override
  String historyScanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# Scans',
      one: '# Scan',
    );
    return '$_temp0';
  }

  @override
  String historyDeviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# Geräte',
      one: '# Gerät',
    );
    return '$_temp0';
  }

  @override
  String historySummaryLine(String scans, String time, String devices) {
    return '$scans · zuletzt $time · $devices';
  }

  @override
  String get noScanHistoryYet => 'Noch kein Scanverlauf vorhanden.';

  @override
  String get runScanHint =>
      'Starte einen Scan oder aktiviere die Überwachung — Snapshots werden automatisch gespeichert.';

  @override
  String changeAppeared(String ip) {
    return 'Aufgetaucht · $ip';
  }

  @override
  String changeDisappeared(String ip) {
    return 'Verschwunden · zuletzt unter $ip';
  }

  @override
  String changeChanged(String fields, String ip) {
    return 'Geändert: $fields · $ip';
  }

  @override
  String get fieldIp => 'IP';

  @override
  String get fieldHostname => 'Hostname';

  @override
  String get fieldVendor => 'Hersteller';

  @override
  String get fieldType => 'Typ';

  @override
  String get fieldOpenPorts => 'offene Ports';

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
  String get typePhone => 'Telefon';

  @override
  String get typeTablet => 'Tablet';

  @override
  String get typePrinter => 'Drucker';

  @override
  String get typeTv => 'TV';

  @override
  String get typeSpeaker => 'Lautsprecher';

  @override
  String get typeCamera => 'Kamera';

  @override
  String get typeNas => 'NAS';

  @override
  String get typeServer => 'Server';

  @override
  String get typeIot => 'IoT';

  @override
  String get typeUnknown => 'Unbekannt';

  @override
  String get aboutTitle => 'Sextant';

  @override
  String get aboutBody =>
      'LAN-Scanner zum Erkennen und Überwachen von Geräten.';

  @override
  String get builtWithFlutter => 'Erstellt mit Flutter.';

  @override
  String get close => 'Schließen';

  @override
  String get networkChangedSnackbar =>
      'Netzwerk geändert — verfügbare Netzwerke werden aktualisiert…';

  @override
  String newDeviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# neue Geräte',
      one: '# neues Gerät',
    );
    return '$_temp0';
  }

  @override
  String newDeviceAlert(String countLabel, String names) {
    return '$countLabel: $names';
  }

  @override
  String newDeviceMore(int count) {
    return '+$count weitere';
  }

  @override
  String get noActiveNetworkFound => 'Kein aktives Netzwerk gefunden';

  @override
  String networkOption(String name, String address, int prefix) {
    return '$name  ($address/$prefix)';
  }

  @override
  String get scanButtonLabel => 'SCANNEN';

  @override
  String get stopButtonLabel => 'STOPPEN';

  @override
  String get monitoringStopTooltip => 'Live-Überwachung stoppen';

  @override
  String get monitoringStartTooltip =>
      'Live-Überwachung — erneuter Scan und Benachrichtigung bei neuen Geräten';

  @override
  String get exportScanTooltip => 'Scan exportieren';

  @override
  String get exportAsCsv => 'Als CSV exportieren…';

  @override
  String get exportAsJson => 'Als JSON exportieren…';

  @override
  String get scanHistoryTooltip => 'Scanverlauf';

  @override
  String get aboutTooltip => 'Info';

  @override
  String get settingsTooltip => 'Einstellungen';

  @override
  String exportedDevices(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# Geräte nach $path exportiert',
      one: '# Gerät nach $path exportiert',
    );
    return '$_temp0';
  }

  @override
  String exportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String scanningStatus(int found, int scanned, int total) {
    return 'Scannen… $found gefunden, $scanned von $total gescannt';
  }

  @override
  String resolvingMacAddresses(int found) {
    return 'MAC-Adressen werden aufgelöst… $found gefunden';
  }

  @override
  String monitoringStatus(int online, String offlineSuffix) {
    return 'Überwachung… $online online$offlineSuffix';
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
  String get idleStatus => 'Inaktiv';

  @override
  String get scanningEllipsis => 'Scannen…';

  @override
  String get pressScanHint =>
      'Tippe auf SCANNEN, um Geräte in deinem Netzwerk zu finden.';

  @override
  String get columnIp => 'IP-Adresse';

  @override
  String get columnName => 'Name';

  @override
  String get columnMac => 'MAC';

  @override
  String get columnVendor => 'Hersteller';

  @override
  String get columnOpenPorts => 'Offene Ports';

  @override
  String get columnFoundVia => 'Gefunden über';

  @override
  String get columnLatency => 'Latenz';

  @override
  String alsoSeenAt(String ips) {
    return 'Auch gesehen unter: $ips';
  }

  @override
  String get discoveredVia => 'Entdeckt über';

  @override
  String get openInBrowser => 'Im Browser öffnen';

  @override
  String get renameEllipsis => 'Umbenennen…';

  @override
  String get changeTypeEllipsis => 'Typ ändern…';

  @override
  String get copyIp => 'IP kopieren';

  @override
  String get copyMac => 'MAC kopieren';

  @override
  String get wakeOnLan => 'Wake-on-LAN senden';

  @override
  String magicPacketSent(String mac) {
    return 'Magic Packet gesendet an $mac';
  }

  @override
  String magicPacketFailed(String error) {
    return 'Magic Packet konnte nicht gesendet werden: $error';
  }

  @override
  String renameDialogTitle(String ip) {
    return '$ip umbenennen';
  }

  @override
  String get deviceNameLabel => 'Gerätename';

  @override
  String get deviceNameHint => 'z. B. Bürodrucker';

  @override
  String get save => 'Speichern';

  @override
  String deviceTypeDialogTitle(String ip) {
    return 'Gerätetyp · $ip';
  }

  @override
  String get resetToAutomatic => 'Auf automatisch zurücksetzen';

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
