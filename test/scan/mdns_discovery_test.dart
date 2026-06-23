import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/scan/mdns_discovery.dart';

void main() {
  group('mdnsServiceLabel', () {
    test('maps common Bonjour service types to friendly labels', () {
      expect(mdnsServiceLabel('_airplay._tcp'), 'AirPlay');
      expect(mdnsServiceLabel('_googlecast._tcp'), 'Chromecast');
      expect(mdnsServiceLabel('_ipp._tcp'), 'Printer');
      expect(mdnsServiceLabel('_raop._tcp'), 'AirPlay Audio');
      expect(mdnsServiceLabel('_smb._tcp'), 'File Sharing (SMB)');
    });

    test('handles a trailing .local and proto-only forms', () {
      expect(mdnsServiceLabel('_airplay._tcp.local'), 'AirPlay');
    });

    test('returns null for unknown service types', () {
      expect(mdnsServiceLabel('_obscureservice._tcp'), isNull);
    });
  });

  group('mdnsInstanceName', () {
    test('extracts the instance label from a PTR name', () {
      expect(
        mdnsInstanceName('Living Room._airplay._tcp.local'),
        'Living Room',
      );
    });

    test('decodes DNS-SD escaping (\\032 -> space)', () {
      expect(
        mdnsInstanceName(r'Brother\032HL-L2350DW._ipp._tcp.local'),
        'Brother HL-L2350DW',
      );
    });

    test('returns the input when it has no service suffix', () {
      expect(mdnsInstanceName('Bedroom Speaker'), 'Bedroom Speaker');
    });
  });
}
