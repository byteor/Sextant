import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/model/device.dart';
import 'package:sextant/model/discovery_source.dart';
import 'package:sextant/state/providers.dart';

Device _dev(String? mac, Set<DiscoverySource> sources) {
  final now = DateTime(2026);
  return Device(
    ip: '192.168.1.20',
    mac: mac,
    discoveredBy: sources,
    firstSeen: now,
    lastSeen: now,
  );
}

void main() {
  group('mergeDeviceMac', () {
    const arpMac = 'aa:bb:cc:00:00:01';
    const mdnsMac = 'aa:bb:cc:00:00:02';

    test('an mDNS-only MAC does not replace a known ARP MAC', () {
      expect(
        mergeDeviceMac(
          _dev(arpMac, {DiscoverySource.arp}),
          _dev(mdnsMac, {DiscoverySource.mdns}),
        ),
        arpMac,
      );
    });

    test('an mDNS-only MAC fills in when no MAC is known', () {
      expect(
        mergeDeviceMac(
          _dev(null, {DiscoverySource.tcp}),
          _dev(mdnsMac, {DiscoverySource.mdns}),
        ),
        mdnsMac,
      );
    });

    test('an ARP MAC replaces an earlier mDNS-derived one', () {
      expect(
        mergeDeviceMac(
          _dev(mdnsMac, {DiscoverySource.mdns}),
          _dev(arpMac, {DiscoverySource.arp}),
        ),
        arpMac,
      );
    });

    test('keeps the existing MAC when the incoming one is null', () {
      expect(
        mergeDeviceMac(
          _dev(arpMac, {DiscoverySource.arp}),
          _dev(null, {DiscoverySource.netbios}),
        ),
        arpMac,
      );
    });
  });
}
