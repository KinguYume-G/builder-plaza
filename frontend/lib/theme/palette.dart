import 'package:flutter/painting.dart';

/// Soft Brutalist color palette for Builder Plaza.
///
/// All colors used across the app are defined here as a single source of
/// truth. Never hard-code hex values in widgets — reference [Palette] instead.
abstract final class Palette {
  // Surfaces (warm paper tones)
  static const Color paper = Color(0xFFFFFEF8);
  static const Color cream50 = Color(0xFFFAF6EC);
  static const Color cream100 = Color(0xFFF4ECD8);

  // Ink (text + borders)
  static const Color ink = Color(0xFF0A0A0A);
  static const Color ink600 = Color(0xFF3D3D3D);
  static const Color ink400 = Color(0xFF857C70);
  static const Color ink200 = Color(0xFFCFC8BD);

  // Accents
  static const Color cobalt = Color(0xFF1E3AFF);
  static const Color tomato = Color(0xFFFF4D2E);
  static const Color mustard = Color(0xFFF4B400);
  static const Color lime = Color(0xFF5BD27D);
  static const Color plum = Color(0xFF7C3AED);
}
