import 'discovery_source.dart';

/// A device discovered on the network, aggregated across all scan sources.
class Device {
  Device({
    required this.ip,
    this.mac,
    this.vendor,
    this.hostname,
    this.customName,
    this.deviceType = DeviceType.unknown,
    List<int>? openPorts,
    Map<int, String>? services,
    Set<DiscoverySource>? discoveredBy,
    required this.firstSeen,
    required this.lastSeen,
    this.networkId,
    this.isOnline = true,
    this.latencyMs,
    this.additionalIps = const [],
  })  : openPorts = openPorts ?? const [],
        services = services ?? const {},
        discoveredBy = discoveredBy ?? const {};

  final String ip;
  final String? mac;
  final String? vendor;
  final String? hostname;

  /// A user-assigned name, persisted by device identity. Takes precedence over
  /// [hostname] for display.
  final String? customName;
  final DeviceType deviceType;

  /// Open TCP ports, ascending.
  final List<int> openPorts;

  /// Identified service per port (e.g. {22: 'OpenSSH 9.6', 80: 'nginx 1.25'}).
  final Map<int, String> services;
  final Set<DiscoverySource> discoveredBy;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final String? networkId;

  /// Whether the device was seen in the most recent scan. During live
  /// monitoring a device that stops responding is kept in the list but marked
  /// offline (rendered greyed-out) rather than removed.
  final bool isOnline;

  /// Round-trip ICMP latency in milliseconds from the most recent scan that
  /// pinged this device, if any (some devices never answer ICMP).
  final double? latencyMs;

  /// Secondary IPs of the same physical host (multi-homed devices sharing a
  /// MAC), beyond the primary [ip]. Populated only by display-time dedup.
  final List<String> additionalIps;

  /// What to show as the device's primary label.
  String get displayName => customName ?? hostname ?? ip;

  /// A numeric key for sorting by IPv4 address (so 192.168.1.9 < 192.168.1.10).
  int get ipSortKey {
    final parts = ip.split('.');
    if (parts.length != 4) return 0;
    var value = 0;
    for (final part in parts) {
      value = (value << 8) | (int.tryParse(part) ?? 0);
    }
    return value & 0xFFFFFFFF;
  }

  Device copyWith({
    String? ip,
    String? mac,
    String? vendor,
    String? hostname,
    String? customName,
    DeviceType? deviceType,
    List<int>? openPorts,
    Map<int, String>? services,
    Set<DiscoverySource>? discoveredBy,
    DateTime? firstSeen,
    DateTime? lastSeen,
    String? networkId,
    bool? isOnline,
    double? latencyMs,
    List<String>? additionalIps,
  }) {
    return Device(
      ip: ip ?? this.ip,
      mac: mac ?? this.mac,
      vendor: vendor ?? this.vendor,
      hostname: hostname ?? this.hostname,
      customName: customName ?? this.customName,
      deviceType: deviceType ?? this.deviceType,
      openPorts: openPorts ?? this.openPorts,
      services: services ?? this.services,
      discoveredBy: discoveredBy ?? this.discoveredBy,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      networkId: networkId ?? this.networkId,
      isOnline: isOnline ?? this.isOnline,
      latencyMs: latencyMs ?? this.latencyMs,
      additionalIps: additionalIps ?? this.additionalIps,
    );
  }
}
