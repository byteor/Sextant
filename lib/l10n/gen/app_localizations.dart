import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ru'),
  ];

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load settings: {error}'**
  String settingsLoadError(String error);

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @appearanceLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLight;

  /// No description provided for @appearanceDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceDark;

  /// No description provided for @appearanceAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get appearanceAuto;

  /// No description provided for @sectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get sectionLanguage;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// No description provided for @sectionScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning'**
  String get sectionScanning;

  /// No description provided for @autoRefreshInterval.
  ///
  /// In en, this message translates to:
  /// **'Auto-refresh interval'**
  String get autoRefreshInterval;

  /// No description provided for @durationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String durationSeconds(int seconds);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, one{{minutes} min} other{{minutes} min}}'**
  String durationMinutes(int minutes);

  /// No description provided for @protocolNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on this platform'**
  String get protocolNotAvailable;

  /// No description provided for @protocolIcmp.
  ///
  /// In en, this message translates to:
  /// **'ICMP ping sweep'**
  String get protocolIcmp;

  /// No description provided for @protocolArp.
  ///
  /// In en, this message translates to:
  /// **'ARP table'**
  String get protocolArp;

  /// No description provided for @protocolTcp.
  ///
  /// In en, this message translates to:
  /// **'TCP port scan'**
  String get protocolTcp;

  /// No description provided for @protocolMdns.
  ///
  /// In en, this message translates to:
  /// **'mDNS / Bonjour'**
  String get protocolMdns;

  /// No description provided for @protocolNetbios.
  ///
  /// In en, this message translates to:
  /// **'NetBIOS'**
  String get protocolNetbios;

  /// No description provided for @protocolSsdp.
  ///
  /// In en, this message translates to:
  /// **'SSDP / UPnP'**
  String get protocolSsdp;

  /// No description provided for @sectionHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get sectionHistory;

  /// No description provided for @saveScanHistory.
  ///
  /// In en, this message translates to:
  /// **'Save scan history'**
  String get saveScanHistory;

  /// No description provided for @retentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Retention'**
  String get retentionTitle;

  /// No description provided for @retentionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Maximum saved scan snapshots'**
  String get retentionSubtitle;

  /// No description provided for @sectionVendorDatabase.
  ///
  /// In en, this message translates to:
  /// **'Vendor database'**
  String get sectionVendorDatabase;

  /// No description provided for @vendorDbUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update from the IEEE registry'**
  String get vendorDbUpdateTitle;

  /// No description provided for @vendorDbUpdateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Improves MAC-address vendor names'**
  String get vendorDbUpdateSubtitle;

  /// No description provided for @refreshNow.
  ///
  /// In en, this message translates to:
  /// **'Refresh now'**
  String get refreshNow;

  /// No description provided for @vendorDbAutoRefresh.
  ///
  /// In en, this message translates to:
  /// **'Auto-refresh vendor database'**
  String get vendorDbAutoRefresh;

  /// No description provided for @vendorDbAutoRefreshInterval.
  ///
  /// In en, this message translates to:
  /// **'Auto-refresh interval'**
  String get vendorDbAutoRefreshInterval;

  /// No description provided for @vendorDbIntervalDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{{days} day} other{{days} days}}'**
  String vendorDbIntervalDays(int days);

  /// No description provided for @vendorDbRefreshedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Vendor database refreshed.'**
  String get vendorDbRefreshedSuccess;

  /// No description provided for @vendorDbRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh vendor database — check your connection.'**
  String get vendorDbRefreshFailed;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan History'**
  String get historyTitle;

  /// No description provided for @clearAllHistoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear all history'**
  String get clearAllHistoryTooltip;

  /// No description provided for @historyLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load history: {error}'**
  String historyLoadError(String error);

  /// No description provided for @clearHistoryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear scan history?'**
  String get clearHistoryDialogTitle;

  /// No description provided for @clearHistoryDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes all saved scan snapshots and their change logs. This cannot be undone.'**
  String get clearHistoryDialogBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @noChangesRecorded.
  ///
  /// In en, this message translates to:
  /// **'No changes recorded yet — this is the baseline.'**
  String get noChangesRecorded;

  /// No description provided for @historyScanCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{# scan} other{# scans}}'**
  String historyScanCount(int count);

  /// No description provided for @historyDeviceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{# device} other{# devices}}'**
  String historyDeviceCount(int count);

  /// No description provided for @historySummaryLine.
  ///
  /// In en, this message translates to:
  /// **'{scans} · latest {time} · {devices}'**
  String historySummaryLine(String scans, String time, String devices);

  /// No description provided for @noScanHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No scan history yet.'**
  String get noScanHistoryYet;

  /// No description provided for @runScanHint.
  ///
  /// In en, this message translates to:
  /// **'Run a scan or enable monitoring — snapshots are saved automatically.'**
  String get runScanHint;

  /// No description provided for @changeAppeared.
  ///
  /// In en, this message translates to:
  /// **'Appeared · {ip}'**
  String changeAppeared(String ip);

  /// No description provided for @changeDisappeared.
  ///
  /// In en, this message translates to:
  /// **'Disappeared · last at {ip}'**
  String changeDisappeared(String ip);

  /// No description provided for @changeChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed {fields} · {ip}'**
  String changeChanged(String fields, String ip);

  /// No description provided for @fieldIp.
  ///
  /// In en, this message translates to:
  /// **'IP'**
  String get fieldIp;

  /// No description provided for @fieldHostname.
  ///
  /// In en, this message translates to:
  /// **'hostname'**
  String get fieldHostname;

  /// No description provided for @fieldVendor.
  ///
  /// In en, this message translates to:
  /// **'vendor'**
  String get fieldVendor;

  /// No description provided for @fieldType.
  ///
  /// In en, this message translates to:
  /// **'type'**
  String get fieldType;

  /// No description provided for @fieldOpenPorts.
  ///
  /// In en, this message translates to:
  /// **'open ports'**
  String get fieldOpenPorts;

  /// No description provided for @sourceTcp.
  ///
  /// In en, this message translates to:
  /// **'TCP'**
  String get sourceTcp;

  /// No description provided for @sourceIcmp.
  ///
  /// In en, this message translates to:
  /// **'ICMP'**
  String get sourceIcmp;

  /// No description provided for @sourceArp.
  ///
  /// In en, this message translates to:
  /// **'ARP'**
  String get sourceArp;

  /// No description provided for @sourceMdns.
  ///
  /// In en, this message translates to:
  /// **'mDNS'**
  String get sourceMdns;

  /// No description provided for @sourceBonjour.
  ///
  /// In en, this message translates to:
  /// **'Bonjour'**
  String get sourceBonjour;

  /// No description provided for @sourceNetbios.
  ///
  /// In en, this message translates to:
  /// **'NetBIOS'**
  String get sourceNetbios;

  /// No description provided for @sourceSsdp.
  ///
  /// In en, this message translates to:
  /// **'SSDP'**
  String get sourceSsdp;

  /// No description provided for @typeRouter.
  ///
  /// In en, this message translates to:
  /// **'Router'**
  String get typeRouter;

  /// No description provided for @typeComputer.
  ///
  /// In en, this message translates to:
  /// **'Computer'**
  String get typeComputer;

  /// No description provided for @typeLaptop.
  ///
  /// In en, this message translates to:
  /// **'Laptop'**
  String get typeLaptop;

  /// No description provided for @typePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get typePhone;

  /// No description provided for @typeTablet.
  ///
  /// In en, this message translates to:
  /// **'Tablet'**
  String get typeTablet;

  /// No description provided for @typePrinter.
  ///
  /// In en, this message translates to:
  /// **'Printer'**
  String get typePrinter;

  /// No description provided for @typeTv.
  ///
  /// In en, this message translates to:
  /// **'TV'**
  String get typeTv;

  /// No description provided for @typeSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get typeSpeaker;

  /// No description provided for @typeCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get typeCamera;

  /// No description provided for @typeNas.
  ///
  /// In en, this message translates to:
  /// **'NAS'**
  String get typeNas;

  /// No description provided for @typeServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get typeServer;

  /// No description provided for @typeIot.
  ///
  /// In en, this message translates to:
  /// **'IoT'**
  String get typeIot;

  /// No description provided for @typeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get typeUnknown;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sextant'**
  String get aboutTitle;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'A lightweight LAN scanner for discovering and monitoring devices on your local network.'**
  String get aboutBody;

  /// No description provided for @builtWithFlutter.
  ///
  /// In en, this message translates to:
  /// **'Built with Flutter.'**
  String get builtWithFlutter;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @networkChangedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Network changed — updating available networks…'**
  String get networkChangedSnackbar;

  /// No description provided for @newDeviceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{# new device} other{# new devices}}'**
  String newDeviceCount(int count);

  /// No description provided for @newDeviceAlert.
  ///
  /// In en, this message translates to:
  /// **'{countLabel}: {names}'**
  String newDeviceAlert(String countLabel, String names);

  /// No description provided for @newDeviceMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String newDeviceMore(int count);

  /// No description provided for @noActiveNetworkFound.
  ///
  /// In en, this message translates to:
  /// **'No active network found'**
  String get noActiveNetworkFound;

  /// No description provided for @networkOption.
  ///
  /// In en, this message translates to:
  /// **'{name}  ({address}/{prefix})'**
  String networkOption(String name, String address, int prefix);

  /// No description provided for @scanButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'SCAN'**
  String get scanButtonLabel;

  /// No description provided for @stopButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'STOP'**
  String get stopButtonLabel;

  /// No description provided for @monitoringStopTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop live monitoring'**
  String get monitoringStopTooltip;

  /// No description provided for @monitoringStartTooltip.
  ///
  /// In en, this message translates to:
  /// **'Live monitoring — re-scan and alert on new devices'**
  String get monitoringStartTooltip;

  /// No description provided for @exportScanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export scan'**
  String get exportScanTooltip;

  /// No description provided for @exportAsCsv.
  ///
  /// In en, this message translates to:
  /// **'Export as CSV…'**
  String get exportAsCsv;

  /// No description provided for @exportAsJson.
  ///
  /// In en, this message translates to:
  /// **'Export as JSON…'**
  String get exportAsJson;

  /// No description provided for @scanHistoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scan history'**
  String get scanHistoryTooltip;

  /// No description provided for @aboutTooltip.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTooltip;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// No description provided for @exportedDevices.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Exported # device to {path}} other{Exported # devices to {path}}}'**
  String exportedDevices(int count, String path);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @scanningStatus.
  ///
  /// In en, this message translates to:
  /// **'Scanning… {found} found, scanned {scanned} of {total}'**
  String scanningStatus(int found, int scanned, int total);

  /// No description provided for @resolvingMacAddresses.
  ///
  /// In en, this message translates to:
  /// **'Resolving MAC addresses… {found} found'**
  String resolvingMacAddresses(int found);

  /// No description provided for @monitoringStatus.
  ///
  /// In en, this message translates to:
  /// **'Monitoring… {online} online{offlineSuffix}'**
  String monitoringStatus(int online, String offlineSuffix);

  /// No description provided for @onlineStatus.
  ///
  /// In en, this message translates to:
  /// **'{online} online{offlineSuffix}'**
  String onlineStatus(int online, String offlineSuffix);

  /// No description provided for @offlineSuffix.
  ///
  /// In en, this message translates to:
  /// **', {count} offline'**
  String offlineSuffix(int count);

  /// No description provided for @idleStatus.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get idleStatus;

  /// No description provided for @scanningEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get scanningEllipsis;

  /// No description provided for @pressScanHint.
  ///
  /// In en, this message translates to:
  /// **'Press SCAN to discover devices on your network.'**
  String get pressScanHint;

  /// No description provided for @columnIp.
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get columnIp;

  /// No description provided for @columnName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get columnName;

  /// No description provided for @columnMac.
  ///
  /// In en, this message translates to:
  /// **'MAC'**
  String get columnMac;

  /// No description provided for @columnVendor.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get columnVendor;

  /// No description provided for @columnOpenPorts.
  ///
  /// In en, this message translates to:
  /// **'Open ports'**
  String get columnOpenPorts;

  /// No description provided for @columnFoundVia.
  ///
  /// In en, this message translates to:
  /// **'Found via'**
  String get columnFoundVia;

  /// No description provided for @columnLatency.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get columnLatency;

  /// No description provided for @alsoSeenAt.
  ///
  /// In en, this message translates to:
  /// **'Also seen at: {ips}'**
  String alsoSeenAt(String ips);

  /// No description provided for @discoveredVia.
  ///
  /// In en, this message translates to:
  /// **'Discovered via'**
  String get discoveredVia;

  /// No description provided for @openInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get openInBrowser;

  /// No description provided for @renameEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Rename…'**
  String get renameEllipsis;

  /// No description provided for @changeTypeEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Change type…'**
  String get changeTypeEllipsis;

  /// No description provided for @copyIp.
  ///
  /// In en, this message translates to:
  /// **'Copy IP'**
  String get copyIp;

  /// No description provided for @copyMac.
  ///
  /// In en, this message translates to:
  /// **'Copy MAC'**
  String get copyMac;

  /// No description provided for @wakeOnLan.
  ///
  /// In en, this message translates to:
  /// **'Wake on LAN'**
  String get wakeOnLan;

  /// No description provided for @magicPacketSent.
  ///
  /// In en, this message translates to:
  /// **'Magic packet sent to {mac}'**
  String magicPacketSent(String mac);

  /// No description provided for @magicPacketFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send magic packet: {error}'**
  String magicPacketFailed(String error);

  /// No description provided for @renameDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename {ip}'**
  String renameDialogTitle(String ip);

  /// No description provided for @deviceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get deviceNameLabel;

  /// No description provided for @deviceNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Office Printer'**
  String get deviceNameHint;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @deviceTypeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Device type · {ip}'**
  String deviceTypeDialogTitle(String ip);

  /// No description provided for @resetToAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Reset to automatic'**
  String get resetToAutomatic;

  /// No description provided for @statusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get statusOnline;

  /// No description provided for @statusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get statusOffline;

  /// No description provided for @deviceTypeOfflineTooltip.
  ///
  /// In en, this message translates to:
  /// **'{type} · offline'**
  String deviceTypeOfflineTooltip(String type);

  /// No description provided for @latencySuffix.
  ///
  /// In en, this message translates to:
  /// **' · {ms} ms'**
  String latencySuffix(String ms);

  /// No description provided for @portWithLabel.
  ///
  /// In en, this message translates to:
  /// **'{port} · {label}'**
  String portWithLabel(int port, String label);

  /// No description provided for @portService.
  ///
  /// In en, this message translates to:
  /// **'→ {service}'**
  String portService(String service);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
