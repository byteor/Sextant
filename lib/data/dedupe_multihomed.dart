import '../model/device.dart';
import '../platform/arp_table.dart';

/// Collapses devices that share a MAC address (multi-homed hosts — e.g. a
/// machine with both Wi-Fi and Ethernet up) into one row for display,
/// keeping the lowest IP as the primary and recording the rest in
/// [Device.additionalIps]. Devices without a MAC (most fingerprint-identity
/// devices) pass through unchanged, since grouping them would risk merging
/// unrelated hosts. This is a display-only transform: callers must apply it
/// strictly after diffing/history have already used the raw per-IP list.
List<Device> dedupeMultihomed(List<Device> devices) {
  final byMac = <String, List<Device>>{};
  final result = <Device>[];

  for (final d in devices) {
    final mac = d.mac;
    if (mac == null) {
      result.add(d);
      continue;
    }
    byMac.putIfAbsent(normalizeMac(mac.replaceAll('-', ':')), () => []).add(d);
  }

  for (final group in byMac.values) {
    if (group.length == 1) {
      result.add(group.single);
      continue;
    }
    final sorted = [...group]..sort((a, b) => a.ipSortKey.compareTo(b.ipSortKey));
    final primary = sorted.first;
    final others = sorted.skip(1);

    final openPorts = <int>{...primary.openPorts};
    final services = <int, String>{...primary.services};
    final discoveredBy = {...primary.discoveredBy};
    var isOnline = primary.isOnline;
    for (final o in others) {
      openPorts.addAll(o.openPorts);
      services.addAll(o.services);
      discoveredBy.addAll(o.discoveredBy);
      isOnline = isOnline || o.isOnline;
    }

    result.add(primary.copyWith(
      openPorts: openPorts.toList()..sort(),
      services: services,
      discoveredBy: discoveredBy,
      isOnline: isOnline,
      additionalIps: [for (final o in others) o.ip],
    ));
  }

  return result;
}
