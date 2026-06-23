import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/data/history_database.dart';

void main() {
  late HistoryDatabase db;

  setUp(() => db = HistoryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('latency samples', () {
    test('records samples and reads them back oldest-first', () async {
      await db.recordLatencySamples([
        (
          deviceIdentity: 'mac:aa:aa:aa:aa:aa:aa',
          networkId: 'wifi',
          timestamp: DateTime.utc(2026, 6, 22, 10, 0),
          rttMs: 12.0,
        ),
        (
          deviceIdentity: 'mac:aa:aa:aa:aa:aa:aa',
          networkId: 'wifi',
          timestamp: DateTime.utc(2026, 6, 22, 10, 1),
          rttMs: 14.0,
        ),
      ]);

      final history = await db.latencyHistory('mac:aa:aa:aa:aa:aa:aa');

      expect(history.map((s) => s.rttMs), [12.0, 14.0]);
    });

    test('latencyHistory only returns samples for the requested device', () async {
      await db.recordLatencySamples([
        (
          deviceIdentity: 'mac:aa',
          networkId: 'wifi',
          timestamp: DateTime.utc(2026, 1, 1),
          rttMs: 1.0,
        ),
        (
          deviceIdentity: 'mac:bb',
          networkId: 'wifi',
          timestamp: DateTime.utc(2026, 1, 1),
          rttMs: 2.0,
        ),
      ]);

      final history = await db.latencyHistory('mac:bb');

      expect(history, hasLength(1));
      expect(history.single.rttMs, 2.0);
    });

    test('latencyHistory limits to the most recent N samples', () async {
      for (var i = 0; i < 5; i++) {
        await db.recordLatencySamples([
          (
            deviceIdentity: 'mac:aa',
            networkId: 'wifi',
            timestamp: DateTime.utc(2026, 1, 1, i),
            rttMs: i.toDouble(),
          ),
        ]);
      }

      final history = await db.latencyHistory('mac:aa', limit: 3);

      expect(history.map((s) => s.rttMs), [2.0, 3.0, 4.0]);
    });

    test('recordLatencySamples prunes each device history beyond maxSamplesPerDevice', () async {
      for (var i = 0; i < 5; i++) {
        await db.recordLatencySamples(
          [
            (
              deviceIdentity: 'mac:aa',
              networkId: 'wifi',
              timestamp: DateTime.utc(2026, 1, 1, i),
              rttMs: i.toDouble(),
            ),
          ],
          maxSamplesPerDevice: 3,
        );
      }

      final history = await db.latencyHistory('mac:aa', limit: 10);

      expect(history.map((s) => s.rttMs), [2.0, 3.0, 4.0]);
    });
  });
}
