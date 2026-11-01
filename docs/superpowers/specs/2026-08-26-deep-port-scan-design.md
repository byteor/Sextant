# Deep port scan (all 65,535 ports on one device)

## Problem

The regular scan only probes a fixed list of ~34 well-known ports
(`kWellKnownPorts`). A user who suspects a device is running something
unusual (an IoT device with a hidden management port, a server with a
non-standard service) has no way to check the full port range from within
the app.

## Goal

A context-menu action on a device row, "Scan all ports (65,535)…", that
TCP-scans one device's full port range, shows live progress without
blocking the rest of the app, and remembers what it finds so future regular
scans keep showing those ports as open without re-running the full scan.

## Non-goals

- Scanning more than one device's full port range at a time.
- UDP scanning — TCP-connect only, matching the existing scanner.
- User-configurable concurrency/timeout for the deep scan.
- Precise per-device re-check targeting (see "Re-check semantics" below for
  the simplification and its accepted tradeoff).

## Data model

New Drift table, `DeepScanPorts`:

```dart
class DeepScanPorts extends Table {
  TextColumn get deviceIdentity => text()();
  TextColumn get networkId => text()();   // informational only, not part of the key
  IntColumn get port => integer()();
  DateTimeColumn get discoveredAt => dateTime()();

  @override
  Set<Column> get primaryKey => {deviceIdentity, port};
}
```

Keyed by `deviceIdentity` alone (not network-scoped like `SeenDevices`):
"this device has a service on port 8888" is a fact about the physical
device, not the network it's currently on — matching how `RenameStore` and
`TypeOverrideStore` already key by identity only. `networkId` is kept as
metadata (which network it was discovered from) but isn't part of the
lookup key.

`HistoryDatabase` gains:
- `recordDeepScanPorts(deviceIdentity, networkId, List<int> ports)` — upserts
  (insert-or-ignore on the identity+port pair keeps `discoveredAt` at the
  first-found date on repeat deep scans of the same device).
- `allExtraPorts()` — the distinct set of every port ever recorded, across
  every device, for building the regular scan's port list (see below).

## Re-check semantics

"Re-checked next time this device is scanned" is implemented as: the
regular scan's TCP-phase port list becomes
`kDefaultScanPorts ∪ allExtraPorts()` — every host in a regular scan gets
probed on every port anyone has ever found via a deep scan, not just the
device it was originally found on.

This is deliberately simpler than precise per-device targeting, which would
require threading a per-host port list through `TcpHostScanner`'s
currently-shared port list. The cost is negligible: probing a few dozen
extra ports against hosts that don't have them open just returns "closed"
quickly. The tradeoff: port 8888 found on device A also gets (harmlessly)
checked on device B.

## Scan engine

Reuses `TcpHostScanner` against a single host with `ports: List.generate(65535, (i) => i + 1)`,
rather than a new scan engine. Two additions:

1. **Tuned concurrency/timeout for one host**: `concurrency: 64`,
   `timeout: Duration(milliseconds: 400)` — the existing defaults
   (concurrency 256, 1s timeout) are tuned for sweeping many hosts at once
   and would be closer to a flood against a single device. LAN round-trips
   are sub-millisecond, so 400ms is generous for a real response; worst
   case (every port silently dropped, no RST) is ~7 minutes, but ports that
   actively refuse (the common case) respond near-instantly, so typical
   scans finish in well under a minute.

2. **Per-probe progress callback**: `TcpHostScanner` currently only reports
   progress via `onHostComplete`, fired once a host's *entire* port list
   finishes — fine for many-hosts/few-ports, useless for one host with
   65,535 ports (progress would jump 0% → 100%). Add an additive, optional
   `onProbeComplete(int done, int total)` callback fired after every
   individual port probe. Existing callers (the regular subnet scan) don't
   pass it, so today's behavior is unchanged.

## State (on `ScanController`/`ScanState`, not a separate controller)

New `ScanState` fields:
- `deepScanDeviceIdentity` (`String?`) — which device, if any.
- `deepScanIp` (`String?`) — for display.
- `deepScanCompleted` / `deepScanTotal` (`int`) — probe progress.
- `deepScanOpenPorts` (`List<int>`) — live-updating as ports are found.

`ScanController` gains `startDeepPortScan(Device device, ScanNetwork network)`
and `cancelDeepPortScan()`.

### Mutual exclusion

Only one thing may ever mutate the live device list (`_byIp`) at a time.
Concretely:

- `startDeepPortScan` no-ops if `state.isScanning`, `state.isBackgroundScanning`,
  or a deep scan is already running.
- `startScan` no-ops if a deep scan is running (mirrors its existing
  `if (state.isScanning) return;` guard).
- `_monitorTick`, if it fires while a deep scan is running, skips that
  tick's actual work and just calls `_scheduleNextTick()` again — monitoring
  silently resumes on its own once the deep scan finishes, rather than
  racing with it.
- UI: the SCAN button and the monitoring toggle button are disabled while a
  deep scan is running; "Scan all ports…" in the context menu is disabled
  (with a tooltip) while a regular scan or a background monitor tick is
  active.

This directly follows from the review that a regular scan's `_byIp.clear()`
or a monitor tick's `_reconcile()` overwrite would otherwise corrupt/lose
the in-flight deep-scan device entry, or the deep scan's completion merge
would clobber a concurrently-running regular scan's fresher data.

## UI

- **Context menu** (`DeviceRow._showMenu`): new item "Scan all ports
  (65,535)…", disabled with a tooltip while any scan (regular, monitoring
  tick, or another deep scan) is active elsewhere, and disabled with a
  different tooltip when the device itself is currently offline (a
  multi-minute scan against a device that isn't responding is pointless) —
  the first action in this menu to be online-gated; every existing item is
  shown regardless of online state today.
- **Confirm dialog**: selecting it shows a confirm dialog ("This can take
  several minutes and generates significant traffic to the device") before
  starting — matches the app's existing confirm-before-heavier-action
  pattern (e.g. clear history).
- **Row-level progress**: the scanned device's row swaps its status dot for
  a small `CircularProgressIndicator` (value: `completed / total`).
- **Status bar**: a line while active, e.g. "Deep-scanning 192.168.1.23 —
  12,340 / 65,535 (3 open)" with an inline Cancel action calling
  `cancelDeepPortScan()`.
- **Completion**: merge found ports into the live device (visible in Open
  Ports immediately), persist via `recordDeepScanPorts`, call the existing
  `_saveHistory` so the History screen's diff naturally shows a "changed
  open ports" entry (already a tracked `DeviceChangeField` — no new diff
  logic needed), and show a summary SnackBar ("Deep scan of 192.168.1.23
  complete: 3 open ports found (8080, 8888, 47990)" / "no additional open
  ports found").
- **Cancellation**: same `_cancelled`-flag pattern already used by
  `ScanOrchestrator`/`TcpHostScanner`. A cancelled deep scan persists
  nothing and shows no summary.

## Testing

- `TcpHostScanner`: test for the new `onProbeComplete` callback (fires per
  probe, existing `onHostComplete` behavior unchanged).
- `HistoryDatabase`: unit tests for `recordDeepScanPorts` (upsert keeps
  first-found `discoveredAt`) and `allExtraPorts` (union across devices).
- `ScanController`: mutual-exclusion guards — starting a deep scan while
  scanning/monitoring no-ops; starting a regular scan while a deep scan
  runs no-ops; a monitor tick during a deep scan reschedules without
  touching `_byIp`.
- Widget tests (state-driven, via the existing `_FixedScanController`
  pattern): context-menu item disabled in each busy state; confirm dialog
  appears before starting; row shows the progress ring when
  `deepScanDeviceIdentity` matches; SCAN/monitoring buttons disabled during
  a deep scan.
