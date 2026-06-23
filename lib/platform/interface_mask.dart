import 'dart:io';

final _ifconfigMask = RegExp(r'netmask\s+0x([0-9a-fA-F]{8})');
final _ipCidr = RegExp(r'inet\s+[0-9.]+/(\d{1,2})');

/// Parses a BSD/macOS `ifconfig <iface>` block and returns the prefix length
/// from its hex `netmask 0x........`, or null if absent.
int? prefixFromIfconfig(String output) {
  final match = _ifconfigMask.firstMatch(output);
  if (match == null) return null;
  final mask = int.parse(match.group(1)!, radix: 16);
  return _popcount(mask);
}

/// Parses Linux `ip -o -f inet addr show <iface>` output and returns the prefix
/// length from the `inet x.x.x.x/NN` field, or null if absent.
int? prefixFromIpAddr(String output) {
  final match = _ipCidr.firstMatch(output);
  if (match == null) return null;
  return int.parse(match.group(1)!);
}

int _popcount(int value) {
  var count = 0;
  var v = value;
  while (v != 0) {
    count += v & 1;
    v >>= 1;
  }
  return count;
}

/// Resolves the real IPv4 prefix length of a named interface by querying the
/// OS, since Dart's [NetworkInterface] does not expose the netmask. Returns null
/// on platforms/interfaces where it can't be determined (caller falls back).
class InterfaceMaskResolver {
  const InterfaceMaskResolver();

  Future<int?> prefixFor(String interfaceName) async {
    try {
      if (Platform.isMacOS) {
        final r = await Process.run('ifconfig', [interfaceName]);
        return r.exitCode == 0 ? prefixFromIfconfig(r.stdout as String) : null;
      }
      if (Platform.isLinux) {
        final r = await Process.run(
          'ip',
          ['-o', '-f', 'inet', 'addr', 'show', interfaceName],
        );
        return r.exitCode == 0 ? prefixFromIpAddr(r.stdout as String) : null;
      }
    } on ProcessException {
      return null;
    }
    return null;
  }
}
