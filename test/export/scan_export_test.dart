import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/export/scan_export.dart';
import 'package:sextant/model/device.dart';
import 'package:sextant/model/discovery_source.dart';

Device _device({
  String ip = '192.168.1.10',
  String? mac,
  String? vendor,
  String? hostname,
  String? customName,
  DeviceType type = DeviceType.unknown,
  List<int> openPorts = const [],
  Map<int, String> services = const {},
  Set<DiscoverySource> discoveredBy = const {},
}) {
  return Device(
    ip: ip,
    mac: mac,
    vendor: vendor,
    hostname: hostname,
    customName: customName,
    deviceType: type,
    openPorts: openPorts,
    services: services,
    discoveredBy: discoveredBy,
    firstSeen: DateTime.utc(2026, 6, 22, 10, 0, 0),
    lastSeen: DateTime.utc(2026, 6, 22, 10, 5, 0),
  );
}

void main() {
  group('devicesToCsv', () {
    test('emits a header row even for an empty scan', () {
      final csv = devicesToCsv(const []);
      final lines = const LineSplitter().convert(csv);
      expect(lines, hasLength(1));
      expect(lines.first, startsWith('ip,name,hostname,mac,vendor,type,'));
    });

    test('serialises a device row in column order', () {
      final csv = devicesToCsv([
        _device(
          ip: '192.168.4.35',
          mac: 'AA:BB:CC:DD:EE:FF',
          vendor: 'ASUSTek',
          hostname: 'DESKTOP-JBDR11A',
          type: DeviceType.computer,
          openPorts: [139, 445, 3389],
          discoveredBy: {DiscoverySource.arp, DiscoverySource.netbios},
        ),
      ]);
      final row = const LineSplitter().convert(csv)[1];
      expect(row, contains('192.168.4.35'));
      expect(row, contains('DESKTOP-JBDR11A'));
      expect(row, contains('AA:BB:CC:DD:EE:FF'));
      expect(row, contains('computer'));
      expect(row, contains('139 445 3389')); // space-joined ports
      expect(row, contains('arp netbios')); // sorted, space-joined sources
    });

    test('quotes and escapes fields containing commas or quotes', () {
      // Real OUI vendor names contain commas, e.g. "LEXMARK INTERNATIONAL, INC."
      final csv = devicesToCsv([
        _device(vendor: 'LEXMARK INTERNATIONAL, INC.', hostname: 'a"b'),
      ]);
      final row = const LineSplitter().convert(csv)[1];
      expect(row, contains('"LEXMARK INTERNATIONAL, INC."'));
      expect(row, contains('"a""b"')); // embedded quote doubled
    });

    test('uses the display name (custom name wins over hostname)', () {
      final csv = devicesToCsv([
        _device(hostname: 'host-1', customName: 'Office Printer'),
      ]);
      final row = const LineSplitter().convert(csv)[1];
      expect(row, contains('Office Printer'));
      expect(row, contains('host-1')); // raw hostname kept in its own column
    });
  });

  group('devicesToJson', () {
    test('is valid JSON with a count and per-device fields', () {
      final json = devicesToJson(
        [
          _device(
            ip: '10.0.0.5',
            mac: 'AA:BB:CC:00:11:22',
            type: DeviceType.nas,
            openPorts: [22, 80],
            services: {22: 'OpenSSH 9.6'},
            discoveredBy: {DiscoverySource.mdns},
          ),
        ],
        exportedAt: DateTime.utc(2026, 6, 22, 12, 0, 0),
      );
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['deviceCount'], 1);
      expect(decoded['exportedAt'], '2026-06-22T12:00:00.000Z');
      final devices = decoded['devices'] as List;
      final d = devices.single as Map<String, dynamic>;
      expect(d['ip'], '10.0.0.5');
      expect(d['type'], 'nas');
      expect(d['openPorts'], [22, 80]);
      expect(d['services'], {'22': 'OpenSSH 9.6'});
      expect(d['discoveredBy'], ['mdns']);
    });

    test('reports zero devices for an empty scan', () {
      final decoded = jsonDecode(devicesToJson(const [])) as Map<String, dynamic>;
      expect(decoded['deviceCount'], 0);
      expect(decoded['devices'], isEmpty);
    });
  });

  group('buildScanExport', () {
    final at = DateTime.utc(2026, 6, 22, 9, 8, 7);

    test('builds a timestamped CSV file with the right content & mime', () {
      final file = buildScanExport([_device()], ExportFormat.csv, now: at);
      expect(file.suggestedName, 'sextant-scan-20260622-090807.csv');
      expect(file.mimeType, 'text/csv');
      expect(file.content, devicesToCsv([_device()]));
    });

    test('builds a JSON file whose embedded timestamp matches the filename', () {
      final file = buildScanExport([_device()], ExportFormat.json, now: at);
      expect(file.suggestedName, 'sextant-scan-20260622-090807.json');
      expect(file.mimeType, 'application/json');
      final decoded = jsonDecode(file.content) as Map<String, dynamic>;
      expect(decoded['exportedAt'], at.toIso8601String());
    });
  });
}
