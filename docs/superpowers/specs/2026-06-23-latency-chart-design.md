# Latency Chart Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the per-device latency sparkline in the scan table interactive: hovering it shows latest/average latency, and tapping it opens a full-size, axis-labeled latency chart covering the device's full retained history.

**Architecture:** Add the `fl_chart` package (the project's first charting dependency, chosen over hand-rolling axes/gridlines in a `CustomPainter`). Add one new Riverpod provider that reads the device's full latency history (up to the DB's existing 200-sample-per-device retention cap) via the already-existing `HistoryDatabase.latencyHistory(identity, limit: ...)` method — no schema or migration changes. Wrap the existing `LatencySparkline` usage with a `Tooltip` (computed from data already loaded for the sparkline) and a tap handler that opens a `Dialog` containing a stats header and an `fl_chart` `LineChart`.

**Tech Stack:** Flutter, `flutter_riverpod` 3.3.2, `drift` 2.34.0 (existing `HistoryDatabase`/`LatencySample`), new dependency: `fl_chart`.

## Global Constraints

- No DB schema or migration changes — `LatencySamples` table and `LatencySample` rows (`deviceIdentity`, `networkId`, `timestamp`, `rttMs`) already carry everything needed.
- Reuse `HistoryDatabase.latencyHistory(deviceIdentity, {limit})` (`lib/data/history_database.dart`) as-is; it already returns rows oldest-first and accepts a `limit`.
- Do not change `latencyHistoryProvider` (`lib/state/providers.dart:71-76`) or its 50-sample default — the existing sparkline behavior and any tests covering it must keep working unchanged.
- Full-size chart shows up to 200 samples (the DB's existing per-device retention cap, set in `_pruneSamplesTo`/`recordLatencySamples`'s `maxSamplesPerDevice` default).
- Tooltip on the small sparkline shows latest + average latency, computed from the same 50-sample window the sparkline already renders (no extra query).
- Chart engine: `fl_chart` `LineChart`, not a hand-rolled `CustomPainter` — this is a deliberate deviation from the sparkline/topology view's no-extra-deps convention, confirmed with the user.
- Dialog surface: a `Dialog` (not `AlertDialog`) sized to comfortably fit an axis-labeled chart (enough room for a chart area plus a stats row and title).

## Components

### 1. Dependency

**Modify:** `pubspec.yaml` — run `flutter pub add fl_chart` from the project root. This resolves and pins the actual latest published version compatible with this project's SDK constraint (`^3.12.2`) rather than hand-typing a version number that may already be stale by implementation time.

### 2. Data layer

**Modify:** `lib/state/providers.dart`

Add, near the existing `latencyHistoryProvider` (around line 71-76):

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

`LatencySample` is the drift-generated row class (already imported transitively via `history_database.dart`'s `part 'history_database.g.dart';`); add an explicit import of `history_database.dart` to `providers.dart` if not already present (check current imports — `historyDatabaseProvider` already requires it, so it should already be imported).

Invalidate this provider alongside `latencyHistoryProvider` wherever new samples are recorded — `lib/state/providers.dart:349` (`ref.invalidate(latencyHistoryProvider);`) becomes two invalidate calls:

```dart
ref.invalidate(latencyHistoryProvider);
ref.invalidate(latencyChartDataProvider);
```

### 3. Full-size chart widget

**Create:** `lib/ui/latency_chart_dialog.dart`

- `void showLatencyChartDialog(BuildContext context, {required String deviceLabel, required String deviceIdentity})` — opens a `Dialog` via `showDialog`, content is a `_LatencyChartDialogContent` (a `ConsumerWidget` so it can `ref.watch(latencyChartDataProvider(deviceIdentity))` directly, with its own loading/empty states rather than requiring the caller to pre-fetch).
- `_LatencyChartDialogContent extends ConsumerWidget`:
  - Title: `deviceLabel`, with a close (`IconButton(Icons.close)`) in the top-right.
  - `ref.watch(latencyChartDataProvider(deviceIdentity)).when(data:, loading:, error:)`:
    - `loading`: centered `CircularProgressIndicator` inside a sized box (so the dialog doesn't jump size when data arrives).
    - `error`: a short error message (e.g. `Text('Could not load latency history.')`) — this is a local SQLite read, errors are not expected in normal operation, so no retry affordance is needed.
    - `data: (samples)`: if `samples.length < 2`, show `Text('Not enough latency data yet.')` (mirrors the sparkline's own <2-sample empty case). Otherwise render the stats row + chart (below).
  - Stats row: a `Row` of four labeled values — Latest (`samples.last.rttMs`), Avg (`mean of samples.map((s) => s.rttMs)`), Min, Max — each as a small `Column` with a muted label `Text` above a value `Text`, formatted as `'${ms.round()} ms'`.
  - Chart: `SizedBox(width: 480, height: 280, child: LineChart(...))` using `fl_chart`:
    - `LineChartData.lineBarsData`: one `LineChartBarData` with `spots: [for (final s in samples) FlSpot(s.timestamp.millisecondsSinceEpoch.toDouble(), s.rttMs)]`, `isCurved: false`, `dotData: const FlDotData(show: false)` (keep the line clean; rely on touch for point detail), `color: Theme.of(context).colorScheme.primary`.
    - `LineChartData.titlesData`: bottom (`AxisTitles` with `SideTitles(showTitles: true, getTitlesWidget: ...)` mapping the epoch-millis value back to a `DateTime` and formatting as `'HH:mm'` using `DateTime.fromMillisecondsSinceEpoch(value.toInt())` and manual zero-padding — no `intl` dependency needed); left (`ms` values, integer labels); top/right titles disabled (`AxisTitles(sideTitles: SideTitles(showTitles: false))`).
    - `LineChartData.gridData`: `FlGridData(show: true)` with both horizontal and vertical lines, default styling.
    - `LineChartData.lineTouchData`: `LineTouchData(enabled: true)` (default tooltip behavior — shows the exact `rttMs` on touch/hover; this satisfies "real axis" with point-level detail without custom tooltip-building code).
    - `LineChartData.minY`/`maxY`: leave unset (let `fl_chart` auto-scale to the data) — avoids hand-tuned padding logic that duplicates what the library already does well.

### 4. Sparkline tooltip + tap wiring

**Modify:** `lib/ui/scan_screen.dart:475-481` (the existing `SizedBox(width: 56, child: ref.watch(latencyHistoryProvider(identity))...)` block).

Current code:

```dart
SizedBox(
  width: 56,
  child: ref.watch(latencyHistoryProvider(identity)).maybeWhen(
        data: (values) => LatencySparkline(values: values),
        orElse: () => const SizedBox.shrink(),
      ),
),
```

New code:

```dart
SizedBox(
  width: 56,
  child: ref.watch(latencyHistoryProvider(identity)).maybeWhen(
        data: (values) {
          if (values.length < 2) return const SizedBox.shrink();
          final avg = values.reduce((a, b) => a + b) / values.length;
          return Tooltip(
            message:
                'Latest: ${values.last.round()} ms · Avg: ${avg.round()} ms',
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

Add `import 'latency_chart_dialog.dart';` to `scan_screen.dart`'s imports.

Note: `LatencySparkline` itself already returns `SizedBox.shrink()` internally for `values.length < 2`, but the explicit check above is needed here too so the `Tooltip`/`InkWell` wrapper isn't rendered as an empty interactive region when there's nothing to show.

## Data Flow

1. `ScanController` records latency samples as before (`lib/state/providers.dart` around line 342-349) — unchanged, except both latency providers are now invalidated after a save.
2. Sparkline cell: `latencyHistoryProvider(identity)` (unchanged, 50-sample window) feeds both the sparkline line and the new tooltip's latest/avg text.
3. On tap: `showLatencyChartDialog` opens a `Dialog`; its content widget watches `latencyChartDataProvider(identity)`, a fresh DB read for up to 200 samples with timestamps.
4. `fl_chart` renders the line, axes, gridlines, and handles touch/hover tooltips internally.

## Error Handling

- DB read failures for the chart dialog: shown as a short in-dialog message, not a crash — same posture as the rest of the app's read paths (no special retry/backoff; a local SQLite read failing here would indicate a deeper, unexpected problem, not a transient condition worth engineering around).
- Fewer than 2 samples (either window): both the sparkline and the dialog degrade to an empty/placeholder state rather than attempting to draw a degenerate chart.

## Testing

- `test/data/latency_samples_test.dart` (existing) — unchanged; no changes to sample-building logic.
- New: a widget test for the sparkline cell's tooltip text computation — extract the latest/avg formatting into a small pure function (e.g. `latencyTooltipMessage(List<double> values) -> String`) in `lib/ui/latency_sparkline.dart` so it's unit-testable without pumping a full widget tree; test with a known `values` list and assert the exact formatted string.
- New: `test/ui/latency_chart_dialog_test.dart` — widget test following the `ProviderScope(overrides: [...])` pattern already used in `test/ui/topology_screen_test.dart`: override `latencyChartDataProvider` directly with `.overrideWith((ref, identity) async => [<fixture LatencySample rows>])` (the generated `LatencySample` class has a plain `const` constructor — `LatencySample(id:, deviceIdentity:, networkId:, timestamp:, rttMs:)` — so fixtures don't need a real or in-memory database). Pump `MaterialApp(home: Scaffold(body: Builder(builder: (context) => ElevatedButton(onPressed: () => showLatencyChartDialog(...), ...))))` or directly pump the dialog's content widget, then assert the stats row shows the correct Latest/Avg/Min/Max values. Does not need to assert on `fl_chart`'s internal rendering — only on this codebase's own stats-row text.
- Manual verification (per this project's UI-change convention): run the macOS app, scan a network, wait for a couple of latency samples to accumulate, hover a sparkline (tooltip appears), tap it (dialog opens with a real chart), close it.
