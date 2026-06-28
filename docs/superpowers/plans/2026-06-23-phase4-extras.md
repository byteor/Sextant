# Sextant Phase 4 Extras — Latency History, Polish, Topology — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close out three Phase 4 line items from `docs/PLAN.md`: persisted latency time-series with a sparkline UI, three small polish items (dedupe multi-homed devices, ICMP sweep concurrency tuning, periodic OUI vendor DB refresh), and a radial topology / network map view.

**Architecture:** Each feature follows the codebase's existing layering — a pure, unit-testable function or class in `lib/data`/`lib/enrich`/`lib/ui`, wired into `ScanController` (`lib/state/providers.dart`) or a screen via Riverpod, with widget-level code kept thin. No existing identity, diff, or history semantics change; latency samples and dedup are purely additive/presentation-layer.

**Tech Stack:** Flutter/Dart, Riverpod 3.3.2 (`flutter_riverpod`), Drift 2.34.0 + `drift_flutter` (single `HistoryDatabase`, file `sextant_history`), pure-Dart `dart:io` networking (no `package:http`).

## Global Constraints

- Run the full suite with `flutter test`; a single file with `flutter test <path>`.
- No new pub dependencies. Use only `dart:io`/`dart:ui`/`dart:math`/`dart:async`/`dart:convert` and packages already in `pubspec.yaml`.
- TDD: every pure-logic file gets a failing test before implementation. Widget-level changes get a widget test where there's existing precedent for testing that kind of widget; otherwise they're verified by running the full suite with zero regressions (the codebase has no precedent for testing `ScanScreen`'s row widgets directly).
- Device identity is `deviceIdentity({String? mac, String? hostname, List<int> openPorts})` from `lib/data/device_identity.dart` — MAC primary, hostname+ports fingerprint fallback. Reuse it; never reimplement it.
- `Device.copyWith` follows the existing "`??` means keep existing value" convention for every parameter — match it for any new field.
- Drift `DateTime` columns are stored as UTC ISO text (`build.yaml`: `store_date_time_values_as_text: true`); this applies automatically to new tables/columns, no per-column configuration needed.
- After changing the `@DriftDatabase(tables: [...])` list or adding/changing a table, regenerate `lib/data/history_database.g.dart` with `dart run build_runner build --delete-conflicting-outputs` and commit the regenerated file alongside the source change.
- Never change `ScanDiff`/`diffScans`/`excludeReappeared` correlation semantics, and never feed a de-duplicated or otherwise transformed device list into them — any new presentation-layer transform is applied only at final render time (`ScanController._emit()`), strictly after history-saving and diffing have already run on the raw per-IP device list.
- Match existing comment style: no comment unless it explains a non-obvious *why*; never multi-paragraph doc comments.

---

### Task 1: Latency history Drift table + DAO

**Files:**
- Modify: `lib/data/history_database.dart`
- Test: `test/data/latency_database_test.dart`

**Interfaces:**
- Consumes: nothing new (uses the existing `HistoryDatabase`/`Scans` machinery already in the file).
- Produces: `LatencySamples` Drift table (generates row class `LatencySample` with fields `id`, `deviceIdentity`, `networkId`, `timestamp`, `rttMs`); `HistoryDatabase.recordLatencySamples(List<({String deviceIdentity, String networkId, DateTime timestamp, double rttMs})> samples, {int maxSamplesPerDevice = 200})`; `HistoryDatabase.latencyHistory(String deviceIdentity, {int limit = 50}) -> Future<List<LatencySample>>` (oldest-first). Task 2 consumes both.

- [ ] **Step 1: Write the failing tests**

Create `test/data/latency_database_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/latency_database_test.dart`
Expected: FAIL to compile — `recordLatencySamples` and `latencyHistory` are not defined on `HistoryDatabase`.

- [ ] **Step 3: Add the table and DAO methods**

Replace the full contents of `lib/data/history_database.dart` with:

```dart
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
```

Then regenerate the Drift code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected output ends with something like:
```
[INFO] Build: Succeeded after ... with N outputs
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/latency_database_test.dart test/data/history_database_test.dart`
Expected: PASS, all tests green (the existing `history_database_test.dart` must still pass unchanged — `schemaVersion` bumping to 2 only adds a table via `onCreate: (m) => m.createAll()` for fresh in-memory test databases, so it doesn't affect existing `Scans`-table behavior).

- [ ] **Step 5: Commit**

```bash
git add lib/data/history_database.dart lib/data/history_database.g.dart test/data/latency_database_test.dart
git commit -m "feat: add latency samples table and DAO to HistoryDatabase"
```

---

### Task 2: Pure latency-sample builder + ScanController wiring

**Files:**
- Create: `lib/data/latency_samples.dart`
- Test: `test/data/latency_samples_test.dart`
- Modify: `lib/state/providers.dart`

**Interfaces:**
- Consumes: `HistoryDatabase.recordLatencySamples`/`.latencyHistory` (Task 1); `deviceIdentity({String? mac, String? hostname, List<int> openPorts})` from `lib/data/device_identity.dart`; `historyDatabaseProvider` (already defined in `lib/state/providers.dart`).
- Produces: `buildLatencySamples(List<Device> devices, {required String networkId, required DateTime now}) -> List<({String deviceIdentity, String networkId, DateTime timestamp, double rttMs})>`; `latencyHistoryProvider` — `FutureProvider.family<List<double>, String>` keyed by `deviceIdentity`, returning oldest-first RTT values. Task 3 consumes `latencyHistoryProvider`.

- [ ] **Step 1: Write the failing test**

Create `test/data/latency_samples_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/latency_samples_test.dart`
Expected: FAIL to compile — `package:sextant/data/latency_samples.dart` does not exist.

- [ ] **Step 3: Implement `buildLatencySamples`**

Create `lib/data/latency_samples.dart`:

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/latency_samples_test.dart`
Expected: PASS, 3/3 tests green.

- [ ] **Step 5: Wire into `ScanController`**

In `lib/state/providers.dart`, add the import alongside the other `data/` imports near the top of the file:

```dart
import '../data/latency_samples.dart';
```

Add a new provider near `scanHistoryProvider` (same top-level section as the other `FutureProvider`s):

```dart
/// The recent latency history for one device (by stable identity), used to
/// draw its sparkline. Invalidated whenever new samples are recorded.
final latencyHistoryProvider =
    FutureProvider.family<List<double>, String>((ref, deviceIdentity) async {
  final db = ref.watch(historyDatabaseProvider);
  final samples = await db.latencyHistory(deviceIdentity);
  return [for (final s in samples) s.rttMs];
});
```

In the `ScanController` class, find the end of `startScan` (it currently ends with `_emit(isScanning: false);` followed by `await _saveHistory(network, _byIp.values.toList());`). Replace:

```dart
    await completer.future;
    _emit(isScanning: false);
    await _saveHistory(network, _byIp.values.toList());
  }
```

with:

```dart
    await completer.future;
    _emit(isScanning: false);
    await _recordLatency(network, _byIp.values.toList());
    await _saveHistory(network, _byIp.values.toList());
  }
```

Find `_monitorTick` (it starts with the `_monitoring`/`_monitorNetwork` guard, calls `_backgroundScan`, re-checks `_monitoring`, then calls `_reconcile`). Replace:

```dart
  Future<void> _monitorTick() async {
    if (!_monitoring || _monitorNetwork == null) return;
    final found = await _backgroundScan(_monitorNetwork!);
    if (!_monitoring) return; // toggled off mid-scan; discard
    final diff = _reconcile(found);
```

with:

```dart
  Future<void> _monitorTick() async {
    if (!_monitoring || _monitorNetwork == null) return;
    final found = await _backgroundScan(_monitorNetwork!);
    if (!_monitoring) return; // toggled off mid-scan; discard
    await _recordLatency(_monitorNetwork!, found);
    final diff = _reconcile(found);
```

Find the end of the existing `_saveHistory` method (it ends with `ref.invalidate(scanHistoryProvider);` followed by the closing brace, then `String _identityOf(Device d) => deviceIdentity(`). Insert a new method between them:

```dart
    ref.invalidate(scanHistoryProvider);
  }

  /// Persists a latency reading for every device that answered ICMP this pass
  /// and refreshes any open sparklines.
  Future<void> _recordLatency(ScanNetwork network, List<Device> devices) async {
    final samples = buildLatencySamples(
      devices,
      networkId: network.id,
      now: DateTime.now(),
    );
    if (samples.isEmpty) return;
    await ref.read(historyDatabaseProvider).recordLatencySamples(samples);
    ref.invalidate(latencyHistoryProvider);
  }

  String _identityOf(Device d) => deviceIdentity(
```

- [ ] **Step 6: Run the full suite to verify no regressions**

Run: `flutter test`
Expected: PASS, all tests green (no existing test exercises `ScanController` directly, so this step is a regression check, not new coverage).

- [ ] **Step 7: Commit**

```bash
git add lib/data/latency_samples.dart test/data/latency_samples_test.dart lib/state/providers.dart
git commit -m "feat: persist latency samples on every scan and monitor tick"
```

---

### Task 3: Latency sparkline widget + wire into the device table

**Files:**
- Create: `lib/ui/latency_sparkline.dart`
- Test: `test/ui/latency_sparkline_test.dart`
- Modify: `lib/ui/scan_screen.dart`

**Interfaces:**
- Consumes: `latencyHistoryProvider` (Task 2, `FutureProvider.family<List<double>, String>`); `deviceIdentity()` from `lib/data/device_identity.dart`.
- Produces: `sparklinePoints(List<double> values, {required double width, required double height}) -> List<Offset>` (pure, normalizes values into a `width`×`height` box, low values at the bottom); `LatencySparkline` widget (`{required List<double> values, Color? color}`) — renders nothing for fewer than 2 values, otherwise a `CustomPaint` line chart.

- [ ] **Step 1: Write the failing tests**

Create `test/ui/latency_sparkline_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/ui/latency_sparkline.dart';

void main() {
  group('sparklinePoints', () {
    test('maps a single repeated value to a flat horizontal line', () {
      final points = sparklinePoints([5, 5, 5], width: 30, height: 10);

      expect(points, hasLength(3));
      expect(points.every((p) => p.dy == 5), isTrue);
      expect(points.first.dx, 0);
      expect(points.last.dx, 30);
    });

    test('maps the minimum value to the bottom and maximum to the top', () {
      final points = sparklinePoints([0, 10], width: 20, height: 10);

      expect(points.first.dy, 10);
      expect(points.last.dy, 0);
    });

    test('spaces points evenly across the width', () {
      final points = sparklinePoints([1, 2, 3, 4], width: 30, height: 10);

      expect(points.map((p) => p.dx), [0, 10, 20, 30]);
    });

    test('returns an empty list for fewer than 2 values', () {
      expect(sparklinePoints([], width: 10, height: 10), isEmpty);
      expect(sparklinePoints([5], width: 10, height: 10), isEmpty);
    });
  });

  group('LatencySparkline', () {
    testWidgets('renders nothing for fewer than 2 values', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: LatencySparkline(values: [5], color: Colors.blue),
        ),
      );

      expect(find.byType(CustomPaint), findsNothing);
    });

    testWidgets('renders a CustomPaint for 2 or more values', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: LatencySparkline(values: [5, 8, 6], color: Colors.blue),
        ),
      );

      expect(find.byType(CustomPaint), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/ui/latency_sparkline_test.dart`
Expected: FAIL to compile — `package:sextant/ui/latency_sparkline.dart` does not exist.

- [ ] **Step 3: Implement the pure function and widget**

Create `lib/ui/latency_sparkline.dart`:

```dart
import 'package:flutter/material.dart';

/// Maps [values] onto evenly-spaced points across a [width]x[height] box,
/// with the minimum value at the bottom (`dy = height`) and the maximum at
/// the top (`dy = 0`), matching screen Y-axis convention for [CustomPainter].
/// Returns an empty list when there's nothing meaningful to draw a line
/// through (fewer than 2 values).
List<Offset> sparklinePoints(
  List<double> values, {
  required double width,
  required double height,
}) {
  if (values.length < 2) return [];
  final min = values.reduce((a, b) => a < b ? a : b);
  final max = values.reduce((a, b) => a > b ? a : b);
  final range = max - min;
  final step = width / (values.length - 1);
  return [
    for (var i = 0; i < values.length; i++)
      Offset(
        i * step,
        range == 0 ? height / 2 : height - (values[i] - min) / range * height,
      ),
  ];
}

/// A minimal line-chart sparkline of recent latency readings. Renders nothing
/// when there's fewer than 2 samples (nothing to draw a trend through).
class LatencySparkline extends StatelessWidget {
  const LatencySparkline({super.key, required this.values, this.color});

  final List<double> values;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();
    return SizedBox(
      width: 48,
      height: 16,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final points = sparklinePoints(values, width: size.width, height: size.height);
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/ui/latency_sparkline_test.dart`
Expected: PASS, all tests green.

- [ ] **Step 5: Wire into the device table**

In `lib/ui/scan_screen.dart`, add two imports alongside the existing `import` block at the top of the file:

```dart
import '../data/device_identity.dart';
import 'latency_sparkline.dart';
```

In `_DeviceTableHeader.build`, find the end of its `Row`'s children (it ends with the "Found via" column just before the closing of the `children` list):

```dart
          SizedBox(width: 80, child: Text('Found via', style: style)),
        ],
      ),
    );
  }
}
```

Replace with:

```dart
          SizedBox(width: 80, child: Text('Found via', style: style)),
          SizedBox(width: 56, child: Text('Latency', style: style)),
        ],
      ),
    );
  }
}
```

In `DeviceRow.build`, find where `small`/`mutedSmall` are computed just before the row's `Padding` is built:

```dart
    final small = theme.textTheme.bodySmall;
    final mutedSmall = small?.copyWith(color: muted);

    final row = Padding(
```

Replace with:

```dart
    final small = theme.textTheme.bodySmall;
    final mutedSmall = small?.copyWith(color: muted);
    final identity = deviceIdentity(
      mac: device.mac,
      hostname: device.hostname,
      openPorts: device.openPorts,
    );

    final row = Padding(
```

Find the "Found via" cell inside that same `Row`'s children (the `Wrap` of discovery-source icons), which ends right before the children list closes:

```dart
          SizedBox(
            width: 80,
            child: Wrap(
              spacing: 4,
              children: [
                for (final source in device.discoveredBy)
                  Tooltip(
                    message: discoverySourceLabel(source),
                    child: Icon(
                      discoverySourceIcon(source),
                      size: 16,
                      color: offline ? muted : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
```

Replace with:

```dart
          SizedBox(
            width: 80,
            child: Wrap(
              spacing: 4,
              children: [
                for (final source in device.discoveredBy)
                  Tooltip(
                    message: discoverySourceLabel(source),
                    child: Icon(
                      discoverySourceIcon(source),
                      size: 16,
                      color: offline ? muted : null,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            child: ref.watch(latencyHistoryProvider(identity)).maybeWhen(
                  data: (values) => LatencySparkline(values: values),
                  orElse: () => const SizedBox.shrink(),
                ),
          ),
        ],
      ),
    );
```

(`DeviceRow` is already a `ConsumerWidget`/has a `ref` in scope — it already reads providers elsewhere in this file for context-menu actions, e.g. `renameDevice`/`setDeviceType` calls via `ref.read(scanControllerProvider.notifier)`.)

- [ ] **Step 6: Run the full suite to verify no regressions**

Run: `flutter test`
Expected: PASS, all tests green.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/latency_sparkline.dart test/ui/latency_sparkline_test.dart lib/ui/scan_screen.dart
git commit -m "feat: show a latency sparkline column in the device table"
```

---

### Task 4: Dedupe multi-homed devices (same MAC, multiple IPs)

**Files:**
- Modify: `lib/model/device.dart`
- Modify: `lib/data/device_serialization.dart`
- Modify: `test/data/device_serialization_test.dart`
- Create: `lib/data/dedupe_multihomed.dart`
- Test: `test/data/dedupe_multihomed_test.dart`
- Modify: `lib/state/providers.dart`
- Modify: `lib/ui/scan_screen.dart`

**Interfaces:**
- Consumes: `Device` (adds new field), `normalizeMac(String mac)` from `lib/platform/arp_table.dart`, `Device.ipSortKey` getter (existing, used to order merged IPs).
- Produces: `Device.additionalIps` (`List<String>`, default `const []`) — secondary IPs of the same physical host, beyond the primary `Device.ip`; `dedupeMultihomed(List<Device> devices) -> List<Device>` (pure, groups by normalized MAC, keeps the lowest IP as primary, merges `openPorts`/`services`/`discoveredBy`/`isOnline` and records the rest as `additionalIps`; devices without a MAC pass through unchanged). Task 4 itself wires `dedupeMultihomed` into `ScanController._emit()` for display only — it does not touch `_byIp`, `diffScans`, or `_saveHistory`'s inputs.

- [ ] **Step 1: Add `additionalIps` to `Device`**

Open `lib/model/device.dart`. Add a new field to the class, matching the existing field declarations exactly in style (find the `openPorts` field declaration and add `additionalIps` near it):

```dart
  final List<int> openPorts;
```

becomes:

```dart
  final List<int> openPorts;
  final List<String> additionalIps;
```

In the constructor, find:

```dart
    this.openPorts = const [],
```

and change to:

```dart
    this.openPorts = const [],
    this.additionalIps = const [],
```

In `copyWith`, find:

```dart
    List<int>? openPorts,
```

and the corresponding assignment `openPorts: openPorts ?? this.openPorts,`. Add, matching the existing `??`-keeps-current convention:

```dart
    List<int>? openPorts,
    List<String>? additionalIps,
```

and:

```dart
      openPorts: openPorts ?? this.openPorts,
      additionalIps: additionalIps ?? this.additionalIps,
```

- [ ] **Step 2: Round-trip `additionalIps` through serialization — write the failing test**

In `test/data/device_serialization_test.dart`, update the "fully-populated device" test. Find:

```dart
        networkId: 'net-abc',
        isOnline: false,
        latencyMs: 12.5,
      );
```

and change to:

```dart
        networkId: 'net-abc',
        isOnline: false,
        latencyMs: 12.5,
        additionalIps: ['192.168.1.43'],
      );
```

Then find the matching assertions block for that test and add an assertion right after `expect(restored.latencyMs, 12.5);`:

```dart
      expect(restored.latencyMs, 12.5);
      expect(restored.additionalIps, ['192.168.1.43']);
```

In the "minimal device" test, find `expect(restored.latencyMs, isNull);` and add immediately after:

```dart
      expect(restored.latencyMs, isNull);
      expect(restored.additionalIps, isEmpty);
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/data/device_serialization_test.dart`
Expected: FAIL — `additionalIps` is not a named parameter of `Device`'s constructor used in the test... actually it now is (Step 1 added it), so this will instead fail with `restored.additionalIps` returning `[]` for the fully-populated case (mismatch: expected `['192.168.1.43']`, got `[]`), because `deviceToMap`/`deviceFromMap` don't round-trip it yet.

- [ ] **Step 4: Round-trip `additionalIps` through `deviceToMap`/`deviceFromMap`**

In `lib/data/device_serialization.dart`, in `deviceToMap`, find:

```dart
      'isOnline': device.isOnline,
      'latencyMs': device.latencyMs,
    };
```

and change to:

```dart
      'isOnline': device.isOnline,
      'latencyMs': device.latencyMs,
      'additionalIps': device.additionalIps,
    };
```

In `deviceFromMap`, find:

```dart
      isOnline: map['isOnline'] as bool? ?? true,
      latencyMs: (map['latencyMs'] as num?)?.toDouble(),
    );
```

and change to:

```dart
      isOnline: map['isOnline'] as bool? ?? true,
      latencyMs: (map['latencyMs'] as num?)?.toDouble(),
      additionalIps: [
        for (final ip in (map['additionalIps'] as List? ?? const [])) ip as String,
      ],
    );
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/device_serialization_test.dart`
Expected: PASS, all tests green.

- [ ] **Step 6: Write the failing tests for `dedupeMultihomed`**

Create `test/data/dedupe_multihomed_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/data/dedupe_multihomed.dart';
import 'package:sextant/model/device.dart';
import 'package:sextant/model/discovery_source.dart';

Device _dev(
  String ip, {
  String? mac,
  List<int>? openPorts,
  Map<int, String>? services,
  Set<DiscoverySource>? discoveredBy,
  bool isOnline = true,
}) {
  final t = DateTime.utc(2026, 1, 1);
  return Device(
    ip: ip,
    mac: mac,
    openPorts: openPorts ?? const [],
    services: services ?? const {},
    discoveredBy: discoveredBy ?? const {},
    isOnline: isOnline,
    firstSeen: t,
    lastSeen: t,
  );
}

void main() {
  group('dedupeMultihomed', () {
    test('devices with no MAC pass through unchanged', () {
      final devices = [_dev('10.0.0.1'), _dev('10.0.0.2')];

      final result = dedupeMultihomed(devices);

      expect(result, devices);
    });

    test('merges two IPs sharing a MAC, keeping the lower IP as primary', () {
      final a = _dev('10.0.0.20', mac: 'aa:aa:aa:aa:aa:aa', openPorts: [22]);
      final b = _dev('10.0.0.5', mac: 'aa:aa:aa:aa:aa:aa', openPorts: [80]);

      final result = dedupeMultihomed([a, b]);

      expect(result, hasLength(1));
      expect(result.single.ip, '10.0.0.5');
      expect(result.single.additionalIps, ['10.0.0.20']);
      expect(result.single.openPorts, [22, 80]);
    });

    test('MAC matching is case- and dash/colon-insensitive', () {
      final a = _dev('10.0.0.5', mac: 'AA-AA-AA-AA-AA-AA');
      final b = _dev('10.0.0.6', mac: 'aa:aa:aa:aa:aa:aa');

      final result = dedupeMultihomed([a, b]);

      expect(result, hasLength(1));
    });

    test('unions services and discoveredBy across the merged group', () {
      final a = _dev(
        '10.0.0.5',
        mac: 'aa:aa:aa:aa:aa:aa',
        services: {80: 'nginx'},
        discoveredBy: {DiscoverySource.tcp},
      );
      final b = _dev(
        '10.0.0.6',
        mac: 'aa:aa:aa:aa:aa:aa',
        services: {443: 'TLS'},
        discoveredBy: {DiscoverySource.arp},
      );

      final result = dedupeMultihomed([a, b]).single;

      expect(result.services, {80: 'nginx', 443: 'TLS'});
      expect(result.discoveredBy, {DiscoverySource.tcp, DiscoverySource.arp});
    });

    test('merged device is online if any member is online', () {
      final a = _dev('10.0.0.5', mac: 'aa:aa:aa:aa:aa:aa', isOnline: false);
      final b = _dev('10.0.0.6', mac: 'aa:aa:aa:aa:aa:aa', isOnline: true);

      final result = dedupeMultihomed([a, b]).single;

      expect(result.isOnline, isTrue);
    });

    test('three IPs sharing a MAC merge into one device', () {
      final devices = [
        _dev('10.0.0.30', mac: 'bb:bb:bb:bb:bb:bb'),
        _dev('10.0.0.10', mac: 'bb:bb:bb:bb:bb:bb'),
        _dev('10.0.0.20', mac: 'bb:bb:bb:bb:bb:bb'),
      ];

      final result = dedupeMultihomed(devices);

      expect(result, hasLength(1));
      expect(result.single.ip, '10.0.0.10');
      expect(result.single.additionalIps, ['10.0.0.20', '10.0.0.30']);
    });
  });
}
```

- [ ] **Step 7: Run tests to verify they fail**

Run: `flutter test test/data/dedupe_multihomed_test.dart`
Expected: FAIL to compile — `package:sextant/data/dedupe_multihomed.dart` does not exist.

- [ ] **Step 8: Implement `dedupeMultihomed`**

Create `lib/data/dedupe_multihomed.dart`:

```dart
import '../model/device.dart';
import '../platform/arp_table.dart';

/// Collapses devices that share a MAC address (multi-homed hosts — e.g. a
/// machine with both Wi-Fi and Ethernet up) into one row for display,
/// keeping the lowest IP as the primary and recording the rest in
/// [Device.additionalIps]. Devices without a MAC (most fingerprint-identity
/// devices) pass through unchanged, since grouping them would risk merging
/// unrelated hosts. This is a display-only transform: callers must apply it
/// strictly after diffing/history have already used the raw per-IP list.
List<Device> dedupeMultihomed(List<Device> devices) {
  final byMac = <String, List<Device>>{};
  final result = <Device>[];

  for (final d in devices) {
    final mac = d.mac;
    if (mac == null) {
      result.add(d);
      continue;
    }
    byMac.putIfAbsent(normalizeMac(mac), () => []).add(d);
  }

  for (final group in byMac.values) {
    if (group.length == 1) {
      result.add(group.single);
      continue;
    }
    final sorted = [...group]..sort((a, b) => a.ipSortKey.compareTo(b.ipSortKey));
    final primary = sorted.first;
    final others = sorted.skip(1);

    final openPorts = <int>{...primary.openPorts};
    final services = <int, String>{...primary.services};
    final discoveredBy = {...primary.discoveredBy};
    var isOnline = primary.isOnline;
    for (final o in others) {
      openPorts.addAll(o.openPorts);
      services.addAll(o.services);
      discoveredBy.addAll(o.discoveredBy);
      isOnline = isOnline || o.isOnline;
    }

    result.add(primary.copyWith(
      openPorts: openPorts.toList()..sort(),
      services: services,
      discoveredBy: discoveredBy,
      isOnline: isOnline,
      additionalIps: [for (final o in others) o.ip],
    ));
  }

  return result;
}
```

- [ ] **Step 9: Run tests to verify they pass**

Run: `flutter test test/data/dedupe_multihomed_test.dart`
Expected: PASS, 6/6 tests green.

- [ ] **Step 10: Wire into `ScanController._emit()` for display only**

In `lib/state/providers.dart`, add the import alongside the other `data/` imports:

```dart
import '../data/dedupe_multihomed.dart';
```

Find the `_emit` method:

```dart
  void _emit({bool? isScanning, bool? enriching}) {
    final sorted = _byIp.values.toList()
      ..sort((a, b) => a.ipSortKey.compareTo(b.ipSortKey));
    state = state.copyWith(
      devices: sorted,
      scanned: _probed,
      isScanning: isScanning,
      enriching: enriching,
      isMonitoring: _monitoring,
    );
  }
```

Change the `devices:` line so the emitted list is deduped, leaving everything else in the method untouched:

```dart
  void _emit({bool? isScanning, bool? enriching}) {
    final sorted = _byIp.values.toList()
      ..sort((a, b) => a.ipSortKey.compareTo(b.ipSortKey));
    state = state.copyWith(
      devices: dedupeMultihomed(sorted),
      scanned: _probed,
      isScanning: isScanning,
      enriching: enriching,
      isMonitoring: _monitoring,
    );
  }
```

Do not change anything else in `_emit`, and do not apply `dedupeMultihomed` anywhere in `_saveHistory`, `_reconcile`, `_merge`, or any code path that feeds `diffScans` — those must keep operating on the raw per-IP devices.

- [ ] **Step 11: Show a "+N" badge for merged IPs in the device table**

In `lib/ui/scan_screen.dart`, find the IP cell in `DeviceRow.build` (the `SizedBox` wrapping the `Text` widget that renders `device.ip`). Wrap it so an additional badge appears when `device.additionalIps` is non-empty. Find:

```dart
          SizedBox(
            width: _kIpWidth,
            child: Text(
              device.ip,
              style: TextStyle(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: offline ? muted : null,
              ),
            ),
          ),
```

and replace with:

```dart
          SizedBox(
            width: _kIpWidth,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  device.ip,
                  style: TextStyle(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: offline ? muted : null,
                  ),
                ),
                if (device.additionalIps.isNotEmpty)
                  Tooltip(
                    message: 'Also seen at: ${device.additionalIps.join(', ')}',
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '+${device.additionalIps.length}',
                        style: mutedSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
```

- [ ] **Step 12: Run the full suite to verify no regressions**

Run: `flutter test`
Expected: PASS, all tests green.

- [ ] **Step 13: Commit**

```bash
git add lib/model/device.dart lib/data/device_serialization.dart test/data/device_serialization_test.dart lib/data/dedupe_multihomed.dart test/data/dedupe_multihomed_test.dart lib/state/providers.dart lib/ui/scan_screen.dart
git commit -m "feat: dedupe multi-homed devices in the table display"
```

---

### Task 5: ICMP sweep concurrency tuning

**Files:**
- Modify: `lib/platform/icmp_pinger.dart`
- Modify: `test/platform/icmp_pinger_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing new (no new public API — `IcmpSweeper.concurrency`'s default value changes from `64` to `128`; the type and parameter name are unchanged, so no other task's interface block needs updating).

- [ ] **Step 1: Write the failing test**

Open `test/platform/icmp_pinger_test.dart`. Find the end of the `group('IcmpPinger (real)', ...)` block, just before the file's closing `}`:

```dart
    test('reports an unroutable TEST-NET address as not alive', () async {
      final alive = await const IcmpPinger(
        timeout: Duration(milliseconds: 800),
      ).isAlive(InternetAddress('192.0.2.1'));
      expect(alive, isFalse);
    });
  });
}
```

Replace with:

```dart
    test('reports an unroutable TEST-NET address as not alive', () async {
      final alive = await const IcmpPinger(
        timeout: Duration(milliseconds: 800),
      ).isAlive(InternetAddress('192.0.2.1'));
      expect(alive, isFalse);
    });
  });

  group('IcmpSweeper', () {
    test('defaults to a concurrency of 128', () {
      expect(IcmpSweeper().concurrency, 128);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/platform/icmp_pinger_test.dart`
Expected: FAIL — `Expected: <128> Actual: <64>`.

- [ ] **Step 3: Raise the default concurrency**

In `lib/platform/icmp_pinger.dart`, find the `IcmpSweeper` class doc comment and constructor:

```dart
/// Pings a list of hosts with bounded concurrency, emitting each host that
/// replies. Doubles as an ARP primer: sending an echo to an on-link host
/// triggers ARP resolution, so the OS ARP cache is populated for every host
/// that answers at layer 2 — even those that drop the ICMP echo.
class IcmpSweeper {
  IcmpSweeper({IcmpPinger? pinger, this.concurrency = 64})
      : _pinger = pinger ?? const IcmpPinger();
```

Replace with:

```dart
/// Pings a list of hosts with bounded concurrency, emitting each host that
/// replies. Doubles as an ARP primer: sending an echo to an on-link host
/// triggers ARP resolution, so the OS ARP cache is populated for every host
/// that answers at layer 2 — even those that drop the ICMP echo.
///
/// The ping sweep is the dominant phase of a scan: a host that doesn't reply
/// costs the full [IcmpPinger.timeout] (1s default). At concurrency 64, a
/// /22 (1022 hosts) needs >=16 sequential rounds whenever any round contains
/// a non-responder — which is most of them — i.e. >=16s just for the sweep,
/// matching the ~18s observed on the real /22 this was tuned against.
/// Concurrency 128 halves that floor to >=8 rounds, while staying well below
/// the TCP scanner's 256 (each ping forks a process, heavier than a TCP
/// connect, so it isn't raised all the way to parity).
class IcmpSweeper {
  IcmpSweeper({IcmpPinger? pinger, this.concurrency = 128})
      : _pinger = pinger ?? const IcmpPinger();
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/platform/icmp_pinger_test.dart`
Expected: PASS, all tests green.

- [ ] **Step 5: Verify on the real LAN (informational, not gating)**

Run: `dart run tool/live_scan.dart`
Expected: completes successfully; note the elapsed time printed at the end in the commit/report for comparison against the historical ~18s baseline (a faster sweep should show up as a lower total). This step does not block the commit if `live_scan.dart` can't reach a real network from the current environment — note that in the report instead.

- [ ] **Step 6: Run the full suite to verify no regressions**

Run: `flutter test`
Expected: PASS, all tests green.

- [ ] **Step 7: Commit**

```bash
git add lib/platform/icmp_pinger.dart test/platform/icmp_pinger_test.dart
git commit -m "perf: raise ICMP sweep concurrency from 64 to 128"
```

---

### Task 6: Periodic OUI vendor DB refresh

**Files:**
- Create: `lib/enrich/oui_refresh.dart`
- Test: `test/enrich/oui_refresh_test.dart`
- Modify: `tool/build_oui.dart`
- Modify: `lib/state/providers.dart`

**Interfaces:**
- Consumes: `parseOuiTsv`/`OuiVendorLookup` from `lib/enrich/oui_vendor_lookup.dart`; `kSeedOuiTable` (already used in `providers.dart`'s existing `ouiLookupProvider`); the IEEE OUI CSV URL `https://standards-oui.ieee.org/oui/oui.csv` (reused verbatim from the existing comment in `tool/build_oui.dart`, not newly invented).
- Produces: `parseOuiCsv(String csv) -> Map<String, String>` (pure; OUI hex → org name); `ouiTableToTsv(Map<String, String> table) -> String` (serializes to the same `AABBCC\tVendor` format as `assets/oui.tsv`, loadable by the existing `parseOuiTsv`); `OuiCsvFetcher` typedef (`Future<String?> Function(Uri source)`, injectable for tests); `OuiRefresher({Duration maxAge = const Duration(days: 30), Uri? source, OuiCsvFetcher? fetch})` with `Future<bool> refreshIfStale(File cacheFile)`. No other task in this plan depends on this task's output.

- [ ] **Step 1: Write the failing tests**

Create `test/enrich/oui_refresh_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/enrich/oui_refresh.dart';
import 'package:sextant/enrich/oui_vendor_lookup.dart';

void main() {
  group('parseOuiCsv', () {
    test('parses Registry,Assignment,Organization Name,Address rows', () {
      const csv = 'Registry,Assignment,Organization Name,Organization Address\n'
          'MA-L,001122,Acme Corp,123 Main St\n';

      expect(parseOuiCsv(csv), {'001122': 'Acme Corp'});
    });

    test('parses quoted organization names containing commas', () {
      const csv = 'Registry,Assignment,Organization Name,Organization Address\n'
          'MA-L,A483E7,"LEXMARK INTERNATIONAL, INC.",740 New Circle Road NW\n';

      expect(parseOuiCsv(csv), {'A483E7': 'LEXMARK INTERNATIONAL, INC.'});
    });

    test('skips rows with a malformed OUI or empty organization', () {
      const csv = 'Registry,Assignment,Organization Name,Organization Address\n'
          'MA-L,BAD,Some Org,Addr\n'
          'MA-L,AABBCC,,Addr\n';

      expect(parseOuiCsv(csv), isEmpty);
    });
  });

  test('ouiTableToTsv round-trips through parseOuiTsv', () {
    const table = {'AABBCC': 'Acme, Inc.', '112233': 'Other Co'};

    expect(parseOuiTsv(ouiTableToTsv(table)), table);
  });

  group('OuiRefresher.refreshIfStale', () {
    late Directory tempDir;
    late File cacheFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('oui_refresh_test');
      cacheFile = File('${tempDir.path}/oui_cache.tsv');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('fetches and writes the cache when none exists yet', () async {
      final refresher = OuiRefresher(
        fetch: (uri) async => 'Registry,Assignment,Organization Name,Address\n'
            'MA-L,AABBCC,Acme Corp,1 Main St\n',
      );

      final refreshed = await refresher.refreshIfStale(cacheFile);

      expect(refreshed, isTrue);
      expect(await cacheFile.exists(), isTrue);
      expect(parseOuiTsv(await cacheFile.readAsString()), {'AABBCC': 'Acme Corp'});
    });

    test('does not refetch when the cache is younger than maxAge', () async {
      await cacheFile.writeAsString('AABBCC\tOld Vendor\n');
      var fetched = false;
      final refresher = OuiRefresher(fetch: (uri) async {
        fetched = true;
        return 'Registry,Assignment,Organization Name,Address\nMA-L,AABBCC,New Vendor,Addr\n';
      });

      final refreshed = await refresher.refreshIfStale(cacheFile);

      expect(refreshed, isFalse);
      expect(fetched, isFalse);
      expect(await cacheFile.readAsString(), 'AABBCC\tOld Vendor\n');
    });

    test('refetches when the cache is older than maxAge', () async {
      await cacheFile.writeAsString('AABBCC\tOld Vendor\n');
      await cacheFile.setLastModified(
        DateTime.now().subtract(const Duration(days: 31)),
      );
      final refresher = OuiRefresher(
        maxAge: const Duration(days: 30),
        fetch: (uri) async =>
            'Registry,Assignment,Organization Name,Address\nMA-L,AABBCC,New Vendor,Addr\n',
      );

      final refreshed = await refresher.refreshIfStale(cacheFile);

      expect(refreshed, isTrue);
      expect(parseOuiTsv(await cacheFile.readAsString()), {'AABBCC': 'New Vendor'});
    });

    test('leaves the cache untouched when the fetch fails', () async {
      await cacheFile.writeAsString('AABBCC\tOld Vendor\n');
      await cacheFile.setLastModified(
        DateTime.now().subtract(const Duration(days: 31)),
      );
      final refresher = OuiRefresher(fetch: (uri) async => null);

      final refreshed = await refresher.refreshIfStale(cacheFile);

      expect(refreshed, isFalse);
      expect(await cacheFile.readAsString(), 'AABBCC\tOld Vendor\n');
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/enrich/oui_refresh_test.dart`
Expected: FAIL to compile — `package:sextant/enrich/oui_refresh.dart` does not exist.

- [ ] **Step 3: Implement `oui_refresh.dart`**

Create `lib/enrich/oui_refresh.dart`:

```dart
import 'dart:convert';
import 'dart:io';

/// Pure CSV parsing for the IEEE OUI registry's published CSV format
/// (`Registry,Assignment,Organization Name,Organization Address`). Shared by
/// the in-app refresher below and the one-off `tool/build_oui.dart` generator,
/// so both parse identically.
Map<String, String> parseOuiCsv(String csv) {
  final table = <String, String>{};
  for (final line in csv.split('\n').skip(1)) {
    if (line.trim().isEmpty) continue;
    final fields = _parseCsvLine(line);
    if (fields.length < 3) continue;
    final oui = fields[1].trim().toUpperCase();
    final org = fields[2].trim();
    if (oui.length != 6 || org.isEmpty) continue;
    table[oui] = org;
  }
  return table;
}

/// Minimal RFC-4180 CSV line parser (handles double-quoted fields containing
/// commas and escaped quotes).
List<String> _parseCsvLine(String line) {
  final fields = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buf.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      fields.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  fields.add(buf.toString());
  return fields;
}

/// Serialises an OUI table back into the same `AABBCC\tVendor` TSV format as
/// the bundled `assets/oui.tsv`, so it can be cached to disk and re-loaded
/// with the existing `parseOuiTsv`.
String ouiTableToTsv(Map<String, String> table) {
  final out = StringBuffer();
  for (final entry in table.entries) {
    out.writeln('${entry.key}\t${entry.value}');
  }
  return out.toString();
}

/// Fetches the raw IEEE OUI CSV from [source]. The default implementation
/// hits the network directly; tests inject a fake to avoid real HTTP calls.
typedef OuiCsvFetcher = Future<String?> Function(Uri source);

Future<String?> _fetchOuiCsv(Uri source) async {
  final client = HttpClient();
  try {
    final request =
        await client.getUrl(source).timeout(const Duration(seconds: 20));
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return null;
    return await response.transform(utf8.decoder).join().timeout(
          const Duration(seconds: 20),
        );
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// Refreshes a cached copy of the IEEE OUI registry on disk, so the bundled
/// `assets/oui.tsv` (which only updates between app releases) doesn't go
/// stale forever between them. Refreshing is best-effort: a failed fetch
/// (offline, non-200, parse error) leaves the existing cache (or the bundled
/// asset, if there is no cache yet) as the fallback.
class OuiRefresher {
  OuiRefresher({
    this.maxAge = const Duration(days: 30),
    Uri? source,
    OuiCsvFetcher? fetch,
  })  : source = source ?? Uri.parse('https://standards-oui.ieee.org/oui/oui.csv'),
        _fetch = fetch ?? _fetchOuiCsv;

  final Duration maxAge;
  final Uri source;
  final OuiCsvFetcher _fetch;

  /// Refreshes [cacheFile] in place if it's missing or older than [maxAge].
  /// Returns true if a refresh actually happened.
  Future<bool> refreshIfStale(File cacheFile) async {
    if (await cacheFile.exists()) {
      final age = DateTime.now().difference(await cacheFile.lastModified());
      if (age < maxAge) return false;
    }
    final csv = await _fetch(source);
    if (csv == null) return false;
    final table = parseOuiCsv(csv);
    if (table.isEmpty) return false;
    await cacheFile.create(recursive: true);
    await cacheFile.writeAsString(ouiTableToTsv(table));
    return true;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/enrich/oui_refresh_test.dart`
Expected: PASS, all tests green. (These tests never make a real network call — every `OuiRefresher` in this file injects `fetch`.)

- [ ] **Step 5: Remove the duplicated CSV parser from `tool/build_oui.dart`**

Read the current `tool/build_oui.dart` to see its existing `_parseCsvLine`/CSV-walking logic, then replace the whole file with a version that reuses the new pure functions instead of duplicating them:

```dart
import 'dart:io';

import 'package:sextant/enrich/oui_refresh.dart';

/// One-off generator for `assets/oui.tsv` from the IEEE OUI registry CSV
/// (https://standards-oui.ieee.org/oui/oui.csv). Run manually when the
/// bundled snapshot needs updating for a release:
///   dart run tool/build_oui.dart
/// (download the CSV to /tmp/oui.csv first).
void main() {
  final csv = File('/tmp/oui.csv').readAsStringSync();
  final table = parseOuiCsv(csv);
  Directory('assets').createSync(recursive: true);
  File('assets/oui.tsv').writeAsStringSync(ouiTableToTsv(table));
  stdout.writeln('Wrote assets/oui.tsv with ${table.length} entries.');
}
```

This is a one-off dev script with no existing test; do not add one. Do not regenerate `assets/oui.tsv` as part of this task — that requires downloading the live IEEE registry, which is a manual, pre-release step, not part of this code change.

- [ ] **Step 6: Wire `OuiRefresher` into `ouiLookupProvider`**

In `lib/state/providers.dart`, add one import alongside the other `enrich/` imports (the file already imports `dart:io`, `dart:async`, and `package:path_provider/path_provider.dart`, so no other new imports are needed):

```dart
import '../enrich/oui_refresh.dart';
```

Find the existing `ouiLookupProvider`:

```dart
/// The OUI → vendor lookup, loaded from the bundled IEEE database
/// (`assets/oui.tsv`, ~39.5k entries), with the small seed table as a fallback
/// for any prefixes not present. Falls back to the seed alone if the asset
/// can't be read.
final ouiLookupProvider = FutureProvider<OuiVendorLookup>((ref) async {
  try {
    final table = parseOuiTsv(await rootBundle.loadString('assets/oui.tsv'));
    for (final entry in kSeedOuiTable.entries) {
      table.putIfAbsent(entry.key, () => entry.value);
    }
    return OuiVendorLookup(table);
  } catch (_) {
    return const OuiVendorLookup(kSeedOuiTable);
  }
});
```

Replace with:

```dart
/// The OUI → vendor lookup. Prefers a previously-refreshed cache in the app
/// support directory over the bundled IEEE snapshot (`assets/oui.tsv`,
/// ~39.5k entries, which only updates between app releases), with the small
/// seed table as a fallback for any prefixes not present in either. A
/// background refresh is kicked off on every load (debounced by [OuiRefresher]'s
/// `maxAge`) so the cache improves over time without ever blocking this lookup
/// or requiring the app to be online.
final ouiLookupProvider = FutureProvider<OuiVendorLookup>((ref) async {
  final dir = await getApplicationSupportDirectory();
  final cacheFile = File('${dir.path}/oui_cache.tsv');
  unawaited(OuiRefresher().refreshIfStale(cacheFile));

  try {
    final tsv = await cacheFile.exists()
        ? await cacheFile.readAsString()
        : await rootBundle.loadString('assets/oui.tsv');
    final table = parseOuiTsv(tsv);
    for (final entry in kSeedOuiTable.entries) {
      table.putIfAbsent(entry.key, () => entry.value);
    }
    return OuiVendorLookup(table);
  } catch (_) {
    return const OuiVendorLookup(kSeedOuiTable);
  }
});
```

(`getApplicationSupportDirectory` and `unawaited` are already available — `path_provider` and `dart:async` are both already imported at the top of this file.)

- [ ] **Step 7: Run the full suite to verify no regressions**

Run: `flutter test`
Expected: PASS, all tests green.

- [ ] **Step 8: Commit**

```bash
git add lib/enrich/oui_refresh.dart test/enrich/oui_refresh_test.dart tool/build_oui.dart lib/state/providers.dart
git commit -m "feat: periodically refresh the OUI vendor DB from the IEEE registry"
```

---

### Task 7: Radial topology layout (pure geometry)

**Files:**
- Create: `lib/ui/topology_layout.dart`
- Test: `test/ui/topology_layout_test.dart`

**Interfaces:**
- Consumes: `Device` (`lib/model/device.dart`).
- Produces: `TopologyNode` (`{required Device device, required Offset position, required bool isGateway}`); `layoutRadial(List<Device> devices, {String? gatewayIp, required Size size}) -> List<TopologyNode>` — places the device whose `ip == gatewayIp` (if any) at the center, all others evenly spaced on a ring around it starting at 12 o'clock, sorted by IP; with no gateway match, all devices go on the ring. Task 8 consumes `TopologyNode`/`layoutRadial`.

- [ ] **Step 1: Write the failing tests**

Create `test/ui/topology_layout_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/model/device.dart';
import 'package:sextant/ui/topology_layout.dart';

Device _dev(String ip) {
  final t = DateTime.utc(2026, 1, 1);
  return Device(ip: ip, firstSeen: t, lastSeen: t);
}

void main() {
  group('layoutRadial', () {
    test('returns no nodes for an empty device list', () {
      expect(layoutRadial([], size: const Size(200, 200)), isEmpty);
    });

    test('a single device with no gateway match sits on the ring', () {
      final device = _dev('10.0.0.5');

      final nodes = layoutRadial([device], size: const Size(200, 200));

      expect(nodes, hasLength(1));
      expect(nodes.single.isGateway, isFalse);
    });

    test('the device matching gatewayIp is centered and flagged', () {
      final gateway = _dev('10.0.0.1');
      final other = _dev('10.0.0.2');

      final nodes = layoutRadial(
        [other, gateway],
        gatewayIp: '10.0.0.1',
        size: const Size(200, 200),
      );

      final center = nodes.singleWhere((n) => n.isGateway);
      expect(center.device.ip, '10.0.0.1');
      expect(center.position, const Offset(100, 100));
    });

    test("ring devices are sorted by IP and spaced evenly starting at 12 o'clock", () {
      final gateway = _dev('10.0.0.1');
      final devices = [_dev('10.0.0.4'), _dev('10.0.0.3'), _dev('10.0.0.2'), gateway];

      final nodes = layoutRadial(devices, gatewayIp: '10.0.0.1', size: const Size(200, 200));
      final ring = nodes.where((n) => !n.isGateway).toList();

      expect(ring.map((n) => n.device.ip), ['10.0.0.2', '10.0.0.3', '10.0.0.4']);
      const radius = 100 - 24.0;
      expect(ring[0].position.dx, closeTo(100, 0.001));
      expect(ring[0].position.dy, closeTo(100 - radius, 0.001));
    });

    test('with no gateway match, all devices are placed on the ring', () {
      final devices = [_dev('10.0.0.2'), _dev('10.0.0.3')];

      final nodes = layoutRadial(devices, size: const Size(200, 200));

      expect(nodes, hasLength(2));
      expect(nodes.every((n) => !n.isGateway), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/ui/topology_layout_test.dart`
Expected: FAIL to compile — `package:sextant/ui/topology_layout.dart` does not exist.

- [ ] **Step 3: Implement `layoutRadial`**

Create `lib/ui/topology_layout.dart`:

```dart
import 'dart:math';
import 'dart:ui';

import '../model/device.dart';

/// One positioned node in a radial topology layout.
class TopologyNode {
  const TopologyNode({
    required this.device,
    required this.position,
    required this.isGateway,
  });

  final Device device;
  final Offset position;
  final bool isGateway;
}

/// Lays [devices] out radially within [size]: the device whose IP matches
/// [gatewayIp] (if any) sits at the center; every other device is placed on
/// a ring around it, sorted by IP and spaced evenly starting at 12 o'clock.
/// With no gateway match, every device goes on the ring (no center node).
List<TopologyNode> layoutRadial(
  List<Device> devices, {
  String? gatewayIp,
  required Size size,
}) {
  if (devices.isEmpty) return [];

  final center = Offset(size.width / 2, size.height / 2);
  const nodeRadius = 24.0;
  final ringRadius = min(size.width, size.height) / 2 - nodeRadius;

  Device? gateway;
  final ring = <Device>[];
  for (final d in devices) {
    if (gatewayIp != null && d.ip == gatewayIp && gateway == null) {
      gateway = d;
    } else {
      ring.add(d);
    }
  }
  ring.sort((a, b) => a.ipSortKey.compareTo(b.ipSortKey));

  final nodes = <TopologyNode>[];
  if (gateway != null) {
    nodes.add(TopologyNode(device: gateway, position: center, isGateway: true));
  }
  for (var i = 0; i < ring.length; i++) {
    final angle = -pi / 2 + (2 * pi * i / ring.length);
    nodes.add(TopologyNode(
      device: ring[i],
      position: Offset(
        center.dx + ringRadius * cos(angle),
        center.dy + ringRadius * sin(angle),
      ),
      isGateway: false,
    ));
  }
  return nodes;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/ui/topology_layout_test.dart`
Expected: PASS, all tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/topology_layout.dart test/ui/topology_layout_test.dart
git commit -m "feat: add a pure radial layout function for the topology view"
```

---

### Task 8: Topology screen + toolbar entry point

**Files:**
- Create: `lib/ui/topology_screen.dart`
- Test: `test/ui/topology_screen_test.dart`
- Modify: `lib/ui/scan_screen.dart`

**Interfaces:**
- Consumes: `layoutRadial`/`TopologyNode` (Task 7); `deviceIcon(Device)` from `lib/ui/device_visuals.dart`; `scanControllerProvider` (`ScanState.devices`), `networksProvider`, `selectedNetworkProvider` (all existing in `lib/state/providers.dart`); `effectiveNetwork(List<ScanNetwork> networks, ScanNetwork? selected)` from `lib/state/network_selection.dart`.
- Produces: `TopologyScreen` widget (no constructor parameters) — pushed as a full route from the toolbar, like the existing `HistoryScreen`. No later task in this plan depends on it.

- [ ] **Step 1: Write the failing tests**

Create `test/ui/topology_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/model/device.dart';
import 'package:sextant/model/network_info.dart';
import 'package:sextant/state/providers.dart';
import 'package:sextant/state/scan_state.dart';
import 'package:sextant/ui/topology_screen.dart';

class _FixedScanController extends ScanController {
  _FixedScanController(this._state);
  final ScanState _state;

  @override
  ScanState build() => _state;
}

Device _dev(String ip) {
  final t = DateTime.utc(2026, 1, 1);
  return Device(ip: ip, firstSeen: t, lastSeen: t);
}

Future<void> _pump(WidgetTester tester, List<Device> devices) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scanControllerProvider
            .overrideWith(() => _FixedScanController(ScanState(devices: devices))),
        networksProvider.overrideWith((ref) async => <ScanNetwork>[]),
      ],
      child: const MaterialApp(home: TopologyScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows a placeholder when there are no devices', (tester) async {
    await _pump(tester, []);

    expect(find.text('Run a scan to see the network map.'), findsOneWidget);
  });

  testWidgets('renders one node per discovered device', (tester) async {
    await _pump(tester, [_dev('10.0.0.1'), _dev('10.0.0.2'), _dev('10.0.0.3')]);

    expect(find.byType(CircleAvatar), findsNWidgets(3));
  });

  testWidgets('tapping a node opens a detail dialog', (tester) async {
    await _pump(tester, [_dev('10.0.0.1')]);

    await tester.tap(find.byType(CircleAvatar));
    await tester.pumpAndSettle();

    expect(find.text('IP: 10.0.0.1'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/ui/topology_screen_test.dart`
Expected: FAIL to compile — `package:sextant/ui/topology_screen.dart` does not exist.

- [ ] **Step 3: Implement `TopologyScreen`**

Create `lib/ui/topology_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/device.dart';
import '../state/network_selection.dart';
import '../state/providers.dart';
import 'device_visuals.dart';
import 'topology_layout.dart';

/// A radial network map: the gateway (if known) at the center, every
/// discovered device on a ring around it. Tapping a node shows its details.
class TopologyScreen extends ConsumerWidget {
  const TopologyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(scanControllerProvider).devices;
    final networks = ref.watch(networksProvider).valueOrNull ?? const [];
    final selected = ref.watch(selectedNetworkProvider);
    final gatewayIp = effectiveNetwork(networks, selected)?.gateway?.address;

    return Scaffold(
      appBar: AppBar(title: const Text('Network Map')),
      body: devices.isEmpty
          ? const Center(child: Text('Run a scan to see the network map.'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final nodes = layoutRadial(devices, gatewayIp: gatewayIp, size: size);
                return Stack(
                  children: [
                    CustomPaint(size: size, painter: _EdgePainter(nodes)),
                    for (final node in nodes)
                      Positioned(
                        left: node.position.dx - 24,
                        top: node.position.dy - 24,
                        child: _TopologyNodeWidget(node: node),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _TopologyNodeWidget extends StatelessWidget {
  const _TopologyNodeWidget({required this.node});

  final TopologyNode node;

  @override
  Widget build(BuildContext context) {
    final device = node.device;
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(device.displayName),
          content: Text('IP: ${device.ip}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
      child: Tooltip(
        message: device.displayName,
        child: CircleAvatar(
          radius: 24,
          backgroundColor: node.isGateway
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(deviceIcon(device)),
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.nodes);

  final List<TopologyNode> nodes;

  @override
  void paint(Canvas canvas, Size size) {
    TopologyNode? center;
    for (final n in nodes) {
      if (n.isGateway) {
        center = n;
        break;
      }
    }
    if (center == null) return;
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (final n in nodes) {
      if (n.isGateway) continue;
      canvas.drawLine(center.position, n.position, paint);
    }
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) => oldDelegate.nodes != nodes;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/ui/topology_screen_test.dart`
Expected: PASS, all tests green.

- [ ] **Step 5: Add a toolbar entry point**

In `lib/ui/scan_screen.dart`, add an import alongside the other `ui/` imports:

```dart
import 'topology_screen.dart';
```

In `_Toolbar`'s build, find the existing history button at the end of the toolbar `Row`:

```dart
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Scan history',
          icon: const Icon(Icons.history),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const HistoryScreen(),
            ),
          ),
        ),
      ],
    );
  }
}
```

and replace with (adding a new "Network map" button right after it, same `Row`):

```dart
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Scan history',
          icon: const Icon(Icons.history),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const HistoryScreen(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Network map',
          icon: const Icon(Icons.hub_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const TopologyScreen(),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Run the full suite to verify no regressions**

Run: `flutter test`
Expected: PASS, all tests green.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/topology_screen.dart test/ui/topology_screen_test.dart lib/ui/scan_screen.dart
git commit -m "feat: add a radial network map view"
```
