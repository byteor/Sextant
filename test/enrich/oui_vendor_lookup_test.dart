import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/enrich/oui_vendor_lookup.dart';

void main() {
  group('OuiVendorLookup', () {
    final lookup = OuiVendorLookup({
      'A483E7': 'Apple, Inc.',
      'ACDE48': 'Private',
    });

    test('resolves a vendor from the first three octets of a MAC', () {
      expect(lookup.vendorFor('a4:83:e7:2b:0c:09'), 'Apple, Inc.');
    });

    test('is case- and separator-insensitive', () {
      expect(lookup.vendorFor('A4-83-E7-2B-0C-09'), 'Apple, Inc.');
      expect(lookup.vendorFor('a483e72b0c09'), 'Apple, Inc.');
    });

    test('returns null for an unknown OUI', () {
      expect(lookup.vendorFor('00:11:22:33:44:55'), isNull);
    });

    test('returns null for a malformed MAC', () {
      expect(lookup.vendorFor('not-a-mac'), isNull);
    });
  });

  group('parseOuiTsv', () {
    test('parses OUI\\tVendor lines, skipping blanks and malformed rows', () {
      const tsv = 'A483E7\tApple, Inc.\n'
          '\n'
          'ACDE48\tPrivate\n'
          'BADLINE_NO_TAB\n';
      final table = parseOuiTsv(tsv);

      expect(table, hasLength(2));
      expect(table['A483E7'], 'Apple, Inc.');
      expect(table['ACDE48'], 'Private');
    });
  });
}
