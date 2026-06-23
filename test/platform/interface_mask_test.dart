import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/platform/interface_mask.dart';

void main() {
  group('prefixFromIfconfig (macOS/BSD)', () {
    test('parses a hex netmask into a prefix length', () {
      const output = '''
en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
	inet 192.168.4.25 netmask 0xfffffc00 broadcast 192.168.7.255
''';
      expect(prefixFromIfconfig(output), 22);
    });

    test('parses a /24 hex netmask', () {
      const output = '\tinet 10.0.0.5 netmask 0xffffff00 broadcast 10.0.0.255';
      expect(prefixFromIfconfig(output), 24);
    });

    test('returns null when there is no netmask', () {
      expect(prefixFromIfconfig('en0: flags=8863 mtu 1500'), isNull);
    });
  });

  group('prefixFromIpAddr (Linux)', () {
    test('parses the CIDR suffix from `ip -o -f inet addr show`', () {
      const output =
          '2: eth0    inet 192.168.4.25/22 brd 192.168.7.255 scope global eth0';
      expect(prefixFromIpAddr(output), 22);
    });

    test('returns null when there is no inet line', () {
      expect(prefixFromIpAddr('1: lo: <LOOPBACK> mtu 65536'), isNull);
    });
  });
}
