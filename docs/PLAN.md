# Sextant (by IonJet) — Cross-Platform Network Scanner

> Living plan/design doc. Status markers reflect actual progress; see "Status" below.

## Status (updated continuously)

- ✅ **Phase 1 — COMPLETE & verified on a real /22** (32 devices, ~18s). TCP scan → IP-sorted
  table → rename → open-in-browser, macOS. 55+ tests green.
- ✅ **Phase 2 — essentially COMPLETE.** Fingerprint-fallback identity, `DeviceClassifier`,
  service/banner detection (`BannerGrabber` +
  `identifyService`), and the full bundled IEEE OUI DB (39.5k entries, `assets/oui.tsv`). Online
  vendor fallback deliberately skipped (unresolved MACs are randomized — no DB resolves them).
  Remaining: scan-speed tuning.
- ✅ **Phase 3 — COMPLETE.** Discovery protocols wired as parallel sources: mDNS/Bonjour
  (`MdnsDiscovery`), NetBIOS (`NetbiosResolver`, NBSTAT/UDP 137), and SSDP/UPnP (`SsdpDiscovery`,
  M-SEARCH + description-XML fetch → friendly name/type). Classification hardened: service- and
  UPnP-type-aware typing, Apple/Sonos/Google inference from Bonjour for randomized MACs. **Multi-network
  dropdown** wired to `selectedNetworkProvider`, default Wi-Fi-first; selection survives re-discovery
  by stable id (`effectiveNetwork`). **Wired/wireless detection** via `InterfaceTyper`
  (`networksetup -listallhardwareports` on macOS, name heuristic elsewhere — verified: en0=Wi-Fi,
  Ethernet/Thunderbolt=wired). **Network-change detection** via `NetworkMonitor`: event-driven on
  `connectivity_plus` (merged with an 8s safety tick), deduped against a cheap interface signature
  (the plugin can fire spuriously and can miss same-adapter SSID/DHCP swaps); on a real change →
  stop in-flight scan, re-discover, re-default to Wi-Fi, toast. **Discovery is resilient to the
  switch transient** (`retryWhileEmpty`): the change event arrives while the new network is still
  acquiring an IP, so a single re-discovery would cache an empty list and strand on "No active
  network found"; discovery now retries (~6×700ms) across the settle window so it lands on the live
  network instead of getting stuck.
- 🟡 **Phase 4 — STARTED.** **Export CSV/JSON** done: pure serialisers (`devicesToCsv` with
  RFC-4180 quoting, `devicesToJson` with count + timestamp) and `buildScanExport` (format +
  timestamped filename), all TDD; toolbar download menu → native save dialog (`file_selector`) →
  writes the file, snackbar reports the path. **Live monitoring + new-device alerts** done:
  `diffScans` (pure, TDD — added/removed/changed correlated by `deviceIdentity`) underpins a
  monitor loop in `ScanController` (`toggleMonitoring` → visible baseline only if empty, then
  re-scan every 30s). Periodic re-scans run **entirely in the background** and only reconcile the
  delta afterward (no clear/repopulate flicker): devices not found are **kept and greyed-out**
  (`Device.isOnline`), not deleted; new ones surface via `lastNewDevices`. Toolbar sensors toggle +
  status-bar indicator + snackbar alert. Online/offline is judged by **active reachability**
  (`activelyReachable`, TDD): ARP presence alone is a stale-cache artifact (a powered-off device
  lingers in ARP for minutes), so a device is only "online" if it answered ICMP, has an open TCP
  port, or replied to mDNS/NetBIOS/SSDP this pass — otherwise it's greyed offline. Offline rows show
  a hollow status dot + struck-through, muted text; the list has zebra striping. (Datagram sockets
  in NetBIOS/SSDP now swallow async "host is down" ICMP errors so they don't crash the app.) Plus
  renamed names render bold+italic, and the device-type icon has a tooltip and is changeable from the
  row context menu (persisted by identity via `TypeOverrideStore`, overriding auto-classification).
  **Scan history + change log** done: a Drift DB (`HistoryDatabase`, single `Scans` table storing each
  snapshot's devices as a JSON blob — devices are only ever read/written whole, so a join table buys
  nothing; datetimes stored as UTC ISO text via `build.yaml` for deterministic round-trips) persists a
  snapshot on every completed manual scan and, during monitoring, only when `diffScans` reports a change
  (so history is a meaningful change log, not identical hourly dumps; capped at 500 via prune-on-save).
  Pure layers TDD'd: `deviceToMap`/`deviceFromMap` (lossless round-trip, unknown enum names decode
  safely), `groupByNetwork` (networks + scans newest-first) and `changeLog` (diffs consecutive scans →
  appeared/disappeared/changed entries, newest-first). UI: `HistoryScreen` (toolbar history button →
  per-network `ExpansionTile` cards showing the change log; clear-all with confirm).
  **Network-change bugfix:** detection fired only once then never again — `NetworkMonitor.changes()`
  emitted `void`, so the `StreamProvider`'s `AsyncData(null)` never differed between events and
  `ref.listen` deduped every change after the first. `changes()` now yields a monotonically increasing
  counter (`StreamProvider<int>`) so each change is a distinct value the listener actually sees.
  **Wake-on-LAN** done: `buildMagicPacket` (TDD'd — 6×0xFF + MAC repeated 16×, accepts `:`/`-`
  separators, rejects malformed MACs) + `WakeOnLan.send` (UDP broadcast, port 9, `dart:io` only, no new
  dependency). Row context menu gained "Wake on LAN" whenever a MAC is known, with a success/failure
  snackbar.
  **Monitoring bugfixes:** background monitor ticks deliberately never set `isScanning`/`isBusy`
  (to avoid UI flicker), which meant the network-change listener's `isBusy` gate never tripped
  during monitoring — a network switch left `_monitoring` on and the 30s timer kept re-scanning the
  stale/disconnected network forever. Fixed by calling `stopScan()` unconditionally on every network
  change (it's a no-op when nothing is running). Separately, a fingerprint-fallback identity (no MAC)
  can drift slightly between passes (a port not yet detected, a hostname not yet resolved), which made
  `diffScans` see a different identity for the *same* device coming back online and misreport it as
  "added". Fixed with `excludeReappeared` (TDD'd, lib/data/scan_diff.dart): strips any "added" device
  whose IP was already on record as offline in the previous snapshot before it reaches
  `lastNewDevices` — a reappearance, not a new device.
  **Latency tracking started:** `parsePingRttMs` (TDD'd, lib/platform/icmp_pinger.dart) extracts the
  round-trip time from the system `ping` reply line (macOS/Linux `time=1.234 ms`, Windows
  `time=1ms`/`time<1ms`); `PingResult.rttMs` carries it, `ScanOrchestrator`'s ICMP phase attaches it
  to the emitted `Device.latencyMs`, `_merge` keeps it across the same pass's ARP/TCP observations.
  Shown today as "· N ms" in the status-dot tooltip. Remaining: persisted time-series + sparkline/graph
  (latency isn't diffed into the change log — it fluctuates every scan, which would just be noise),
  topology view, opt-in ICMP via privileged helper, native ARP on Windows/Linux, iOS/Android.

**OS detection removed (per user):** TTL-based OS fingerprinting was inherently ambiguous
(TTL 64 = Linux/macOS *or* ESP/lwIP; 128 = Windows *or* printer/IoT). Even corroborated it added
little signal for the cost, so the whole feature (`os_fingerprint.dart`, the `Device.os` field, the
OS table column, and `PingResult.ttl`) was deleted in favour of "unknown over a wrong guess."

Key accuracy work already shipped beyond the original Phase 1:
- **Real subnet mask read from the OS** (`InterfaceMaskResolver`) — scans the true /22 instead
  of assuming /24 (this alone recovered most "missing" devices).
- **Two-phase discovery:** ICMP ping sweep (also primes ARP) → ARP-as-discovery for every
  L2-present host (filtered for network/broadcast/non-unicast) → TCP port-scan only live hosts.
- **Progressive emit:** each device appears the instant its IP is found; hostname/MAC/ports/sources
  stream in afterward.
- **Resizable desktop window** (`window_manager`), discovery-method **tooltips + context-menu
  legend**, determinate **scan progress** ("Scanning… N found, scanned X of Y").

## Context

A greenfield Flutter app that scans every device on the local network and presents them in a
rich, sortable table — aiming to be best-in-class (alongside Fing, Angry IP Scanner, Advanced
IP Scanner, SoftPerfect).

**Decisions (from brainstorming):**

- **Platforms: Desktop + Mobile, treated equally.** Desktop (macOS/Windows/Linux) is the
  full-power tier; mobile (iOS/Android) is an honest, gracefully-degraded companion. No web —
  browsers cannot do raw sockets/TCP/ICMP.
- **Audience: IT / network pros & power users.** Dense, data-rich table; export; deep detail.
- **Platform capability asymmetry is the dominant constraint:**
  - ICMP via raw sockets needs root; default liveness is privilege-free TCP-connect + system
    `ping`. (Raw ICMP remains an opt-in elevation path.)
  - MAC comes from the ARP cache — desktop-only; blocked on modern iOS/Android.
  - iOS needs a Local Network permission prompt and sandboxes mDNS.
- **Native code is allowed** for ARP/MAC, raw ICMP, interface typing.
- **Branding:** Product = **Sextant**; studio/domain = **IonJet** (`ionjet.net`); bundle id
  `net.ionjet.sextant`.
- **macOS App Sandbox is intentionally disabled** (a scanner needs ARP + broad outbound; not a
  Mac App Store candidate).

## Goals (13 requirements + agreed extras)

Core: discover hosts (multi-threaded ping/TCP + port probes); find MACs; resolve
Bonjour/mDNS/NetBIOS names; discover via those protocols too; rich table (ports +
"discovered-by" mini-icons); rename/notes persisted by device identity; device-type guessing;
MAC→manufacturer; network-change detection; multi-network dropdown next to SCAN (default Wi-Fi);
wired-vs-wireless detection; per-row right-click/long-press context menu; list sorted by IP.

Extras: scan history + change log (grouped network → scan-time, recent first); new-device alerts
via live monitoring (toolbar toggle); latency/uptime graphs; export CSV/JSON; service/banner
detection; Wake-on-LAN; topology / network map. (OS fingerprinting was tried and removed — see Status.)

## Tech Stack

Flutter / Dart; **Riverpod** (state, async streams); **Drift + sqlite3** planned for relational
history/diffing (Phase 4); mostly pure-Dart networking; native bridges only where Dart can't
reach. Packages in use: `network_info_plus`, `connectivity_plus` (network-change events),
`multicast_dns`, `path_provider`, `url_launcher`, `window_manager`.

## Architecture (layered, isolated, testable)

`lib/platform/` — `NetworkDiscovery` (active networks, default Wi-Fi, real masks),
`InterfaceMaskResolver` (OS netmask), `ArpResolver` + `parseArpOutput`, `IcmpPinger`/`IcmpSweeper`
(system ping), `WakeOnLan` (planned).

`lib/scan/` — pure-Dart engine: `TcpProbe`, `TcpHostScanner` (bounded concurrency + progress),
`Ipv4Subnet`, `ScanOrchestrator` (two-phase, progressive stream), `well_known_ports`.

`lib/enrich/` — `OuiVendorLookup` (+ seed; full asset DB + online fallback planned),
`classifyDevice` (DeviceClassifier). (OS fingerprinting removed.)

`lib/model/` — `Device`, `ScanNetwork`, `DiscoverySource`, `DeviceType`.

`lib/data/` — `deviceIdentity` (MAC primary, fingerprint fallback), `RenameStore` (JSON now;
Drift later).

`lib/state/` (Riverpod) — `networksProvider`, `selectedNetworkProvider` (default Wi-Fi),
`scanControllerProvider` (progressive, IP-sorted, merges observations).

`lib/ui/` — `ScanScreen` (toolbar: network dropdown + SCAN + progress; IP-sorted device list;
row context menu with discovery legend, open-in-browser, rename, copy). Planned: `DeviceDetailPanel`,
`HistoryScreen`, `TopologyView`; adaptive desktop/mobile layouts.

## Phased Delivery

**Phase 1 — Vertical slice (DONE).** Interface/subnet detection; discovery + port scan
(progressive, bounded concurrency); ARP MAC + OUI vendor; IP-sorted table; rename-by-identity;
row context menu; network dropdown + SCAN.

**Phase 2 — Identity & enrichment (DONE).** Fingerprint identity ✅; `DeviceClassifier` ✅;
banner/service detection ✅; full OUI DB ✅; speed tuning (minor). OS fingerprinting tried & removed.

**Phase 3 — Discovery protocols & multi-network (DONE).** mDNS/Bonjour + NetBIOS + SSDP/UPnP feeding
aggregation ✅; protocol mini-icons ✅; multi-network dropdown ✅; wired/wireless detection ✅;
network-change detection ✅.

**Phase 4 — Monitoring, history, extras, full cross-platform.** Export CSV/JSON ✅; live-monitor
toggle + new-device alerts ✅; scan history + change log ✅ (Drift `HistoryDatabase`); Wake-on-LAN ✅;
latency/uptime graphs; topology view; opt-in ICMP via privileged helper; Windows/Linux native ARP;
iOS/Android with graceful degradation + Local Network permission.

## Testing Strategy (TDD throughout)

Unit-test the engine against loopback TCP listeners and real ping/ARP parsing; classifier /
classifier / OUI against fixtures; identity & rename store with temp files; an integration
test scanning local listeners end-to-end. A headless CLI harness (`tool/live_scan.dart`)
validates against the real LAN.

## Open Items / Pre-Release

- Formal trademark-class search + domain confirmation for "Sextant" / "IonJet".
- iOS `NSLocalNetworkUsageDescription` + Bonjour service declarations; Android scan permissions.
- Full IEEE OUI DB bundling + periodic refresh.
- Dedupe multi-homed devices (same MAC, multiple IPs) in the table.
