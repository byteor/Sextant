import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/data/dedupe_multihomed.dart';
import 'package:sextant/model/device.dart';
import 'package:sextant/model/discovery_source.dart';

Device _dev(
  String ip, {
  String? mac,
  List<int>? openPorts,
  Map<int, String>? services,
  Set<DiscoverySource>? discoveredBy,
  bool isOnline = true,
}) {
  final t = DateTime.utc(2026, 1, 1);
  return Device(
    ip: ip,
    mac: mac,
    openPorts: openPorts ?? const [],
    services: services ?? const {},
    discoveredBy: discoveredBy ?? const {},
    isOnline: isOnline,
    firstSeen: t,
    lastSeen: t,
  );
}

void main() {
  group('dedupeMultihomed', () {
    test('devices with no MAC pass through unchanged', () {
      final devices = [_dev('10.0.0.1'), _dev('10.0.0.2')];

      final result = dedupeMultihomed(devices);

      expect(result, devices);
    });

    test('merges two IPs sharing a MAC, keeping the lower IP as primary', () {
      final a = _dev('10.0.0.20', mac: 'aa:aa:aa:aa:aa:aa', openPorts: [22]);
      final b = _dev('10.0.0.5', mac: 'aa:aa:aa:aa:aa:aa', openPorts: [80]);

      final result = dedupeMultihomed([a, b]);

      expect(result, hasLength(1));
      expect(result.single.ip, '10.0.0.5');
      expect(result.single.additionalIps, ['10.0.0.20']);
      expect(result.single.openPorts, [22, 80]);
    });

    test('MAC matching is case- and dash/colon-insensitive', () {
      final a = _dev('10.0.0.5', mac: 'AA-AA-AA-AA-AA-AA');
      final b = _dev('10.0.0.6', mac: 'aa:aa:aa:aa:aa:aa');

      final result = dedupeMultihomed([a, b]);

      expect(result, hasLength(1));
    });

    test('unions services and discoveredBy across the merged group', () {
      final a = _dev(
        '10.0.0.5',
        mac: 'aa:aa:aa:aa:aa:aa',
        services: {80: 'nginx'},
        discoveredBy: {DiscoverySource.tcp},
      );
      final b = _dev(
        '10.0.0.6',
        mac: 'aa:aa:aa:aa:aa:aa',
        services: {443: 'TLS'},
        discoveredBy: {DiscoverySource.arp},
      );

      final result = dedupeMultihomed([a, b]).single;

      expect(result.services, {80: 'nginx', 443: 'TLS'});
      expect(result.discoveredBy, {DiscoverySource.tcp, DiscoverySource.arp});
    });

    test('merged device is online if any member is online', () {
      final a = _dev('10.0.0.5', mac: 'aa:aa:aa:aa:aa:aa', isOnline: false);
      final b = _dev('10.0.0.6', mac: 'aa:aa:aa:aa:aa:aa', isOnline: true);

      final result = dedupeMultihomed([a, b]).single;

      expect(result.isOnline, isTrue);
    });

    test('three IPs sharing a MAC merge into one device', () {
      final devices = [
        _dev('10.0.0.30', mac: 'bb:bb:bb:bb:bb:bb'),
        _dev('10.0.0.10', mac: 'bb:bb:bb:bb:bb:bb'),
        _dev('10.0.0.20', mac: 'bb:bb:bb:bb:bb:bb'),
      ];

      final result = dedupeMultihomed(devices);

      expect(result, hasLength(1));
      expect(result.single.ip, '10.0.0.10');
      expect(result.single.additionalIps, ['10.0.0.20', '10.0.0.30']);
    });

    test('multiple distinct MAC groups are returned in ascending IP order', () {
      final devices = [
        // Group A: MAC AA:AA... with primary IP 10.0.0.3
        _dev('10.0.0.3', mac: 'aa:aa:aa:aa:aa:aa'),
        _dev('10.0.0.4', mac: 'aa:aa:aa:aa:aa:aa'),
        // Group B: MAC BB:BB... with primary IP 10.0.0.1
        _dev('10.0.0.1', mac: 'bb:bb:bb:bb:bb:bb'),
        _dev('10.0.0.2', mac: 'bb:bb:bb:bb:bb:bb'),
      ];

      final result = dedupeMultihomed(devices);

      expect(result, hasLength(2));
      // Verify that results are in ascending IP order: 10.0.0.1, then 10.0.0.3
      expect(result[0].ip, '10.0.0.1');
      expect(result[1].ip, '10.0.0.3');
    });
  });
}
