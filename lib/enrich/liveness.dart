import '../model/discovery_source.dart';

/// Discovery sources that represent an *active* response from the device this
/// scan (as opposed to the passive ARP cache).
const _activeSources = {
  DiscoverySource.icmp,
  DiscoverySource.tcp,
  DiscoverySource.mdns,
  DiscoverySource.bonjour,
  DiscoverySource.netbios,
  DiscoverySource.ssdp,
};

/// Whether a device was *actively* reachable this scan, rather than merely
/// present in the ARP cache.
///
/// A powered-off device lingers in the OS ARP cache for minutes, so ARP
/// presence alone does not prove liveness. We require an active response — an
/// ICMP reply, an open TCP port, or an answer to a discovery protocol
/// (mDNS/NetBIOS/SSDP). This lets monitoring mark a stale-ARP-only device
/// offline instead of showing it perpetually online.
bool activelyReachable(
  Set<DiscoverySource> sources, {
  bool hasOpenPorts = false,
}) {
  return hasOpenPorts || sources.any(_activeSources.contains);
}
