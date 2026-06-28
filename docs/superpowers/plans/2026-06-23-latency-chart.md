# Interactive Latency Chart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the per-device latency sparkline interactive: a hover tooltip shows latest/average latency, and tapping it opens a dialog with a full-size, axis-labeled latency chart over the device's full retained history.

**Architecture:** Add the `fl_chart` package (this project's first charting dependency) and a thin Riverpod provider that reads up to 200 retained samples (with real timestamps) via the already-existing `HistoryDatabase.latencyHistory(identity, limit:)`. Wrap the existing sparkline cell in `scan_screen.dart` with a `Tooltip` and a tap handler that opens a `Dialog` rendering an `fl_chart` `LineChart` plus a Latest/Avg/Min/Max stats row.

**Tech Stack:** Flutter, `flutter_riverpod` 3.3.2, `drift` 2.34.0, new dependency: `fl_chart`.

Full design rationale: `docs/superpowers/specs/2026-06-23-latency-chart-design.md`.

## Global Constraints

- No DB schema or migration changes — reuse `HistoryDatabase.latencyHistory(deviceIdentity, {limit})` (`lib/data/history_database.dart`) exactly as it exists today.
- Do not change `latencyHistoryProvider` (`lib/state/providers.dart:71-76`) or its 50-sample default — the sparkline's existing behavior must keep working unchanged.
- The full-size chart shows up to 200 samples — the existing `maxSamplesPerDevice` retention default already enforced by `recordLatencySamples`.
- The sparkline's hover tooltip shows latest + average latency computed from the same 50-sample window the sparkline already renders — no extra DB query for the tooltip.
- Chart engine is `fl_chart`'s `LineChart`, not a hand-rolled `CustomPainter` — a deliberate, user-confirmed deviation from this codebase's existing no-extra-deps-for-visuals convention (the sparkline and topology view are both hand-rolled).
- Add the dependency via `flutter pub add fl_chart` (resolves the actual latest compatible version against this project's `sdk: ^3.12.2` constraint) — do not hand-pin a guessed version number.
- Dialog surface is a `Dialog` (not `AlertDialog`) — needs more layout room than `AlertDialog`'s title/content/actions slots comfortably give an axis-labeled chart.

---

## File Structure

| File | Change | Task |
|---|---|---|
| `pubspec.yaml` | add `fl_chart` dependency | 1 |
| `lib/ui/latency_sparkline.dart` | add `latencyTooltipMessage(List<double>) -> String` | 2 |
| `test/ui/latency_sparkline_test.dart` | test the new function | 2 |
| `lib/state/providers.dart` | add `latencyChartDataProvider`; invalidate it alongside `latencyHistoryProvider` | 3 |
| `lib/ui/latency_chart_dialog.dart` | new: `showLatencyChartDialog` + dialog content widgets | 4 |
| `test/ui/latency_chart_dialog_test.dart` | new: widget test for the dialog | 4 |
| `lib/ui/scan_screen.dart` | wrap the sparkline cell with the tooltip + tap handler | 5 |

Dependency order: 1 → 2 → 3 → 4 → 5 (4 needs 1 and 3; 5 needs 2 and 4).

---

### Task 1: Add the fl_chart dependency

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Consumes: none.
- Produces: the `fl_chart` package, importable as `package:fl_chart/fl_chart.dart` from Task 4 onward.

- [ ] **Step 1: Add the dependency**

Run from the project root (`/Users/andvas/Projects/tinker/NetScan`):

```bash
flutter pub add fl_chart
```

Expected: prints a line like `+ fl_chart 0.x.y` and exits 0. `pubspec.yaml` gains an `fl_chart: ^0.x.y` line under `dependencies`; `pubspec.lock` is updated.

- [ ] **Step 2: Confirm no regressions from the dependency bump alone**

Run: `flutter test`
Expected: all existing tests still pass (same pass count as before this task — no source code changed yet, only dependency resolution).

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: add fl_chart for the full-size latency chart"
```

---

### Task 2: Sparkline tooltip text helper

**Files:**
- Modify: `lib/ui/latency_sparkline.dart`
- Test: `test/ui/latency_sparkline_test.dart`

**Interfaces:**
- Consumes: none (pure function over `List<double>`).
- Produces: `String latencyTooltipMessage(List<double> values)`. Precondition: callers must only call it with `values.length >= 2` (same minimum as `LatencySparkline`/`sparklinePoints`) — Task 5 enforces this at the call site.

- [ ] **Step 1: Write the failing tests**

In `test/ui/latency_sparkline_test.dart`, add this group after the existing `group('LatencySparkline', ...)` block, still inside `main()`:

```dart
  group('latencyTooltipMessage', () {
    test('formats the latest value and the average, rounded to whole ms', () {
      expect(latencyTooltipMessage([10, 20, 30]), 'Latest: 30 ms · Avg: 20 ms');
    });

    test('rounds to the nearest ms', () {
      expect(latencyTooltipMessage([11.6, 14.4]), 'Latest: 14 ms · Avg: 13 ms');
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/ui/latency_sparkline_test.dart`
Expected: FAIL — `Error: The function 'latencyTooltipMessage' isn't defined.`

- [ ] **Step 3: Implement**

In `lib/ui/latency_sparkline.dart`, add this function immediately after `sparklinePoints`'s closing `}` and before the `LatencySparkline` class's doc comment:

```dart
/// Formats the latest and average of [values] for a hover/long-press tooltip
/// on the sparkline. Callers must only call this with 2+ values (mirrors
/// [LatencySparkline]'s own minimum).
String latencyTooltipMessage(List<double> values) {
  final avg = values.reduce((a, b) => a + b) / values.length;
  return 'Latest: ${values.last.round()} ms · Avg: ${avg.round()} ms';
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/ui/latency_sparkline_test.dart`
Expected: PASS — all tests in the file, including the 2 new ones.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/latency_sparkline.dart test/ui/latency_sparkline_test.dart
git commit -m "feat: add latencyTooltipMessage for the sparkline hover tooltip"
```

---

### Task 3: Full-history provider

**Files:**
- Modify: `lib/state/providers.dart` (new provider after line 76; invalidate-call update at line 349)

**Interfaces:**
- Consumes: `historyDatabaseProvider` (existing), `HistoryDatabase.latencyHistory(String deviceIdentity, {int limit})` (existing, returns `Future<List<LatencySample>>`, already covered by `test/data/latency_database_test.dart`).
- Produces: `latencyChartDataProvider` — `FutureProvider.family<List<LatencySample>, String>`, keyed by device identity. Used by Task 4's dialog widget.

No new test in this task: this is wiring with no new pure logic (the underlying `db.latencyHistory` behavior is already fully tested), and it mirrors the existing `latencyHistoryProvider` immediately above it, which likewise has no dedicated test of its own — both are exercised indirectly by the widgets that watch them (Task 4's dialog test covers this one). Verification here is "nothing broke," via the full suite in Step 3.

- [ ] **Step 1: Add the new provider**

In `lib/state/providers.dart`, immediately after `latencyHistoryProvider`'s closing `});` (currently lines 71-76) and before the `/// The OUI → vendor lookup...` comment, insert:

```dart
/// The full retained latency history for one device (by stable identity),
/// used to draw the full-size latency chart. Unlike [latencyHistoryProvider]
/// (which trims to the sparkline's display window), this returns every
/// sample the database still retains for the device, with timestamps.
final latencyChartDataProvider =
    FutureProvider.family<List<LatencySample>, String>((ref, deviceIdentity) async {
  final db = ref.watch(historyDatabaseProvider);
  return db.latencyHistory(deviceIdentity, limit: 200);
});
```

(`LatencySample` is already in scope — `history_database.dart`, which defines it via its generated part file, is already imported in this file.)

- [ ] **Step 2: Invalidate it alongside the sparkline's provider**

In `_recordLatency` (around line 349), change:

```dart
    await ref.read(historyDatabaseProvider).recordLatencySamples(samples);
    ref.invalidate(latencyHistoryProvider);
  }
```

to:

```dart
    await ref.read(historyDatabaseProvider).recordLatencySamples(samples);
    ref.invalidate(latencyHistoryProvider);
    ref.invalidate(latencyChartDataProvider);
  }
```

- [ ] **Step 3: Confirm no regressions**

Run: `flutter test`
Expected: PASS, same count as the end of Task 2 (this task added no new tests).

- [ ] **Step 4: Commit**

```bash
git add lib/state/providers.dart
git commit -m "feat: add latencyChartDataProvider for the full-size latency chart"
```

---

### Task 4: Full-size chart dialog

**Files:**
- Create: `lib/ui/latency_chart_dialog.dart`
- Test: `test/ui/latency_chart_dialog_test.dart`

**Interfaces:**
- Consumes: `latencyChartDataProvider` (Task 3), `LatencySample` (`lib/data/history_database.dart`: fields `id` (`int`), `deviceIdentity` (`String`), `networkId` (`String`), `timestamp` (`DateTime`), `rttMs` (`double`); plain `const` constructor with all-named-required params, so test fixtures can construct it directly without a database).
- Produces: `void showLatencyChartDialog(BuildContext context, {required String deviceLabel, required String deviceIdentity})`. Used by Task 5.

- [ ] **Step 1: Verify the installed fl_chart API before writing real code**

Task 1 already ran `flutter pub add fl_chart`. Find where it resolved to:

```bash
grep '"fl_chart"' -A2 .dart_tool/package_config.json
```

This prints a `"rootUri"` pointing under `~/.pub-cache/hosted/pub.dev/fl_chart-<version>/`. Read `lib/src/chart/line_chart/line_chart_data.dart` and `lib/src/chart/base/axis_chart/axis_chart_data.dart` under that path and confirm `LineChartData`, `LineChartBarData`, `FlSpot`, `FlGridData`, `FlBorderData`, `FlTitlesData`, `AxisTitles`, `SideTitles` (with a `getTitlesWidget` field), `FlDotData`, and `LineTouchData` exist with these names. If any have been renamed in the resolved version, use the current names in Step 2 below — the structure (one `LineChartBarData` of timestamp-vs-rttMs spots, a visible left axis for ms and bottom axis for time, grid on, touch enabled) stays the same regardless of minor renames.

- [ ] **Step 2: Write the dialog**

Create `lib/ui/latency_chart_dialog.dart`:

```dart
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/history_database.dart';
import '../state/providers.dart';

/// Opens a dialog showing [deviceIdentity]'s full retained latency history as
/// an axis-labeled line chart, with a Latest/Avg/Min/Max summary above it.
void showLatencyChartDialog(
  BuildContext context, {
  required String deviceLabel,
  required String deviceIdentity,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _LatencyChartDialogContent(
          deviceLabel: deviceLabel,
          deviceIdentity: deviceIdentity,
        ),
      ),
    ),
  );
}

class _LatencyChartDialogContent extends ConsumerWidget {
  const _LatencyChartDialogContent({
    required this.deviceLabel,
    required this.deviceIdentity,
  });

  final String deviceLabel;
  final String deviceIdentity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final samplesAsync = ref.watch(latencyChartDataProvider(deviceIdentity));
    return SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  deviceLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          samplesAsync.when(
            data: (samples) => _LatencyChartBody(samples: samples),
            loading: () => const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => const SizedBox(
              height: 280,
              child: Center(child: Text('Could not load latency history.')),
            ),
          ),
        ],
      ),
    );
  }
}

class _LatencyChartBody extends StatelessWidget {
  const _LatencyChartBody({required this.samples});

  final List<LatencySample> samples;

  @override
  Widget build(BuildContext context) {
    if (samples.length < 2) {
      return const SizedBox(
        height: 280,
        child: Center(child: Text('Not enough latency data yet.')),
      );
    }

    final values = [for (final s in samples) s.rttMs];
    final latest = values.last;
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce(math.min);
    final max = values.reduce(math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(label: 'Latest', ms: latest),
              _Stat(label: 'Avg', ms: avg),
              _Stat(label: 'Min', ms: min),
              _Stat(label: 'Max', ms: max),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final time = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                      final hh = time.hour.toString().padLeft(2, '0');
                      final mm = time.minute.toString().padLeft(2, '0');
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '$hh:$mm',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) => Text(
                      value.round().toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
              lineTouchData: const LineTouchData(enabled: true),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (final s in samples)
                      FlSpot(s.timestamp.millisecondsSinceEpoch.toDouble(), s.rttMs),
                  ],
                  isCurved: false,
                  barWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.ms});

  final String label;
  final double ms;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text('${ms.round()} ms', style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}
```

- [ ] **Step 3: Write the widget test**

Create `test/ui/latency_chart_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/data/history_database.dart';
import 'package:sextant/state/providers.dart';
import 'package:sextant/ui/latency_chart_dialog.dart';

LatencySample _sample(DateTime t, double rttMs) => LatencySample(
      id: 0,
      deviceIdentity: 'mac:aa',
      networkId: 'wifi',
      timestamp: t,
      rttMs: rttMs,
    );

Future<void> _pumpAndOpen(WidgetTester tester, List<LatencySample> samples) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        latencyChartDataProvider.overrideWith((ref, identity) async => samples),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showLatencyChartDialog(
                context,
                deviceLabel: 'My Device',
                deviceIdentity: 'mac:aa',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a placeholder when fewer than 2 samples', (tester) async {
    await _pumpAndOpen(tester, [_sample(DateTime.utc(2026, 1, 1), 10)]);

    expect(find.text('Not enough latency data yet.'), findsOneWidget);
  });

  testWidgets('shows Latest/Avg/Min/Max computed from all retained samples', (tester) async {
    await _pumpAndOpen(tester, [
      _sample(DateTime.utc(2026, 1, 1, 0, 0), 10),
      _sample(DateTime.utc(2026, 1, 1, 0, 1), 40),
      _sample(DateTime.utc(2026, 1, 1, 0, 2), 20),
    ]);

    expect(find.text('My Device'), findsOneWidget);
    expect(find.text('20 ms'), findsOneWidget); // Latest (last sample)
    expect(find.text('23 ms'), findsOneWidget); // Avg: (10+40+20)/3 = 23.33 -> 23
    expect(find.text('10 ms'), findsOneWidget); // Min
    expect(find.text('40 ms'), findsOneWidget); // Max
  });
}
```

- [ ] **Step 4: Run the new tests**

Run: `flutter test test/ui/latency_chart_dialog_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Static analysis**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/ui/latency_chart_dialog.dart test/ui/latency_chart_dialog_test.dart
git commit -m "feat: add full-size latency chart dialog using fl_chart"
```

---

### Task 5: Wire the tooltip and tap handler into the device table

**Files:**
- Modify: `lib/ui/scan_screen.dart:20` (import), `lib/ui/scan_screen.dart:475-481` (sparkline cell)

**Interfaces:**
- Consumes: `latencyTooltipMessage` (Task 2), `showLatencyChartDialog` (Task 4).
- Produces: nothing new — terminal UI wiring.

- [ ] **Step 1: Add the import**

In `lib/ui/scan_screen.dart`, add `import 'latency_chart_dialog.dart';` alphabetically, between the existing `import 'history_screen.dart';` and `import 'latency_sparkline.dart';` lines (around line 19-20):

```dart
import 'history_screen.dart';
import 'latency_chart_dialog.dart';
import 'latency_sparkline.dart';
```

- [ ] **Step 2: Replace the sparkline cell**

In `lib/ui/scan_screen.dart`, change (around line 475-481):

```dart
          SizedBox(
            width: 56,
            child: ref.watch(latencyHistoryProvider(identity)).maybeWhen(
                  data: (values) => LatencySparkline(values: values),
                  orElse: () => const SizedBox.shrink(),
                ),
          ),
```

to:

```dart
          SizedBox(
            width: 56,
            child: ref.watch(latencyHistoryProvider(identity)).maybeWhen(
                  data: (values) {
                    if (values.length < 2) return const SizedBox.shrink();
                    return Tooltip(
                      message: latencyTooltipMessage(values),
                      child: InkWell(
                        onTap: () => showLatencyChartDialog(
                          context,
                          deviceLabel: device.displayName,
                          deviceIdentity: identity,
                        ),
                        child: LatencySparkline(values: values),
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
          ),
```

- [ ] **Step 3: Static analysis and full test suite**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: PASS, full suite (baseline + Task 2's 2 + Task 4's 2 new tests).

- [ ] **Step 4: Commit**

```bash
git add lib/ui/scan_screen.dart
git commit -m "feat: make the latency sparkline interactive (tooltip + tap-to-expand chart)"
```

---

## After All Tasks

Manual verification (this codebase's established convention for UI changes — see `docs/superpowers/specs/2026-06-23-latency-chart-design.md`'s Testing section): run the macOS app, scan a network, wait for at least 2 latency samples to accumulate for some device, hover its sparkline (tooltip should show "Latest: N ms · Avg: M ms"), tap it (dialog should open showing the stats row and an axis-labeled chart), close it. This step is done by the controller/user after subagent-driven-development completes all 5 tasks — not by a task subagent, which cannot drive a running GUI app.
