import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/data/history_database.dart';
import 'package:sextant/data/scan_record.dart';
import 'package:sextant/model/device.dart';

Device _dev(String ip, {String? mac, List<int>? ports}) {
  final t = DateTime.utc(2026, 1, 1);
  return Device(
    ip: ip,
    mac: mac,
    openPorts: ports,
    firstSeen: t,
    lastSeen: t,
  );
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
    final id = await db.saveScan(_rec(
      'wifi',
      DateTime.utc(2026, 6, 22, 10),
      [_dev('1.1.1.1', mac: 'aa:aa:aa:aa:aa:aa', ports: [22, 80])],
    ));

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

    expect(
      scans.map((s) => s.timestamp),
      [
        DateTime.utc(2026, 6, 22),
        DateTime.utc(2026, 6, 21),
        DateTime.utc(2026, 6, 20),
      ],
    );
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

    await db.saveScan(
      _rec('wifi', DateTime.utc(2026, 6, 6), []),
      maxScans: 3,
    );

    final scans = await db.recentScans();
    expect(scans, hasLength(3));
    expect(
      scans.map((s) => s.timestamp),
      [DateTime.utc(2026, 6, 6), DateTime.utc(2026, 6, 5), DateTime.utc(2026, 6, 4)],
    );
  });
}
