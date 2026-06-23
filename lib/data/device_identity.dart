import '../platform/arp_table.dart' show normalizeMac;

/// Computes a stable identity key for a device, used to persist user-assigned
/// names/notes and to correlate the same device across scans.
///
/// Strategy (decided during design): **MAC primary, fingerprint fallback.**
/// When a MAC is known it is authoritative. Otherwise — common on mobile, where
/// the ARP table is inaccessible — a composite fingerprint of the hostname and
/// open-port signature is used so renames still survive across IP changes.
String deviceIdentity({
  String? mac,
  String? hostname,
  List<int> openPorts = const [],
}) {
  if (mac != null && mac.trim().isNotEmpty) {
    return 'mac:${normalizeMac(mac.replaceAll('-', ':'))}';
  }
  final ports = [...openPorts]..sort();
  return 'fp:${hostname ?? ''}|${ports.join(',')}';
}
