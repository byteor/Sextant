import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../l10n/gen/app_localizations.dart';
import '../version.dart';

const _aboutIconAsset = 'assets/about/about_icon.png';

Future<void> showSextantAboutDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.aboutTitle),
      content: SizedBox(
        width: 420,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(_aboutIconAsset, width: 96, height: 96),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(data: l10n.aboutBody),
                  const SizedBox(height: 12),
                  Text(kAboutVersion,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(l10n.builtWithFlutter,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    ),
  );
}
