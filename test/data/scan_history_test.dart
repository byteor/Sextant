import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/data/scan_diff.dart';
import 'package:sextant/data/scan_history.dart';
import 'package:sextant/data/scan_record.dart';
import 'package:sextant/model/device.dart';

Device _dev(String ip, {String? mac, List<int>? ports, String? hostname}) {
  final t = DateTime.utc(2026, 1, 1);
  return Device(
    ip: ip,
    mac: mac,
    hostname: hostname,
    openPorts: ports,
    firstSeen: t,
    lastSeen: t,
  );
}

ScanRecord _rec(
  String networkId,
  String label,
  DateTime ts,
  List<Device> devices,
) =>
    ScanRecord(
      networkId: networkId,
      networkLabel: label,
      timestamp: ts,
      devices: devices,
    );

void main() {
  group('groupByNetwork', () {
    test('groups scans by network, networks and scans newest-first', () {
      final scans = [
        _rec('wifi', 'Wi-Fi', DateTime.utc(2026, 6, 20, 8), [_dev('1.1.1.1')]),
        _rec('eth', 'Ethernet', DateTime.utc(2026, 6, 22, 9), [_dev('2.2.2.2')]),
        _rec('wifi', 'Wi-Fi', DateTime.utc(2026, 6, 21, 8), [_dev('1.1.1.1')]),
      ];

      final groups = groupByNetwork(scans);

      // Ethernet's latest scan (Jun 22) is newer than Wi-Fi's (Jun 21).
      expect(groups.map((g) => g.networkId), ['eth', 'wifi']);
      final wifi = groups.firstWhere((g) => g.networkId == 'wifi');
      expect(wifi.networkLabel, 'Wi-Fi');
      expect(
        wifi.scans.map((s) => s.timestamp),
        [DateTime.utc(2026, 6, 21, 8), DateTime.utc(2026, 6, 20, 8)],
      );
    });

    test('returns an empty list for no scans', () {
      expect(groupByNetwork([]), isEmpty);
    });
  });

  group('changeLog', () {
    test('reports devices that appeared, disappeared and changed, newest-first',
        () {
      final t1 = DateTime.utc(2026, 6, 20, 8);
      final t2 = DateTime.utc(2026, 6, 21, 8);
      final scans = [
        _rec('wifi', 'Wi-Fi', t1, [
          _dev('1.1.1.1', mac: 'aa:aa:aa:aa:aa:aa'),
          _dev('1.1.1.2', mac: 'bb:bb:bb:bb:bb:bb', ports: [22]),
        ]),
        _rec('wifi', 'Wi-Fi', t2, [
          _dev('1.1.1.2', mac: 'bb:bb:bb:bb:bb:bb', ports: [22, 80]),
          _dev('1.1.1.3', mac: 'cc:cc:cc:cc:cc:cc'),
        ]),
      ];

      final log = changeLog(scans);

      // All entries are stamped with the newer scan's time.
      expect(log.every((e) => e.timestamp == t2), isTrue);
      final appeared = log.where((e) => e.kind == ScanChangeKind.appeared);
      final disappeared =
          log.where((e) => e.kind == ScanChangeKind.disappeared);
      final changed = log.where((e) => e.kind == ScanChangeKind.changed);
      expect(appeared.map((e) => e.device.mac), ['cc:cc:cc:cc:cc:cc']);
      expect(disappeared.map((e) => e.device.mac), ['aa:aa:aa:aa:aa:aa']);
      expect(changed.single.device.mac, 'bb:bb:bb:bb:bb:bb');
      expect(changed.single.fields, contains(DeviceChangeField.openPorts));
    });

    test('a single scan produces no change entries', () {
      final scans = [
        _rec('wifi', 'Wi-Fi', DateTime.utc(2026, 6, 20), [_dev('1.1.1.1')]),
      ];
      expect(changeLog(scans), isEmpty);
    });

    test('orders entries across multiple intervals newest-first', () {
      final t1 = DateTime.utc(2026, 6, 20);
      final t2 = DateTime.utc(2026, 6, 21);
      final t3 = DateTime.utc(2026, 6, 22);
      final scans = [
        _rec('wifi', 'Wi-Fi', t1, []),
        _rec('wifi', 'Wi-Fi', t2, [_dev('1.1.1.1', mac: 'aa:aa:aa:aa:aa:aa')]),
        _rec('wifi', 'Wi-Fi', t3, [
          _dev('1.1.1.1', mac: 'aa:aa:aa:aa:aa:aa'),
          _dev('1.1.1.2', mac: 'bb:bb:bb:bb:bb:bb'),
        ]),
      ];

      final log = changeLog(scans);

      expect(log.first.timestamp, t3);
      expect(log.first.device.mac, 'bb:bb:bb:bb:bb:bb');
      expect(log.last.timestamp, t2);
      expect(log.last.device.mac, 'aa:aa:aa:aa:aa:aa');
    });
  });
}
