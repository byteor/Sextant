import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/scan/ipv4_subnet.dart';
import 'package:sextant/scan/scan_orchestrator.dart';

void main() {
  final subnet = Ipv4Subnet.fromCidr('192.168.4.0/22');

  group('isScannableArpEntry', () {
    test('accepts a normal in-subnet host with a unicast MAC', () {
      expect(
        isScannableArpEntry('192.168.6.123', '44:42:01:33:c0:1d', subnet),
        isTrue,
      );
    });

    test('rejects the broadcast address / broadcast MAC', () {
      expect(
        isScannableArpEntry('192.168.7.255', 'ff:ff:ff:ff:ff:ff', subnet),
        isFalse,
      );
    });

    test('rejects the network address', () {
      expect(isScannableArpEntry('192.168.4.0', '00:11:22:33:44:55', subnet),
          isFalse);
    });

    test('rejects multicast MACs (IPv4 and IPv6)', () {
      expect(isScannableArpEntry('192.168.4.50', '01:00:5e:00:00:fb', subnet),
          isFalse);
      expect(isScannableArpEntry('192.168.4.51', '33:33:00:00:00:01', subnet),
          isFalse);
    });

    test('rejects addresses outside the subnet', () {
      expect(isScannableArpEntry('10.0.0.5', '00:11:22:33:44:55', subnet),
          isFalse);
    });
  });
}
