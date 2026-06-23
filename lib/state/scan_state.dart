import '../model/device.dart';

/// Immutable snapshot of an in-progress or completed scan, rendered by the UI.
class ScanState {
  const ScanState({
    this.isScanning = false,
    this.devices = const [],
    this.scanned = 0,
    this.total = 0,
    this.enriching = false,
    this.isMonitoring = false,
    this.lastNewDevices = const [],
  });

  final bool isScanning;

  /// Discovered devices, always sorted by IPv4 address ascending.
  final List<Device> devices;

  /// Hosts probed so far / total hosts in the subnet (scan progress).
  final int scanned;
  final int total;

  /// True while MAC/vendor enrichment runs after the host sweep completes.
  final bool enriching;

  /// True while live monitoring is on (periodic re-scans of the network).
  final bool isMonitoring;

  /// Devices that first appeared in the most recent monitor cycle. Drives the
  /// new-device alert; reset to empty on each subsequent scan.
  final List<Device> lastNewDevices;

  bool get isBusy => isScanning || enriching;

  double get progress => total == 0 ? 0 : scanned / total;

  ScanState copyWith({
    bool? isScanning,
    List<Device>? devices,
    int? scanned,
    int? total,
    bool? enriching,
    bool? isMonitoring,
    List<Device>? lastNewDevices,
  }) {
    return ScanState(
      isScanning: isScanning ?? this.isScanning,
      devices: devices ?? this.devices,
      scanned: scanned ?? this.scanned,
      total: total ?? this.total,
      enriching: enriching ?? this.enriching,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      lastNewDevices: lastNewDevices ?? this.lastNewDevices,
    );
  }
}
