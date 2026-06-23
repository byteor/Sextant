import 'dart:io';

import '../model/network_info.dart';

final _hwPort = RegExp(r'Hardware Port:\s*(.+)');
final _device = RegExp(r'Device:\s*(\S+)');

/// Classifies a macOS hardware-port label into a [LinkType]. On macOS the
/// interface *name* (en0, en4 …) is ambiguous — only the hardware-port label
/// distinguishes Wi-Fi from Ethernet/Thunderbolt — so we key off the label.
LinkType _linkTypeFromHardwarePort(String port) {
  final p = port.toLowerCase();
  if (p.contains('wi-fi') || p.contains('airport')) return LinkType.wifi;
  if (p.contains('ethernet') ||
      p.contains('thunderbolt') ||
      p.contains('lan')) {
    return LinkType.wired;
  }
  return LinkType.other; // iPhone USB tether, Bluetooth PAN, etc.
}

/// Parses `networksetup -listallhardwareports` into a device-name → [LinkType]
/// map. This is the authoritative source for wired-vs-wireless on macOS, where
/// the bare interface name doesn't reveal the physical medium.
Map<String, LinkType> parseMacHardwarePorts(String output) {
  final types = <String, LinkType>{};
  String? pendingPort;
  for (final line in output.split('\n')) {
    final portMatch = _hwPort.firstMatch(line);
    if (portMatch != null) {
      pendingPort = portMatch.group(1)!.trim();
      continue;
    }
    final deviceMatch = _device.firstMatch(line);
    if (deviceMatch != null && pendingPort != null) {
      types[deviceMatch.group(1)!] = _linkTypeFromHardwarePort(pendingPort);
      pendingPort = null;
    }
  }
  return types;
}

final _wirelessName = RegExp(r'^(wlan|wlp|wl\d|wifi)', caseSensitive: false);
final _wiredName = RegExp(r'^(eth|enp|ens|eno)', caseSensitive: false);

/// A best-effort link-type guess from an interface name alone, for platforms
/// where we have no richer source. Deliberately returns [LinkType.other] for
/// names that are genuinely ambiguous (bare `en0` on macOS is Wi-Fi *or*
/// Ethernet) rather than guessing wrong.
LinkType linkTypeFromName(String name) {
  if (_wirelessName.hasMatch(name)) return LinkType.wifi;
  if (_wiredName.hasMatch(name)) return LinkType.wired;
  return LinkType.other;
}

/// Resolves the physical link type of each network interface, using the most
/// authoritative source available per platform: `networksetup` on macOS, the
/// name heuristic elsewhere. Returns an empty map when nothing can be
/// determined (the caller falls back to [linkTypeFromName]).
class InterfaceTyper {
  const InterfaceTyper();

  Future<Map<String, LinkType>> typeAll() async {
    try {
      if (Platform.isMacOS) {
        final r = await Process.run(
          'networksetup',
          ['-listallhardwareports'],
        );
        if (r.exitCode == 0) return parseMacHardwarePorts(r.stdout as String);
      }
    } on ProcessException {
      return const {};
    }
    return const {};
  }
}
