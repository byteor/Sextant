import 'dart:async';
import 'dart:io';

import '../enrich/service_identifier.dart';
import '../model/device.dart';
import '../model/discovery_source.dart';
import '../model/network_info.dart';
import '../platform/arp_table.dart';
import '../platform/icmp_pinger.dart';
import '../platform/netbios.dart';
import 'banner_grabber.dart';
import 'ipv4_subnet.dart';
import 'mdns_discovery.dart';
import 'ssdp_discovery.dart';
import 'tcp_host_scanner.dart';
import 'well_known_ports.dart';

/// Open ports worth grabbing a banner from to identify the running service.
const _bannerPorts = {21, 22, 25, 80, 110, 143, 443, 3000, 5000, 8000, 8080,
    8443, 9000};

/// Whether an ARP-cache entry represents a real, scannable device — excluding
/// the subnet's network and broadcast addresses and any non-unicast MAC
/// (broadcast `ff:ff:ff:ff:ff:ff` and multicast `01:00:5e…` / `33:33…`).
bool isScannableArpEntry(String ip, String mac, Ipv4Subnet subnet) {
  final addr = InternetAddress(ip);
  if (!subnet.contains(addr)) return false;
  if (addr.address == subnet.networkAddress.address) return false;
  if (addr.address == subnet.broadcastAddress.address) return false;
  final m = mac.toLowerCase();
  if (m == 'ff:ff:ff:ff:ff:ff') return false;
  if (m.startsWith('01:00:5e') || m.startsWith('33:33')) return false;
  return true;
}

/// Resolves an IPv4 address to a hostname via reverse DNS. Returns null when no
/// PTR record exists or the lookup fails.
typedef HostnameResolver = Future<String?> Function(InternetAddress address);

Future<String?> _reverseDns(InternetAddress address) async {
  try {
    final resolved = await address.reverse();
    final host = resolved.host;
    return host == address.address ? null : host;
  } on SocketException {
    return null;
  }
}

/// Coordinates a scan of a [ScanNetwork] in two phases:
///
/// 1. **Host discovery** — ICMP-ping every address in the subnet (bounded
///    concurrency). This both finds ping responders and primes the ARP cache,
///    so reading the ARP table afterwards reveals every L2-present host,
///    including devices that have no open ports and ones that drop ICMP.
/// 2. **Port scan** — TCP-scan only the discovered live hosts for open ports.
///
/// A [Device] observation is emitted for each live host (with reverse-DNS
/// hostname and MAC), then again per host with its open ports; the scan
/// controller merges observations by IP. Discovery progress (the dominant
/// phase) is reported via [onHostComplete] so the UI can show "scanned X of Y".
///
/// Call [cancel] to signal all in-progress work to stop as soon as possible.
/// Workers stop picking up new tasks immediately; already-in-flight network
/// operations (pings, TCP connects) finish within their natural timeouts (≤2s).
class ScanOrchestrator {
  ScanOrchestrator({
    TcpHostScanner? scanner,
    IcmpSweeper? icmpSweeper,
    ArpResolver? arpResolver,
    BannerGrabber? bannerGrabber,
    MdnsDiscovery? mdns,
    NetbiosResolver? netbios,
    SsdpDiscovery? ssdp,
    HostnameResolver? resolveHostname,
    List<int>? ports,
    this.icmpEnabled = true,
    this.arpEnabled = true,
    this.tcpEnabled = true,
    this.mdnsEnabled = true,
    this.netbiosEnabled = true,
    this.ssdpEnabled = true,
  })  : _scanner = scanner ?? TcpHostScanner(),
        _icmp = icmpSweeper ?? IcmpSweeper(),
        _arp = arpResolver ?? const ArpResolver(),
        _banner = bannerGrabber ?? const BannerGrabber(),
        _mdns = mdns ?? const MdnsDiscovery(),
        _netbios = netbios ?? const NetbiosResolver(),
        _ssdp = ssdp ?? const SsdpDiscovery(),
        _resolveHostname = resolveHostname ?? _reverseDns,
        _ports = ports ?? kDefaultScanPorts;

  final TcpHostScanner _scanner;
  final IcmpSweeper _icmp;
  final ArpResolver _arp;
  final BannerGrabber _banner;
  final MdnsDiscovery _mdns;
  final NetbiosResolver _netbios;
  final SsdpDiscovery _ssdp;
  final HostnameResolver _resolveHostname;
  final List<int> _ports;

  /// Per-protocol enable flags, configured from Settings. A disabled protocol's
  /// scan phase is skipped entirely in [_run] (not merely hidden in the UI).
  /// All default true, preserving prior behavior for callers that don't set them.
  final bool icmpEnabled;
  final bool arpEnabled;
  final bool tcpEnabled;
  final bool mdnsEnabled;
  final bool netbiosEnabled;
  final bool ssdpEnabled;

  bool _cancelled = false;

  /// Signals all in-progress work to stop as soon as possible.
  void cancel() => _cancelled = true;

  Stream<Device> scan(
    ScanNetwork network, {
    HostProgress? onHostComplete,
    void Function(double)? onProgress,
  }) {
    _cancelled = false;
    final controller = StreamController<Device>();
    unawaited(_run(network, controller, onHostComplete, onProgress));
    return controller.stream;
  }

  Future<void> _run(
    ScanNetwork network,
    StreamController<Device> controller,
    HostProgress? onHostComplete,
    void Function(double)? onProgress,
  ) async {
    final hosts = network.subnet.hostAddresses().toList();
    final now = DateTime.now();
    final live = <String, InternetAddress>{};
    final pendingNames = <Future<void>>[];

    // mDNS/Bonjour and SSDP/UPnP run in parallel with the sweeps: many devices
    // announce a friendly name (and service/type) over these even with no
    // reverse-DNS record.
    if (mdnsEnabled) pendingNames.add(_runMdns(controller, network, now));
    if (ssdpEnabled) pendingNames.add(_runSsdp(controller, network, now));

    Device base(
      String ip,
      Set<DiscoverySource> sources, {
      String? mac,
      double? latencyMs,
    }) =>
        Device(
          ip: ip,
          mac: mac,
          discoveredBy: sources,
          firstSeen: now,
          lastSeen: now,
          networkId: network.id,
          latencyMs: latencyMs,
        );

    // Progress weights: when both ICMP and TCP are enabled, ICMP fills 0→80%
    // and TCP fills 80→100%. If only one phase is enabled it fills 0→100%.
    // This keeps progress strictly increasing — ICMP can never hit 100% while
    // TCP is still pending, so there is no backwards step when TCP kicks in.
    final double icmpEnd = (icmpEnabled && tcpEnabled) ? 0.8 : 1.0;
    final double tcpStart = icmpEnabled ? icmpEnd : 0.0;
    final double tcpRange = 1.0 - tcpStart;

    // Phase 1: ping sweep — emit each responder the instant it answers, and
    // kick off reverse DNS in the background.
    if (icmpEnabled && !_cancelled) {
      await for (final result in _icmp.sweep(
        hosts,
        onProgress: (done, total) {
          onHostComplete?.call(done, total);
          if (total > 0) onProgress?.call(icmpEnd * done / total);
        },
        isCancelled: () => _cancelled,
      )) {
        if (_cancelled) break;
        final addr = result.address;
        final ip = addr.address;
        live[ip] = addr;
        controller.add(
          base(ip, {DiscoverySource.icmp}, latencyMs: result.rttMs),
        );
        pendingNames.add(_emitHostname(controller, addr, network, now));
      }
    }

    // Phase 2: every L2-present host is now in the ARP cache. Emit MAC + ARP
    // source; hosts that didn't answer ping appear here for the first time.
    if (arpEnabled && !_cancelled) {
      final arp = await _arp.lookup();
      for (final entry in arp.entries) {
        if (_cancelled) break;
        if (!isScannableArpEntry(entry.key, entry.value, network.subnet)) {
          continue;
        }
        final isNew = !live.containsKey(entry.key);
        final addr = InternetAddress(entry.key);
        live[entry.key] = addr;
        controller.add(base(entry.key, {DiscoverySource.arp}, mac: entry.value));
        if (isNew) {
          pendingNames.add(_emitHostname(controller, addr, network, now));
        }
      }
    }

    // NetBIOS name lookups for the live hosts (gets Windows/SMB machine names),
    // in parallel with the port scan.
    if (netbiosEnabled && !_cancelled) {
      pendingNames
          .add(_runNetbios(controller, live.values.toList(), network, now));
    }

    // Phase 3: port-scan the live hosts; emit ports as each host completes,
    // then grab banners on identifiable ports to name the running services.
    if (tcpEnabled && !_cancelled) {
      final liveCount = live.length;
      await for (final result in _scanner.scan(
        live.values.toList(),
        _ports,
        onHostComplete: liveCount == 0 || onProgress == null
            ? null
            : (done, _) =>
                onProgress(tcpStart + tcpRange * done / liveCount),
        isCancelled: () => _cancelled,
      )) {
        if (_cancelled) break;
        controller.add(
          Device(
            ip: result.host.address,
            openPorts: result.openPorts,
            discoveredBy: {DiscoverySource.tcp},
            firstSeen: now,
            lastSeen: now,
            networkId: network.id,
          ),
        );
        pendingNames.add(_emitServices(controller, result, network, now));
      }
    }

    // Only wait for background helpers (DNS, mDNS, SSDP, NetBIOS, banners)
    // when the scan ran to completion. On cancellation, close immediately —
    // the helpers will finish on their own but check controller.isClosed
    // before writing, so no events are lost or errored.
    if (!_cancelled) {
      await Future.wait(pendingNames);
    }
    if (!controller.isClosed) await controller.close();
  }

  Future<void> _runMdns(
    StreamController<Device> controller,
    ScanNetwork network,
    DateTime now,
  ) async {
    try {
      await for (final obs in _mdns.discover()) {
        if (_cancelled || controller.isClosed) break;
        final InternetAddress addr;
        try {
          addr = InternetAddress(obs.ip);
        } catch (_) {
          continue;
        }
        if (!network.subnet.contains(addr) || controller.isClosed) continue;
        controller.add(
          Device(
            ip: obs.ip,
            hostname: obs.name.isEmpty ? null : obs.name,
            services: {obs.port: obs.serviceLabel},
            discoveredBy: {DiscoverySource.mdns},
            firstSeen: now,
            lastSeen: now,
            networkId: network.id,
          ),
        );
      }
    } catch (_) {
      // mDNS is best-effort; never let it break a scan.
    }
  }

  Future<void> _runSsdp(
    StreamController<Device> controller,
    ScanNetwork network,
    DateTime now,
  ) async {
    try {
      await for (final obs in _ssdp.discover()) {
        if (_cancelled || controller.isClosed) break;
        final InternetAddress addr;
        try {
          addr = InternetAddress(obs.ip);
        } catch (_) {
          continue;
        }
        if (!network.subnet.contains(addr) || controller.isClosed) continue;
        controller.add(
          Device(
            ip: obs.ip,
            hostname: (obs.name?.isEmpty ?? true) ? null : obs.name,
            // The UPnP device-type label feeds the classifier via the services
            // values; key 1900 (SSDP) keeps it out of the open-port chips.
            services: obs.typeLabel != null ? {1900: obs.typeLabel!} : const {},
            discoveredBy: {DiscoverySource.ssdp},
            firstSeen: now,
            lastSeen: now,
            networkId: network.id,
          ),
        );
      }
    } catch (_) {
      // SSDP is best-effort; never let it break a scan.
    }
  }

  Future<void> _runNetbios(
    StreamController<Device> controller,
    List<InternetAddress> hosts,
    ScanNetwork network,
    DateTime now,
  ) async {
    const concurrency = 32;
    var next = 0;
    Future<void> worker() async {
      while (next < hosts.length) {
        if (_cancelled) break;
        final host = hosts[next++];
        final name = await _netbios.queryName(host);
        if (name == null || controller.isClosed) continue;
        controller.add(
          Device(
            ip: host.address,
            hostname: name,
            discoveredBy: {DiscoverySource.netbios},
            firstSeen: now,
            lastSeen: now,
            networkId: network.id,
          ),
        );
      }
    }

    await Future.wait([
      for (var i = 0; i < concurrency && i < hosts.length; i++) worker(),
    ]);
  }

  Future<void> _emitServices(
    StreamController<Device> controller,
    HostScanResult result,
    ScanNetwork network,
    DateTime now,
  ) async {
    if (_cancelled) return;
    final ports = result.openPorts.where(_bannerPorts.contains).toList();
    if (ports.isEmpty) return;
    final services = <int, String>{};
    await Future.wait(ports.map((port) async {
      if (_cancelled) return;
      final raw = await _banner.grab(result.host, port);
      if (raw == null) return;
      final service = identifyService(port, raw);
      if (service != null) services[port] = service;
    }));
    if (services.isEmpty || controller.isClosed) return;
    controller.add(
      Device(
        ip: result.host.address,
        services: services,
        firstSeen: now,
        lastSeen: now,
        networkId: network.id,
      ),
    );
  }

  Future<void> _emitHostname(
    StreamController<Device> controller,
    InternetAddress addr,
    ScanNetwork network,
    DateTime now,
  ) async {
    if (_cancelled) return;
    final name = await _resolveHostname(addr);
    if (name == null || controller.isClosed) return;
    controller.add(
      Device(
        ip: addr.address,
        hostname: name,
        firstSeen: now,
        lastSeen: now,
        networkId: network.id,
      ),
    );
  }
}
