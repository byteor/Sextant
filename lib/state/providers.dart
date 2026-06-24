import 'dart:async';
import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/dedupe_multihomed.dart';
import '../data/device_identity.dart';
import '../data/history_database.dart';
import '../data/latency_samples.dart';
import '../data/rename_store.dart';
import '../data/scan_diff.dart';
import '../data/scan_history.dart';
import '../data/scan_record.dart';
import '../data/type_override_store.dart';
import '../enrich/device_classifier.dart';
import '../enrich/liveness.dart';
import '../enrich/oui_refresh.dart';
import '../enrich/oui_seed.dart';
import '../enrich/oui_vendor_lookup.dart';
import '../model/device.dart';
import '../model/discovery_source.dart';
import '../model/network_info.dart';
import '../platform/network_discovery.dart';
import '../platform/network_monitor.dart';
import '../scan/scan_orchestrator.dart';
import 'column_widths.dart';
import 'scan_state.dart';

/// Loads (and caches) the persisted device-name store.
final renameStoreProvider = FutureProvider<RenameStore>((ref) async {
  final dir = await getApplicationSupportDirectory();
  final store = RenameStore(File('${dir.path}/device_names.json'));
  await store.load();
  return store;
});

/// Loads (and caches) the persisted manual-device-type store.
final typeOverrideStoreProvider = FutureProvider<TypeOverrideStore>((ref) async {
  final dir = await getApplicationSupportDirectory();
  final store = TypeOverrideStore(File('${dir.path}/device_types.json'));
  await store.load();
  return store;
});

/// The on-disk scan-history database (Drift), stored in the app support
/// directory. Opened lazily on first query and closed when the provider is
/// disposed.
final historyDatabaseProvider = Provider<HistoryDatabase>((ref) {
  final db = HistoryDatabase(driftDatabase(name: 'sextant_history'));
  ref.onDispose(db.close);
  return db;
});

/// The persisted scan history, grouped by network (each network and its scans
/// most-recent-first) for the history screen. Invalidated by [ScanController]
/// whenever a new snapshot is saved.
final scanHistoryProvider =
    FutureProvider<List<NetworkScanHistory>>((ref) async {
  final db = ref.watch(historyDatabaseProvider);
  return groupByNetwork(await db.recentScans(limit: _historyRetention));
});

/// Upper bound on retained scan snapshots, enforced on every save so live
/// monitoring can't grow the history file without limit.
const _historyRetention = 500;

/// The recent latency history for one device (by stable identity), used to
/// draw its sparkline. Invalidated whenever new samples are recorded.
final latencyHistoryProvider =
    FutureProvider.family<List<double>, String>((ref, deviceIdentity) async {
  final db = ref.watch(historyDatabaseProvider);
  final samples = await db.latencyHistory(deviceIdentity);
  return [for (final s in samples) s.rttMs];
});

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

/// The active local networks, Wi-Fi first so the UI can default to it.
final networksProvider = FutureProvider<List<ScanNetwork>>(
  (ref) => NetworkDiscovery().discover(),
);

/// Emits whenever the host's network attachment changes (Wi-Fi switch, cable
/// plug/unplug, DHCP move). The UI listens to this to re-discover networks and
/// re-default the selection to Wi-Fi.
/// Emits a distinct, increasing counter on each real network change. The value
/// itself is unused by listeners — it must merely *differ* each time so the
/// StreamProvider doesn't dedup identical events (which silently swallowed every
/// change after the first when this emitted `void`).
final networkChangeProvider = StreamProvider<int>(
  (ref) => NetworkMonitor().changes(),
);

/// The network the user has selected to scan (defaults to the first/Wi-Fi).
final selectedNetworkProvider =
    NotifierProvider<SelectedNetworkController, ScanNetwork?>(
  SelectedNetworkController.new,
);

class SelectedNetworkController extends Notifier<ScanNetwork?> {
  @override
  ScanNetwork? build() => null;

  void select(ScanNetwork? network) => state = network;
}

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

final scanControllerProvider =
    NotifierProvider<ScanController, ScanState>(ScanController.new);

/// Drives a scan of a [ScanNetwork] and maintains the live, IP-sorted device
/// list: progressive TCP results first, then MAC/vendor enrichment from the ARP
/// cache, with persisted custom names re-applied throughout.
class ScanController extends Notifier<ScanState> {
  StreamSubscription<Device>? _sub;
  final Map<String, Device> _byIp = {};
  int _probed = 0;
  String? _gatewayIp;
  OuiVendorLookup _oui = const OuiVendorLookup({});

  /// Live-monitoring state: when [_monitoring] is on, the network is re-scanned
  /// every [_monitorInterval] and each pass is diffed against the previous to
  /// surface newly-appeared devices.
  bool _monitoring = false;
  ScanNetwork? _monitorNetwork;
  Timer? _monitorTimer;
  StreamSubscription<Device>? _monitorSub;
  static const _monitorInterval = Duration(seconds: 30);

  @override
  ScanState build() {
    ref.onDispose(() {
      _monitoring = false;
      _monitorTimer?.cancel();
      _monitorSub?.cancel();
      _sub?.cancel();
    });
    return const ScanState();
  }

  Future<void> startScan(ScanNetwork network) async {
    if (state.isScanning) return;
    await _sub?.cancel();
    _byIp.clear();
    _probed = 0;
    _gatewayIp = network.gateway?.address;

    _oui = await ref.read(ouiLookupProvider.future);
    final store = await ref.read(renameStoreProvider.future);
    final typeStore = await ref.read(typeOverrideStoreProvider.future);
    final total = network.subnet.hostAddresses().length;

    state = ScanState(
      isScanning: true,
      total: total,
      isMonitoring: _monitoring,
    );

    final orchestrator = ScanOrchestrator();
    final completer = Completer<void>();
    _sub = orchestrator
        .scan(
      network,
      onHostComplete: (done, _) {
        _probed = done;
        _emit(isScanning: true);
      },
    )
        .listen(
      (observation) {
        final merged = _merge(_byIp[observation.ip], observation);
        _byIp[observation.ip] = _decorate(merged, store, typeStore);
        _emit(isScanning: true);
      },
      onError: (_) {},
      onDone: () => completer.complete(),
      cancelOnError: false,
    );

    await completer.future;
    _emit(isScanning: false);
    await _recordLatency(network, _byIp.values.toList());
    await _saveHistory(network, _byIp.values.toList());
  }

  Future<void> stopScan() async {
    _stopMonitoring();
    await _sub?.cancel();
    _sub = null;
    _emit(isScanning: false);
  }

  /// Turns live monitoring on or off. On enable, if the list is empty it runs a
  /// visible baseline scan to populate it; thereafter it re-scans every
  /// [_monitorInterval]. Each periodic re-scan runs *entirely in the background*
  /// (the on-screen list is untouched while it runs) and only when it completes
  /// is the result reconciled into the list: new devices added, missing ones
  /// greyed out (kept, not deleted), changed ones updated — and newly-appeared
  /// devices surfaced via [ScanState.lastNewDevices] for the alert.
  Future<void> toggleMonitoring(ScanNetwork network) async {
    if (_monitoring) {
      _stopMonitoring();
      return;
    }
    _monitoring = true;
    _monitorNetwork = network;
    _emit(); // reflect the monitoring-on state immediately
    if (state.devices.isEmpty && !state.isScanning) {
      await startScan(network); // visible initial populate
    }
    if (!_monitoring) return; // toggled off during the baseline scan
    _scheduleNextTick();
  }

  void _stopMonitoring() {
    _monitoring = false;
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _monitorSub?.cancel();
    _monitorSub = null;
    _emit();
  }

  void _scheduleNextTick() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer(_monitorInterval, _monitorTick);
  }

  Future<void> _monitorTick() async {
    if (!_monitoring || _monitorNetwork == null) return;
    final found = await _backgroundScan(_monitorNetwork!);
    if (!_monitoring) return; // toggled off mid-scan; discard
    await _recordLatency(_monitorNetwork!, found);
    final diff = _reconcile(found);
    // Only record a snapshot when something actually changed, so the history is
    // a meaningful change log rather than thousands of identical hourly dumps.
    if (diff.hasChanges) await _saveHistory(_monitorNetwork!, found);
    _scheduleNextTick();
  }

  /// Runs a full scan to completion without touching the displayed state,
  /// returning the decorated devices it found. The on-screen list keeps showing
  /// the previous results until [_reconcile] applies the delta.
  Future<List<Device>> _backgroundScan(ScanNetwork network) async {
    final store = await ref.read(renameStoreProvider.future);
    final typeStore = await ref.read(typeOverrideStoreProvider.future);
    final byIp = <String, Device>{};
    final orchestrator = ScanOrchestrator();
    final completer = Completer<void>();
    _monitorSub = orchestrator.scan(network).listen(
      (observation) {
        final merged = _merge(byIp[observation.ip], observation);
        byIp[observation.ip] = _decorate(merged, store, typeStore);
      },
      onError: (_) {},
      onDone: () => completer.complete(),
      cancelOnError: false,
    );
    await completer.future;
    return byIp.values.toList();
  }

  /// Applies a completed background scan ([found]) to the displayed list:
  /// upserts found devices as online, greys out devices that were not found,
  /// and raises the new-device alert for genuinely-new identities.
  ScanDiff _reconcile(List<Device> found) {
    final previous = _byIp.values.toList();
    final foundIds = {for (final d in found) _identityOf(d)};

    // Devices on screen but not found this pass → offline (kept, greyed).
    for (final ip in _byIp.keys.toList()) {
      final d = _byIp[ip]!;
      if (!foundIds.contains(_identityOf(d)) && d.isOnline) {
        _byIp[ip] = d.copyWith(isOnline: false);
      }
    }
    // Found devices → online; drop any stale duplicate at a former IP.
    for (final d in found) {
      final id = _identityOf(d);
      _byIp.removeWhere((ip, e) => ip != d.ip && _identityOf(e) == id);
      _byIp[d.ip] = d;
    }

    final diff = diffScans(previous, found);
    _emit();
    // A device that simply came back online at an IP it already occupied
    // (offline) is a reappearance, not a new device — even if its
    // fingerprint identity drifted slightly between passes.
    final genuinelyNew = excludeReappeared(diff.added, previous);
    if (genuinelyNew.isNotEmpty) {
      state = state.copyWith(lastNewDevices: genuinelyNew);
    }
    return diff;
  }

  /// Persists [devices] as a history snapshot for [network] (capped at
  /// [_historyRetention]) and refreshes the history view. Empty results aren't
  /// recorded — a scan that found nothing is noise, not history.
  Future<void> _saveHistory(ScanNetwork network, List<Device> devices) async {
    if (devices.isEmpty) return;
    final db = ref.read(historyDatabaseProvider);
    await db.saveScan(
      ScanRecord(
        networkId: network.id,
        networkLabel: network.displayName,
        timestamp: DateTime.now(),
        devices: devices,
      ),
      maxScans: _historyRetention,
    );
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
        mac: d.mac,
        hostname: d.hostname,
        openPorts: d.openPorts,
      );

  /// Combines a new observation for an IP with any existing record: unions the
  /// open ports and discovery sources, and keeps the first non-null hostname /
  /// MAC seen across sources.
  Device _merge(Device? existing, Device incoming) {
    if (existing == null) return incoming;
    return Device(
      ip: incoming.ip,
      mac: incoming.mac ?? existing.mac,
      hostname: incoming.hostname ?? existing.hostname,
      openPorts: <int>{...existing.openPorts, ...incoming.openPorts}.toList()
        ..sort(),
      services: {...existing.services, ...incoming.services},
      discoveredBy: {...existing.discoveredBy, ...incoming.discoveredBy},
      firstSeen: existing.firstSeen,
      lastSeen: incoming.lastSeen,
      networkId: incoming.networkId ?? existing.networkId,
      latencyMs: incoming.latencyMs ?? existing.latencyMs,
    );
  }

  Future<void> renameDevice(Device device, String? name) async {
    final store = await ref.read(renameStoreProvider.future);
    final id = _identityOf(device);
    await store.setName(id, name);
    final current = _byIp[device.ip];
    if (current != null) {
      _byIp[device.ip] = current.copyWith(customName: name);
      _emit();
    }
  }

  /// Sets (or clears, when [type] is null) a manual device type that overrides
  /// automatic classification, persisted by identity so it survives re-scans.
  Future<void> setDeviceType(Device device, DeviceType? type) async {
    final store = await ref.read(typeOverrideStoreProvider.future);
    final id = _identityOf(device);
    await store.setType(id, type);
    final current = _byIp[device.ip];
    if (current != null) {
      // When cleared, fall back to the original automatic classification.
      _byIp[device.ip] = current.copyWith(
        deviceType: type ?? _classify(current),
      );
      _emit();
    }
  }

  /// Applies the persisted custom name and manual type override (by identity)
  /// and resolves the vendor from the MAC.
  Device _decorate(Device device, RenameStore store, TypeOverrideStore types) {
    final id = _identityOf(device);
    final serviceLabels = device.services.values.toSet();
    // OUI vendor first; fall back to Bonjour-service inference for devices with
    // randomized/private MACs (e.g. Apple's Private Wi-Fi Address).
    final vendor =
        (device.mac != null ? _oui.vendorFor(device.mac!) : device.vendor) ??
            inferVendorFromServices(serviceLabels);
    final decorated = device.copyWith(vendor: vendor);
    // A manual type override wins over automatic classification.
    final type = types.typeFor(id) ?? _classify(decorated);

    return decorated.copyWith(
      customName: store.nameFor(id),
      deviceType: type,
      // ARP presence alone is a stale-cache risk; only mark online when the
      // device actively responded (ICMP/TCP/mDNS/NetBIOS/SSDP) this scan.
      isOnline: activelyReachable(
        decorated.discoveredBy,
        hasOpenPorts: decorated.openPorts.isNotEmpty,
      ),
    );
  }

  /// The automatic device-type classification for [device].
  DeviceType _classify(Device device) => classifyDevice(
        openPorts: device.openPorts.toSet(),
        vendor: device.vendor,
        hostname: device.hostname,
        services: device.services.values.toSet(),
        isGateway: _gatewayIp != null && device.ip == _gatewayIp,
      );

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
}
