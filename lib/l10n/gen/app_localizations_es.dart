// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get settingsTitle => 'Configuración';

  @override
  String settingsLoadError(String error) {
    return 'No se pudieron cargar los ajustes: $error';
  }

  @override
  String get sectionAppearance => 'Tema';

  @override
  String get appearanceLight => 'Claro';

  @override
  String get appearanceDark => 'Oscuro';

  @override
  String get appearanceAuto => 'Automático';

  @override
  String get sectionLanguage => 'Idioma';

  @override
  String get languageSystemDefault => 'Predeterminado del sistema';

  @override
  String get sectionScanning => 'Escaneo';

  @override
  String get autoRefreshInterval => 'Intervalo de actualización automática';

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
  String get protocolNotAvailable => 'No disponible en esta plataforma';

  @override
  String get protocolIcmp => 'Barrido ICMP (ping)';

  @override
  String get protocolArp => 'Tabla ARP';

  @override
  String get protocolTcp => 'Escaneo de puertos TCP';

  @override
  String get protocolMdns => 'mDNS / Bonjour';

  @override
  String get protocolNetbios => 'NetBIOS';

  @override
  String get protocolSsdp => 'SSDP / UPnP';

  @override
  String get sectionHistory => 'Historial';

  @override
  String get saveScanHistory => 'Guardar historial';

  @override
  String get retentionTitle => 'Profundidad del historial';

  @override
  String get retentionSubtitle => 'Máximo de análisis guardados';

  @override
  String get sectionVendorDatabase => 'Base de datos de fabricantes';

  @override
  String get vendorDbUpdateTitle => 'Actualizar desde el registro IEEE';

  @override
  String get vendorDbUpdateSubtitle =>
      'Mejora los nombres de fabricante por dirección MAC';

  @override
  String get refreshNow => 'Actualizar ahora';

  @override
  String get vendorDbAutoRefresh =>
      'Actualización automática de la base de fabricantes';

  @override
  String get vendorDbAutoRefreshInterval =>
      'Intervalo de actualización automática';

  @override
  String vendorDbIntervalDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días',
      one: '$days día',
    );
    return '$_temp0';
  }

  @override
  String get vendorDbRefreshedSuccess =>
      'Base de datos de fabricantes actualizada.';

  @override
  String get vendorDbRefreshFailed =>
      'No se pudo actualizar la base de fabricantes — comprueba tu conexión.';

  @override
  String get historyTitle => 'Historial de análisis';

  @override
  String get clearAllHistoryTooltip => 'Borrar todo el historial';

  @override
  String historyLoadError(String error) {
    return 'No se pudo cargar el historial: $error';
  }

  @override
  String get clearHistoryDialogTitle => '¿Borrar el historial de análisis?';

  @override
  String get clearHistoryDialogBody =>
      'Esto elimina permanentemente todo el historial de análisis y su registro de cambios. Esta acción no se puede deshacer.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get clear => 'Borrar';

  @override
  String get noChangesRecorded =>
      'Aún no se han registrado cambios — este es el estado inicial.';

  @override
  String historyScanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# análisis',
      one: '# análisis',
    );
    return '$_temp0';
  }

  @override
  String historyDeviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# dispositivos',
      one: '# dispositivo',
    );
    return '$_temp0';
  }

  @override
  String historySummaryLine(String scans, String time, String devices) {
    return '$scans · más reciente $time · $devices';
  }

  @override
  String get noScanHistoryYet => 'Aún no hay historial de análisis.';

  @override
  String get runScanHint =>
      'Ejecuta un análisis o activa el monitoreo — los datos se guardan automáticamente.';

  @override
  String changeAppeared(String ip) {
    return 'Apareció · $ip';
  }

  @override
  String changeDisappeared(String ip) {
    return 'Desapareció · visto por última vez en $ip';
  }

  @override
  String changeChanged(String fields, String ip) {
    return 'Cambió $fields · $ip';
  }

  @override
  String get fieldIp => 'IP';

  @override
  String get fieldHostname => 'nombre de host';

  @override
  String get fieldVendor => 'fabricante';

  @override
  String get fieldType => 'tipo';

  @override
  String get fieldOpenPorts => 'puertos abiertos';

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
  String get typeComputer => 'Ordenador';

  @override
  String get typeLaptop => 'Portátil';

  @override
  String get typePhone => 'Teléfono';

  @override
  String get typeTablet => 'Tableta';

  @override
  String get typePrinter => 'Impresora';

  @override
  String get typeTv => 'TV';

  @override
  String get typeSpeaker => 'Altavoz';

  @override
  String get typeCamera => 'Cámara';

  @override
  String get typeNas => 'NAS';

  @override
  String get typeServer => 'Servidor';

  @override
  String get typeIot => 'IoT';

  @override
  String get typeUnknown => 'Desconocido';

  @override
  String get aboutTitle => 'Sextant';

  @override
  String get aboutBody =>
      'Escáner de red local para descubrir y monitorizar dispositivos.';

  @override
  String get builtWithFlutter => 'Creado con Flutter.';

  @override
  String get close => 'Cerrar';

  @override
  String get networkChangedSnackbar =>
      'La red ha cambiado — actualizando las redes disponibles…';

  @override
  String newDeviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# dispositivos nuevos',
      one: '# dispositivo nuevo',
    );
    return '$_temp0';
  }

  @override
  String newDeviceAlert(String countLabel, String names) {
    return '$countLabel: $names';
  }

  @override
  String newDeviceMore(int count) {
    return '+$count más';
  }

  @override
  String get noActiveNetworkFound => 'No se encontró ninguna red activa';

  @override
  String networkOption(String name, String address, int prefix) {
    return '$name  ($address/$prefix)';
  }

  @override
  String get scanButtonLabel => 'ESCANEAR';

  @override
  String get stopButtonLabel => 'DETENER';

  @override
  String get monitoringStopTooltip => 'Detener monitoreo en vivo';

  @override
  String get monitoringStartTooltip =>
      'Monitoreo en vivo — reanaliza y avisa sobre nuevos dispositivos';

  @override
  String get exportScanTooltip => 'Exportar análisis';

  @override
  String get exportAsCsv => 'Exportar como CSV…';

  @override
  String get exportAsJson => 'Exportar como JSON…';

  @override
  String get scanHistoryTooltip => 'Historial de análisis';

  @override
  String get aboutTooltip => 'Acerca de';

  @override
  String get settingsTooltip => 'Configuración';

  @override
  String exportedDevices(int count, String path) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se exportaron # dispositivos a $path',
      one: 'Se exportó # dispositivo a $path',
    );
    return '$_temp0';
  }

  @override
  String exportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String scanningStatus(int found, int scanned, int total) {
    return 'Escaneando… $found encontrados, $scanned de $total analizados';
  }

  @override
  String resolvingMacAddresses(int found) {
    return 'Resolviendo direcciones MAC… $found encontrados';
  }

  @override
  String monitoringStatus(int online, String offlineSuffix) {
    return 'Monitoreando… $online en línea$offlineSuffix';
  }

  @override
  String onlineStatus(int online, String offlineSuffix) {
    return '$online en línea$offlineSuffix';
  }

  @override
  String offlineSuffix(int count) {
    return ', $count sin conexión';
  }

  @override
  String get idleStatus => 'Inactivo';

  @override
  String get scanningEllipsis => 'Escaneando…';

  @override
  String get pressScanHint =>
      'Pulsa ESCANEAR para descubrir dispositivos en tu red.';

  @override
  String get columnIp => 'Dirección IP';

  @override
  String get columnName => 'Nombre';

  @override
  String get columnMac => 'MAC';

  @override
  String get columnVendor => 'Fabricante';

  @override
  String get columnOpenPorts => 'Puertos abiertos';

  @override
  String get columnFoundVia => 'Encontrado vía';

  @override
  String get columnLatency => 'Latencia';

  @override
  String alsoSeenAt(String ips) {
    return 'También visto en: $ips';
  }

  @override
  String get discoveredVia => 'Descubierto vía';

  @override
  String get openInBrowser => 'Abrir en el navegador';

  @override
  String get renameEllipsis => 'Renombrar…';

  @override
  String get changeTypeEllipsis => 'Cambiar tipo…';

  @override
  String get copyIp => 'Copiar IP';

  @override
  String get copyMac => 'Copiar MAC';

  @override
  String get wakeOnLan => 'Enviar Wake-on-LAN';

  @override
  String magicPacketSent(String mac) {
    return 'Paquete mágico enviado a $mac';
  }

  @override
  String magicPacketFailed(String error) {
    return 'No se pudo enviar el paquete mágico: $error';
  }

  @override
  String renameDialogTitle(String ip) {
    return 'Renombrar $ip';
  }

  @override
  String get deviceNameLabel => 'Nombre del dispositivo';

  @override
  String get deviceNameHint => 'p. ej. Impresora de la oficina';

  @override
  String get save => 'Guardar';

  @override
  String deviceTypeDialogTitle(String ip) {
    return 'Tipo de dispositivo · $ip';
  }

  @override
  String get resetToAutomatic => 'Restablecer a automático';

  @override
  String get statusOnline => 'En línea';

  @override
  String get statusOffline => 'Sin conexión';

  @override
  String deviceTypeOfflineTooltip(String type) {
    return '$type · sin conexión';
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
