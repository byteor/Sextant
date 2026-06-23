import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/platform/wake_on_lan.dart';

void main() {
  group('buildMagicPacket', () {
    test('is 102 bytes: 6 bytes of 0xFF then the MAC repeated 16 times', () {
      final packet = buildMagicPacket('aa:bb:cc:dd:ee:ff');

      expect(packet.length, 102);
      expect(packet.sublist(0, 6), [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);
      const mac = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF];
      for (var i = 0; i < 16; i++) {
        final start = 6 + i * 6;
        expect(packet.sublist(start, start + 6), mac,
            reason: 'repetition $i should match the MAC');
      }
    });

    test('accepts hyphen-separated MAC addresses', () {
      final packet = buildMagicPacket('AA-BB-CC-DD-EE-FF');
      expect(packet.sublist(6, 12), [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]);
    });

    test('throws for a MAC address with the wrong number of octets', () {
      expect(() => buildMagicPacket('aa:bb:cc:dd:ee'), throwsArgumentError);
      expect(
        () => buildMagicPacket('aa:bb:cc:dd:ee:ff:00'),
        throwsArgumentError,
      );
    });

    test('throws for a MAC address with invalid hex digits', () {
      expect(() => buildMagicPacket('zz:bb:cc:dd:ee:ff'), throwsArgumentError);
    });
  });
}
