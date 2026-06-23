import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/data/latency_samples.dart';
import 'package:sextant/model/device.dart';

Device _dev(String ip, {String? mac, double? latencyMs}) {
  final t = DateTime.utc(2026, 1, 1);
  return Device(ip: ip, mac: mac, firstSeen: t, lastSeen: t, latencyMs: latencyMs);
}

void main() {
  group('buildLatencySamples', () {
    test('skips devices with no latency reading', () {
      final devices = [_dev('10.0.0.1'), _dev('10.0.0.2', latencyMs: 5.0)];
      final now = DateTime.utc(2026, 6, 22, 10);

      final samples = buildLatencySamples(devices, networkId: 'wifi', now: now);

      expect(samples, hasLength(1));
      expect(samples.single.rttMs, 5.0);
      expect(samples.single.networkId, 'wifi');
      expect(samples.single.timestamp, now);
    });

    test("keys each sample by the device's stable identity, not its IP", () {
      final device = _dev('10.0.0.5', mac: 'aa:aa:aa:aa:aa:aa', latencyMs: 3.0);

      final samples = buildLatencySamples(
        [device],
        networkId: 'wifi',
        now: DateTime.utc(2026, 1, 1),
      );

      expect(samples.single.deviceIdentity, 'mac:aa:aa:aa:aa:aa:aa');
    });

    test('returns nothing for an empty device list', () {
      final samples = buildLatencySamples([], networkId: 'wifi', now: DateTime.utc(2026, 1, 1));

      expect(samples, isEmpty);
    });
  });
}
