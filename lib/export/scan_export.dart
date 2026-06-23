import 'dart:convert';

import '../model/device.dart';

/// A serialisation format the user can export a scan to.
enum ExportFormat { csv, json }

/// An in-memory export ready to be written to disk: the file [content], a
/// suggested [suggestedName] (timestamped), and its [mimeType].
class ScanExportFile {
  const ScanExportFile({
    required this.suggestedName,
    required this.mimeType,
    required this.content,
  });

  final String suggestedName;
  final String mimeType;
  final String content;
}

/// Builds a ready-to-save export of [devices] in [format], with a timestamped
/// filename (`sextant-scan-YYYYMMDD-HHMMSS.<ext>`). For JSON the embedded
/// `exportedAt` matches the filename timestamp.
ScanExportFile buildScanExport(
  List<Device> devices,
  ExportFormat format, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final stamp = _filenameStamp(at);
  switch (format) {
    case ExportFormat.csv:
      return ScanExportFile(
        suggestedName: 'sextant-scan-$stamp.csv',
        mimeType: 'text/csv',
        content: devicesToCsv(devices),
      );
    case ExportFormat.json:
      return ScanExportFile(
        suggestedName: 'sextant-scan-$stamp.json',
        mimeType: 'application/json',
        content: devicesToJson(devices, exportedAt: at),
      );
  }
}

String _filenameStamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}${two(t.month)}${two(t.day)}-'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}';
}

/// Column order shared by the CSV header and each row.
const List<String> _csvHeaders = [
  'ip',
  'name',
  'hostname',
  'mac',
  'vendor',
  'type',
  'open_ports',
  'services',
  'discovered_by',
  'first_seen',
  'last_seen',
];

/// Serialises [devices] to RFC-4180-style CSV (a header row plus one row per
/// device). Fields containing commas, quotes, or newlines are quoted/escaped —
/// real OUI vendor names such as "LEXMARK INTERNATIONAL, INC." contain commas.
String devicesToCsv(List<Device> devices) {
  final rows = <String>[_csvHeaders.join(',')];
  for (final d in devices) {
    rows.add([
      d.ip,
      d.displayName,
      d.hostname ?? '',
      d.mac ?? '',
      d.vendor ?? '',
      d.deviceType.name,
      d.openPorts.join(' '),
      d.services.entries.map((e) => '${e.key}:${e.value}').join('; '),
      _sortedSources(d).join(' '),
      d.firstSeen.toIso8601String(),
      d.lastSeen.toIso8601String(),
    ].map(_csvField).join(','));
  }
  return rows.join('\n');
}

/// Serialises [devices] to pretty-printed JSON with an export timestamp and a
/// device count, each device a structured object (ports as a list, services as
/// a port→label map, sources as a list).
String devicesToJson(List<Device> devices, {DateTime? exportedAt}) {
  final payload = <String, dynamic>{
    'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
    'deviceCount': devices.length,
    'devices': [for (final d in devices) _deviceJson(d)],
  };
  return const JsonEncoder.withIndent('  ').convert(payload);
}

Map<String, dynamic> _deviceJson(Device d) => {
      'ip': d.ip,
      'name': d.displayName,
      'hostname': d.hostname,
      'customName': d.customName,
      'mac': d.mac,
      'vendor': d.vendor,
      'type': d.deviceType.name,
      'openPorts': d.openPorts,
      'services': {
        for (final e in d.services.entries) e.key.toString(): e.value,
      },
      'discoveredBy': _sortedSources(d),
      'firstSeen': d.firstSeen.toIso8601String(),
      'lastSeen': d.lastSeen.toIso8601String(),
    };

List<String> _sortedSources(Device d) =>
    d.discoveredBy.map((s) => s.name).toList()..sort();

String _csvField(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
