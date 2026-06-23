import '../model/device.dart';
import '../model/discovery_source.dart';

/// Serialises a [Device] into a plain, JSON-encodable map so a scan snapshot can
/// be persisted (e.g. as the devices column of a history row) and restored
/// later without loss. Enums are stored by `name`; unrecognised names decode to
/// safe defaults so a future enum rename never breaks loading old history.
Map<String, dynamic> deviceToMap(Device device) => {
      'ip': device.ip,
      'mac': device.mac,
      'vendor': device.vendor,
      'hostname': device.hostname,
      'customName': device.customName,
      'deviceType': device.deviceType.name,
      'openPorts': device.openPorts,
      'services': {
        for (final entry in device.services.entries)
          entry.key.toString(): entry.value,
      },
      'discoveredBy': [for (final s in device.discoveredBy) s.name],
      'firstSeen': device.firstSeen.toIso8601String(),
      'lastSeen': device.lastSeen.toIso8601String(),
      'networkId': device.networkId,
      'isOnline': device.isOnline,
      'latencyMs': device.latencyMs,
    };

Device deviceFromMap(Map<String, dynamic> map) => Device(
      ip: map['ip'] as String,
      mac: map['mac'] as String?,
      vendor: map['vendor'] as String?,
      hostname: map['hostname'] as String?,
      customName: map['customName'] as String?,
      deviceType: _deviceType(map['deviceType']),
      openPorts: [
        for (final p in (map['openPorts'] as List? ?? const [])) p as int,
      ],
      services: {
        for (final entry
            in (map['services'] as Map?)?.entries ?? const <MapEntry>[])
          int.parse(entry.key as String): entry.value as String,
      },
      discoveredBy: {
        for (final s in (map['discoveredBy'] as List? ?? const [])) ?_source(s),
      },
      firstSeen: DateTime.parse(map['firstSeen'] as String),
      lastSeen: DateTime.parse(map['lastSeen'] as String),
      networkId: map['networkId'] as String?,
      isOnline: map['isOnline'] as bool? ?? true,
      latencyMs: (map['latencyMs'] as num?)?.toDouble(),
    );

DeviceType _deviceType(Object? name) {
  for (final t in DeviceType.values) {
    if (t.name == name) return t;
  }
  return DeviceType.unknown;
}

DiscoverySource? _source(Object? name) {
  for (final s in DiscoverySource.values) {
    if (s.name == name) return s;
  }
  return null;
}
