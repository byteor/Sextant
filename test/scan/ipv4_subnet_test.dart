import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/scan/ipv4_subnet.dart';

void main() {
  group('Ipv4Subnet', () {
    test('a /24 yields 254 usable host addresses', () {
      final subnet = Ipv4Subnet.fromCidr('192.168.1.0/24');

      final hosts = subnet.hostAddresses().toList();

      expect(hosts, hasLength(254));
      expect(hosts.first.address, '192.168.1.1');
      expect(hosts.last.address, '192.168.1.254');
      final addresses = hosts.map((h) => h.address);
      expect(addresses, isNot(contains('192.168.1.0'))); // network
      expect(addresses, isNot(contains('192.168.1.255'))); // broadcast
    });

    test('a /30 yields its 2 usable hosts', () {
      final subnet = Ipv4Subnet.fromCidr('10.0.0.0/30');

      expect(
        subnet.hostAddresses().map((h) => h.address),
        ['10.0.0.1', '10.0.0.2'],
      );
    });

    test('derives the network from an arbitrary host IP and prefix', () {
      final subnet = Ipv4Subnet.fromHostAndPrefix(
        InternetAddress('192.168.1.57'),
        24,
      );

      expect(subnet.networkAddress.address, '192.168.1.0');
      expect(subnet.broadcastAddress.address, '192.168.1.255');
      expect(subnet.hostAddresses(), hasLength(254));
    });

    test('derives the prefix from a dotted netmask', () {
      final subnet = Ipv4Subnet.fromHostAndMask(
        InternetAddress('192.168.1.57'),
        InternetAddress('255.255.255.0'),
      );

      expect(subnet.prefixLength, 24);
      expect(subnet.networkAddress.address, '192.168.1.0');
    });

    test('contains() reports membership across the whole range', () {
      final subnet = Ipv4Subnet.fromCidr('192.168.4.0/22');

      expect(subnet.contains(InternetAddress('192.168.4.0')), isTrue);
      expect(subnet.contains(InternetAddress('192.168.6.10')), isTrue);
      expect(subnet.contains(InternetAddress('192.168.7.255')), isTrue);
      expect(subnet.contains(InternetAddress('192.168.8.1')), isFalse);
      expect(subnet.contains(InternetAddress('192.168.3.255')), isFalse);
    });

    test('a /32 yields exactly its single address', () {
      final subnet = Ipv4Subnet.fromCidr('192.168.1.5/32');

      expect(
        subnet.hostAddresses().map((h) => h.address),
        ['192.168.1.5'],
      );
    });
  });
}
