import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/model/network_info.dart';
import 'package:sextant/scan/ipv4_subnet.dart';
import 'package:sextant/state/network_selection.dart';

ScanNetwork _net(String iface, String ip, {LinkType link = LinkType.other}) {
  final addr = InternetAddress(ip);
  return ScanNetwork(
    interfaceName: iface,
    displayName: iface,
    address: addr,
    subnet: Ipv4Subnet.fromHostAndPrefix(addr, 24),
    linkType: link,
  );
}

void main() {
  group('effectiveNetwork', () {
    test('returns null when there are no networks', () {
      expect(effectiveNetwork(const [], null), isNull);
    });

    test('defaults to the first (Wi-Fi-first) network when nothing selected', () {
      final wifi = _net('en0', '192.168.1.10', link: LinkType.wifi);
      final wired = _net('en4', '10.0.0.5', link: LinkType.wired);
      expect(effectiveNetwork([wifi, wired], null), same(wifi));
    });

    test('keeps the selected network when it is still present', () {
      final wifi = _net('en0', '192.168.1.10', link: LinkType.wifi);
      final wired = _net('en4', '10.0.0.5', link: LinkType.wired);
      expect(effectiveNetwork([wifi, wired], wired), same(wired));
    });

    test('matches selection by stable id across re-discovery (new object)', () {
      // After a network change, networksProvider yields fresh ScanNetwork
      // objects; the selection must survive via id, not object identity.
      final before = _net('en4', '10.0.0.5', link: LinkType.wired);
      final after = _net('en4', '10.0.0.5', link: LinkType.wired);
      expect(identical(before, after), isFalse);
      final result = effectiveNetwork([after], before);
      expect(result, same(after)); // the new object, not the stale one
    });

    test('falls back to Wi-Fi-first when the selected network disappeared', () {
      final wifi = _net('en0', '192.168.1.10', link: LinkType.wifi);
      final gone = _net('en9', '172.16.0.2', link: LinkType.wired);
      expect(effectiveNetwork([wifi], gone), same(wifi));
    });
  });
}
