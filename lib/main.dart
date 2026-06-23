import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'ui/scan_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop: a properly resizable window with a sensible default and minimum
  // size, following native UX. Mobile platforms have no window to manage.
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1100, 720),
      minimumSize: Size(820, 520),
      center: true,
      title: 'Sextant',
      titleBarStyle: TitleBarStyle.normal,
    );
    unawaited(windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    }));
  }

  runApp(const ProviderScope(child: SextantApp()));
}

class SextantApp extends StatelessWidget {
  const SextantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sextant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4C8DFF),
          brightness: Brightness.dark,
        ),
        visualDensity: VisualDensity.compact,
      ),
      home: const ScanScreen(),
    );
  }
}
