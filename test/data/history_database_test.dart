import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/data/history_database.dart';
import 'package:sextant/data/scan_record.dart';
import 'package:sextant/model/device.dart';

Device _dev(String ip, {String? mac, List<int>? ports}) {
  final t = DateTime.utc(2026, 1, 1);
  return Device(ip: ip, mac: mac, openPorts: ports, firstSeen: t, lastSeen: t);
}

ScanRecord _rec(String networkId, DateTime ts, List<Device> devices) =>
    ScanRecord(
      networkId: networkId,
      networkLabel: 'Wi-Fi',
      timestamp: ts,
      devices: devices,
    );

void main() {
  late HistoryDatabase db;

  setUp(() => db = HistoryDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('saves a scan and reads it back with its devices intact', () async {
    final id = await db.saveScan(
      _rec('wifi', DateTime.utc(2026, 6, 22, 10), [
        _dev('1.1.1.1', mac: 'aa:aa:aa:aa:aa:aa', ports: [22, 80]),
      ]),
    );

    expect(id, greaterThan(0));
    final scans = await db.recentScans();
    expect(scans, hasLength(1));
    final scan = scans.single;
    expect(scan.id, id);
    expect(scan.networkId, 'wifi');
    expect(scan.networkLabel, 'Wi-Fi');
    expect(scan.timestamp, DateTime.utc(2026, 6, 22, 10));
    expect(scan.devices.single.mac, 'aa:aa:aa:aa:aa:aa');
    expect(scan.devices.single.openPorts, [22, 80]);
  });

  test('recentScans returns newest first', () async {
    await db.saveScan(_rec('wifi', DateTime.utc(2026, 6, 20), []));
    await db.saveScan(_rec('wifi', DateTime.utc(2026, 6, 22), []));
    await db.saveScan(_rec('wifi', DateTime.utc(2026, 6, 21), []));

    final scans = await db.recentScans();

    expect(scans.map((s) => s.timestamp), [
      DateTime.utc(2026, 6, 22),
      DateTime.utc(2026, 6, 21),
      DateTime.utc(2026, 6, 20),
    ]);
  });

  test('scansForNetwork filters to one network, newest first', () async {
    await db.saveScan(_rec('wifi', DateTime.utc(2026, 6, 20), []));
    await db.saveScan(_rec('eth', DateTime.utc(2026, 6, 21), []));
    await db.saveScan(_rec('wifi', DateTime.utc(2026, 6, 22), []));

    final wifi = await db.scansForNetwork('wifi');

    expect(wifi, hasLength(2));
    expect(wifi.map((s) => s.networkId), ['wifi', 'wifi']);
    expect(wifi.first.timestamp, DateTime.utc(2026, 6, 22));
  });

  test('clearHistory removes everything', () async {
    await db.saveScan(_rec('wifi', DateTime.utc(2026, 6, 20), []));
    await db.clearHistory();
    expect(await db.recentScans(), isEmpty);
  });

  test('saveScan prunes oldest scans beyond the retention cap', () async {
    for (var day = 1; day <= 5; day++) {
      await db.saveScan(_rec('wifi', DateTime.utc(2026, 6, day), []));
    }

    await db.saveScan(_rec('wifi', DateTime.utc(2026, 6, 6), []), maxScans: 3);

    final scans = await db.recentScans();
    expect(scans, hasLength(3));
    expect(scans.map((s) => s.timestamp), [
      DateTime.utc(2026, 6, 6),
      DateTime.utc(2026, 6, 5),
      DateTime.utc(2026, 6, 4),
    ]);
  });

  group('recordNewDevices', () {
    test('a network\'s very first scan seeds the baseline silently — '
        'nothing is reported as new', () async {
      final found = await db.recordNewDevices('wifi', [
        _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
        _dev('10.0.0.2', mac: 'bb:bb:bb:bb:bb:bb'),
      ]);

      expect(found, isEmpty);
      expect(await db.unacknowledgedCount('wifi'), 0);
    });

    test('a MAC not present in any prior scan is reported as new', () async {
      await db.recordNewDevices('wifi', [
        _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
      ]);

      final found = await db.recordNewDevices('wifi', [
        _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
        _dev('10.0.0.2', mac: 'bb:bb:bb:bb:bb:bb'),
      ]);

      expect(found, hasLength(1));
      expect(found.single.mac, 'bb:bb:bb:bb:bb:bb');
    });

    test(
      'a MAC already recorded is never reported again on later scans',
      () async {
        await db.recordNewDevices('wifi', [
          _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
        ]);
        await db.recordNewDevices('wifi', [
          _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
          _dev('10.0.0.2', mac: 'bb:bb:bb:bb:bb:bb'),
        ]);

        final found = await db.recordNewDevices('wifi', [
          _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
          _dev('10.0.0.2', mac: 'bb:bb:bb:bb:bb:bb'),
        ]);

        expect(found, isEmpty);
      },
    );

    test(
      'the same network\'s devices don\'t affect a different network',
      () async {
        await db.recordNewDevices('wifi', [
          _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
        ]);

        final found = await db.recordNewDevices('eth', [
          _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
        ]);

        // "eth" has no baseline yet, so this call seeds it instead of
        // reporting the device as new.
        expect(found, isEmpty);
        expect(await db.unacknowledgedCount('eth'), 0);
      },
    );

    test('an empty scan reports nothing and records nothing', () async {
      final found = await db.recordNewDevices('wifi', []);
      expect(found, isEmpty);
    });

    test('baseline seeding backfills each device\'s own earliest appearance '
        'across saved scan history, instead of stamping every device with '
        '"now"', () async {
      // Scan history already exists for this network — saved before the
      // "seen devices" feature ever ran (e.g. an app that's been in use for
      // months before this update). 'aa' has been around since day one;
      // 'bb' only joined later.
      await db.saveScan(
        _rec('wifi', DateTime.utc(2026, 1, 1), [
          _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
        ]),
      );
      await db.saveScan(
        _rec('wifi', DateTime.utc(2026, 3, 15), [
          _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
          _dev('10.0.0.2', mac: 'bb:bb:bb:bb:bb:bb'),
        ]),
      );

      await db.recordNewDevices('wifi', [
        _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
        _dev('10.0.0.2', mac: 'bb:bb:bb:bb:bb:bb'),
      ]);

      final entries = await db.recentlySeenDevices('wifi');
      final byIdentity = {for (final e in entries) e.deviceIdentity: e};
      expect(
        byIdentity['mac:aa:aa:aa:aa:aa:aa']!.firstSeenAt,
        DateTime.utc(2026, 1, 1),
      );
      expect(
        byIdentity['mac:bb:bb:bb:bb:bb:bb']!.firstSeenAt,
        DateTime.utc(2026, 3, 15),
      );
    });

    test('baseline seeding falls back to now for a device absent from '
        'every saved scan', () async {
      await db.saveScan(
        _rec('wifi', DateTime.utc(2026, 1, 1), [
          _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
        ]),
      );

      final before = DateTime.now();
      await db.recordNewDevices('wifi', [
        _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
        _dev('10.0.0.2', mac: 'bb:bb:bb:bb:bb:bb'), // never in saved history
      ]);
      final after = DateTime.now();

      final entries = await db.recentlySeenDevices('wifi');
      final newOne = entries.firstWhere(
        (e) => e.deviceIdentity == 'mac:bb:bb:bb:bb:bb:bb',
      );
      expect(
        newOne.firstSeenAt.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        newOne.firstSeenAt.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
      // 'aa' still gets its real historical date, not "now".
      final oldOne = entries.firstWhere(
        (e) => e.deviceIdentity == 'mac:aa:aa:aa:aa:aa:aa',
      );
      expect(oldOne.firstSeenAt, DateTime.utc(2026, 1, 1));
    });
  });

  test('clearHistory also resets the "new devices" ledger, so the next '
      'scan re-establishes a fresh baseline', () async {
    await db.recordNewDevices('wifi', [
      _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
    ]);
    await db.recordNewDevices('wifi', [
      _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
      _dev('10.0.0.2', mac: 'bb:bb:bb:bb:bb:bb'),
    ]);
    expect(await db.recentlySeenDevices('wifi'), isNotEmpty);

    await db.clearHistory();

    expect(await db.recentlySeenDevices('wifi'), isEmpty);
    // The next scan is treated as a brand-new baseline again.
    final found = await db.recordNewDevices('wifi', [
      _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
      _dev('10.0.0.2', mac: 'bb:bb:bb:bb:bb:bb'),
    ]);
    expect(found, isEmpty);
    expect(await db.unacknowledgedCount('wifi'), 0);
  });

  group(
    'unacknowledgedCount / recentlySeenDevices / acknowledgeNewDevices',
    () {
      test('counts only genuinely-new, unacknowledged devices', () async {
        await db.recordNewDevices('wifi', [
          _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
        ]); // baseline — not counted
        await db.recordNewDevices('wifi', [
          _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
          _dev('10.0.0.2', mac: 'bb:bb:bb:bb:bb:bb'),
          _dev('10.0.0.3', mac: 'cc:cc:cc:cc:cc:cc'),
        ]);

        expect(await db.unacknowledgedCount('wifi'), 2);
      });

      test(
        'recentlySeenDevices lists newest first with the acknowledged flag',
        () async {
          await db.recordNewDevices('wifi', [
            _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
          ]); // baseline, acknowledged: true
          await db.recordNewDevices('wifi', [
            _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
            _dev('10.0.0.2', mac: 'bb:bb:bb:bb:bb:bb'),
          ]); // 'bb' is new, acknowledged: false

          final entries = await db.recentlySeenDevices('wifi');

          expect(entries, hasLength(2));
          expect(entries.first.deviceIdentity, 'mac:bb:bb:bb:bb:bb:bb');
          expect(entries.first.acknowledged, isFalse);
          expect(entries.last.deviceIdentity, 'mac:aa:aa:aa:aa:aa:aa');
          expect(entries.last.acknowledged, isTrue);
        },
      );

      test(
        'acknowledgeNewDevices clears the badge and marks entries read',
        () async {
          await db.recordNewDevices('wifi', [
            _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
          ]);
          await db.recordNewDevices('wifi', [
            _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
            _dev('10.0.0.2', mac: 'bb:bb:bb:bb:bb:bb'),
          ]);
          expect(await db.unacknowledgedCount('wifi'), 1);

          await db.acknowledgeNewDevices('wifi');

          expect(await db.unacknowledgedCount('wifi'), 0);
          final entries = await db.recentlySeenDevices('wifi');
          expect(entries.every((e) => e.acknowledged), isTrue);
        },
      );

      test('acknowledging one network does not affect another', () async {
        await db.recordNewDevices('wifi', [
          _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
        ]);
        await db.recordNewDevices('wifi', [
          _dev('10.0.0.1', mac: 'aa:aa:aa:aa:aa:aa'),
          _dev('10.0.0.2', mac: 'bb:bb:bb:bb:bb:bb'),
        ]);
        await db.recordNewDevices('eth', [
          _dev('10.0.0.1', mac: 'cc:cc:cc:cc:cc:cc'),
        ]);
        await db.recordNewDevices('eth', [
          _dev('10.0.0.1', mac: 'cc:cc:cc:cc:cc:cc'),
          _dev('10.0.0.2', mac: 'dd:dd:dd:dd:dd:dd'),
        ]);

        await db.acknowledgeNewDevices('wifi');

        expect(await db.unacknowledgedCount('wifi'), 0);
        expect(await db.unacknowledgedCount('eth'), 1);
      });
    },
  );

  group('recordDeepScanPorts / allExtraPorts', () {
    test('records ports found for a device', () async {
      await db.recordDeepScanPorts('mac:aa:aa:aa:aa:aa:aa', 'wifi', [22, 8888]);

      expect(await db.allExtraPorts(), [22, 8888]);
    });

    test(
      'allExtraPorts is the deduplicated union across every device',
      () async {
        await db.recordDeepScanPorts('mac:aa:aa:aa:aa:aa:aa', 'wifi', [
          22,
          8888,
        ]);
        await db.recordDeepScanPorts('mac:bb:bb:bb:bb:bb:bb', 'wifi', [
          8888,
          9999,
        ]);

        expect(await db.allExtraPorts(), [22, 8888, 9999]);
      },
    );

    test('recording the same port twice does not duplicate or throw', () async {
      await db.recordDeepScanPorts('mac:aa:aa:aa:aa:aa:aa', 'wifi', [22]);
      await db.recordDeepScanPorts('mac:aa:aa:aa:aa:aa:aa', 'wifi', [22]);

      expect(await db.allExtraPorts(), [22]);
    });

    test('an empty port list records nothing', () async {
      await db.recordDeepScanPorts('mac:aa:aa:aa:aa:aa:aa', 'wifi', []);

      expect(await db.allExtraPorts(), isEmpty);
    });
  });
}
