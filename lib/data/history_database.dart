import 'dart:convert';

import 'package:drift/drift.dart';

import '../model/device.dart';
import 'device_identity.dart';
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

/// One MAC (or fingerprint) identity ever recorded as newly-discovered on a
/// network, keyed by [networkId] + [deviceIdentity] so the same physical
/// device is only ever recorded once per network no matter how many scans
/// see it afterwards. [ip]/[label] are a snapshot from the moment it was
/// first detected, so the "new devices" list still has something readable to
/// show even if the device later goes offline for good. [acknowledged]
/// tracks whether the user has opened the "new devices" list since —
/// unread/read, the way an inbox works.
class SeenDevices extends Table {
  TextColumn get networkId => text()();
  TextColumn get deviceIdentity => text()();
  TextColumn get ip => text()();
  TextColumn get label => text()();
  DateTimeColumn get firstSeenAt => dateTime()();
  BoolColumn get acknowledged => boolean()();

  @override
  Set<Column> get primaryKey => {networkId, deviceIdentity};
}

/// One port found open on a device via a full (all-ports) deep scan, keyed
/// by [deviceIdentity] alone — not network-scoped like [SeenDevices] — since
/// "this device runs a service on this port" is a fact about the physical
/// device, not the network it happens to be on right now. [networkId] is
/// kept as metadata (which network it was discovered from) but isn't part
/// of the lookup key. See `HistoryDatabase.allExtraPorts`, which unions
/// every recorded port across every device into the regular scan's port
/// list so these keep showing as open without re-running a full deep scan.
class DeepScanPorts extends Table {
  TextColumn get deviceIdentity => text()();
  TextColumn get networkId => text()();
  IntColumn get port => integer()();
  DateTimeColumn get discoveredAt => dateTime()();

  @override
  Set<Column> get primaryKey => {deviceIdentity, port};
}

/// Drift-backed store for scan history. Construct with
/// `HistoryDatabase(NativeDatabase.memory())` in tests, or the app's on-disk
/// executor in production.
@DriftDatabase(tables: [Scans, LatencySamples, SeenDevices, DeepScanPorts])
class HistoryDatabase extends _$HistoryDatabase {
  HistoryDatabase(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(latencySamples);
      if (from < 3) await m.createTable(seenDevices);
      if (from < 4) await m.createTable(deepScanPorts);
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

  /// Clears saved scan snapshots and the "new devices" ledger together: the
  /// ledger's baseline is derived from scan history (see [recordNewDevices]),
  /// so wiping one without the other would leave stale/inconsistent dates
  /// behind. The next scan silently re-establishes a fresh baseline.
  Future<void> clearHistory() async {
    await delete(scans).go();
    await delete(seenDevices).go();
  }

  /// Records latency [samples] (each a reading for one device at one time)
  /// and prunes each sampled device's history beyond [maxSamplesPerDevice]
  /// (oldest first), so the table can't grow without bound under long-running
  /// monitoring.
  Future<void> recordLatencySamples(
    List<
      ({
        String deviceIdentity,
        String networkId,
        DateTime timestamp,
        double rttMs,
      })
    >
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

  /// Cross-references [devices] against every identity already recorded for
  /// [networkId] and records any that aren't yet known. Returns the devices
  /// that were genuinely new — always empty on a network's very first scan,
  /// since that pass only establishes the baseline (there's nothing to
  /// compare against yet, so nothing should look "new" to the user).
  Future<List<Device>> recordNewDevices(
    String networkId,
    List<Device> devices,
  ) async {
    if (devices.isEmpty) return const [];
    final known =
        await (selectOnly(seenDevices)
              ..addColumns([seenDevices.deviceIdentity])
              ..where(seenDevices.networkId.equals(networkId)))
            .map((row) => row.read(seenDevices.deviceIdentity)!)
            .get();
    final knownSet = known.toSet();
    final isBaseline = knownSet.isEmpty;

    final unseen = <String, Device>{};
    for (final d in devices) {
      final id = deviceIdentity(
        mac: d.mac,
        hostname: d.hostname,
        openPorts: d.openPorts,
      );
      unseen.putIfAbsent(id, () => d);
    }
    unseen.removeWhere((id, _) => knownSet.contains(id));
    if (unseen.isEmpty) return const [];

    // On a network's first-ever baseline, backfill each device's firstSeenAt
    // with its own earliest appearance across every scan already saved for
    // this network, rather than stamping everything with "now" — the
    // network may already have months of scan history recorded before this
    // feature existed. A device that never appears in any saved scan
    // (genuinely never seen before this pass) falls back to "now".
    final earliestSeen = isBaseline
        ? await _earliestSeenByIdentity(networkId)
        : const <String, DateTime>{};
    final now = DateTime.now();
    await batch((b) {
      b.insertAll(seenDevices, [
        for (final entry in unseen.entries)
          SeenDevicesCompanion.insert(
            networkId: networkId,
            deviceIdentity: entry.key,
            ip: entry.value.ip,
            label: entry.value.displayName,
            firstSeenAt: earliestSeen[entry.key] ?? now,
            acknowledged: isBaseline,
          ),
      ], mode: InsertMode.insertOrIgnore);
    });

    return isBaseline ? const [] : unseen.values.toList();
  }

  /// The earliest timestamp each device identity appears at across every
  /// scan already saved for [networkId], oldest occurrence wins. Used only
  /// when establishing a network's baseline (see [recordNewDevices]) so each
  /// device shows its own real first-seen date, as far back as saved history
  /// goes, rather than a single shared date or "now" for everything.
  Future<Map<String, DateTime>> _earliestSeenByIdentity(
    String networkId,
  ) async {
    final history = await scansForNetwork(networkId); // newest first
    final earliest = <String, DateTime>{};
    for (final scan in history.reversed) {
      // oldest first, so putIfAbsent keeps the earliest.
      for (final d in scan.devices) {
        final id = deviceIdentity(
          mac: d.mac,
          hostname: d.hostname,
          openPorts: d.openPorts,
        );
        earliest.putIfAbsent(id, () => scan.timestamp);
      }
    }
    return earliest;
  }

  /// Number of devices recorded as new on [networkId] the user hasn't
  /// acknowledged yet (by opening the "new devices" list) — drives the
  /// toolbar badge.
  Future<int> unacknowledgedCount(String networkId) async {
    final countColumn = seenDevices.deviceIdentity.count();
    final query = selectOnly(seenDevices)
      ..addColumns([countColumn])
      ..where(
        seenDevices.networkId.equals(networkId) &
            seenDevices.acknowledged.equals(false),
      );
    final row = await query.getSingle();
    return row.read(countColumn) ?? 0;
  }

  /// Every device ever recorded as newly-discovered on [networkId], newest
  /// first, capped at [limit] so the list can't grow unbounded on a network
  /// that's been scanned for a long time.
  Future<List<SeenDevice>> recentlySeenDevices(
    String networkId, {
    int limit = 100,
  }) {
    final query = select(seenDevices)
      ..where((t) => t.networkId.equals(networkId))
      ..orderBy([(t) => OrderingTerm.desc(t.firstSeenAt)])
      ..limit(limit);
    return query.get();
  }

  /// Marks every currently-unacknowledged device on [networkId] as
  /// acknowledged — called when the user opens the "new devices" list, like
  /// opening an inbox: they don't show as unread again afterwards.
  Future<void> acknowledgeNewDevices(String networkId) =>
      (update(seenDevices)..where(
            (t) => t.networkId.equals(networkId) & t.acknowledged.equals(false),
          ))
          .write(const SeenDevicesCompanion(acknowledged: Value(true)));

  /// Records [ports] as found open on [deviceIdentity] via a deep (all-ports)
  /// scan. A port already on record keeps its original [discoveredAt]
  /// (insert-or-ignore) rather than being bumped to now on a repeat scan.
  Future<void> recordDeepScanPorts(
    String deviceIdentity,
    String networkId,
    List<int> ports,
  ) async {
    if (ports.isEmpty) return;
    final now = DateTime.now();
    await batch((b) {
      b.insertAll(deepScanPorts, [
        for (final port in ports)
          DeepScanPortsCompanion.insert(
            deviceIdentity: deviceIdentity,
            networkId: networkId,
            port: port,
            discoveredAt: now,
          ),
      ], mode: InsertMode.insertOrIgnore);
    });
  }

  /// The [limit] most recently discovered ports recorded via a deep scan,
  /// across every device — deduplicated and returned sorted ascending. Merged
  /// into the regular scan's port list (see
  /// `ScanController._buildOrchestrator`) so previously-found ports keep
  /// showing as open without re-running a full deep scan.
  ///
  /// Capped because this list is probed against *every* host of *every*
  /// future regular scan: a single broadly-responding device (a tarpitting
  /// firewall, some NAT/proxy appliances) could otherwise add hundreds of
  /// ports to every host's probe list forever. Recency wins, so the cap
  /// keeps what was found most recently rather than an arbitrary slice.
  /// A port's discovery date is the newest time any device was recorded as
  /// having it open. Drift compares these dates at whole-second resolution,
  /// so ports recorded in the same second — in practice the ports of one
  /// deep scan, which stamps them all at once — tie, and which of them
  /// survives a cap boundary that falls inside that scan is arbitrary.
  Future<List<int>> allExtraPorts({int limit = 200}) async {
    final newestDiscovery = deepScanPorts.discoveredAt.max();
    final query = selectOnly(deepScanPorts)
      ..addColumns([deepScanPorts.port, newestDiscovery])
      ..groupBy([deepScanPorts.port])
      ..orderBy([OrderingTerm.desc(newestDiscovery)])
      ..limit(limit);
    final rows = await query.get();
    return [for (final row in rows) row.read(deepScanPorts.port)!]..sort();
  }

  /// Deletes the oldest scans so at most [maxScans] remain.
  Future<void> _pruneTo(int maxScans) async {
    final keepIds =
        await (selectOnly(scans)
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
    final keepIds =
        await (selectOnly(latencySamples)
              ..addColumns([latencySamples.id])
              ..where(latencySamples.deviceIdentity.equals(deviceIdentity))
              ..orderBy([OrderingTerm.desc(latencySamples.timestamp)])
              ..limit(max))
            .map((row) => row.read(latencySamples.id)!)
            .get();
    await (delete(latencySamples)..where(
          (t) =>
              t.deviceIdentity.equals(deviceIdentity) & t.id.isNotIn(keepIds),
        ))
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
