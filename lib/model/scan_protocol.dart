import 'dart:io';

import '../l10n/gen/app_localizations.dart';

/// The discovery/scan mechanisms [ScanOrchestrator] runs, individually
/// toggleable from Settings. Distinct from [DiscoverySource]: that enum
/// labels *how a device was found* after the fact; this one controls *which
/// mechanisms run at all*.
enum ScanProtocol { icmp, arp, tcp, mdns, netbios, ssdp }

extension ScanProtocolInfo on ScanProtocol {
  String label(AppLocalizations l10n) => switch (this) {
        ScanProtocol.icmp => l10n.protocolIcmp,
        ScanProtocol.arp => l10n.protocolArp,
        ScanProtocol.tcp => l10n.protocolTcp,
        ScanProtocol.mdns => l10n.protocolMdns,
        ScanProtocol.netbios => l10n.protocolNetbios,
        ScanProtocol.ssdp => l10n.protocolSsdp,
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
