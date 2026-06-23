import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/enrich/oui_refresh.dart';
import 'package:sextant/enrich/oui_vendor_lookup.dart';

void main() {
  group('parseOuiCsv', () {
    test('parses Registry,Assignment,Organization Name,Address rows', () {
      const csv = 'Registry,Assignment,Organization Name,Organization Address\n'
          'MA-L,001122,Acme Corp,123 Main St\n';

      expect(parseOuiCsv(csv), {'001122': 'Acme Corp'});
    });

    test('parses quoted organization names containing commas', () {
      const csv = 'Registry,Assignment,Organization Name,Organization Address\n'
          'MA-L,A483E7,"LEXMARK INTERNATIONAL, INC.",740 New Circle Road NW\n';

      expect(parseOuiCsv(csv), {'A483E7': 'LEXMARK INTERNATIONAL, INC.'});
    });

    test('skips rows with a malformed OUI or empty organization', () {
      const csv = 'Registry,Assignment,Organization Name,Organization Address\n'
          'MA-L,BAD,Some Org,Addr\n'
          'MA-L,AABBCC,,Addr\n';

      expect(parseOuiCsv(csv), isEmpty);
    });
  });

  test('ouiTableToTsv round-trips through parseOuiTsv', () {
    const table = {'AABBCC': 'Acme, Inc.', '112233': 'Other Co'};

    expect(parseOuiTsv(ouiTableToTsv(table)), table);
  });

  group('OuiRefresher.refreshIfStale', () {
    late Directory tempDir;
    late File cacheFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('oui_refresh_test');
      cacheFile = File('${tempDir.path}/oui_cache.tsv');
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test('fetches and writes the cache when none exists yet', () async {
      final refresher = OuiRefresher(
        fetch: (uri) async => 'Registry,Assignment,Organization Name,Address\n'
            'MA-L,AABBCC,Acme Corp,1 Main St\n',
      );

      final refreshed = await refresher.refreshIfStale(cacheFile);

      expect(refreshed, isTrue);
      expect(await cacheFile.exists(), isTrue);
      expect(parseOuiTsv(await cacheFile.readAsString()), {'AABBCC': 'Acme Corp'});
    });

    test('does not refetch when the cache is younger than maxAge', () async {
      await cacheFile.writeAsString('AABBCC\tOld Vendor\n');
      var fetched = false;
      final refresher = OuiRefresher(fetch: (uri) async {
        fetched = true;
        return 'Registry,Assignment,Organization Name,Address\nMA-L,AABBCC,New Vendor,Addr\n';
      });

      final refreshed = await refresher.refreshIfStale(cacheFile);

      expect(refreshed, isFalse);
      expect(fetched, isFalse);
      expect(await cacheFile.readAsString(), 'AABBCC\tOld Vendor\n');
    });

    test('refetches when the cache is older than maxAge', () async {
      await cacheFile.writeAsString('AABBCC\tOld Vendor\n');
      await cacheFile.setLastModified(
        DateTime.now().subtract(const Duration(days: 31)),
      );
      final refresher = OuiRefresher(
        maxAge: const Duration(days: 30),
        fetch: (uri) async =>
            'Registry,Assignment,Organization Name,Address\nMA-L,AABBCC,New Vendor,Addr\n',
      );

      final refreshed = await refresher.refreshIfStale(cacheFile);

      expect(refreshed, isTrue);
      expect(parseOuiTsv(await cacheFile.readAsString()), {'AABBCC': 'New Vendor'});
    });

    test('leaves the cache untouched when the fetch fails', () async {
      await cacheFile.writeAsString('AABBCC\tOld Vendor\n');
      await cacheFile.setLastModified(
        DateTime.now().subtract(const Duration(days: 31)),
      );
      final refresher = OuiRefresher(fetch: (uri) async => null);

      final refreshed = await refresher.refreshIfStale(cacheFile);

      expect(refreshed, isFalse);
      expect(await cacheFile.readAsString(), 'AABBCC\tOld Vendor\n');
    });
  });
}
