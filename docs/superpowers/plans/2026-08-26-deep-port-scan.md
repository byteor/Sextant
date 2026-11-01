# Deep Port Scan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Scan all ports (65,535)…" context-menu action that deep-scans one device's full TCP port range, shows non-blocking progress, and persists results so they're auto-included in future regular scans.

**Architecture:** A new small `DeepPortScanner` engine (wrapping the existing `TcpHostScanner` with tuned concurrency/timeout and a per-probe progress callback) runs against a single host, driven by a new `ScanController.startDeepPortScan` method that's mutually exclusive with regular scanning/monitoring. Results persist to a new `DeepScanPorts` Drift table and get unioned into every future regular scan's port list.

**Tech Stack:** Flutter, Riverpod (`NotifierProvider`), Drift (SQLite), existing `TcpHostScanner`/`TcpProbe`.

**Spec:** `docs/superpowers/specs/2026-08-26-deep-port-scan-design.md`

## Global Constraints

- Deep scan port range: 1–65,535 inclusive (`kAllTcpPorts`).
- Deep scan concurrency: 64. Deep scan per-probe timeout: 400ms. (The regular subnet sweep's existing defaults — concurrency 256, 1s timeout — are unchanged; these are new, separate values used only for the single-host deep scan.)
- `DeepScanPorts` is keyed by `deviceIdentity` alone (not network-scoped) — a found-open port is a fact about the physical device, not the network it's on.
- "Auto-include in future scans" means the *network-wide union* of every port ever found via any deep scan gets added to the regular scan's port list — not per-device targeting.
- Mutual exclusion: only one of {regular scan, monitoring tick, deep scan} may run at a time. A deep scan request while another is busy no-ops; a monitoring tick that fires during a deep scan skips that tick and reschedules.

---

### Task 1: `TcpHostScanner` per-probe progress callback

**Files:**
- Modify: `lib/scan/tcp_host_scanner.dart`
- Test: `test/scan/tcp_host_scanner_test.dart`

**Interfaces:**
- Produces: `TcpHostScanner.scan(..., {HostProgress? onProbeComplete})` — fires after every individual port probe completes, with `(completedProbes, totalProbes)`. Additive: existing `onHostComplete` behavior is unchanged, and existing callers that don't pass `onProbeComplete` see no behavior change.

- [ ] **Step 1: Write the failing test**

Add to `test/scan/tcp_host_scanner_test.dart`, inside the existing `group('TcpHostScanner', ...)`:

```dart
    test('reports progress after every individual port probe, not just per '
        'host', () async {
      final scanner = TcpHostScanner(
        probe: (host, port) async => false,
        concurrency: 4,
      );
      final progress = <int>[];
      int? totalSeen;

      await scanner
          .scan(
            [InternetAddress.loopbackIPv4],
            [80, 443, 8080, 8443],
            onProbeComplete: (done, total) {
              progress.add(done);
              totalSeen = total;
            },
          )
          .drain<void>();

      expect(totalSeen, 4);
      // One callback per probe, monotonically increasing to the port count —
      // regardless of completion order, each call gets the next integer up.
      expect(progress, [1, 2, 3, 4]);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/scan/tcp_host_scanner_test.dart`
Expected: FAIL — `The named parameter 'onProbeComplete' isn't defined`.

- [ ] **Step 3: Write minimal implementation**

In `lib/scan/tcp_host_scanner.dart`, update `scan()` and `_drive()`:

```dart
  Stream<HostScanResult> scan(
    List<InternetAddress> hosts,
    List<int> ports, {
    HostProgress? onHostComplete,
    HostProgress? onProbeComplete,
    bool Function()? isCancelled,
  }) {
    final controller = StreamController<HostScanResult>();
    unawaited(
      _drive(hosts, ports, controller, onHostComplete, onProbeComplete, isCancelled),
    );
    return controller.stream;
  }

  Future<void> _drive(
    List<InternetAddress> hosts,
    List<int> ports,
    StreamController<HostScanResult> controller,
    HostProgress? onHostComplete,
    HostProgress? onProbeComplete,
    bool Function()? isCancelled,
  ) async {
    if (hosts.isEmpty || ports.isEmpty) {
      await controller.close();
      return;
    }

    final openByHost = List.generate(hosts.length, (_) => <int>[]);
    final remaining = List<int>.filled(hosts.length, ports.length);

    // Flatten into a single task list so concurrency is bounded across the
    // whole sweep, not per host.
    final tasks = <_ProbeTask>[
      for (var h = 0; h < hosts.length; h++)
        for (final port in ports) _ProbeTask(h, port),
    ];

    var next = 0;
    var completedHosts = 0;
    var completedProbes = 0;
    Future<void> worker() async {
      while (true) {
        if (isCancelled?.call() ?? false) break;
        final i = next++;
        if (i >= tasks.length) break;
        final task = tasks[i];
        final open = await _runProbe(hosts[task.hostIndex], task.port);
        if (open) openByHost[task.hostIndex].add(task.port);
        onProbeComplete?.call(++completedProbes, tasks.length);
        if (--remaining[task.hostIndex] == 0) {
          final found = openByHost[task.hostIndex]..sort();
          if (found.isNotEmpty && !(isCancelled?.call() ?? false)) {
            controller.add(HostScanResult(hosts[task.hostIndex], found));
          }
          onHostComplete?.call(++completedHosts, hosts.length);
        }
      }
    }

    final workerCount = math.min(concurrency, tasks.length);
    await Future.wait([for (var i = 0; i < workerCount; i++) worker()]);
    await controller.close();
  }
```

(Only the `scan()` signature, `_drive()` signature, and the two new lines — the `onProbeComplete?.call(...)` line and threading it through — change. Everything else in the file is untouched.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/scan/tcp_host_scanner_test.dart`
Expected: PASS (all tests in the file, including the 4 pre-existing ones).

- [ ] **Step 5: Commit**

```bash
git add lib/scan/tcp_host_scanner.dart test/scan/tcp_host_scanner_test.dart
git commit -m "Add per-probe progress callback to TcpHostScanner"
```

---

### Task 2: `DeepScanPorts` table and `HistoryDatabase` methods

**Files:**
- Modify: `lib/data/history_database.dart`
- Generated: `lib/data/history_database.g.dart` (via build_runner)
- Test: `test/data/history_database_test.dart`

**Interfaces:**
- Produces: `HistoryDatabase.recordDeepScanPorts(String deviceIdentity, String networkId, List<int> ports) → Future<void>`; `HistoryDatabase.allExtraPorts() → Future<List<int>>` (sorted, deduplicated, across every device).

- [ ] **Step 1: Write the failing tests**

Add to `test/data/history_database_test.dart`, as a new top-level group (after the existing `unacknowledgedCount / recentlySeenDevices / acknowledgeNewDevices` group, before the final closing `}`):

```dart
  group('recordDeepScanPorts / allExtraPorts', () {
    test('records ports found for a device', () async {
      await db.recordDeepScanPorts('mac:aa:aa:aa:aa:aa:aa', 'wifi', [22, 8888]);

      expect(await db.allExtraPorts(), [22, 8888]);
    });

    test('allExtraPorts is the deduplicated union across every device', () async {
      await db.recordDeepScanPorts('mac:aa:aa:aa:aa:aa:aa', 'wifi', [22, 8888]);
      await db.recordDeepScanPorts('mac:bb:bb:bb:bb:bb:bb', 'wifi', [8888, 9999]);

      expect(await db.allExtraPorts(), [22, 8888, 9999]);
    });

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/history_database_test.dart`
Expected: FAIL — `The method 'recordDeepScanPorts' isn't defined for the type 'HistoryDatabase'`.

- [ ] **Step 3: Add the table**

In `lib/data/history_database.dart`, add after the `SeenDevices` table class (after its closing `}`, before the `HistoryDatabase` class doc comment):

```dart
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
```

- [ ] **Step 4: Register the table and bump the schema version**

In `lib/data/history_database.dart`, change:

```dart
@DriftDatabase(tables: [Scans, LatencySamples, SeenDevices])
class HistoryDatabase extends _$HistoryDatabase {
  HistoryDatabase(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(latencySamples);
      if (from < 3) await m.createTable(seenDevices);
    },
  );
```

to:

```dart
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
```

- [ ] **Step 5: Add the two methods**

In `lib/data/history_database.dart`, add after `acknowledgeNewDevices` (right before the `/// Deletes the oldest scans...` comment for `_pruneTo`):

```dart
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
      b.insertAll(
        deepScanPorts,
        [
          for (final port in ports)
            DeepScanPortsCompanion.insert(
              deviceIdentity: deviceIdentity,
              networkId: networkId,
              port: port,
              discoveredAt: now,
            ),
        ],
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// Every port ever recorded via a deep scan, across every device —
  /// deduplicated and sorted. Merged into the regular scan's port list (see
  /// `ScanController._buildOrchestrator`) so previously-found ports keep
  /// showing as open without re-running a full deep scan.
  Future<List<int>> allExtraPorts() async {
    final query = selectOnly(deepScanPorts, distinct: true)
      ..addColumns([deepScanPorts.port]);
    final rows = await query.get();
    return [for (final row in rows) row.read(deepScanPorts.port)!]..sort();
  }
```

- [ ] **Step 6: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes with `DeepScanPortsCompanion` and the `deepScanPorts` table accessor generated into `lib/data/history_database.g.dart`.

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/data/history_database_test.dart`
Expected: PASS (all tests in the file, including every pre-existing one).

- [ ] **Step 8: Run the analyzer and format**

Run: `dart format lib/data/history_database.dart test/data/history_database_test.dart && flutter analyze`
Expected: no issues.

- [ ] **Step 9: Commit**

```bash
git add lib/data/history_database.dart lib/data/history_database.g.dart test/data/history_database_test.dart
git commit -m "Add DeepScanPorts table for deep-scan port persistence"
```

---

### Task 3: `mergedScanPorts` — pure port-list union

**Files:**
- Modify: `lib/scan/well_known_ports.dart`
- Test: `test/scan/well_known_ports_test.dart` (new file)

**Interfaces:**
- Consumes: `kDefaultScanPorts` (existing getter in the same file).
- Produces: `mergedScanPorts(List<int> extraPorts) → List<int>` — sorted, deduplicated union of `kDefaultScanPorts` and `extraPorts`. This is the one piece of Task 5's `_buildOrchestrator` change that's independently pure-testable (`ScanController`'s async orchestration has no existing direct unit-test harness in this codebase — see Task 5's note).

- [ ] **Step 1: Write the failing test**

Create `test/scan/well_known_ports_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/scan/well_known_ports.dart';

void main() {
  group('mergedScanPorts', () {
    test('with no extra ports, returns exactly the default list', () {
      expect(mergedScanPorts(const []), kDefaultScanPorts);
    });

    test('adds extra ports not already in the default list', () {
      final merged = mergedScanPorts([9999]);

      expect(merged, contains(9999));
      expect(merged.length, kDefaultScanPorts.length + 1);
    });

    test('does not duplicate an extra port already in the default list', () {
      final merged = mergedScanPorts([22]); // 22 (SSH) is already default

      expect(merged.length, kDefaultScanPorts.length);
    });

    test('result is sorted ascending', () {
      final merged = mergedScanPorts([3, 65535]);

      expect(merged, orderedEquals(merged.toList()..sort()));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/scan/well_known_ports_test.dart`
Expected: FAIL — `The function 'mergedScanPorts' isn't defined`.

- [ ] **Step 3: Write minimal implementation**

In `lib/scan/well_known_ports.dart`, add at the end of the file:

```dart

/// The regular scan's default ports plus every [extraPorts] entry, sorted
/// and deduplicated — used to fold in ports found via a deep scan (see
/// `HistoryDatabase.allExtraPorts`) so they keep showing as open on every
/// future regular scan.
List<int> mergedScanPorts(List<int> extraPorts) =>
    (<int>{...kDefaultScanPorts, ...extraPorts}.toList()..sort());
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/scan/well_known_ports_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/scan/well_known_ports.dart test/scan/well_known_ports_test.dart
git commit -m "Add mergedScanPorts for folding deep-scan ports into regular scans"
```

---

### Task 4: `DeepPortScanner` engine

**Files:**
- Create: `lib/scan/deep_port_scanner.dart`
- Test: `test/scan/deep_port_scanner_test.dart` (new file)

**Interfaces:**
- Consumes: `TcpHostScanner` (Task 1's `onProbeComplete`), `HostProgress` typedef (both from `lib/scan/tcp_host_scanner.dart`).
- Produces: `kAllTcpPorts` (`List<int>`, ports 1–65535); `DeepPortScanner` class with `DeepPortScanner({TcpHostScanner? scanner})` and `Future<List<int>> scan(InternetAddress host, {HostProgress? onProgress, bool Function()? isCancelled})` — returns the sorted open ports found (empty if none, or if cancelled).

- [ ] **Step 1: Write the failing tests**

Create `test/scan/deep_port_scanner_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/scan/deep_port_scanner.dart';
import 'package:sextant/scan/tcp_host_scanner.dart';

void main() {
  group('kAllTcpPorts', () {
    test('covers every TCP port, 1 through 65535', () {
      expect(kAllTcpPorts, hasLength(65535));
      expect(kAllTcpPorts.first, 1);
      expect(kAllTcpPorts.last, 65535);
    });
  });

  group('DeepPortScanner', () {
    test('finds an actually-open loopback port among the full range', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close());

      final scanner = DeepPortScanner(
        scanner: TcpHostScanner(
          concurrency: 128,
          timeout: const Duration(milliseconds: 200),
        ),
      );
      final found = await scanner.scan(InternetAddress.loopbackIPv4);

      expect(found, contains(server.port));
    });

    test('reports progress via onProgress as probes complete', () async {
      final scanner = DeepPortScanner(
        scanner: TcpHostScanner(
          probe: (host, port) async => false,
          concurrency: 64,
        ),
      );
      var lastDone = 0;
      int? lastTotal;

      await scanner.scan(
        InternetAddress.loopbackIPv4,
        onProgress: (done, total) {
          lastDone = done;
          lastTotal = total;
        },
      );

      expect(lastTotal, 65535);
      expect(lastDone, 65535);
    });

    test('returns an empty list for a cancelled scan', () async {
      final scanner = DeepPortScanner(
        scanner: TcpHostScanner(
          probe: (host, port) async => true, // would otherwise find lots
          concurrency: 4,
        ),
      );

      final found = await scanner.scan(
        InternetAddress.loopbackIPv4,
        isCancelled: () => true,
      );

      expect(found, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/scan/deep_port_scanner_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:sextant/scan/deep_port_scanner.dart'`.

- [ ] **Step 3: Write minimal implementation**

Create `lib/scan/deep_port_scanner.dart`:

```dart
import 'dart:io';

import 'tcp_host_scanner.dart';

/// Every TCP port, 1–65,535 inclusive.
final List<int> kAllTcpPorts = List.generate(65535, (i) => i + 1);

/// Scans every TCP port on a single host, tuned to be gentler than the
/// regular subnet sweep (lower concurrency, shorter timeout) since this runs
/// against one device rather than spreading load across many.
///
/// Unlike [TcpHostScanner] on its own — built for many-hosts/few-ports,
/// reporting progress once a whole host finishes — this reports progress
/// after every individual port probe via [onProgress], since there's only
/// one host and 65,535 ports: host-level progress would jump straight from
/// 0% to 100%.
class DeepPortScanner {
  DeepPortScanner({TcpHostScanner? scanner})
    : _scanner =
          scanner ??
          TcpHostScanner(
            concurrency: 64,
            timeout: const Duration(milliseconds: 400),
          );

  final TcpHostScanner _scanner;

  /// Scans every port in [kAllTcpPorts] on [host]. Returns the sorted list
  /// of open ports found — empty if none are open, or if [isCancelled]
  /// became true before the scan finished (a cancelled scan reports nothing,
  /// even if some ports were found open before cancellation).
  Future<List<int>> scan(
    InternetAddress host, {
    HostProgress? onProgress,
    bool Function()? isCancelled,
  }) async {
    final results = await _scanner
        .scan(
          [host],
          kAllTcpPorts,
          onProbeComplete: onProgress,
          isCancelled: isCancelled,
        )
        .toList();
    return results.isEmpty ? const [] : results.single.openPorts;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/scan/deep_port_scanner_test.dart`
Expected: PASS. (The full-range progress test scans 65,535 fake probes at concurrency 64 with an instant fake `probe` — this completes in well under a second; no real network I/O is involved in that test.)

- [ ] **Step 5: Run the analyzer and format**

Run: `dart format lib/scan/deep_port_scanner.dart test/scan/deep_port_scanner_test.dart && flutter analyze`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/scan/deep_port_scanner.dart test/scan/deep_port_scanner_test.dart
git commit -m "Add DeepPortScanner: single-host, all-port scan engine"
```

---

### Task 5: `ScanController` integration — mutual exclusion, `startDeepPortScan`, merged ports

**Files:**
- Modify: `lib/state/scan_state.dart`
- Modify: `lib/state/providers.dart`

**Interfaces:**
- Consumes: `DeepPortScanner` (Task 4), `mergedScanPorts` (Task 3), `HistoryDatabase.recordDeepScanPorts`/`allExtraPorts` (Task 2).
- Produces: `ScanState.isDeepScanning` (`bool`), `ScanState.deepScanDeviceIdentity`/`deepScanIp` (`String?`), `ScanState.deepScanCompleted`/`deepScanTotal` (`int`); `ScanController.startDeepPortScan(Device device, ScanNetwork network) → Future<List<int>?>` (null if cancelled or blocked by mutual exclusion); `ScanController.cancelDeepPortScan() → void`.

**Testing note:** this codebase has no existing direct unit-test harness for `ScanController`'s async orchestration (`startScan`/`_monitorTick`/`_reconcile` have none either — see `lib/state/providers.dart`) since it requires real network I/O via `ScanOrchestrator`. This task's guard logic is simple, low-risk conditionals; the observable behavior it produces (buttons disabled, row progress, menu state) is covered by Task 6/7's widget tests using the existing `_FixedScanController` test-double pattern already established in `test/ui/scan_screen_test.dart`.

- [ ] **Step 1: Add `ScanState` fields**

In `lib/state/scan_state.dart`, change the constructor:

```dart
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
    this.justDiscoveredIdentities = const {},
    this.isDeepScanning = false,
    this.deepScanDeviceIdentity,
    this.deepScanIp,
    this.deepScanCompleted = 0,
    this.deepScanTotal = 0,
  });
```

Add fields after `justDiscoveredIdentities`'s field declaration:

```dart
  /// True while a deep (all-65,535-port) scan of a single device is in
  /// flight. Mutually exclusive with [isScanning]/[isBackgroundScanning] —
  /// see `ScanController.startDeepPortScan`.
  final bool isDeepScanning;

  /// Identity/IP of the device being deep-scanned, if [isDeepScanning].
  /// Stale (last-scanned device) once [isDeepScanning] is false — harmless,
  /// since callers should gate on [isDeepScanning] first.
  final String? deepScanDeviceIdentity;
  final String? deepScanIp;

  /// Probe progress for the in-flight deep scan (0 / 0 when none has run).
  final int deepScanCompleted;
  final int deepScanTotal;
```

Update `copyWith`:

```dart
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
    Set<String>? justDiscoveredIdentities,
    bool? isDeepScanning,
    String? deepScanDeviceIdentity,
    String? deepScanIp,
    int? deepScanCompleted,
    int? deepScanTotal,
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
      justDiscoveredIdentities:
          justDiscoveredIdentities ?? this.justDiscoveredIdentities,
      isDeepScanning: isDeepScanning ?? this.isDeepScanning,
      deepScanDeviceIdentity:
          deepScanDeviceIdentity ?? this.deepScanDeviceIdentity,
      deepScanIp: deepScanIp ?? this.deepScanIp,
      deepScanCompleted: deepScanCompleted ?? this.deepScanCompleted,
      deepScanTotal: deepScanTotal ?? this.deepScanTotal,
    );
  }
```

- [ ] **Step 2: Add mutual-exclusion guards to `startScan` and `_monitorTick`**

In `lib/state/providers.dart`, change:

```dart
  Future<void> startScan(ScanNetwork network) async {
    if (state.isScanning) return;
```

to:

```dart
  Future<void> startScan(ScanNetwork network) async {
    if (state.isScanning || state.isDeepScanning) return;
```

Change:

```dart
  Future<void> _monitorTick() async {
    if (!_monitoring || _monitorNetwork == null) return;
    final found = await _backgroundScan(_monitorNetwork!);
```

to:

```dart
  Future<void> _monitorTick() async {
    if (!_monitoring || _monitorNetwork == null) return;
    if (state.isDeepScanning) {
      // Defer this tick rather than race the deep scan for _byIp — retry on
      // the next scheduled tick once it's finished.
      _scheduleNextTick();
      return;
    }
    final found = await _backgroundScan(_monitorNetwork!);
```

- [ ] **Step 3: Merge extra ports into the orchestrator's port list**

In `lib/state/providers.dart`, change:

```dart
  /// Builds a [ScanOrchestrator] with each scan phase enabled per the user's
  /// current settings, falling back to all-enabled (prior behavior) until
  /// settings have loaded.
  ScanOrchestrator _buildOrchestrator() {
    final enabled =
        ref.read(settingsProvider).value?.enabledProtocols ??
        ScanProtocol.values.toSet();
    return ScanOrchestrator(
      icmpEnabled: enabled.contains(ScanProtocol.icmp),
      arpEnabled: enabled.contains(ScanProtocol.arp),
      tcpEnabled: enabled.contains(ScanProtocol.tcp),
      mdnsEnabled: enabled.contains(ScanProtocol.mdns),
      netbiosEnabled: enabled.contains(ScanProtocol.netbios),
      ssdpEnabled: enabled.contains(ScanProtocol.ssdp),
    );
  }
```

to:

```dart
  /// Builds a [ScanOrchestrator] with each scan phase enabled per the user's
  /// current settings, falling back to all-enabled (prior behavior) until
  /// settings have loaded. The TCP phase's port list is the default list
  /// plus every port ever found via a deep scan on any device (see
  /// [mergedScanPorts]), so those keep showing as open on every future scan.
  Future<ScanOrchestrator> _buildOrchestrator() async {
    final enabled =
        ref.read(settingsProvider).value?.enabledProtocols ??
        ScanProtocol.values.toSet();
    final extraPorts = await ref.read(historyDatabaseProvider).allExtraPorts();
    return ScanOrchestrator(
      icmpEnabled: enabled.contains(ScanProtocol.icmp),
      arpEnabled: enabled.contains(ScanProtocol.arp),
      tcpEnabled: enabled.contains(ScanProtocol.tcp),
      mdnsEnabled: enabled.contains(ScanProtocol.mdns),
      netbiosEnabled: enabled.contains(ScanProtocol.netbios),
      ssdpEnabled: enabled.contains(ScanProtocol.ssdp),
      ports: mergedScanPorts(extraPorts),
    );
  }
```

Update both call sites to await it — in `startScan`, change:

```dart
    final orchestrator = _buildOrchestrator();
```

to:

```dart
    final orchestrator = await _buildOrchestrator();
```

and in `_backgroundScan`, change:

```dart
    final orchestrator = _buildOrchestrator();
```

to:

```dart
    final orchestrator = await _buildOrchestrator();
```

Add the import at the top of `lib/state/providers.dart` (alongside the other `scan/` import):

```dart
import '../scan/deep_port_scanner.dart';
import '../scan/well_known_ports.dart';
```

(`../scan/scan_orchestrator.dart` is already imported.)

- [ ] **Step 4: Add `startDeepPortScan`/`cancelDeepPortScan`**

In `lib/state/providers.dart`, add a new field near the other cancellation-related fields (after `bool _scanWasStopped = false;`):

```dart
  // Deep (all-port) single-device scan cancellation.
  bool _deepScanCancelled = false;
```

Add the two methods after `stopScan()`:

```dart
  /// Scans every TCP port (1–65,535) on [device]'s current IP. Returns the
  /// sorted list of open ports found (already merged into the live device
  /// and persisted), or null if the scan was cancelled, or if it couldn't
  /// start because a regular scan, a monitoring tick, or another deep scan
  /// is already running — only one of those three may run at a time, since
  /// all three mutate the live device list.
  Future<List<int>?> startDeepPortScan(
    Device device,
    ScanNetwork network,
  ) async {
    if (state.isScanning || state.isBackgroundScanning || state.isDeepScanning) {
      return null;
    }
    final identity = _identityOf(device);
    _deepScanCancelled = false;
    state = state.copyWith(
      isDeepScanning: true,
      deepScanDeviceIdentity: identity,
      deepScanIp: device.ip,
      deepScanCompleted: 0,
      deepScanTotal: kAllTcpPorts.length,
    );

    final found = await DeepPortScanner().scan(
      InternetAddress(device.ip),
      onProgress: (done, total) {
        state = state.copyWith(deepScanCompleted: done, deepScanTotal: total);
      },
      isCancelled: () => _deepScanCancelled,
    );
    final cancelled = _deepScanCancelled;
    state = state.copyWith(isDeepScanning: false);
    if (cancelled) return null;

    if (found.isNotEmpty) {
      final db = ref.read(historyDatabaseProvider);
      await db.recordDeepScanPorts(identity, network.id, found);

      final current = _byIp[device.ip];
      if (current != null) {
        _byIp[device.ip] = current.copyWith(
          openPorts: (<int>{...current.openPorts, ...found}.toList()..sort()),
        );
        _emit();
        await _saveHistory(network, _byIp.values.toList());
      }
    }
    return found;
  }

  /// Cancels the in-flight deep port scan, if any. Nothing is persisted and
  /// [startDeepPortScan] returns null for a cancelled scan.
  void cancelDeepPortScan() {
    _deepScanCancelled = true;
  }
```

Add `import 'dart:io';` if not already present — check the top of `lib/state/providers.dart`: it already has `import 'dart:io';` (used for `File`), so no change needed there.

- [ ] **Step 5: Run the analyzer**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 6: Run the full test suite to confirm no regressions**

Run: `flutter test`
Expected: every existing test still passes — `_buildOrchestrator` becoming `async` only affects its two internal call sites, both already inside `async` functions.

- [ ] **Step 7: Commit**

```bash
git add lib/state/scan_state.dart lib/state/providers.dart
git commit -m "Add ScanController.startDeepPortScan with mutual exclusion"
```

---

### Task 6: UI — context menu item and confirm dialog

**Files:**
- Modify: `lib/ui/scan_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`, `lib/l10n/app_es.arb`, `lib/l10n/app_fr.arb`, `lib/l10n/app_ru.arb`
- Generated: `lib/l10n/gen/*.dart` (via `flutter gen-l10n`)
- Test: `test/ui/scan_screen_test.dart`

**Interfaces:**
- Consumes: `ScanController.startDeepPortScan` (Task 5), `effectiveNetwork` (existing, `lib/state/network_selection.dart`).
- Produces: a new "Scan all ports (65,535)…" item in `DeviceRow`'s context menu, and `DeviceRow._confirmAndStartDeepScan` (private) wiring it to a confirm dialog.

- [ ] **Step 1: Add l10n keys**

In `lib/l10n/app_en.arb`, add after `"scanHistoryTooltip": "Scan history",` (keep the existing `newDevicesTooltip` etc. that already follow it — insert these new keys right after `noNewDevicesYet`):

```json
  "deepScanMenuItem": "Scan all ports (65,535)…",
  "deepScanConfirmTitle": "Scan all 65,535 ports on {ip}?",
  "@deepScanConfirmTitle": {
    "placeholders": { "ip": { "type": "String" } }
  },
  "deepScanConfirmBody": "This can take several minutes and generates significant network traffic to the device.",
  "deepScanConfirmButton": "Scan",
  "deepScanBusyTooltip": "Wait for the current scan to finish first",
  "deepScanOfflineTooltip": "Device is offline",
```

In `lib/l10n/app_de.arb`, add in the same relative position:

```json
  "deepScanMenuItem": "Alle Ports scannen (65.535)…",
  "deepScanConfirmTitle": "Alle 65.535 Ports auf {ip} scannen?",
  "@deepScanConfirmTitle": {
    "placeholders": { "ip": { "type": "String" } }
  },
  "deepScanConfirmBody": "Dies kann mehrere Minuten dauern und erzeugt erheblichen Netzwerkverkehr zum Gerät.",
  "deepScanConfirmButton": "Scannen",
  "deepScanBusyTooltip": "Bitte warten, bis der aktuelle Scan abgeschlossen ist",
  "deepScanOfflineTooltip": "Gerät ist offline",
```

In `lib/l10n/app_es.arb`:

```json
  "deepScanMenuItem": "Escanear todos los puertos (65.535)…",
  "deepScanConfirmTitle": "¿Escanear los 65.535 puertos de {ip}?",
  "@deepScanConfirmTitle": {
    "placeholders": { "ip": { "type": "String" } }
  },
  "deepScanConfirmBody": "Esto puede tardar varios minutos y genera tráfico de red significativo hacia el dispositivo.",
  "deepScanConfirmButton": "Escanear",
  "deepScanBusyTooltip": "Espera a que termine el análisis actual",
  "deepScanOfflineTooltip": "El dispositivo está fuera de línea",
```

In `lib/l10n/app_fr.arb`:

```json
  "deepScanMenuItem": "Analyser tous les ports (65 535)…",
  "deepScanConfirmTitle": "Analyser les 65 535 ports de {ip} ?",
  "@deepScanConfirmTitle": {
    "placeholders": { "ip": { "type": "String" } }
  },
  "deepScanConfirmBody": "Cela peut prendre plusieurs minutes et génère un trafic réseau important vers l'appareil.",
  "deepScanConfirmButton": "Analyser",
  "deepScanBusyTooltip": "Attendez la fin de l'analyse en cours",
  "deepScanOfflineTooltip": "L'appareil est hors ligne",
```

In `lib/l10n/app_ru.arb`:

```json
  "deepScanMenuItem": "Сканировать все порты (65535)…",
  "deepScanConfirmTitle": "Сканировать все 65535 портов {ip}?",
  "@deepScanConfirmTitle": {
    "placeholders": { "ip": { "type": "String" } }
  },
  "deepScanConfirmBody": "Это может занять несколько минут и создать значительную сетевую нагрузку на устройство.",
  "deepScanConfirmButton": "Сканировать",
  "deepScanBusyTooltip": "Дождитесь завершения текущего сканирования",
  "deepScanOfflineTooltip": "Устройство не в сети",
```

Run: `flutter gen-l10n`
Expected: regenerates `lib/l10n/gen/*.dart` with the new getters, no warnings for `app_en.arb` (the template file).

- [ ] **Step 2: Write the failing widget tests**

Add to `test/ui/scan_screen_test.dart`. First, add a spy controller near the top of the file, after `_FixedScanController`:

```dart
class _SpyScanController extends _FixedScanController {
  _SpyScanController(super.state);
  Device? startedDevice;
  ScanNetwork? startedNetwork;

  @override
  Future<List<int>?> startDeepPortScan(
    Device device,
    ScanNetwork network,
  ) async {
    startedDevice = device;
    startedNetwork = network;
    return null;
  }
}
```

Then add a new test group at the end of `main()`, before the final closing `}`:

```dart
  group('the "scan all ports" context menu item', () {
    testWidgets('appears when long-pressing a device row', (tester) async {
      final device = _dev('10.0.0.7', mac: 'cc:cc:cc:cc:cc:cc');
      await _pump(tester, [device]);

      await tester.longPress(find.byType(DeviceRow));
      await tester.pumpAndSettle();

      expect(find.text('Scan all ports (65,535)…'), findsOneWidget);
    });

    testWidgets('tapping it while a regular scan is running does not open '
        'the confirm dialog', (tester) async {
      final device = _dev('10.0.0.7', mac: 'cc:cc:cc:cc:cc:cc');
      await _pump(
        tester,
        [device],
        state: ScanState(devices: [device], isScanning: true),
      );

      await tester.longPress(find.byType(DeviceRow));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan all ports (65,535)…'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Scan all 65,535 ports on'), findsNothing);
    });

    testWidgets('confirming the dialog starts a deep scan on the right '
        'device and network', (tester) async {
      final device = _dev('10.0.0.7', mac: 'cc:cc:cc:cc:cc:cc');
      final network = _network();
      await tester.binding.setSurfaceSize(const Size(1400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          scanControllerProvider.overrideWith(
            () => _SpyScanController(ScanState(devices: [device])),
          ),
          networksProvider.overrideWith((ref) async => [network]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: kSupportedLocales,
            home: const ScanScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.longPress(find.byType(DeviceRow));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan all ports (65,535)…'));
      await tester.pumpAndSettle();

      expect(find.text('Scan all 65,535 ports on 10.0.0.7?'), findsOneWidget);

      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();

      final spy =
          container.read(scanControllerProvider.notifier) as _SpyScanController;
      expect(spy.startedDevice?.ip, '10.0.0.7');
      expect(spy.startedNetwork, same(network));
    });

    testWidgets('cancelling the confirm dialog does not start a scan', (
      tester,
    ) async {
      final device = _dev('10.0.0.7', mac: 'cc:cc:cc:cc:cc:cc');
      final network = _network();
      await tester.binding.setSurfaceSize(const Size(1400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          scanControllerProvider.overrideWith(
            () => _SpyScanController(ScanState(devices: [device])),
          ),
          networksProvider.overrideWith((ref) async => [network]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: kSupportedLocales,
            home: const ScanScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.longPress(find.byType(DeviceRow));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan all ports (65,535)…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final spy =
          container.read(scanControllerProvider.notifier) as _SpyScanController;
      expect(spy.startedDevice, isNull);
    });
  });
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/ui/scan_screen_test.dart`
Expected: FAIL — no "Scan all ports (65,535)…" text found (menu item doesn't exist yet), and `startDeepPortScan` isn't overridable yet on `_FixedScanController`'s parent chain in a way the spy can use (it will fail to compile until Task 5 is in place — Task 5 must be completed before this task; if run standalone it fails with "The method 'startDeepPortScan' isn't defined").

- [ ] **Step 4: Add the menu item and confirm dialog**

In `lib/ui/scan_screen.dart`, inside `DeviceRow._showMenu`, add the new menu item. Change:

```dart
        if (device.mac != null)
          PopupMenuItem(
            value: 'wake',
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.flash_on_outlined),
              title: Text(l10n.wakeOnLan),
            ),
          ),
      ],
    );
```

to:

```dart
        if (device.mac != null)
          PopupMenuItem(
            value: 'wake',
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.flash_on_outlined),
              title: Text(l10n.wakeOnLan),
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: deepScanDisabledReason == null ? 'deep_scan' : null,
          enabled: deepScanDisabledReason == null,
          child: deepScanTile,
        ),
      ],
    );
```

Immediately before the `final selected = await showMenu<String>(` line in the same method, add:

```dart
    final scan = ref.read(scanControllerProvider);
    final deepScanBusy =
        scan.isScanning || scan.isBackgroundScanning || scan.isDeepScanning;
    final deepScanDisabledReason = !device.isOnline
        ? l10n.deepScanOfflineTooltip
        : deepScanBusy
        ? l10n.deepScanBusyTooltip
        : null;
    Widget deepScanTile = ListTile(
      dense: true,
      leading: const Icon(Icons.travel_explore),
      title: Text(l10n.deepScanMenuItem),
    );
    if (deepScanDisabledReason != null) {
      deepScanTile = Tooltip(message: deepScanDisabledReason, child: deepScanTile);
    }
```

In the `switch (selected)` block, add a case:

```dart
      case 'wake':
        if (context.mounted) await _wakeOnLan(context);
      case 'deep_scan':
        if (context.mounted) await _confirmAndStartDeepScan(context, ref);
    }
```

Add a new private method to `DeviceRow`, after `_wakeOnLan`:

```dart
  Future<void> _confirmAndStartDeepScan(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deepScanConfirmTitle(device.ip)),
        content: Text(l10n.deepScanConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deepScanConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final networks = ref.read(networksProvider).value ?? const [];
    final selected = ref.read(selectedNetworkProvider);
    final network = effectiveNetwork(networks, selected);
    if (network == null) return;

    await ref
        .read(scanControllerProvider.notifier)
        .startDeepPortScan(device, network);
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/ui/scan_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Run the analyzer and format**

Run: `dart format lib/ui/scan_screen.dart test/ui/scan_screen_test.dart && flutter analyze`
Expected: no issues.

- [ ] **Step 7: Run the full test suite**

Run: `flutter test`
Expected: every test passes.

- [ ] **Step 8: Commit**

```bash
git add lib/ui/scan_screen.dart lib/l10n/*.arb lib/l10n/gen test/ui/scan_screen_test.dart
git commit -m "Add \"Scan all ports\" context menu item and confirm dialog"
```

---

### Task 7: UI — row progress ring, status bar line, cancel, completion snackbar

**Files:**
- Modify: `lib/ui/scan_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`, `lib/l10n/app_es.arb`, `lib/l10n/app_fr.arb`, `lib/l10n/app_ru.arb`
- Generated: `lib/l10n/gen/*.dart`
- Test: `test/ui/scan_screen_test.dart`

**Interfaces:**
- Consumes: `ScanState.isDeepScanning`/`deepScanDeviceIdentity`/`deepScanIp`/`deepScanCompleted`/`deepScanTotal` (Task 5), `ScanController.cancelDeepPortScan` (Task 5), `startDeepPortScan`'s `Future<List<int>?>` return value (Task 5, consumed at the Task 6 call site).

- [ ] **Step 1: Add l10n keys**

In `lib/l10n/app_en.arb`, add after the keys from Task 6:

```json
  "deepScanStatusLine": "Deep-scanning {ip} — {done} / {total}",
  "@deepScanStatusLine": {
    "placeholders": {
      "ip": { "type": "String" },
      "done": { "type": "int" },
      "total": { "type": "int" }
    }
  },
  "deepScanOpenPortCount": "{count, plural, one{# open port} other{# open ports}}",
  "@deepScanOpenPortCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "deepScanComplete": "Deep scan of {ip} complete: {countLabel} found ({ports})",
  "@deepScanComplete": {
    "placeholders": {
      "ip": { "type": "String" },
      "countLabel": { "type": "String" },
      "ports": { "type": "String" }
    }
  },
  "deepScanCompleteNone": "Deep scan of {ip} complete — no additional open ports found.",
  "@deepScanCompleteNone": {
    "placeholders": { "ip": { "type": "String" } }
  },
```

In `lib/l10n/app_de.arb`:

```json
  "deepScanStatusLine": "Tiefenscan von {ip} — {done} / {total}",
  "@deepScanStatusLine": {
    "placeholders": {
      "ip": { "type": "String" },
      "done": { "type": "int" },
      "total": { "type": "int" }
    }
  },
  "deepScanOpenPortCount": "{count, plural, one{# offener Port} other{# offene Ports}}",
  "@deepScanOpenPortCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "deepScanComplete": "Tiefenscan von {ip} abgeschlossen: {countLabel} gefunden ({ports})",
  "@deepScanComplete": {
    "placeholders": {
      "ip": { "type": "String" },
      "countLabel": { "type": "String" },
      "ports": { "type": "String" }
    }
  },
  "deepScanCompleteNone": "Tiefenscan von {ip} abgeschlossen — keine weiteren offenen Ports gefunden.",
  "@deepScanCompleteNone": {
    "placeholders": { "ip": { "type": "String" } }
  },
```

In `lib/l10n/app_es.arb`:

```json
  "deepScanStatusLine": "Análisis profundo de {ip} — {done} / {total}",
  "@deepScanStatusLine": {
    "placeholders": {
      "ip": { "type": "String" },
      "done": { "type": "int" },
      "total": { "type": "int" }
    }
  },
  "deepScanOpenPortCount": "{count, plural, one{# puerto abierto} other{# puertos abiertos}}",
  "@deepScanOpenPortCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "deepScanComplete": "Análisis profundo de {ip} completado: {countLabel} encontrado(s) ({ports})",
  "@deepScanComplete": {
    "placeholders": {
      "ip": { "type": "String" },
      "countLabel": { "type": "String" },
      "ports": { "type": "String" }
    }
  },
  "deepScanCompleteNone": "Análisis profundo de {ip} completado — no se encontraron puertos abiertos adicionales.",
  "@deepScanCompleteNone": {
    "placeholders": { "ip": { "type": "String" } }
  },
```

In `lib/l10n/app_fr.arb`:

```json
  "deepScanStatusLine": "Analyse approfondie de {ip} — {done} / {total}",
  "@deepScanStatusLine": {
    "placeholders": {
      "ip": { "type": "String" },
      "done": { "type": "int" },
      "total": { "type": "int" }
    }
  },
  "deepScanOpenPortCount": "{count, plural, one{# port ouvert} other{# ports ouverts}}",
  "@deepScanOpenPortCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "deepScanComplete": "Analyse approfondie de {ip} terminée : {countLabel} trouvé(s) ({ports})",
  "@deepScanComplete": {
    "placeholders": {
      "ip": { "type": "String" },
      "countLabel": { "type": "String" },
      "ports": { "type": "String" }
    }
  },
  "deepScanCompleteNone": "Analyse approfondie de {ip} terminée — aucun port ouvert supplémentaire trouvé.",
  "@deepScanCompleteNone": {
    "placeholders": { "ip": { "type": "String" } }
  },
```

In `lib/l10n/app_ru.arb`:

```json
  "deepScanStatusLine": "Глубокое сканирование {ip} — {done} / {total}",
  "@deepScanStatusLine": {
    "placeholders": {
      "ip": { "type": "String" },
      "done": { "type": "int" },
      "total": { "type": "int" }
    }
  },
  "deepScanOpenPortCount": "{count, plural, one{# открытый порт} few{# открытых порта} many{# открытых портов} other{# открытых порта}}",
  "@deepScanOpenPortCount": {
    "placeholders": { "count": { "type": "int" } }
  },
  "deepScanComplete": "Глубокое сканирование {ip} завершено: найдено {countLabel} ({ports})",
  "@deepScanComplete": {
    "placeholders": {
      "ip": { "type": "String" },
      "countLabel": { "type": "String" },
      "ports": { "type": "String" }
    }
  },
  "deepScanCompleteNone": "Глубокое сканирование {ip} завершено — дополнительные открытые порты не найдены.",
  "@deepScanCompleteNone": {
    "placeholders": { "ip": { "type": "String" } }
  },
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing widget tests**

Add to `test/ui/scan_screen_test.dart`, in a new group at the end of `main()`:

```dart
  group('deep scan progress display', () {
    testWidgets('the deep-scanned device\'s row shows a progress ring '
        'instead of its status dot', (tester) async {
      final device = _dev('10.0.0.8', mac: 'dd:dd:dd:dd:dd:dd');
      final identity = deviceIdentity(mac: device.mac);
      await _pump(
        tester,
        [],
        state: ScanState(
          devices: [device],
          isDeepScanning: true,
          deepScanDeviceIdentity: identity,
          deepScanIp: device.ip,
          deepScanCompleted: 100,
          deepScanTotal: 65535,
        ),
      );

      expect(
        find.descendant(
          of: find.byType(DeviceRow),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the status bar shows deep-scan progress and a cancel '
        'button while running', (tester) async {
      final device = _dev('10.0.0.8', mac: 'dd:dd:dd:dd:dd:dd');
      await _pump(
        tester,
        [],
        state: ScanState(
          devices: [device],
          isDeepScanning: true,
          deepScanDeviceIdentity: deviceIdentity(mac: device.mac),
          deepScanIp: '10.0.0.8',
          deepScanCompleted: 100,
          deepScanTotal: 65535,
        ),
      );

      expect(
        find.text('Deep-scanning 10.0.0.8 — 100 / 65535'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('the status bar shows no deep-scan line when not deep '
        'scanning', (tester) async {
      await _pump(tester, []);

      expect(find.textContaining('Deep-scanning'), findsNothing);
    });

    testWidgets('tapping Cancel in the status bar calls cancelDeepPortScan', (
      tester,
    ) async {
      final device = _dev('10.0.0.8', mac: 'dd:dd:dd:dd:dd:dd');
      await tester.binding.setSurfaceSize(const Size(1400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          scanControllerProvider.overrideWith(
            () => _SpyCancelScanController(
              ScanState(
                devices: [device],
                isDeepScanning: true,
                deepScanDeviceIdentity: deviceIdentity(mac: device.mac),
                deepScanIp: device.ip,
                deepScanCompleted: 10,
                deepScanTotal: 65535,
              ),
            ),
          ),
          networksProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: kSupportedLocales,
            home: const ScanScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Cancel'));

      final spy =
          container.read(scanControllerProvider.notifier)
              as _SpyCancelScanController;
      expect(spy.cancelled, isTrue);
    });
  });
```

Add the small spy class near `_SpyScanController` (from Task 6):

```dart
class _SpyCancelScanController extends _FixedScanController {
  _SpyCancelScanController(super.state);
  bool cancelled = false;

  @override
  void cancelDeepPortScan() {
    cancelled = true;
  }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/ui/scan_screen_test.dart`
Expected: FAIL — no progress ring/status text/Cancel button rendered yet for the deep-scan state.

- [ ] **Step 4: Add the row progress ring**

In `lib/ui/scan_screen.dart`, `_DeviceTable` needs to know the in-flight deep-scan identity and progress. Change its constructor and fields:

```dart
class _DeviceTable extends ConsumerWidget {
  const _DeviceTable({
    required this.devices,
    required this.isBusy,
    required this.newIdentities,
    required this.deepScanDeviceIdentity,
    required this.deepScanCompleted,
    required this.deepScanTotal,
  });

  final List<Device> devices;
  final bool isBusy;

  /// Identities highlighted as "just discovered" this scan — see
  /// [ScanState.justDiscoveredIdentities].
  final Set<String> newIdentities;

  /// Identity of the device currently being deep-scanned, if any — see
  /// [ScanState.deepScanDeviceIdentity].
  final String? deepScanDeviceIdentity;
  final int deepScanCompleted;
  final int deepScanTotal;
```

In the same class's `build`, change the `itemBuilder`:

```dart
            : ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, i) {
                  final device = devices[i];
                  final identity = deviceIdentity(
                    mac: device.mac,
                    hostname: device.hostname,
                    openPorts: device.openPorts,
                  );
                  final progress = identity == deepScanDeviceIdentity
                      ? (completed: deepScanCompleted, total: deepScanTotal)
                      : null;
                  return DeviceRow(
                    widths: widths,
                    device: device,
                    tinted: i.isOdd,
                    newIdentities: newIdentities,
                    deepScanProgress: progress,
                  );
                },
              );
```

In `ScanScreen.build`, update the `_DeviceTable` construction:

```dart
          Expanded(
            child: _DeviceTable(
              devices: scan.devices,
              isBusy: scan.isBusy,
              newIdentities: scan.justDiscoveredIdentities,
              deepScanDeviceIdentity: scan.isDeepScanning
                  ? scan.deepScanDeviceIdentity
                  : null,
              deepScanCompleted: scan.deepScanCompleted,
              deepScanTotal: scan.deepScanTotal,
            ),
          ),
```

In `DeviceRow`, add the new field:

```dart
class DeviceRow extends ConsumerWidget {
  const DeviceRow({
    super.key,
    required this.widths,
    required this.device,
    this.tinted = false,
    this.newIdentities = const {},
    this.deepScanProgress,
  });

  final EffectiveColumnWidths widths;
  final Device device;

  /// Whether this row gets the alternating (zebra) background tint.
  final bool tinted;

  /// Identities highlighted as "just discovered" this scan — see
  /// [ScanState.justDiscoveredIdentities]. Takes priority over [tinted]'s
  /// zebra striping when this row's device is in the set.
  final Set<String> newIdentities;

  /// Non-null while this exact device is being deep-scanned — replaces the
  /// status dot with a progress ring. See [ScanState.deepScanCompleted].
  final ({int completed, int total})? deepScanProgress;
```

In `DeviceRow.build`, change the leading icon `SizedBox`:

```dart
          SizedBox(
            width: _kIconWidth,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (deepScanProgress != null)
                  SizedBox(
                    width: 9,
                    height: 9,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      value: deepScanProgress!.total == 0
                          ? null
                          : deepScanProgress!.completed /
                                deepScanProgress!.total,
                    ),
                  )
                else
                  _StatusDot(
                    online: device.isOnline,
                    latencyMs: device.latencyMs,
                  ),
                const SizedBox(width: 6),
                Tooltip(
                  message: device.isOnline
                      ? deviceTypeLabel(l10n, device.deviceType)
                      : l10n.deviceTypeOfflineTooltip(
                          deviceTypeLabel(l10n, device.deviceType),
                        ),
                  child: Icon(
                    deviceIcon(device),
                    size: 20,
                    color: offline ? muted : null,
                  ),
                ),
              ],
            ),
          ),
```

- [ ] **Step 5: Add the status bar line, Cancel button, and completion snackbar**

In `lib/ui/scan_screen.dart`, change `_StatusBar.build`'s return statement:

```dart
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (scan.isMonitoring) ...[
            Icon(
              Icons.sensors,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
          ],
          Text(status, style: style),
        ],
      ),
    );
```

to:

```dart
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (scan.isMonitoring) ...[
                Icon(
                  Icons.sensors,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
              ],
              Text(status, style: style),
            ],
          ),
          if (scan.isDeepScanning) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: scan.deepScanTotal == 0
                        ? null
                        : scan.deepScanCompleted / scan.deepScanTotal,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.deepScanStatusLine(
                    scan.deepScanIp ?? '',
                    scan.deepScanCompleted,
                    scan.deepScanTotal,
                  ),
                  style: style,
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => ref
                      .read(scanControllerProvider.notifier)
                      .cancelDeepPortScan(),
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ],
        ],
      ),
    );
```

Now the completion snackbar, driven by `startDeepPortScan`'s return value at the Task 6 call site. In `DeviceRow._confirmAndStartDeepScan`, change:

```dart
    await ref
        .read(scanControllerProvider.notifier)
        .startDeepPortScan(device, network);
  }
```

to:

```dart
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final found = await ref
        .read(scanControllerProvider.notifier)
        .startDeepPortScan(device, network);

    if (found == null) return; // cancelled, or blocked — no summary
    if (found.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.deepScanCompleteNone(device.ip))),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.deepScanComplete(
            device.ip,
            l10n.deepScanOpenPortCount(found.length),
            found.join(', '),
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/ui/scan_screen_test.dart`
Expected: PASS.

- [ ] **Step 7: Run the analyzer and format**

Run: `dart format lib/ui/scan_screen.dart test/ui/scan_screen_test.dart && flutter analyze`
Expected: no issues.

- [ ] **Step 8: Run the full test suite**

Run: `flutter test`
Expected: every test passes.

- [ ] **Step 9: Manual verification**

Run the app (`flutter run -d macos` or your platform), scan a network, right-click a device, choose "Scan all ports (65,535)…", confirm, and verify: the row's status dot becomes a progress ring, the status bar shows the deep-scan line with a working Cancel button, the SCAN button and monitoring toggle are disabled while it runs, and a completion snackbar appears with the right port list (or "no additional open ports found"). Then re-scan the network and confirm the newly-found port(s) show up in the Open Ports column without another deep scan.

- [ ] **Step 10: Commit**

```bash
git add lib/ui/scan_screen.dart lib/l10n/*.arb lib/l10n/gen test/ui/scan_screen_test.dart
git commit -m "Add deep-scan row progress, status bar, cancel, and completion summary"
```

## Self-Review

**Spec coverage:**
- Data model (`DeepScanPorts`, identity-scoped) → Task 2. ✓
- Re-check semantics (network-wide port union) → Tasks 3 and 5 (Step 3). ✓
- Scan engine (`TcpHostScanner` reuse, tuned concurrency/timeout, per-probe progress) → Tasks 1 and 4. ✓
- State (`ScanState` fields, `startDeepPortScan`/`cancelDeepPortScan`) → Task 5. ✓
- Mutual exclusion (both directions, plus monitor-tick deferral) → Task 5, Steps 2 and 4. ✓
- UI: context menu + confirm dialog + offline/busy disabling → Task 6. ✓
- UI: row progress ring, status bar line, cancel, completion snackbar → Task 7. ✓
- Testing plan (engine unit tests, DB unit tests, widget tests for menu/progress/buttons) → Tasks 1, 2, 3, 4, 6, 7. ✓

**Placeholder scan:** no TBD/TODO; every step has runnable code.

**Type consistency:** `startDeepPortScan(Device, ScanNetwork) → Future<List<int>?>` is used identically in Task 5 (definition), Task 6 (spy override + call site), and Task 7 (consuming the return value) — checked. `cancelDeepPortScan()` matches across Task 5 (definition) and Task 7 (spy override + status bar call). `ScanState` field names (`isDeepScanning`, `deepScanDeviceIdentity`, `deepScanIp`, `deepScanCompleted`, `deepScanTotal`) are consistent across Tasks 5, 6, and 7.
