import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/main.dart';

void main() {
  testWidgets('app renders the Sextant toolbar', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SextantApp()));
    await tester.pump();

    expect(find.text('Sextant'), findsOneWidget);
  });
}
