import 'dart:convert';
import 'dart:io';

/// Matches BSD/macOS/Linux `arp -an` lines, e.g.
/// `? (192.168.1.1) at ac:de:48:00:11:22 on en0 ifscope [ethernet]`.
final _bsdArpLine = RegExp(r'\(([0-9.]+)\) at ([0-9a-fA-F:]+)');

/// Matches Windows `arp -a` table rows, e.g.
/// `  192.168.1.1           00-14-22-01-23-45     dynamic`. Windows has no
/// parentheses/`at` and hyphenates the MAC instead of using colons.
final _windowsArpLine = RegExp(
  r'^\s*([\d.]+)\s+([0-9a-fA-F]{2}(?:-[0-9a-fA-F]{2}){5})\s',
);

/// Builds the platform-appropriate arguments for the system `arp` binary.
/// Windows's `arp.exe` doesn't understand the combined BSD/Linux `-an` flag
/// (no `-n` support at all); it just takes `-a`.
List<String> buildArpArgs({required bool isWindows}) =>
    isWindows ? const ['-a'] : const ['-an'];

/// Parses the output of the system `arp` command into a map of IPv4 address
/// -> normalized MAC address. Incomplete entries are skipped. Accepts both
/// the BSD/macOS/Linux format and the differently-shaped Windows format.
Map<String, String> parseArpOutput(String output) {
  final table = <String, String>{};
  for (final line in const LineSplitter().convert(output)) {
    final bsdMatch = _bsdArpLine.firstMatch(line);
    if (bsdMatch != null) {
      table[bsdMatch.group(1)!] = normalizeMac(bsdMatch.group(2)!);
      continue;
    }
    final winMatch = _windowsArpLine.firstMatch(line);
    if (winMatch != null) {
      table[winMatch.group(1)!] = normalizeMac(winMatch.group(2)!);
    }
  }
  return table;
}

/// Normalizes a MAC address to lower-case, colon-separated, two-digit octets
/// (e.g. `a4:83:e7:2b:0c:9` -> `a4:83:e7:2b:0c:09`,
/// `00-14-22-01-23-45` -> `00:14:22:01:23:45`).
String normalizeMac(String mac) {
  return mac
      .split(RegExp('[:-]'))
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
      final args = buildArpArgs(isWindows: Platform.isWindows);
      final result = await Process.run('arp', args);
      if (result.exitCode != 0) return const {};
      return parseArpOutput(result.stdout as String);
    } on ProcessException {
      return const {};
    }
  }
}
