import 'dart:async';
import 'dart:io';

import 'package:async/async.dart' show StreamGroup;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// Builds a stable, order-independent fingerprint of the host's current network
/// attachment: the set of interfaces and their addresses, plus the active Wi-Fi
/// IP. Two calls produce the same string iff the machine is attached to the
/// same networks the same way — so a change in the string means the network
/// changed (Wi-Fi switched, cable plugged/unplugged, DHCP lease moved).
String interfaceSignature(
  Map<String, List<String>> interfaceAddresses, {
  String? wifiIp,
}) {
  final names = interfaceAddresses.keys.toList()..sort();
  final parts = <String>[];
  for (final name in names) {
    final addrs = [...interfaceAddresses[name]!]..sort();
    parts.add('$name=${addrs.join(",")}');
  }
  return 'wifi:${wifiIp ?? "-"}|${parts.join(";")}';
}

/// Watches for changes to the host's network attachment and emits once per
/// real change, so the UI can re-discover networks and re-default to Wi-Fi when
/// the user moves between networks.
///
/// Triggered by `connectivity_plus` events (connect/disconnect/type-switch) —
/// but those events are coalesced/deduped against the [interfaceSignature],
/// because the plugin can fire spuriously *and* can miss a same-adapter Wi-Fi
/// SSID swap or DHCP change. A relaxed [safetyInterval] tick is merged in as a
/// backstop to catch any change the plugin doesn't surface.
class NetworkMonitor {
  NetworkMonitor({
    NetworkInfo? wifiInfo,
    this.safetyInterval = const Duration(seconds: 8),
  }) : _wifi = wifiInfo ?? NetworkInfo();

  final NetworkInfo _wifi;

  /// Backstop poll interval, merged with the connectivity event stream.
  final Duration safetyInterval;

  Future<String> currentSignature() async {
    final wifiIp = await _safe(_wifi.getWifiIP);
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    final map = <String, List<String>>{
      for (final i in interfaces)
        i.name: i.addresses.map((a) => a.address).toList(),
    };
    return interfaceSignature(map, wifiIp: wifiIp);
  }

  /// Emits each time the network signature changes (not on the initial state),
  /// yielding a monotonically increasing change count (1, 2, 3, …).
  ///
  /// The value is deliberately *distinct per change*: a `StreamProvider<void>`
  /// would collapse identical events because `AsyncData(null) == AsyncData(null)`,
  /// so a `ref.listen` would fire on the first change and never again. An
  /// increasing counter guarantees every change is observable downstream.
  ///
  /// [triggers] and [signatureReader] are injectable seams for testing; in
  /// production they default to the connectivity-event stream and the real
  /// interface read.
  Stream<int> changes({
    Stream<void>? triggers,
    Future<String> Function()? signatureReader,
  }) async* {
    final read = signatureReader ?? currentSignature;
    final source = triggers ?? _defaultTriggers();
    var last = await read();
    var count = 0;
    await for (final _ in source) {
      final sig = await read();
      if (sig != last) {
        last = sig;
        yield ++count;
      }
    }
  }

  /// connectivity_plus change events merged with a relaxed safety-net tick.
  Stream<void> _defaultTriggers() {
    final conn = Connectivity().onConnectivityChanged.map((_) {});
    final tick = Stream<void>.periodic(safetyInterval);
    return StreamGroup.merge<void>([conn, tick]);
  }

  static Future<String?> _safe(Future<String?> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      return null;
    }
  }
}
