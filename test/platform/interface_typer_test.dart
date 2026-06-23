import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/model/network_info.dart';
import 'package:sextant/platform/interface_typer.dart';

void main() {
  group('parseMacHardwarePorts', () {
    test('maps each device to its hardware-port link type', () {
      // Real `networksetup -listallhardwareports` shape.
      const out = '''
Hardware Port: Wi-Fi
Device: en0
Ethernet Address: a4:83:e7:00:00:01

Hardware Port: Ethernet
Device: en4
Ethernet Address: 38:f9:d3:00:00:02

Hardware Port: Thunderbolt Bridge
Device: bridge0
Ethernet Address: 36:5a:1a:00:00:03

Hardware Port: iPhone USB
Device: en6
Ethernet Address: N/A
''';
      final types = parseMacHardwarePorts(out);
      expect(types['en0'], LinkType.wifi);
      expect(types['en4'], LinkType.wired);
      expect(types['bridge0'], LinkType.wired); // Thunderbolt Bridge
      expect(types['en6'], LinkType.other); // iPhone USB tether
    });

    test('treats AirPort (older macOS) as Wi-Fi', () {
      const out = 'Hardware Port: AirPort\nDevice: en1\n';
      expect(parseMacHardwarePorts(out)['en1'], LinkType.wifi);
    });

    test('returns empty for unrecognised output', () {
      expect(parseMacHardwarePorts('nonsense'), isEmpty);
    });
  });

  group('linkTypeFromName', () {
    test('classifies common wireless interface names', () {
      expect(linkTypeFromName('wlan0'), LinkType.wifi);
      expect(linkTypeFromName('wlp3s0'), LinkType.wifi);
    });

    test('classifies common wired interface names', () {
      expect(linkTypeFromName('eth0'), LinkType.wired);
      expect(linkTypeFromName('enp0s3'), LinkType.wired);
    });

    test('is unsure about ambiguous macOS en names', () {
      // On macOS en0 can be Wi-Fi OR Ethernet — the heuristic must not guess.
      expect(linkTypeFromName('en0'), LinkType.other);
    });

    test('classifies tunnels/bridges as other', () {
      expect(linkTypeFromName('utun3'), LinkType.other);
      expect(linkTypeFromName('bridge0'), LinkType.other);
    });
  });
}
