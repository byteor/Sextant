import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../version.dart';

const _aboutIconAsset = 'assets/about/about_icon.png';
const _aboutTextAsset = 'assets/about/about_text.txt';

Future<void> showSextantAboutDialog(BuildContext context) async {
  final aboutText = (await rootBundle.loadString(_aboutTextAsset)).trim();
  if (!context.mounted) return;

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sextant'),
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
                  Text(aboutText),
                  const SizedBox(height: 12),
                  Text(kAboutVersion,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text('Built with Flutter.',
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
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
