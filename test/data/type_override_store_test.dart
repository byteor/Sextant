import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/data/type_override_store.dart';
import 'package:sextant/model/discovery_source.dart';

void main() {
  group('TypeOverrideStore', () {
    late Directory tempDir;
    late File file;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sextant_type_test');
      file = File('${tempDir.path}/types.json');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('returns null for an unknown identity', () async {
      final store = TypeOverrideStore(file);
      await store.load();
      expect(store.typeFor('mac:aa:bb:cc:dd:ee:ff'), isNull);
    });

    test('stores and retrieves a manual type by identity', () async {
      final store = TypeOverrideStore(file);
      await store.load();
      await store.setType('mac:aa:bb:cc:dd:ee:ff', DeviceType.printer);
      expect(store.typeFor('mac:aa:bb:cc:dd:ee:ff'), DeviceType.printer);
    });

    test('persists overrides across reloads', () async {
      final first = TypeOverrideStore(file);
      await first.load();
      await first.setType('mac:aa:bb:cc:dd:ee:ff', DeviceType.nas);

      final second = TypeOverrideStore(file);
      await second.load();
      expect(second.typeFor('mac:aa:bb:cc:dd:ee:ff'), DeviceType.nas);
    });

    test('clearing an override removes it', () async {
      final store = TypeOverrideStore(file);
      await store.load();
      await store.setType('mac:aa:bb:cc:dd:ee:ff', DeviceType.camera);
      await store.setType('mac:aa:bb:cc:dd:ee:ff', null);
      expect(store.typeFor('mac:aa:bb:cc:dd:ee:ff'), isNull);
    });

    test('ignores an unrecognised stored type name', () async {
      await file.writeAsString('{"mac:aa:bb:cc:dd:ee:ff":"banana"}');
      final store = TypeOverrideStore(file);
      await store.load();
      expect(store.typeFor('mac:aa:bb:cc:dd:ee:ff'), isNull);
    });
  });
}
