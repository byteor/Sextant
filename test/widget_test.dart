import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/main.dart';

void main() {
  testWidgets('app renders the Sextant toolbar', (tester) async {
    // The device table's fixed-width columns need more horizontal space than
    // flutter_test's default 800x600 surface, which would otherwise overflow
    // the header row before this test gets to look for anything. This only
    // widens the *test* surface — production layout is unaffected.
    await tester.binding.setSurfaceSize(const Size(1400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: SextantApp()));
    await tester.pump();

    expect(find.text('Sextant'), findsOneWidget);
  });
}
