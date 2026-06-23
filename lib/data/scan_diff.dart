import '../model/device.dart';
import 'device_identity.dart';

/// A device attribute whose change between two scans is worth surfacing.
enum DeviceChangeField { ip, hostname, vendor, deviceType, openPorts }

/// A device present in both scans whose meaningful state changed.
class DeviceChange {
  const DeviceChange({
    required this.before,
    required this.after,
    required this.fields,
  });

  final Device before;
  final Device after;
  final Set<DeviceChangeField> fields;
}

/// The difference between two scans of the same network: devices that appeared,
/// disappeared, or changed. Devices are correlated by [deviceIdentity] (MAC
/// primary, hostname+ports fingerprint fallback), so a device that merely
/// changed IP is a *change*, not a remove+add — provided its MAC is known.
class ScanDiff {
  const ScanDiff({
    this.added = const [],
    this.removed = const [],
    this.changed = const [],
  });

  final List<Device> added;
  final List<Device> removed;
  final List<DeviceChange> changed;

  bool get hasChanges =>
      added.isNotEmpty || removed.isNotEmpty || changed.isNotEmpty;
}

String _identity(Device d) =>
    deviceIdentity(mac: d.mac, hostname: d.hostname, openPorts: d.openPorts);

ScanDiff diffScans(List<Device> previous, List<Device> current) {
  final prevById = {for (final d in previous) _identity(d): d};
  final currById = {for (final d in current) _identity(d): d};

  final added = [
    for (final d in current)
      if (!prevById.containsKey(_identity(d))) d,
  ];
  final removed = [
    for (final d in previous)
      if (!currById.containsKey(_identity(d))) d,
  ];

  final changed = <DeviceChange>[];
  for (final entry in currById.entries) {
    final before = prevById[entry.key];
    if (before == null) continue; // it's an add, handled above
    final fields = _changedFields(before, entry.value);
    if (fields.isNotEmpty) {
      changed.add(
        DeviceChange(before: before, after: entry.value, fields: fields),
      );
    }
  }

  return ScanDiff(added: added, removed: removed, changed: changed);
}

Set<DeviceChangeField> _changedFields(Device a, Device b) {
  final fields = <DeviceChangeField>{};
  if (a.ip != b.ip) fields.add(DeviceChangeField.ip);
  if (a.hostname != b.hostname) fields.add(DeviceChangeField.hostname);
  if (a.vendor != b.vendor) fields.add(DeviceChangeField.vendor);
  if (a.deviceType != b.deviceType) fields.add(DeviceChangeField.deviceType);
  if (!_sameInts(a.openPorts, b.openPorts)) {
    fields.add(DeviceChangeField.openPorts);
  }
  return fields;
}

/// Removes devices from [added] that merely *reappeared online* at an IP they
/// already occupied while offline in [previous] — the same physical device
/// coming back, not a new one. This is needed because a fingerprint-fallback
/// identity (no MAC) can drift slightly between passes — a port not yet
/// detected, a hostname not yet resolved — which would otherwise make
/// [diffScans] see a different identity and misreport a reappearance as
/// "added".
List<Device> excludeReappeared(List<Device> added, List<Device> previous) {
  final previouslyOfflineIps = {
    for (final d in previous)
      if (!d.isOnline) d.ip,
  };
  return [
    for (final d in added)
      if (!previouslyOfflineIps.contains(d.ip)) d,
  ];
}

bool _sameInts(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  final sa = [...a]..sort();
  final sb = [...b]..sort();
  for (var i = 0; i < sa.length; i++) {
    if (sa[i] != sb[i]) return false;
  }
  return true;
}
