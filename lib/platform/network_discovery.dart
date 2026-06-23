import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

import '../model/network_info.dart';
import '../scan/ipv4_subnet.dart';
import 'interface_mask.dart';
import 'interface_typer.dart';

/// Calls [fn], retrying while it returns an empty list, up to [attempts] times
/// with [delay] between tries. Returns the first non-empty result, or the last
/// (empty) result once the budget is exhausted.
///
/// This makes network discovery resilient to the transient where a network
/// change fires *while the new network is still coming up* (no IP yet): the one
/// re-discovery would otherwise cache an empty result and strand the UI on "No
/// active network found" until the next change. Retrying spans the settle
/// window so we land on the live network instead.
Future<List<T>> retryWhileEmpty<T>(
  Future<List<T>> Function() fn, {
  int attempts = 6,
  Duration delay = const Duration(milliseconds: 700),
}) async {
  var result = <T>[];
  for (var i = 0; i < attempts; i++) {
    result = await fn();
    if (result.isNotEmpty) return result;
    if (i < attempts - 1) await Future<void>.delayed(delay);
  }
  return result;
}

/// Discovers the active local networks the user can scan.
///
/// Each network's true subnet mask is read from the OS via
/// [InterfaceMaskResolver] (Dart's [NetworkInterface] does not expose it), so a
/// /22 is scanned as a /22 rather than being silently truncated to /24. The
/// Wi-Fi interface is identified by matching its IP (from `network_info_plus`)
/// and is returned first so the UI can default to it.
class NetworkDiscovery {
  NetworkDiscovery({
    NetworkInfo? wifiInfo,
    InterfaceMaskResolver? maskResolver,
    InterfaceTyper? typer,
  })  : _wifi = wifiInfo ?? NetworkInfo(),
        _masks = maskResolver ?? const InterfaceMaskResolver(),
        _typer = typer ?? const InterfaceTyper();

  final NetworkInfo _wifi;
  final InterfaceMaskResolver _masks;
  final InterfaceTyper _typer;

  /// Discovers the active networks, retrying briefly while none are found so a
  /// scan triggered mid-network-change doesn't strand on an empty result while
  /// the new network is still acquiring its address.
  Future<List<ScanNetwork>> discover() => retryWhileEmpty(_discoverOnce);

  Future<List<ScanNetwork>> _discoverOnce() async {
    final wifiIp = await _safe(_wifi.getWifiIP);
    final ssid = _cleanSsid(await _safe(_wifi.getWifiName));
    final gatewayIp = await _safe(_wifi.getWifiGatewayIP);
    final linkTypes = await _typer.typeAll();

    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    final networks = <ScanNetwork>[];
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (addr.address.startsWith('169.254')) continue; // link-local
        final prefix = await _masks.prefixFor(interface.name) ?? 24;
        // The interface carrying the OS-reported Wi-Fi IP is authoritatively
        // Wi-Fi; otherwise trust the platform typer, then the name heuristic.
        final isWifi = wifiIp != null && addr.address == wifiIp;
        final linkType = isWifi
            ? LinkType.wifi
            : linkTypes[interface.name] ?? linkTypeFromName(interface.name);
        networks.add(
          ScanNetwork(
            interfaceName: interface.name,
            displayName: isWifi ? (ssid ?? interface.name) : interface.name,
            address: addr,
            subnet: Ipv4Subnet.fromHostAndPrefix(addr, prefix),
            gateway: isWifi && gatewayIp != null && gatewayIp.isNotEmpty
                ? InternetAddress(gatewayIp)
                : null,
            linkType: linkType,
          ),
        );
      }
    }

    // Wi-Fi first so the UI defaults to it.
    networks.sort((a, b) {
      if (a.isWireless == b.isWireless) return 0;
      return a.isWireless ? -1 : 1;
    });
    return networks;
  }

  static String? _cleanSsid(String? ssid) {
    if (ssid == null || ssid.isEmpty) return null;
    return ssid.replaceAll('"', '').trim();
  }

  static Future<String?> _safe(Future<String?> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      return null;
    }
  }
}
