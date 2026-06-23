import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/enrich/liveness.dart';
import 'package:sextant/model/discovery_source.dart';

void main() {
  group('activelyReachable', () {
    test('ARP presence alone is NOT proof of liveness (stale cache)', () {
      // A powered-off device lingers in the ARP cache for minutes.
      expect(activelyReachable({DiscoverySource.arp}), isFalse);
    });

    test('an ICMP reply proves liveness', () {
      expect(
        activelyReachable({DiscoverySource.arp, DiscoverySource.icmp}),
        isTrue,
      );
    });

    test('an open TCP port proves liveness', () {
      expect(
        activelyReachable({DiscoverySource.arp}, hasOpenPorts: true),
        isTrue,
      );
    });

    test('a discovery-protocol answer proves liveness', () {
      expect(activelyReachable({DiscoverySource.mdns}), isTrue);
      expect(activelyReachable({DiscoverySource.netbios}), isTrue);
      expect(activelyReachable({DiscoverySource.ssdp}), isTrue);
      expect(activelyReachable({DiscoverySource.bonjour}), isTrue);
      expect(activelyReachable({DiscoverySource.tcp}), isTrue);
    });

    test('no sources and no open ports is not reachable', () {
      expect(activelyReachable(const {}), isFalse);
    });
  });
}
