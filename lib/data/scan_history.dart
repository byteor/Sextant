import '../model/device.dart';
import 'scan_diff.dart';
import 'scan_record.dart';

/// All scans of one network, newest-first, for the history UI's per-network
/// grouping.
class NetworkScanHistory {
  const NetworkScanHistory({
    required this.networkId,
    required this.networkLabel,
    required this.scans,
  });

  final String networkId;
  final String networkLabel;

  /// Scans of this network, most recent first.
  final List<ScanRecord> scans;

  ScanRecord get latest => scans.first;
}

/// What happened to a device between two consecutive scans.
enum ScanChangeKind { appeared, disappeared, changed }

/// A single entry in a network's change log: one device appearing,
/// disappearing, or changing between two consecutive scans, stamped with the
/// time of the *newer* scan.
class ScanChangeEntry {
  const ScanChangeEntry({
    required this.timestamp,
    required this.kind,
    required this.device,
    this.fields = const {},
  });

  final DateTime timestamp;
  final ScanChangeKind kind;

  /// The device involved: its new state for [ScanChangeKind.appeared] /
  /// [ScanChangeKind.changed], its last-seen state for
  /// [ScanChangeKind.disappeared].
  final Device device;

  /// For [ScanChangeKind.changed], which attributes differ.
  final Set<DeviceChangeField> fields;
}

/// Groups [scans] by network, with both the networks and each network's scans
/// ordered most-recent-first (networks ranked by their latest scan).
List<NetworkScanHistory> groupByNetwork(List<ScanRecord> scans) {
  final byNetwork = <String, List<ScanRecord>>{};
  final labels = <String, String>{};
  for (final scan in scans) {
    byNetwork.putIfAbsent(scan.networkId, () => []).add(scan);
    labels[scan.networkId] = scan.networkLabel;
  }

  final groups = [
    for (final entry in byNetwork.entries)
      NetworkScanHistory(
        networkId: entry.key,
        networkLabel: labels[entry.key]!,
        scans: entry.value.toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
      ),
  ];
  groups.sort((a, b) => b.latest.timestamp.compareTo(a.latest.timestamp));
  return groups;
}

/// Derives a flat, newest-first change log from a sequence of [scans] (of a
/// single network), diffing each consecutive pair via [diffScans].
List<ScanChangeEntry> changeLog(List<ScanRecord> scans) {
  final chronological = scans.toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final entries = <ScanChangeEntry>[];
  for (var i = 1; i < chronological.length; i++) {
    final older = chronological[i - 1];
    final newer = chronological[i];
    final diff = diffScans(older.devices, newer.devices);
    for (final d in diff.added) {
      entries.add(ScanChangeEntry(
        timestamp: newer.timestamp,
        kind: ScanChangeKind.appeared,
        device: d,
      ));
    }
    for (final d in diff.removed) {
      entries.add(ScanChangeEntry(
        timestamp: newer.timestamp,
        kind: ScanChangeKind.disappeared,
        device: d,
      ));
    }
    for (final c in diff.changed) {
      entries.add(ScanChangeEntry(
        timestamp: newer.timestamp,
        kind: ScanChangeKind.changed,
        device: c.after,
        fields: c.fields,
      ));
    }
  }
  return entries.reversed.toList();
}
