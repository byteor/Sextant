import '../model/network_info.dart';

/// Resolves which network the UI should act on, given the discovered [networks]
/// and the user's [selected] one (if any).
///
/// Selection is matched by stable [ScanNetwork.id], not object identity, so it
/// survives re-discovery after a network change (which yields fresh
/// [ScanNetwork] objects for the same network). When nothing is selected, or
/// the selected network has disappeared, this falls back to the first network —
/// and [networks] is ordered Wi-Fi-first, so that default is Wi-Fi.
ScanNetwork? effectiveNetwork(List<ScanNetwork> networks, ScanNetwork? selected) {
  if (networks.isEmpty) return null;
  if (selected != null) {
    for (final n in networks) {
      if (n.id == selected.id) return n;
    }
  }
  return networks.first;
}
