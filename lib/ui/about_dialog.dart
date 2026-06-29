import 'package:flutter/material.dart';

/// Shows the app's About dialog: name, a short description, and the current
/// version.
void showSextantAboutDialog(BuildContext context, String version) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sextant'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A lightweight LAN scanner for discovering and monitoring '
            'devices on your local network.',
          ),
          const SizedBox(height: 12),
          Text('Version $version',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text('Built with Flutter.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
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
