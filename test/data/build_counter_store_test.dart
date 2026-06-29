import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/data/build_counter_store.dart';

void main() {
  late Directory tempDir;
  late File file;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sextant_build_counter_test');
    file = File('${tempDir.path}/build_counter.json');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('first call on a missing file returns 1 and persists it', () async {
    final store = BuildCounterStore(file);
    expect(await store.loadAndIncrement(), 1);
  });

  test('repeated calls increment by 1 each time, persisted across instances',
      () async {
    expect(await BuildCounterStore(file).loadAndIncrement(), 1);
    expect(await BuildCounterStore(file).loadAndIncrement(), 2);
    expect(await BuildCounterStore(file).loadAndIncrement(), 3);
  });

  test('a corrupt file resets to 0 then increments to 1', () async {
    await file.create(recursive: true);
    await file.writeAsString('not json{{{');
    expect(await BuildCounterStore(file).loadAndIncrement(), 1);
  });
}
