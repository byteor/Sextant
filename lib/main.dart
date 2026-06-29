import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'state/settings.dart';
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

class SextantApp extends ConsumerWidget {
  const SextantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Falls back to dark (today's fixed look) while settings are loading or
    // if they fail to load, so the very first frame is never broken.
    final themeMode =
        ref.watch(settingsProvider).value?.themeMode ?? ThemeMode.dark;

    return MaterialApp(
      title: 'Sextant',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4C8DFF),
          brightness: Brightness.light,
        ),
        visualDensity: VisualDensity.compact,
      ),
      darkTheme: ThemeData(
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
