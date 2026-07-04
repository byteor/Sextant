import '../model/device.dart';

/// Immutable snapshot of an in-progress or completed scan, rendered by the UI.
class ScanState {
  const ScanState({
    this.isScanning = false,
    this.devices = const [],
    this.scanned = 0,
    this.total = 0,
    this.scanProgress = 0.0,
    this.enriching = false,
    this.isMonitoring = false,
    this.lastNewDevices = const [],
    this.isBackgroundScanning = false,
    this.backgroundScanned = 0,
    this.backgroundTotal = 0,
  });

  final bool isScanning;

  /// Discovered devices, always sorted by IPv4 address ascending.
  final List<Device> devices;

  /// Hosts probed so far / total hosts in the subnet (used for status text).
  final int scanned;
  final int total;

  /// Monotonically-increasing scan progress (0.0–1.0) used by the progress bar.
  /// Weighted across phases: ICMP fills 0→0.8 when TCP is also enabled, TCP
  /// fills 0.8→1.0 (or the full 0→1.0 when the other phase is disabled).
  final double scanProgress;

  /// True while MAC/vendor enrichment runs after the host sweep completes.
  final bool enriching;

  /// True while live monitoring is on (periodic re-scans of the network).
  final bool isMonitoring;

  /// Devices that first appeared in the most recent monitor cycle. Drives the
  /// new-device alert; reset to empty on each subsequent scan.
  final List<Device> lastNewDevices;

  /// True while a *background* monitor re-scan is in flight. Unlike
  /// [isScanning], this never touches the on-screen device list (the no-flicker
  /// monitoring design) — it exists only so the UI can show a progress bar for
  /// the otherwise-invisible periodic re-scan.
  final bool isBackgroundScanning;

  /// Host-sweep progress for the in-flight background re-scan (kept separate
  /// from [scanned]/[total] so a background tick can't disturb a foreground
  /// scan's progress display, and vice versa).
  final int backgroundScanned;
  final int backgroundTotal;

  bool get isBusy => isScanning || enriching;

  double get progress => total == 0 ? 0 : scanned / total;

  double get backgroundProgress =>
      backgroundTotal == 0 ? 0 : backgroundScanned / backgroundTotal;

  ScanState copyWith({
    bool? isScanning,
    List<Device>? devices,
    int? scanned,
    int? total,
    double? scanProgress,
    bool? enriching,
    bool? isMonitoring,
    List<Device>? lastNewDevices,
    bool? isBackgroundScanning,
    int? backgroundScanned,
    int? backgroundTotal,
  }) {
    return ScanState(
      isScanning: isScanning ?? this.isScanning,
      devices: devices ?? this.devices,
      scanned: scanned ?? this.scanned,
      total: total ?? this.total,
      scanProgress: scanProgress ?? this.scanProgress,
      enriching: enriching ?? this.enriching,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      lastNewDevices: lastNewDevices ?? this.lastNewDevices,
      isBackgroundScanning: isBackgroundScanning ?? this.isBackgroundScanning,
      backgroundScanned: backgroundScanned ?? this.backgroundScanned,
      backgroundTotal: backgroundTotal ?? this.backgroundTotal,
    );
  }
}
