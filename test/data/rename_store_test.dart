import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/data/rename_store.dart';

void main() {
  group('RenameStore', () {
    late Directory tempDir;
    late File file;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sextant_rename_test');
      file = File('${tempDir.path}/names.json');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('returns null for an unknown identity', () async {
      final store = RenameStore(file);
      await store.load();
      expect(store.nameFor('mac:aa:bb:cc:dd:ee:ff'), isNull);
    });

    test('stores and retrieves a name by identity', () async {
      final store = RenameStore(file);
      await store.load();
      await store.setName('mac:aa:bb:cc:dd:ee:ff', 'Office Printer');
      expect(store.nameFor('mac:aa:bb:cc:dd:ee:ff'), 'Office Printer');
    });

    test('persists names across reloads', () async {
      final first = RenameStore(file);
      await first.load();
      await first.setName('mac:aa:bb:cc:dd:ee:ff', 'Office Printer');

      final second = RenameStore(file);
      await second.load();
      expect(second.nameFor('mac:aa:bb:cc:dd:ee:ff'), 'Office Printer');
    });

    test('clearing a name removes it', () async {
      final store = RenameStore(file);
      await store.load();
      await store.setName('mac:aa:bb:cc:dd:ee:ff', 'Office Printer');
      await store.setName('mac:aa:bb:cc:dd:ee:ff', null);
      expect(store.nameFor('mac:aa:bb:cc:dd:ee:ff'), isNull);
    });
  });
}
