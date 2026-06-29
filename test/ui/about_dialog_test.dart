import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/ui/about_dialog.dart';

void main() {
  testWidgets('shows the Sextant title and the given version', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showSextantAboutDialog(context, '1.0.47'),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Sextant'), findsOneWidget);
    expect(find.textContaining('1.0.47'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Sextant'), findsNothing);
  });
}
