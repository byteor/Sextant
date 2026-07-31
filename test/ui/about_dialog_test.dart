import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/l10n/gen/app_localizations.dart';
import 'package:sextant/l10n/supported_locales.dart';
import 'package:sextant/ui/about_dialog.dart';
import 'package:sextant/version.dart';

void main() {
  testWidgets('shows the Sextant title and the version string', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: kSupportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showSextantAboutDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Sextant'), findsOneWidget);
    expect(find.textContaining(kAboutVersion), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Sextant'), findsNothing);
  });
}
