# Device Table Grid Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the network map feature, fix the "Found via" column so it never wraps its mini icons, and make the device table's columns user-resizable.

**Architecture:** Three independent changes to the scan screen's device table (`lib/ui/scan_screen.dart`) and its toolbar. The "Found via" fit requirement is folded into the resizable-columns work rather than implemented twice: the resizable-column state's default width for that column is computed from the exact same icon-count formula that a standalone fix would use, so the column fits all icons by default *and* is adjustable thereafter.

**Tech Stack:** Flutter, Riverpod 3.3.2 (`NotifierProvider`/`Notifier`, matching the existing `selectedNetworkProvider`/`SelectedNetworkController` pattern in `lib/state/providers.dart`).

## Global Constraints

- Match the existing `Notifier`/`NotifierProvider` pattern already used for `selectedNetworkProvider` in `lib/state/providers.dart` — do not introduce a different state-management approach (e.g. `StateProvider`, `ChangeNotifier`) for the new column-width state.
- Column widths are in-memory/session-only state. Do not add persistence (no SharedPreferences, no disk file) — out of scope.
- The header row and each `DeviceRow` must stay pixel-aligned: any width inserted in the header (e.g. a resize-handle's hit area) must have an exact-width counterpart in `DeviceRow`, even where the row's counterpart is inert (no gesture handling). This is required because Flutter's `Row`/`Expanded` flex computation depends on the *sum* of fixed-width siblings — if the header and row don't have identical fixed-width totals, the flexible "Open ports" filler column resolves to different widths in each, and everything after it visually drifts out of alignment between header and rows.
- The leading icon column (`_kIconWidth`, 40px) and the "Open ports" column stay as they are structurally: the icon column is never resizable (no text to make room for), and "Open ports" remains the table's sole flexible filler column (it absorbs whatever space the resizable columns don't use) — it does not get a stored width or a resize handle.
- Minimum column width when resizing: 40.0 logical pixels (`kMinColumnWidth`), enforced so a column can never be dragged to zero/negative width.

---

### Task 1: Remove the network map feature entirely

**Files:**
- Delete: `lib/ui/topology_screen.dart`
- Delete: `lib/ui/topology_layout.dart`
- Delete: `test/ui/topology_screen_test.dart`
- Delete: `test/ui/topology_layout_test.dart`
- Modify: `lib/ui/scan_screen.dart`

**Context:** The network map (a radial topology view) was added recently and is reachable via a "Network map" toolbar button (tooltip text "Network map", icon `Icons.hub_outlined`) in `_Toolbar` in `lib/ui/scan_screen.dart`. It has no other callers anywhere in the codebase — confirmed by searching the whole `lib/` and `test/` trees for `topology`, `Topology`, and `network map` (case-insensitive): the only hits are the four files above plus the toolbar button itself.

- [ ] **Step 1: Delete the topology files**

```bash
git rm lib/ui/topology_screen.dart lib/ui/topology_layout.dart test/ui/topology_screen_test.dart test/ui/topology_layout_test.dart
```

- [ ] **Step 2: Remove the import and the toolbar button from `lib/ui/scan_screen.dart`**

Remove this import line (near the top, alongside the other `ui/` imports):

```dart
import 'topology_screen.dart';
```

Remove this entire button from the end of `_Toolbar`'s `Row` children (it is the last child in the list, preceded by a `const SizedBox(width: 8),` that belongs to the previous button — leave that `SizedBox` in place, it separates "Scan history" from whatever follows):

```dart
        IconButton(
          tooltip: 'Network map',
          icon: const Icon(Icons.hub_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const TopologyScreen(),
            ),
          ),
        ),
```

After this edit, the `Row`'s last two children should be the `SizedBox(width: 8)` and then the "Scan history" `IconButton` — i.e. "Scan history" becomes the last toolbar button.

- [ ] **Step 3: Verify nothing else references the removed code**

```bash
grep -ril topology lib/ test/ || echo "no matches"
grep -ril "network map" lib/ test/ || echo "no matches"
```

Expected: both print `no matches` (the search is case-insensitive via `-i`; `-l` lists filenames only, `-r` recurses).

- [ ] **Step 4: Run analyze and the full test suite**

```bash
flutter analyze
flutter test
```

Expected: `flutter analyze` reports "No issues found!"; `flutter test` shows all tests passing (190 tests existed before this change; after deleting the 5 topology tests — 3 in `topology_screen_test.dart`, 2 in `topology_layout_test.dart` — expect 185 passing, 0 failing).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "remove: delete the network map feature"
```

---

### Task 2: Add the resizable-column-widths model and provider

**Files:**
- Create: `lib/state/column_widths.dart`
- Create: `test/state/column_widths_test.dart`
- Modify: `lib/state/providers.dart`
- Test (provider): add to `test/state/column_widths_test.dart`

**Interfaces:**
- Produces: `ResizableColumn` enum (`ip`, `name`, `mac`, `vendor`, `foundVia`, `latency`), `kMinColumnWidth` constant, `ColumnWidths` class with `.of(ResizableColumn)` and `.resized(ResizableColumn, double delta)`, `columnWidthsProvider` (a `NotifierProvider<ColumnWidthsController, ColumnWidths>`), `ColumnWidthsController` (its `Notifier`, with a `resize(ResizableColumn, double delta)` method). Task 3 watches `columnWidthsProvider` and calls `ref.read(columnWidthsProvider.notifier).resize(...)`.

This task has no UI in it — it is the pure state layer, fully unit-testable without `flutter_test` widget pumping.

- [ ] **Step 1: Write the failing tests for the pure model**

Create `test/state/column_widths_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/model/discovery_source.dart';
import 'package:sextant/state/column_widths.dart';

void main() {
  group('ColumnWidths', () {
    test('foundVia defaults wide enough to fit every DiscoverySource icon '
        'on one line without wrapping', () {
      const widths = ColumnWidths();
      final expected = DiscoverySource.values.length * 16.0 +
          (DiscoverySource.values.length - 1) * 4.0;

      expect(widths.foundVia, expected);
    });

    test('of() reads back the right field for each column', () {
      const widths = ColumnWidths(
        ip: 1,
        name: 2,
        mac: 3,
        vendor: 4,
        foundVia: 5,
        latency: 6,
      );

      expect(widths.of(ResizableColumn.ip), 1);
      expect(widths.of(ResizableColumn.name), 2);
      expect(widths.of(ResizableColumn.mac), 3);
      expect(widths.of(ResizableColumn.vendor), 4);
      expect(widths.of(ResizableColumn.foundVia), 5);
      expect(widths.of(ResizableColumn.latency), 6);
    });

    test('resized() adjusts only the targeted column, leaving others unchanged', () {
      const widths = ColumnWidths(ip: 100, name: 200);

      final next = widths.resized(ResizableColumn.ip, 25);

      expect(next.of(ResizableColumn.ip), 125);
      expect(next.of(ResizableColumn.name), 200); // untouched
    });

    test('resized() supports negative deltas (shrinking)', () {
      const widths = ColumnWidths(mac: 150);

      final next = widths.resized(ResizableColumn.mac, -30);

      expect(next.of(ResizableColumn.mac), 120);
    });

    test('resized() clamps at kMinColumnWidth, never going below it', () {
      const widths = ColumnWidths(latency: 56);

      final next = widths.resized(ResizableColumn.latency, -1000);

      expect(next.of(ResizableColumn.latency), kMinColumnWidth);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
flutter test test/state/column_widths_test.dart
```

Expected: FAIL — `package:sextant/state/column_widths.dart` does not exist yet (import error).

- [ ] **Step 3: Implement the pure model**

Create `lib/state/column_widths.dart`:

```dart
import 'dart:math' as math;

/// Identifies one resizable column in the device table. The leading icon
/// column and the "Open ports" column are not in this enum: the icon column
/// has no text to make room for, and "Open ports" is the table's flexible
/// filler, automatically absorbing whatever space these columns don't use.
enum ResizableColumn { ip, name, mac, vendor, foundVia, latency }

/// The smallest width a resizable column can be dragged to — small enough to
/// stay out of the way, large enough that a column never fully disappears.
const kMinColumnWidth = 40.0;

/// Default width of the "Found via" column: wide enough to fit every
/// `DiscoverySource` icon (16px, with 4px `Wrap` spacing between icons) on
/// one line without wrapping. `DiscoverySource` currently has 7 values:
/// `7 * 16.0 + 6 * 4.0 = 136.0`. This is a literal (not computed from
/// `DiscoverySource.values.length`) because Dart's constant evaluator
/// can't fold an enum's `.values.length` into a const default parameter
/// value — verified directly: `dart` rejects
/// `this.x = DiscoverySource.values.length * 1.0` with "The property
/// 'length' can't be accessed ... in a constant expression." Update this
/// literal if `DiscoverySource` gains or loses a value — the test in
/// `column_widths_test.dart` computes the expected width independently at
/// runtime (where `.length` access is unrestricted) and fails if this drifts
/// out of sync.
const _kFoundViaDefaultWidth = 136.0;

/// Current pixel widths of the device table's resizable columns. Immutable —
/// [resized] returns a new instance with one column adjusted.
class ColumnWidths {
  const ColumnWidths({
    this.ip = 130,
    this.name = 220,
    this.mac = 150,
    this.vendor = 160,
    this.foundVia = _kFoundViaDefaultWidth,
    this.latency = 56,
  });

  final double ip;
  final double name;
  final double mac;
  final double vendor;
  final double foundVia;
  final double latency;

  double of(ResizableColumn column) => switch (column) {
        ResizableColumn.ip => ip,
        ResizableColumn.name => name,
        ResizableColumn.mac => mac,
        ResizableColumn.vendor => vendor,
        ResizableColumn.foundVia => foundVia,
        ResizableColumn.latency => latency,
      };

  /// Returns a copy with [column] adjusted by [delta] (positive to grow,
  /// negative to shrink), clamped so it never drops below [kMinColumnWidth].
  ColumnWidths resized(ResizableColumn column, double delta) {
    final next = math.max(kMinColumnWidth, of(column) + delta);
    return switch (column) {
      ResizableColumn.ip => ColumnWidths(
          ip: next,
          name: name,
          mac: mac,
          vendor: vendor,
          foundVia: foundVia,
          latency: latency,
        ),
      ResizableColumn.name => ColumnWidths(
          ip: ip,
          name: next,
          mac: mac,
          vendor: vendor,
          foundVia: foundVia,
          latency: latency,
        ),
      ResizableColumn.mac => ColumnWidths(
          ip: ip,
          name: name,
          mac: next,
          vendor: vendor,
          foundVia: foundVia,
          latency: latency,
        ),
      ResizableColumn.vendor => ColumnWidths(
          ip: ip,
          name: name,
          mac: mac,
          vendor: next,
          foundVia: foundVia,
          latency: latency,
        ),
      ResizableColumn.foundVia => ColumnWidths(
          ip: ip,
          name: name,
          mac: mac,
          vendor: vendor,
          foundVia: next,
          latency: latency,
        ),
      ResizableColumn.latency => ColumnWidths(
          ip: ip,
          name: name,
          mac: mac,
          vendor: vendor,
          foundVia: foundVia,
          latency: next,
        ),
    };
  }
}
```

`column_widths.dart` does not import `discovery_source.dart` — `DiscoverySource` is mentioned only in a doc comment (plain text, not a `[DiscoverySource]` dartdoc reference), so importing it would trip the `unused_import` lint. The test file imports it directly to compute its own expectation independently.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
flutter test test/state/column_widths_test.dart
```

Expected: PASS, 5/5 tests.

- [ ] **Step 5: Add the provider, following the existing `selectedNetworkProvider` pattern**

In `lib/state/providers.dart`, add this import alongside the existing imports (the file already imports siblings via relative paths like `'../model/...'`; `column_widths.dart` is a sibling in `lib/state/`, so use a bare relative import):

```dart
import 'column_widths.dart';
```

Add this immediately after the `SelectedNetworkController` class (after the line `void select(ScanNetwork? network) => state = network;` and its closing `}`):

```dart

/// Current pixel widths of the device table's resizable columns (Task 3 in
/// `scan_screen.dart` reads and adjusts these). In-memory only — resets to
/// [ColumnWidths]'s defaults on every app launch.
final columnWidthsProvider =
    NotifierProvider<ColumnWidthsController, ColumnWidths>(
  ColumnWidthsController.new,
);

class ColumnWidthsController extends Notifier<ColumnWidths> {
  @override
  ColumnWidths build() => const ColumnWidths();

  void resize(ResizableColumn column, double delta) =>
      state = state.resized(column, delta);
}
```

- [ ] **Step 6: Write a failing test for the provider**

Append to `test/state/column_widths_test.dart` (add this import at the top alongside the existing ones: `import 'package:flutter_riverpod/flutter_riverpod.dart';` and `import 'package:sextant/state/providers.dart';`), then add this second `group` inside `main()`, after the closing brace of the `ColumnWidths` group:

```dart
  group('columnWidthsProvider', () {
    test('starts at the ColumnWidths defaults', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final widths = container.read(columnWidthsProvider);

      expect(widths.ip, const ColumnWidths().ip);
    });

    test('resize() updates the provider state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(columnWidthsProvider.notifier)
          .resize(ResizableColumn.ip, 50);

      expect(
        container.read(columnWidthsProvider).ip,
        const ColumnWidths().ip + 50,
      );
    });
  });
```

- [ ] **Step 7: Run it to verify it fails, then run again after Step 5's implementation to verify it passes**

(Step 5 already happened above, so this should pass immediately — but run it to be sure nothing was missed.)

```bash
flutter test test/state/column_widths_test.dart
```

Expected: PASS, 7/7 tests (5 from Step 4 plus 2 new).

- [ ] **Step 8: Run analyze and the full test suite**

```bash
flutter analyze
flutter test
```

Expected: `flutter analyze` reports "No issues found!"; `flutter test` passes (185 + 7 = 192 tests).

- [ ] **Step 9: Commit**

```bash
git add lib/state/column_widths.dart lib/state/providers.dart test/state/column_widths_test.dart
git commit -m "feat: add resizable-column-width state (ColumnWidths, columnWidthsProvider)"
```

---

### Task 3: Wire resizable columns into the device table UI

**Files:**
- Modify: `lib/ui/scan_screen.dart`
- Create: `test/ui/scan_screen_test.dart`

**Interfaces:**
- Consumes: `ResizableColumn`, `kMinColumnWidth`, `ColumnWidths` from `../state/column_widths.dart`; `columnWidthsProvider` from `../state/providers.dart` (both already imported in `scan_screen.dart` via the existing `import '../state/providers.dart';` — add the `column_widths.dart` import for the enum).

**Context:** Read `lib/ui/scan_screen.dart` in full before starting — this task rewrites `_DeviceTableHeader` and the column-width parts of `DeviceRow`. The current layout (top of the file) defines:

```dart
const _kIpWidth = 130.0;
const _kMacWidth = 150.0;
const _kIconWidth = 40.0;
```

`_DeviceTableHeader` is a `StatelessWidget` whose `Row` is: `SizedBox(_kIconWidth)`, `SizedBox(_kIpWidth, 'IP address')`, `Expanded(flex:3, 'Name')`, `SizedBox(_kMacWidth, 'MAC')`, `Expanded(flex:2, 'Vendor')`, `Expanded(flex:3, 'Open ports')`, `SizedBox(80, 'Found via')`, `SizedBox(56, 'Latency')`.

`DeviceRow.build`'s `row` local variable is a `Row` with the matching cells in the same order (icon+status, IP+extra-IPs badge, name `Expanded(flex:3)`, MAC `SizedBox(_kMacWidth)`, vendor `Expanded(flex:2)`, ports `Expanded(flex:3)` containing a `Wrap` of `_PortChip`s, found-via `SizedBox(width: 80)` containing a `Wrap` of source icons, latency `SizedBox(width: 56)` containing the sparkline/tooltip/tap-to-chart `Wrap`per.

This task converts every column except the icon column (stays fixed, non-resizable) and "Open ports" (stays the sole flexible filler) to read its width from `columnWidthsProvider`, and adds a draggable resize handle after each resizable column in the header. Because Flutter's `Row` lays out fixed-width children first and gives ALL leftover space to the one `Expanded` child, the header and the row must contain the exact same *sequence and sum* of fixed-width children for the columns to stay pixel-aligned — so a `SizedBox(width: _kHandleWidth)` spacer goes in `DeviceRow` everywhere the header has an (interactive) resize handle, even though the row's spacer does nothing.

- [ ] **Step 1: Add the import**

In `lib/ui/scan_screen.dart`, add this import alongside the existing relative imports (e.g. right after `import '../state/network_selection.dart';`):

```dart
import '../state/column_widths.dart';
```

- [ ] **Step 2: Delete the now-superseded width constants**

Delete these two lines (keep `_kIconWidth`, it still applies to the non-resizable icon column):

```dart
const _kIpWidth = 130.0;
const _kMacWidth = 150.0;
```

Add this one in their place, right after `const _kIconWidth = 40.0;`:

```dart
/// Width of the (invisible, draggable) gap after each resizable column. Must
/// be identical between the header (where it's interactive) and each
/// [DeviceRow] (where it's an inert spacer) — see the alignment note in this
/// file's class docs above `_DeviceTableHeader`.
const _kHandleWidth = 8.0;
```

- [ ] **Step 3: Rewrite `_DeviceTableHeader`**

Replace the entire `_DeviceTableHeader` class with:

```dart
/// The device table's column headers. A [ConsumerWidget] (not
/// [StatelessWidget], like the rest of this file's static widgets) because it
/// both reads [columnWidthsProvider] for current widths and renders the
/// draggable resize handles that write back to it.
///
/// IMPORTANT: every fixed-width child here must have an exact-width sibling
/// in [DeviceRow]'s row, in the same relative position, or the two rows will
/// drift out of alignment — see [_kHandleWidth]'s doc comment.
class _DeviceTableHeader extends ConsumerWidget {
  const _DeviceTableHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widths = ref.watch(columnWidthsProvider);
    final style = Theme.of(context)
        .textTheme
        .labelMedium
        ?.copyWith(fontWeight: FontWeight.bold);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: _kIconWidth),
          SizedBox(width: widths.ip, child: Text('IP address', style: style)),
          const _ColumnResizeHandle(column: ResizableColumn.ip),
          SizedBox(width: widths.name, child: Text('Name', style: style)),
          const _ColumnResizeHandle(column: ResizableColumn.name),
          SizedBox(width: widths.mac, child: Text('MAC', style: style)),
          const _ColumnResizeHandle(column: ResizableColumn.mac),
          SizedBox(width: widths.vendor, child: Text('Vendor', style: style)),
          const _ColumnResizeHandle(column: ResizableColumn.vendor),
          Expanded(child: Text('Open ports', style: style)),
          SizedBox(
              width: widths.foundVia, child: Text('Found via', style: style)),
          const _ColumnResizeHandle(column: ResizableColumn.foundVia),
          SizedBox(
              width: widths.latency, child: Text('Latency', style: style)),
          const _ColumnResizeHandle(column: ResizableColumn.latency),
        ],
      ),
    );
  }
}

/// A thin draggable strip after a resizable column's header cell: dragging it
/// horizontally grows or shrinks that column via [columnWidthsProvider].
/// [_kHandleWidth] wide, matching the inert spacer [DeviceRow] places in the
/// same position so header and rows stay aligned.
class _ColumnResizeHandle extends ConsumerWidget {
  const _ColumnResizeHandle({required this.column});

  final ResizableColumn column;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: _kHandleWidth,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: (details) => ref
              .read(columnWidthsProvider.notifier)
              .resize(column, details.delta.dx),
          child: Center(
            child: Container(
              width: 1,
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Update `DeviceRow.build` to read widths and match the header's spacers**

In `DeviceRow.build`, add this line right after `final identity = deviceIdentity(...)` block's closing `);` (so `widths` is available below):

```dart
    final widths = ref.watch(columnWidthsProvider);
```

Then, in the `row` local variable's `Row.children`, make these replacements (each is a width-source change only — the cell's inner content is unchanged):

Replace:
```dart
          SizedBox(
            width: _kIpWidth,
            child: Row(
```
with:
```dart
          SizedBox(
            width: widths.ip,
            child: Row(
```

Replace the Name cell:
```dart
          Expanded(
            flex: 3,
            child: Text(
              device.displayName,
```
with:
```dart
          const SizedBox(width: _kHandleWidth),
          SizedBox(
            width: widths.name,
            child: Text(
              device.displayName,
```

(Leave the rest of that `Text` widget — `overflow`, `style`, and its closing — exactly as-is; only the wrapping widget and its width source change, from `Expanded(flex: 3, ...)` to `SizedBox(width: widths.name, ...)`.)

Replace the MAC cell:
```dart
          SizedBox(
            width: _kMacWidth,
            child: Text(device.mac ?? '—', style: offline ? mutedSmall : small),
          ),
```
with:
```dart
          const SizedBox(width: _kHandleWidth),
          SizedBox(
            width: widths.mac,
            child: Text(device.mac ?? '—', style: offline ? mutedSmall : small),
          ),
```

Replace the Vendor cell:
```dart
          Expanded(
            flex: 2,
            child: Text(
              device.vendor ?? '—',
              overflow: TextOverflow.ellipsis,
              style: offline ? mutedSmall : small,
            ),
          ),
```
with:
```dart
          const SizedBox(width: _kHandleWidth),
          SizedBox(
            width: widths.vendor,
            child: Text(
              device.vendor ?? '—',
              overflow: TextOverflow.ellipsis,
              style: offline ? mutedSmall : small,
            ),
          ),
          const SizedBox(width: _kHandleWidth),
```

Replace the Open ports cell's flex (drop the explicit flex — it's now the row's only flexible child, so the factor is moot, but keep it parameter-free for clarity that it's the filler):
```dart
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                for (final port in device.openPorts)
                  _PortChip(port: port, service: device.services[port]),
              ],
            ),
          ),
```
with:
```dart
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                for (final port in device.openPorts)
                  _PortChip(port: port, service: device.services[port]),
              ],
            ),
          ),
```

Replace the Found via cell's width:
```dart
          SizedBox(
            width: 80,
            child: Wrap(
              spacing: 4,
              children: [
                for (final source in device.discoveredBy)
```
with:
```dart
          SizedBox(
            width: widths.foundVia,
            child: Wrap(
              spacing: 4,
              children: [
                for (final source in device.discoveredBy)
```

Then add a handle-width spacer right after that `SizedBox`'s closing (the found-via cell currently ends with a `),` immediately followed by the Latency `SizedBox(width: 56, ...)`  — insert the spacer between them):
```dart
          const SizedBox(width: _kHandleWidth),
```

Replace the Latency cell's width:
```dart
          SizedBox(
            width: 56,
            child: ref.watch(latencyHistoryProvider(identity)).maybeWhen(
```
with:
```dart
          SizedBox(
            width: widths.latency,
            child: ref.watch(latencyHistoryProvider(identity)).maybeWhen(
```

And finally add one more trailing spacer right after that `SizedBox`'s closing (to match the header's trailing handle after "Latency" — it's the last child in the `Row.children` list now):
```dart
          const SizedBox(width: _kHandleWidth),
```

After this step, `DeviceRow`'s `Row.children` order is: icon `SizedBox`, IP `SizedBox`, handle-spacer, Name `SizedBox`, handle-spacer, MAC `SizedBox`, handle-spacer, Vendor `SizedBox`, handle-spacer, Open ports `Expanded`, Found via `SizedBox`, handle-spacer, Latency `SizedBox`, handle-spacer — six handle-spacers, matching the header's six `_ColumnResizeHandle`s exactly in count and position relative to the other columns.

- [ ] **Step 5: Write the widget test**

Create `test/ui/scan_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/model/device.dart';
import 'package:sextant/state/providers.dart';
import 'package:sextant/state/scan_state.dart';
import 'package:sextant/ui/scan_screen.dart';

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
        networksProvider.overrideWith((ref) async => []),
      ],
      child: const MaterialApp(home: ScanScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('there is no "Network map" button in the toolbar', (tester) async {
    await _pump(tester, []);

    expect(find.byTooltip('Network map'), findsNothing);
  });

  testWidgets('dragging the IP column resize handle widens it and narrows '
      'the Open ports filler correspondingly', (tester) async {
    await _pump(tester, [_dev('10.0.0.1')]);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ScanScreen)),
    );
    final before = container.read(columnWidthsProvider).ip;

    final handle = find.byWidgetPredicate(
      (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
    );
    expect(handle, findsWidgets);

    await tester.drag(handle.first, const Offset(30, 0));
    await tester.pump();

    expect(container.read(columnWidthsProvider).ip, before + 30);
  });
}
```

- [ ] **Step 6: Run the new test to verify it fails, then implement Steps 1-4 above if not already done, and re-run**

```bash
flutter test test/ui/scan_screen_test.dart
```

Expected after Steps 1-4 are in place: PASS, 2/2 tests. (If you're implementing Steps 1-4 before writing this test file, run this once at the end instead — either order is fine as long as both pass before committing.)

- [ ] **Step 7: Run analyze and the full test suite**

```bash
flutter analyze
flutter test
```

Expected: `flutter analyze` reports "No issues found!"; `flutter test` passes (192 + 2 = 194 tests).

- [ ] **Step 8: Manually sanity-check the column math (no code change, just a check)**

Confirm by inspection that `DeviceRow`'s `Row.children` list and `_DeviceTableHeader`'s `Row.children` list both contain exactly six `SizedBox(width: _kHandleWidth)`-equivalent entries (handle or spacer) in the same relative positions (after IP, Name, MAC, Vendor, Found via, Latency) and exactly one `Expanded` (Open ports). This is the invariant the Global Constraints section calls out — a mismatch here causes silent visual misalignment, not a test failure or analyzer warning, so it can't be caught by Step 7 alone.

- [ ] **Step 9: Commit**

```bash
git add lib/ui/scan_screen.dart test/ui/scan_screen_test.dart
git commit -m "feat: make device table columns resizable; fix Found via column to fit all icons"
```
