import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/platform/arp_table.dart';

void main() {
  group('parseArpOutput', () {
    test('extracts ip -> normalized MAC from BSD/macOS arp -an output', () {
      const output = '''
? (192.168.1.1) at ac:de:48:0:11:22 on en0 ifscope [ethernet]
? (192.168.1.42) at a4:83:e7:2b:0c:9 on en0 ifscope [ethernet]
''';

      final table = parseArpOutput(output);

      // Single-digit octets are zero-padded to two digits, lowercased.
      expect(table['192.168.1.1'], 'ac:de:48:00:11:22');
      expect(table['192.168.1.42'], 'a4:83:e7:2b:0c:09');
    });

    test('skips incomplete entries', () {
      const output = '''
? (192.168.1.1) at ac:de:48:00:11:22 on en0 ifscope [ethernet]
? (192.168.1.99) at (incomplete) on en0 [ethernet]
''';

      final table = parseArpOutput(output);

      expect(table.containsKey('192.168.1.1'), isTrue);
      expect(table.containsKey('192.168.1.99'), isFalse);
    });

    test('parses Linux "arp -an" output with HWaddress column', () {
      const output =
          '? (10.0.0.1) at 00:1a:2b:3c:4d:5e [ether] on eth0';

      final table = parseArpOutput(output);

      expect(table['10.0.0.1'], '00:1a:2b:3c:4d:5e');
    });
  });
}
