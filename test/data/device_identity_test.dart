import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/data/device_identity.dart';

void main() {
  group('deviceIdentity', () {
    test('uses the MAC address when one is available', () {
      final id = deviceIdentity(mac: 'A4:83:E7:2B:0C:09', hostname: 'mac-mini');
      expect(id, 'mac:a4:83:e7:2b:0c:09');
    });

    test('produces the same identity regardless of MAC formatting', () {
      expect(
        deviceIdentity(mac: 'a4-83-e7-2b-0c-09'),
        deviceIdentity(mac: 'A4:83:E7:2B:0C:09'),
      );
    });

    test('falls back to a hostname+ports fingerprint when MAC is absent', () {
      final id = deviceIdentity(hostname: 'printer', openPorts: [80, 443]);
      expect(id, startsWith('fp:'));
    });

    test('fingerprint is independent of port ordering', () {
      expect(
        deviceIdentity(hostname: 'printer', openPorts: [443, 80]),
        deviceIdentity(hostname: 'printer', openPorts: [80, 443]),
      );
    });

    test('different hostname or ports yield different fingerprints', () {
      final a = deviceIdentity(hostname: 'printer', openPorts: [80]);
      final b = deviceIdentity(hostname: 'camera', openPorts: [80]);
      final c = deviceIdentity(hostname: 'printer', openPorts: [80, 554]);
      expect(a, isNot(b));
      expect(a, isNot(c));
    });
  });
}
