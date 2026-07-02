import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/model/device.dart';
import 'package:sextant/model/discovery_source.dart';
import 'package:sextant/model/network_info.dart';
import 'package:sextant/platform/arp_table.dart';
import 'package:sextant/platform/icmp_pinger.dart';
import 'package:sextant/platform/netbios.dart';
import 'package:sextant/scan/ipv4_subnet.dart';
import 'package:sextant/scan/mdns_discovery.dart';
import 'package:sextant/scan/scan_orchestrator.dart';
import 'package:sextant/scan/ssdp_discovery.dart';
import 'package:sextant/scan/tcp_host_scanner.dart';

/// mDNS/NetBIOS do real network IO; keep this end-to-end test hermetic.
class _SilentMdns extends MdnsDiscovery {
  const _SilentMdns();
  @override
  Stream<MdnsObservation> discover({
    Duration timeout = const Duration(seconds: 4),
  }) =>
      const Stream.empty();
}

class _SilentNetbios extends NetbiosResolver {
  const _SilentNetbios();
  @override
  Future<String?> queryName(InternetAddress host) async => null;
}

class _SilentSsdp extends SsdpDiscovery {
  const _SilentSsdp();
  @override
  Stream<SsdpObservation> discover({
    Duration timeout = const Duration(seconds: 3),
  }) =>
      const Stream.empty();
}

class _TrackingIcmpSweeper extends IcmpSweeper {
  bool called = false;
  @override
  Stream<PingResult> sweep(
    List<InternetAddress> hosts, {
    PingProgress? onProgress,
    bool Function()? isCancelled,
  }) {
    called = true;
    return const Stream.empty();
  }
}

class _TrackingArpResolver extends ArpResolver {
  bool called = false;
  @override
  Future<Map<String, String>> lookup() async {
    called = true;
    return const {};
  }
}

class _TrackingTcpHostScanner extends TcpHostScanner {
  bool called = false;
  @override
  Stream<HostScanResult> scan(
    List<InternetAddress> hosts,
    List<int> ports, {
    HostProgress? onHostComplete,
    bool Function()? isCancelled,
  }) {
    called = true;
    return const Stream.empty();
  }
}

class _TrackingMdns extends MdnsDiscovery {
  bool called = false;
  @override
  Stream<MdnsObservation> discover({
    Duration timeout = const Duration(seconds: 4),
  }) {
    called = true;
    return const Stream.empty();
  }
}

class _TrackingNetbios extends NetbiosResolver {
  bool called = false;
  @override
  Future<String?> queryName(InternetAddress host) async {
    called = true;
    return null;
  }
}

class _TrackingSsdp extends SsdpDiscovery {
  bool called = false;
  @override
  Stream<SsdpObservation> discover({
    Duration timeout = const Duration(seconds: 3),
  }) {
    called = true;
    return const Stream.empty();
  }
}

ScanNetwork _loopbackNetwork() => ScanNetwork(
      interfaceName: 'lo',
      displayName: 'Loopback',
      address: InternetAddress.loopbackIPv4,
      subnet: Ipv4Subnet.fromCidr('127.0.0.1/32'),
    );

void main() {
  test('ScanOrchestrator discovers a live loopback host end-to-end', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close());

    final network = ScanNetwork(
      interfaceName: 'lo',
      displayName: 'Loopback',
      address: InternetAddress.loopbackIPv4,
      // /32 so the subnet enumerates exactly 127.0.0.1.
      subnet: Ipv4Subnet.fromCidr('127.0.0.1/32'),
    );

    final orchestrator = ScanOrchestrator(
      ports: [server.port],
      mdns: const _SilentMdns(),
      netbios: const _SilentNetbios(),
      ssdp: const _SilentSsdp(),
    );

    // The orchestrator emits several observations per host (discovery + ports);
    // merge them by IP the way the scan controller does.
    final byIp = <String, Device>{};
    await for (final d in orchestrator.scan(network)) {
      final existing = byIp[d.ip];
      byIp[d.ip] = Device(
        ip: d.ip,
        openPorts: {...?existing?.openPorts, ...d.openPorts}.toList()..sort(),
        discoveredBy: {...?existing?.discoveredBy, ...d.discoveredBy},
        firstSeen: d.firstSeen,
        lastSeen: d.lastSeen,
        networkId: d.networkId,
      );
    }

    expect(byIp.keys, ['127.0.0.1']);
    final device = byIp['127.0.0.1']!;
    expect(device.openPorts, [server.port]);
    expect(device.discoveredBy, contains(DiscoverySource.tcp));
    expect(device.discoveredBy, contains(DiscoverySource.icmp));
    expect(device.networkId, network.id);
  });

  test('icmpEnabled: false never calls IcmpSweeper.sweep()', () async {
    final tracker = _TrackingIcmpSweeper();
    final orchestrator = ScanOrchestrator(
      icmpSweeper: tracker,
      mdns: const _SilentMdns(),
      netbios: const _SilentNetbios(),
      ssdp: const _SilentSsdp(),
      icmpEnabled: false,
    );

    await orchestrator.scan(_loopbackNetwork()).toList();

    expect(tracker.called, isFalse);
  });

  test('arpEnabled: false never calls ArpResolver.lookup()', () async {
    final tracker = _TrackingArpResolver();
    final orchestrator = ScanOrchestrator(
      arpResolver: tracker,
      mdns: const _SilentMdns(),
      netbios: const _SilentNetbios(),
      ssdp: const _SilentSsdp(),
      arpEnabled: false,
    );

    await orchestrator.scan(_loopbackNetwork()).toList();

    expect(tracker.called, isFalse);
  });

  test('tcpEnabled: false never calls TcpHostScanner.scan()', () async {
    final tracker = _TrackingTcpHostScanner();
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close());
    final orchestrator = ScanOrchestrator(
      scanner: tracker,
      ports: [server.port],
      mdns: const _SilentMdns(),
      netbios: const _SilentNetbios(),
      ssdp: const _SilentSsdp(),
      tcpEnabled: false,
    );

    final found = await orchestrator.scan(_loopbackNetwork()).toList();

    expect(tracker.called, isFalse);
    expect(found.any((d) => d.openPorts.isNotEmpty), isFalse);
  });

  test('mdnsEnabled: false never calls MdnsDiscovery.discover()', () async {
    final tracker = _TrackingMdns();
    final orchestrator = ScanOrchestrator(
      mdns: tracker,
      netbios: const _SilentNetbios(),
      ssdp: const _SilentSsdp(),
      mdnsEnabled: false,
    );

    await orchestrator.scan(_loopbackNetwork()).toList();

    expect(tracker.called, isFalse);
  });

  test('netbiosEnabled: false never calls NetbiosResolver.queryName()',
      () async {
    final tracker = _TrackingNetbios();
    final orchestrator = ScanOrchestrator(
      mdns: const _SilentMdns(),
      netbios: tracker,
      ssdp: const _SilentSsdp(),
      netbiosEnabled: false,
    );

    await orchestrator.scan(_loopbackNetwork()).toList();

    expect(tracker.called, isFalse);
  });

  test('ssdpEnabled: false never calls SsdpDiscovery.discover()', () async {
    final tracker = _TrackingSsdp();
    final orchestrator = ScanOrchestrator(
      mdns: const _SilentMdns(),
      netbios: const _SilentNetbios(),
      ssdp: tracker,
      ssdpEnabled: false,
    );

    await orchestrator.scan(_loopbackNetwork()).toList();

    expect(tracker.called, isFalse);
  });
}
