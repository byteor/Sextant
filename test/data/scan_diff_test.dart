import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/data/scan_diff.dart';
import 'package:sextant/model/device.dart';
import 'package:sextant/model/discovery_source.dart';

Device _d({
  required String ip,
  String? mac,
  String? hostname,
  String? vendor,
  DeviceType type = DeviceType.unknown,
  List<int> openPorts = const [],
}) {
  return Device(
    ip: ip,
    mac: mac,
    hostname: hostname,
    vendor: vendor,
    deviceType: type,
    openPorts: openPorts,
    firstSeen: DateTime.utc(2026, 6, 22),
    lastSeen: DateTime.utc(2026, 6, 22),
  );
}

void main() {
  group('diffScans', () {
    test('reports no changes between identical scans', () {
      final a = [_d(ip: '192.168.1.2', mac: 'aa:bb:cc:00:00:01')];
      final b = [_d(ip: '192.168.1.2', mac: 'aa:bb:cc:00:00:01')];
      final diff = diffScans(a, b);
      expect(diff.hasChanges, isFalse);
      expect(diff.added, isEmpty);
      expect(diff.removed, isEmpty);
      expect(diff.changed, isEmpty);
    });

    test('detects a newly-appeared device', () {
      final prev = [_d(ip: '192.168.1.2', mac: 'aa:bb:cc:00:00:01')];
      final curr = [
        _d(ip: '192.168.1.2', mac: 'aa:bb:cc:00:00:01'),
        _d(ip: '192.168.1.9', mac: 'aa:bb:cc:00:00:09'),
      ];
      final diff = diffScans(prev, curr);
      expect(diff.added.map((d) => d.ip), ['192.168.1.9']);
      expect(diff.removed, isEmpty);
      expect(diff.hasChanges, isTrue);
    });

    test('detects a device that went away', () {
      final prev = [
        _d(ip: '192.168.1.2', mac: 'aa:bb:cc:00:00:01'),
        _d(ip: '192.168.1.9', mac: 'aa:bb:cc:00:00:09'),
      ];
      final curr = [_d(ip: '192.168.1.2', mac: 'aa:bb:cc:00:00:01')];
      final diff = diffScans(prev, curr);
      expect(diff.removed.map((d) => d.ip), ['192.168.1.9']);
      expect(diff.added, isEmpty);
    });

    test('detects an IP change on the same device (stable MAC)', () {
      final prev = [_d(ip: '192.168.1.2', mac: 'aa:bb:cc:00:00:01')];
      final curr = [_d(ip: '192.168.1.5', mac: 'aa:bb:cc:00:00:01')];
      final diff = diffScans(prev, curr);
      expect(diff.added, isEmpty);
      expect(diff.removed, isEmpty);
      expect(diff.changed, hasLength(1));
      final change = diff.changed.single;
      expect(change.fields, contains(DeviceChangeField.ip));
      expect(change.before.ip, '192.168.1.2');
      expect(change.after.ip, '192.168.1.5');
    });

    test('detects newly-opened ports on the same device', () {
      final prev = [
        _d(ip: '192.168.1.2', mac: 'aa:bb:cc:00:00:01', openPorts: [22]),
      ];
      final curr = [
        _d(ip: '192.168.1.2', mac: 'aa:bb:cc:00:00:01', openPorts: [22, 80]),
      ];
      final diff = diffScans(prev, curr);
      expect(diff.changed, hasLength(1));
      expect(diff.changed.single.fields, contains(DeviceChangeField.openPorts));
    });

    test('a fingerprint device reappearing online at its old IP is not "added"', () {
      // No MAC, so identity falls back to hostname+ports. While offline the
      // record is kept (greyed) with its last-known fingerprint; when it comes
      // back, this pass's port scan hasn't found every port yet, so the raw
      // fingerprint differs even though it's the same physical device at the
      // same IP.
      final offline = _d(
        ip: '192.168.1.9',
        hostname: 'printer',
        openPorts: const [9100],
      ).copyWith(isOnline: false);
      final reappeared = _d(
        ip: '192.168.1.9',
        hostname: 'printer',
        openPorts: const [9100, 80], // port 80 only just opened/detected
      );
      final added = excludeReappeared([reappeared], [offline]);
      expect(added, isEmpty);
    });

    test('excludeReappeared keeps a genuinely new device at a fresh IP', () {
      final previous = [_d(ip: '192.168.1.9', hostname: 'printer')];
      final newDevice = _d(ip: '192.168.1.50', hostname: 'laptop');
      expect(excludeReappeared([newDevice], previous), [newDevice]);
    });

    test('a host with a different discovery source but same state is unchanged', () {
      final prev = [
        Device(
          ip: '192.168.1.2',
          mac: 'aa:bb:cc:00:00:01',
          discoveredBy: {DiscoverySource.icmp},
          firstSeen: DateTime.utc(2026, 6, 22),
          lastSeen: DateTime.utc(2026, 6, 22),
        ),
      ];
      final curr = [
        Device(
          ip: '192.168.1.2',
          mac: 'aa:bb:cc:00:00:01',
          discoveredBy: {DiscoverySource.arp},
          firstSeen: DateTime.utc(2026, 6, 22),
          lastSeen: DateTime.utc(2026, 6, 23),
        ),
      ];
      // Discovery source and lastSeen are not meaningful "changes" to surface.
      expect(diffScans(prev, curr).hasChanges, isFalse);
    });
  });
}
