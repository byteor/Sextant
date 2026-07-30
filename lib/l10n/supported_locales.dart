import 'package:flutter/material.dart';

/// Locales this build ships and exposes in the Settings language picker.
///
/// This list is independent of which `app_*.arb` files exist under
/// `lib/l10n/` — a locale can be translated in-repo (and will show up in
/// `flutter gen-l10n`'s coverage warnings) without being added here, so it
/// isn't offered to users until it's ready to ship.
const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('ru'),
  Locale('es'),
  Locale('de'),
  Locale('fr'),
];

/// Each supported locale's name in its own language, for the picker, keyed by
/// language code — language names are conventionally shown untranslated (a
/// Russian speaker sees "Русский" regardless of the app's display language).
const Map<String, String> kLocaleNativeNames = {
  'en': 'English',
  'ru': 'Русский',
  'es': 'Español',
  'de': 'Deutsch',
  'fr': 'Français',
};
