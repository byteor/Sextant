import '../model/device.dart';
import 'device_identity.dart';

/// Builds the latency samples to persist for [devices] observed on
/// [networkId] at [now], skipping devices with no latency reading this pass
/// (not every device answers ICMP).
List<({String deviceIdentity, String networkId, DateTime timestamp, double rttMs})>
    buildLatencySamples(
  List<Device> devices, {
  required String networkId,
  required DateTime now,
}) {
  return [
    for (final d in devices)
      if (d.latencyMs != null)
        (
          deviceIdentity: deviceIdentity(
            mac: d.mac,
            hostname: d.hostname,
            openPorts: d.openPorts,
          ),
          networkId: networkId,
          timestamp: now,
          rttMs: d.latencyMs!,
        ),
  ];
}
