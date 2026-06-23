import '../model/device.dart';

/// A persisted snapshot of one scan of one network: the devices seen, the
/// network they were on, and when. The unit of scan history; consecutive
/// records for the same network are diffed to build the change log.
class ScanRecord {
  const ScanRecord({
    this.id,
    required this.networkId,
    required this.networkLabel,
    required this.timestamp,
    required this.devices,
  });

  /// The store-assigned row id, or null for a record not yet persisted.
  final int? id;
  final String networkId;

  /// A human label for the network at scan time (e.g. "Wi-Fi"), used for
  /// grouping headers in the history UI.
  final String networkLabel;
  final DateTime timestamp;
  final List<Device> devices;

  int get deviceCount => devices.length;
}
