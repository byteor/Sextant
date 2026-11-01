import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/scan/mdns_discovery.dart';

void main() {
  group('macFromEui64LinkLocal', () {
    test('recovers the MAC from an EUI-64 link-local address', () {
      // MAC ac:de:48:00:11:22 -> IID with the U/L bit flipped and ff:fe inserted.
      final addr = InternetAddress('fe80::aede:48ff:fe00:1122');
      expect(macFromEui64LinkLocal(addr), 'ac:de:48:00:11:22');
    });

    test('returns null for a privacy (non EUI-64) interface ID', () {
      expect(
        macFromEui64LinkLocal(InternetAddress('fe80::1c2b:3d4e:5f60:7182')),
        isNull,
      );
    });

    test('returns null for non-link-local and IPv4 addresses', () {
      expect(
        macFromEui64LinkLocal(InternetAddress('2001:db8::aede:48ff:fe00:1122')),
        isNull,
      );
      expect(macFromEui64LinkLocal(InternetAddress('192.168.4.1')), isNull);
    });
  });
}
