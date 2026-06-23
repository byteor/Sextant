import 'dart:convert';

import 'package:drift/drift.dart';

import '../model/device.dart';
import 'device_serialization.dart';
import 'scan_record.dart';

part 'history_database.g.dart';

/// One persisted scan snapshot. The devices are stored as a JSON blob
/// ([devicesJson]) rather than a join table: a scan's device list is only ever
/// read or written whole (to render a snapshot or diff two snapshots), so a
/// relational explosion buys nothing. [deviceCount] is denormalised so the
/// history list can show counts without decoding every blob.
class Scans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get networkId => text()();
  TextColumn get networkLabel => text()();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get deviceCount => integer()();
  TextColumn get devicesJson => text()();
}

/// One latency reading for one device, keyed by its stable [deviceIdentity]
/// (see `lib/data/device_identity.dart`) rather than IP, since IPs can change
/// between scans. Feeds the per-device sparkline.
class LatencySamples extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceIdentity => text()();
  TextColumn get networkId => text()();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get rttMs => real()();
}

/// Drift-backed store for scan history. Construct with
/// `HistoryDatabase(NativeDatabase.memory())` in tests, or the app's on-disk
/// executor in production.
@DriftDatabase(tables: [Scans, LatencySamples])
class HistoryDatabase extends _$HistoryDatabase {
  HistoryDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(latencySamples);
        },
      );

  /// Persists [record] and returns its assigned id. When [maxScans] is given,
  /// the oldest scans beyond that many (across all networks) are pruned, so the
  /// history can't grow without bound under live monitoring.
  Future<int> saveScan(ScanRecord record, {int? maxScans}) async {
    final id = await into(scans).insert(
      ScansCompanion.insert(
        networkId: record.networkId,
        networkLabel: record.networkLabel,
        timestamp: record.timestamp,
        deviceCount: record.devices.length,
        devicesJson: _encodeDevices(record.devices),
      ),
    );
    if (maxScans != null) await _pruneTo(maxScans);
    return id;
  }

  /// All scans, newest first, optionally capped at [limit].
  Future<List<ScanRecord>> recentScans({int? limit}) {
    final query = select(scans)
      ..orderBy([(s) => OrderingTerm.desc(s.timestamp)]);
    if (limit != null) query.limit(limit);
    return query.map(_toRecord).get();
  }

  /// Scans of a single network, newest first.
  Future<List<ScanRecord>> scansForNetwork(String networkId) {
    final query = select(scans)
      ..where((s) => s.networkId.equals(networkId))
      ..orderBy([(s) => OrderingTerm.desc(s.timestamp)]);
    return query.map(_toRecord).get();
  }

  Future<void> clearHistory() => delete(scans).go();

  /// Records latency [samples] (each a reading for one device at one time)
  /// and prunes each sampled device's history beyond [maxSamplesPerDevice]
  /// (oldest first), so the table can't grow without bound under long-running
  /// monitoring.
  Future<void> recordLatencySamples(
    List<({String deviceIdentity, String networkId, DateTime timestamp, double rttMs})>
        samples, {
    int maxSamplesPerDevice = 200,
  }) async {
    if (samples.isEmpty) return;
    await batch((b) {
      b.insertAll(latencySamples, [
        for (final s in samples)
          LatencySamplesCompanion.insert(
            deviceIdentity: s.deviceIdentity,
            networkId: s.networkId,
            timestamp: s.timestamp,
            rttMs: s.rttMs,
          ),
      ]);
    });
    for (final identity in {for (final s in samples) s.deviceIdentity}) {
      await _pruneSamplesTo(identity, maxSamplesPerDevice);
    }
  }

  /// The most recent [limit] samples for [deviceIdentity], oldest first (so
  /// callers can plot them left-to-right as a time series).
  Future<List<LatencySample>> latencyHistory(
    String deviceIdentity, {
    int limit = 50,
  }) async {
    final query = select(latencySamples)
      ..where((t) => t.deviceIdentity.equals(deviceIdentity))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
      ..limit(limit);
    final rows = await query.get();
    return rows.reversed.toList();
  }

  /// Deletes the oldest scans so at most [maxScans] remain.
  Future<void> _pruneTo(int maxScans) async {
    final keepIds = await (selectOnly(scans)
          ..addColumns([scans.id])
          ..orderBy([OrderingTerm.desc(scans.timestamp)])
          ..limit(maxScans))
        .map((row) => row.read(scans.id)!)
        .get();
    await (delete(scans)..where((s) => s.id.isNotIn(keepIds))).go();
  }

  /// Deletes the oldest latency samples for [deviceIdentity] so at most [max]
  /// remain.
  Future<void> _pruneSamplesTo(String deviceIdentity, int max) async {
    final keepIds = await (selectOnly(latencySamples)
          ..addColumns([latencySamples.id])
          ..where(latencySamples.deviceIdentity.equals(deviceIdentity))
          ..orderBy([OrderingTerm.desc(latencySamples.timestamp)])
          ..limit(max))
        .map((row) => row.read(latencySamples.id)!)
        .get();
    await (delete(latencySamples)
          ..where((t) =>
              t.deviceIdentity.equals(deviceIdentity) & t.id.isNotIn(keepIds)))
        .go();
  }

  ScanRecord _toRecord(Scan row) => ScanRecord(
        id: row.id,
        networkId: row.networkId,
        networkLabel: row.networkLabel,
        timestamp: row.timestamp,
        devices: _decodeDevices(row.devicesJson),
      );

  static String _encodeDevices(List<Device> devices) =>
      jsonEncode([for (final d in devices) deviceToMap(d)]);

  static List<Device> _decodeDevices(String json) => [
        for (final m in jsonDecode(json) as List)
          deviceFromMap(m as Map<String, dynamic>),
      ];
}
