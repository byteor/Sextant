import 'dart:convert';
import 'dart:io';

final _arpLine = RegExp(r'\(([0-9.]+)\) at ([0-9a-fA-F:]+)');

/// Parses the output of `arp -an` (BSD/macOS and Linux variants) into a map of
/// IPv4 address -> normalized MAC address. Incomplete entries are skipped.
Map<String, String> parseArpOutput(String output) {
  final table = <String, String>{};
  for (final line in const LineSplitter().convert(output)) {
    final match = _arpLine.firstMatch(line);
    if (match == null) continue;
    table[match.group(1)!] = normalizeMac(match.group(2)!);
  }
  return table;
}

/// Normalizes a MAC address to lower-case, colon-separated, two-digit octets
/// (e.g. `a4:83:e7:2b:0c:9` -> `a4:83:e7:2b:0c:09`).
String normalizeMac(String mac) {
  return mac
      .split(':')
      .map((octet) => octet.toLowerCase().padLeft(2, '0'))
      .join(':');
}

/// Reads the system ARP cache to resolve IPv4 addresses to MAC addresses.
///
/// Works on desktop (macOS/Linux/Windows). On mobile the ARP table is not
/// accessible without root, so [lookup] returns an empty map there.
class ArpResolver {
  const ArpResolver();

  Future<Map<String, String>> lookup() async {
    if (!(Platform.isMacOS || Platform.isLinux || Platform.isWindows)) {
      return const {};
    }
    try {
      final result = await Process.run('arp', ['-an']);
      if (result.exitCode != 0) return const {};
      return parseArpOutput(result.stdout as String);
    } on ProcessException {
      return const {};
    }
  }
}
