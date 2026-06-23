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

/// Drift-backed store for scan history. Construct with
/// `HistoryDatabase(NativeDatabase.memory())` in tests, or the app's on-disk
/// executor in production.
@DriftDatabase(tables: [Scans])
class HistoryDatabase extends _$HistoryDatabase {
  HistoryDatabase(super.executor);

  @override
  int get schemaVersion => 1;

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
