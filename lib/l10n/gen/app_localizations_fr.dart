// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String settingsLoadError(String error) {
    return 'Impossible de charger les paramètres : $error';
  }

  @override
  String get sectionAppearance => 'Thème';

  @override
  String get appearanceLight => 'Clair';

  @override
  String get appearanceDark => 'Sombre';

  @override
  String get appearanceAuto => 'Automatique';

  @override
  String get sectionLanguage => 'Langue';

  @override
  String get languageSystemDefault => 'Système par défaut';

  @override
  String get sectionScanning => 'Analyse';

  @override
  String get autoRefreshInterval => 'Intervalle d\'actualisation automatique';

  @override
  String durationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String durationMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
    );
    return '$_temp0';
  }

  @override
  String get protocolNotAvailable => 'Non disponible sur cette plateforme';

  @override
  String get protocolIcmp => 'Balayage ICMP (ping)';

  @override
  String get protocolArp => 'Table ARP';

  @override
  String get protocolTcp => 'Analyse des ports TCP';

  @override
  String get protocolMdns => 'mDNS / Bonjour';

  @override
  String get protocolNetbios => 'NetBIOS';

  @override
  String get protocolSsdp => 'SSDP / UPnP';

  @override
  String get sectionHistory => 'Historique';

  @override
  String get saveScanHistory => 'Enregistrer l\'historique';

  @override
  String get retentionTitle => 'Profondeur de l\'historique';

  @override
  String get retentionSubtitle => 'Nombre maximal d\'analyses enregistrées';

  @override
  String get sectionVendorDatabase => 'Base des fabricants';

  @override
  String get vendorDbUpdateTitle => 'Mettre à jour depuis le registre IEEE';

  @override
  String get vendorDbUpdateSubtitle =>
      'Améliore les noms de fabricants associés aux adresses MAC';

  @override
  String get refreshNow => 'Actualiser maintenant';

  @override
  String get vendorDbAutoRefresh =>
      'Actualisation automatique de la base des fabricants';

  @override
  String get vendorDbAutoRefreshInterval =>
      'Intervalle d\'actualisation automatique';

  @override
  String vendorDbIntervalDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '$days jour',
    );
    return '$_temp0';
  }

  @override
  String get vendorDbRefreshedSuccess => 'Base des fabricants mise à jour.';

  @override
  String get vendorDbRefreshFailed =>
      'Impossible de mettre à jour la base des fabricants — vérifiez votre connexion.';

  @override
  String get historyTitle => 'Historique des analyses';

  @override
  String get clearAllHistoryTooltip => 'Effacer tout l\'historique';

  @override
  String historyLoadError(String error) {
    return 'Impossible de charger l\'historique : $error';
  }

  @override
  String get clearHistoryDialogTitle => 'Effacer l\'historique des analyses ?';

  @override
  String get clearHistoryDialogBody =>
      'Ceci supprime définitivement tout l\'historique des analyses et son journal des modifications. Cette action est irréversible.';

  @override
  String get cancel => 'Annuler';

  @override
  String get clear => 'Effacer';

  @override
  String get noChangesRecorded =>
      'Aucune modification enregistrée pour l\'instant — il s\'agit de l\'état initial.';

  @override
  String historyScanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# analyses',
      one: '# analyse',
    );
    return '$_temp0';
  }

  @override
  String historyDeviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# appareils',
      one: '# appareil',
    );
    return '$_temp0';
  }

  @override
  String historySummaryLine(String scans, String time, String devices) {
    return '$scans · dernière $time · $devices';
  }

  @override
  String get noScanHistoryYet => 'Aucun historique d\'analyse pour l\'instant.';

  @override
  String get runScanHint =>
      'Lancez une analyse ou activez la surveillance — les instantanés sont enregistrés automatiquement.';

  @override
  String changeAppeared(String ip) {
    return 'Apparu · $ip';
  }

  @override
  String changeDisappeared(String ip) {
    return 'Disparu · vu pour la dernière fois à $ip';
  }

  @override
  String changeChanged(String fields, String ip) {
    return 'Modifié $fields · $ip';
  }

  @override
  String get fieldIp => 'IP';

  @override
  String get fieldHostname => 'nom d\'hôte';

  @override
  String get fieldVendor => 'fabricant';

  @override
  String get fieldType => 'type';

  @override
  String get fieldOpenPorts => 'ports ouverts';

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
  String get typeRouter => 'Routeur';

  @override
  String get typeComputer => 'Ordinateur';

  @override
  String get typeLaptop => 'Ordinateur portable';

  @override
  String get typePhone => 'Téléphone';

  @override
  String get typeTablet => 'Tablette';

  @override
  String get typePrinter => 'Imprimante';

  @override
  String get typeTv => 'TV';

  @override
  String get typeSpeaker => 'Enceinte';

  @override
  String get typeCamera => 'Caméra';

  @override
  String get typeNas => 'NAS';

  @override
  String get typeServer => 'Serveur';

  @override
  String get typeIot => 'IoT';

  @override
  String get typeUnknown => 'Inconnu';

  @override
  String get aboutTitle => 'Sextant';

  @override
  String get aboutBody =>
      'Scanner de réseau local pour découvrir et surveiller les appareils.';

  @override
  String get builtWithFlutter => 'Créé avec Flutter.';

  @override
  String get close => 'Fermer';

  @override
  String get networkChangedSnackbar =>
      'Réseau modifié — mise à jour des réseaux disponibles…';

  @override
  String newDeviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# nouveaux appareils',
      one: '# nouvel appareil',
    );
    return '$_temp0';
  }

  @override
  String newDeviceAlert(String countLabel, String names) {
    return '$countLabel: $names';
  }

  @override
  String newDeviceMore(int count) {
    return '+$count de plus';
  }

  @override
  String get noActiveNetworkFound => 'Aucun réseau actif trouvé';

  @override
  String networkOption(String name, String address, int prefix) {
    return '$name  ($address/$prefix)';
  }

  @override
  String get scanButtonLabel => 'ANALYSER';

  @override
  String get stopButtonLabel => 'ARRÊTER';

  @override
  String get monitoringStopTooltip => 'Arrêter la surveillance en direct';

  @override
  String get monitoringStartTooltip =>
      'Surveillance en direct — nouvelle analyse et alerte en cas de nouveaux appareils';

  @override
  String get exportScanTooltip => 'Exporter l\'analyse';

  @override
  String get exportAsCsv => 'Exporter en CSV…';

  @override
  String get exportAsJson => 'Exporter en JSON…';

  @override
  String get scanHistoryTooltip => 'Historique des analyses';

  @override
  String get aboutTooltip => 'À propos';

  @override
  String get settingsTooltip => 'Paramètres';

  @override
  String exportedDevices(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# appareils exportés vers $path',
      one: '# appareil exporté vers $path',
    );
    return '$_temp0';
  }

  @override
  String exportFailed(String error) {
    return 'Échec de l\'exportation : $error';
  }

  @override
  String scanningStatus(int found, int scanned, int total) {
    return 'Analyse en cours… $found trouvés, $scanned sur $total analysés';
  }

  @override
  String resolvingMacAddresses(int found) {
    return 'Résolution des adresses MAC… $found trouvés';
  }

  @override
  String monitoringStatus(int online, String offlineSuffix) {
    return 'Surveillance… $online en ligne$offlineSuffix';
  }

  @override
  String onlineStatus(int online, String offlineSuffix) {
    return '$online en ligne$offlineSuffix';
  }

  @override
  String offlineSuffix(int count) {
    return ', $count hors ligne';
  }

  @override
  String get idleStatus => 'Inactif';

  @override
  String get scanningEllipsis => 'Analyse en cours…';

  @override
  String get pressScanHint =>
      'Appuyez sur ANALYSER pour découvrir les appareils de votre réseau.';

  @override
  String get columnIp => 'Adresse IP';

  @override
  String get columnName => 'Nom';

  @override
  String get columnMac => 'MAC';

  @override
  String get columnVendor => 'Fabricant';

  @override
  String get columnOpenPorts => 'Ports ouverts';

  @override
  String get columnFoundVia => 'Trouvé via';

  @override
  String get columnLatency => 'Latence';

  @override
  String alsoSeenAt(String ips) {
    return 'Également vu à : $ips';
  }

  @override
  String get discoveredVia => 'Découvert via';

  @override
  String get openInBrowser => 'Ouvrir dans le navigateur';

  @override
  String get renameEllipsis => 'Renommer…';

  @override
  String get changeTypeEllipsis => 'Changer le type…';

  @override
  String get copyIp => 'Copier l\'IP';

  @override
  String get copyMac => 'Copier la MAC';

  @override
  String get wakeOnLan => 'Envoyer Wake-on-LAN';

  @override
  String magicPacketSent(String mac) {
    return 'Paquet magique envoyé à $mac';
  }

  @override
  String magicPacketFailed(String error) {
    return 'Impossible d\'envoyer le paquet magique : $error';
  }

  @override
  String renameDialogTitle(String ip) {
    return 'Renommer $ip';
  }

  @override
  String get deviceNameLabel => 'Nom de l\'appareil';

  @override
  String get deviceNameHint => 'par ex. Imprimante du bureau';

  @override
  String get save => 'Enregistrer';

  @override
  String deviceTypeDialogTitle(String ip) {
    return 'Type d\'appareil · $ip';
  }

  @override
  String get resetToAutomatic => 'Réinitialiser en automatique';

  @override
  String get statusOnline => 'En ligne';

  @override
  String get statusOffline => 'Hors ligne';

  @override
  String deviceTypeOfflineTooltip(String type) {
    return '$type · hors ligne';
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
