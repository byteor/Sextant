// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get settingsTitle => 'Настройки';

  @override
  String settingsLoadError(String error) {
    return 'Не удалось загрузить настройки: $error';
  }

  @override
  String get sectionAppearance => 'Тема';

  @override
  String get appearanceLight => 'Светлая';

  @override
  String get appearanceDark => 'Тёмная';

  @override
  String get appearanceAuto => 'Авто';

  @override
  String get sectionLanguage => 'Язык';

  @override
  String get languageSystemDefault => 'Системный язык';

  @override
  String get sectionScanning => 'Сканирование';

  @override
  String get autoRefreshInterval => 'Интервал автообновления';

  @override
  String durationSeconds(int seconds) {
    return '$seconds с';
  }

  @override
  String durationMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes мин',
    );
    return '$_temp0';
  }

  @override
  String get protocolNotAvailable => 'Недоступно на этой платформе';

  @override
  String get protocolIcmp => 'ICMP-сканирование (ping)';

  @override
  String get protocolArp => 'Таблица ARP';

  @override
  String get protocolTcp => 'Сканирование TCP-портов';

  @override
  String get protocolMdns => 'mDNS / Bonjour';

  @override
  String get protocolNetbios => 'NetBIOS';

  @override
  String get protocolSsdp => 'SSDP / UPnP';

  @override
  String get sectionHistory => 'История';

  @override
  String get saveScanHistory => 'Сохранять историю';

  @override
  String get retentionTitle => 'Глубина истории';

  @override
  String get retentionSubtitle => 'Максимум сохранённых сканирований';

  @override
  String get sectionVendorDatabase => 'База производителей';

  @override
  String get vendorDbUpdateTitle => 'Обновить из реестра IEEE';

  @override
  String get vendorDbUpdateSubtitle =>
      'Улучшает определение производителя по MAC-адресу';

  @override
  String get refreshNow => 'Обновить сейчас';

  @override
  String get vendorDbAutoRefresh => 'Автообновление базы производителей';

  @override
  String get vendorDbAutoRefreshInterval => 'Интервал автообновления';

  @override
  String vendorDbIntervalDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days дня',
      many: '$days дней',
      few: '$days дня',
      one: '$days день',
    );
    return '$_temp0';
  }

  @override
  String get vendorDbRefreshedSuccess => 'База производителей обновлена.';

  @override
  String get vendorDbRefreshFailed =>
      'Не удалось обновить базу производителей — проверьте подключение.';

  @override
  String get historyTitle => 'История сканирований';

  @override
  String get clearAllHistoryTooltip => 'Очистить всю историю';

  @override
  String historyLoadError(String error) {
    return 'Не удалось загрузить историю: $error';
  }

  @override
  String get clearHistoryDialogTitle => 'Очистить историю сканирований?';

  @override
  String get clearHistoryDialogBody =>
      'Это навсегда удалит всю историю сканирования и журнал изменений. Это действие нельзя отменить.';

  @override
  String get cancel => 'Отмена';

  @override
  String get clear => 'Очистить';

  @override
  String get noChangesRecorded =>
      'Изменений пока не зафиксировано — это исходное состояние.';

  @override
  String historyScanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# сканирования',
      many: '# сканирований',
      few: '# сканирования',
      one: '# сканирование',
    );
    return '$_temp0';
  }

  @override
  String historyDeviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# устройства',
      many: '# устройств',
      few: '# устройства',
      one: '# устройство',
    );
    return '$_temp0';
  }

  @override
  String historySummaryLine(String scans, String time, String devices) {
    return '$scans · последнее $time · $devices';
  }

  @override
  String get noScanHistoryYet => 'История сканирований пуста.';

  @override
  String get runScanHint =>
      'Запустите сканирование или включите мониторинг — снимки сохраняются автоматически.';

  @override
  String changeAppeared(String ip) {
    return 'Появилось · $ip';
  }

  @override
  String changeDisappeared(String ip) {
    return 'Исчезло · последний раз на $ip';
  }

  @override
  String changeChanged(String fields, String ip) {
    return 'Изменено $fields · $ip';
  }

  @override
  String get fieldIp => 'IP';

  @override
  String get fieldHostname => 'имя хоста';

  @override
  String get fieldVendor => 'производитель';

  @override
  String get fieldType => 'тип';

  @override
  String get fieldOpenPorts => 'открытые порты';

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
  String get typeRouter => 'Роутер';

  @override
  String get typeComputer => 'Компьютер';

  @override
  String get typeLaptop => 'Ноутбук';

  @override
  String get typePhone => 'Телефон';

  @override
  String get typeTablet => 'Планшет';

  @override
  String get typePrinter => 'Принтер';

  @override
  String get typeTv => 'Телевизор';

  @override
  String get typeSpeaker => 'Колонка';

  @override
  String get typeCamera => 'Камера';

  @override
  String get typeNas => 'NAS';

  @override
  String get typeServer => 'Сервер';

  @override
  String get typeIot => 'IoT';

  @override
  String get typeUnknown => 'Неизвестно';

  @override
  String get aboutTitle => 'Sextant';

  @override
  String get aboutBody =>
      'Сканер локальной сети для обнаружения устройств и наблюдения за ними.';

  @override
  String get builtWithFlutter => 'Создано с использованием Flutter.';

  @override
  String get close => 'Закрыть';

  @override
  String get networkChangedSnackbar =>
      'Сеть изменилась — обновляем список доступных сетей…';

  @override
  String newDeviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# новых устройства',
      many: '# новых устройств',
      few: '# новых устройства',
      one: '# новое устройство',
    );
    return '$_temp0';
  }

  @override
  String newDeviceAlert(String countLabel, String names) {
    return '$countLabel: $names';
  }

  @override
  String newDeviceMore(int count) {
    return '+ещё $count';
  }

  @override
  String get noActiveNetworkFound => 'Активная сеть не найдена';

  @override
  String networkOption(String name, String address, int prefix) {
    return '$name  ($address/$prefix)';
  }

  @override
  String get scanButtonLabel => 'СКАН';

  @override
  String get stopButtonLabel => 'СТОП';

  @override
  String get monitoringStopTooltip => 'Остановить мониторинг';

  @override
  String get monitoringStartTooltip =>
      'Мониторинг в реальном времени — сканирование и оповещение о новых устройствах';

  @override
  String get exportScanTooltip => 'Экспорт сканирования';

  @override
  String get exportAsCsv => 'Экспорт в CSV…';

  @override
  String get exportAsJson => 'Экспорт в JSON…';

  @override
  String get scanHistoryTooltip => 'История сканирований';

  @override
  String get aboutTooltip => 'О программе';

  @override
  String get settingsTooltip => 'Настройки';

  @override
  String exportedDevices(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Экспортировано # устройства в $path',
      many: 'Экспортировано # устройств в $path',
      few: 'Экспортировано # устройства в $path',
      one: 'Экспортировано # устройство в $path',
    );
    return '$_temp0';
  }

  @override
  String exportFailed(String error) {
    return 'Ошибка экспорта: $error';
  }

  @override
  String scanningStatus(int found, int scanned, int total) {
    return 'Сканирование… найдено $found, просканировано $scanned из $total';
  }

  @override
  String resolvingMacAddresses(int found) {
    return 'Определение MAC-адресов… найдено $found';
  }

  @override
  String monitoringStatus(int online, String offlineSuffix) {
    return 'Мониторинг… $online онлайн$offlineSuffix';
  }

  @override
  String onlineStatus(int online, String offlineSuffix) {
    return '$online онлайн$offlineSuffix';
  }

  @override
  String offlineSuffix(int count) {
    return ', $count офлайн';
  }

  @override
  String get idleStatus => 'Ожидание';

  @override
  String get scanningEllipsis => 'Сканирование…';

  @override
  String get pressScanHint => 'Нажмите СКАН, чтобы найти устройства в сети.';

  @override
  String get columnIp => 'IP-адрес';

  @override
  String get columnName => 'Имя';

  @override
  String get columnMac => 'MAC';

  @override
  String get columnVendor => 'Производитель';

  @override
  String get columnOpenPorts => 'Открытые порты';

  @override
  String get columnFoundVia => 'Найдено через';

  @override
  String get columnLatency => 'Задержка';

  @override
  String alsoSeenAt(String ips) {
    return 'Также замечено на: $ips';
  }

  @override
  String get discoveredVia => 'Обнаружено через';

  @override
  String get openInBrowser => 'Открыть в браузере';

  @override
  String get renameEllipsis => 'Переименовать…';

  @override
  String get changeTypeEllipsis => 'Изменить тип…';

  @override
  String get copyIp => 'Копировать IP';

  @override
  String get copyMac => 'Копировать MAC';

  @override
  String get wakeOnLan => 'Отправить Wake-on-LAN';

  @override
  String magicPacketSent(String mac) {
    return 'Пакет Wake-on-LAN отправлен на $mac';
  }

  @override
  String magicPacketFailed(String error) {
    return 'Не удалось отправить пакет Wake-on-LAN: $error';
  }

  @override
  String renameDialogTitle(String ip) {
    return 'Переименовать $ip';
  }

  @override
  String get deviceNameLabel => 'Имя устройства';

  @override
  String get deviceNameHint => 'например, Принтер в офисе';

  @override
  String get save => 'Сохранить';

  @override
  String deviceTypeDialogTitle(String ip) {
    return 'Тип устройства · $ip';
  }

  @override
  String get resetToAutomatic => 'Сбросить на автоматический';

  @override
  String get statusOnline => 'Онлайн';

  @override
  String get statusOffline => 'Офлайн';

  @override
  String deviceTypeOfflineTooltip(String type) {
    return '$type · офлайн';
  }

  @override
  String latencySuffix(String ms) {
    return ' · $ms мс';
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
