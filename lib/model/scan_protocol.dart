import 'dart:io';

/// The discovery/scan mechanisms [ScanOrchestrator] runs, individually
/// toggleable from Settings. Distinct from [DiscoverySource]: that enum
/// labels *how a device was found* after the fact; this one controls *which
/// mechanisms run at all*.
enum ScanProtocol { icmp, arp, tcp, mdns, netbios, ssdp }

extension ScanProtocolInfo on ScanProtocol {
  String get label => switch (this) {
        ScanProtocol.icmp => 'ICMP ping sweep',
        ScanProtocol.arp => 'ARP table',
        ScanProtocol.tcp => 'TCP port scan',
        ScanProtocol.mdns => 'mDNS / Bonjour',
        ScanProtocol.netbios => 'NetBIOS',
        ScanProtocol.ssdp => 'SSDP / UPnP',
      };

  /// Whether this protocol can run at all on the current platform. ICMP and
  /// ARP both shell out to a system binary that's only reachable on desktop —
  /// matching the platform gate `ArpResolver.lookup()` already uses (see
  /// `lib/platform/arp_table.dart`). The rest are pure Dart socket
  /// operations, available everywhere.
  bool get isAvailableOnThisPlatform {
    switch (this) {
      case ScanProtocol.icmp:
      case ScanProtocol.arp:
        return Platform.isMacOS || Platform.isLinux || Platform.isWindows;
      case ScanProtocol.tcp:
      case ScanProtocol.mdns:
      case ScanProtocol.netbios:
      case ScanProtocol.ssdp:
        return true;
    }
  }
}
