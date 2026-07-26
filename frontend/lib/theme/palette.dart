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

  // Accents -- a "circuit board" tech palette. Originally blue (cobalt) +
  // purple (plum) for primary/intent, but that pairing reads as generic
  // "AI product" branding -- deliberately moved away from it: teal reads as
  // terminal/circuit rather than chatbot-blue, copper as literal circuit
  // wiring rather than gradient-purple. Same semantic slots as before
  // (lime=trust, mustard=evidence, tomato=error/simulated, teal=primary,
  // copper=intent), different hue family.
  static const Color teal = Color(0xFF1F7A6C);
  static const Color tomato = Color(0xFFB8503A);
  static const Color mustard = Color(0xFFB08A2E);
  static const Color lime = Color(0xFF3F8259);
  static const Color copper = Color(0xFF8B5E3C);

  // Role-identity colors -- separate from the five feature-semantic accents
  // above (teal/lime were both being reused for "Builder" and "Collaborator"
  // respectively, and read as near-identical greens at card scale). Rose and
  // tangerine are picked to sit far from teal on the wheel, and far from each
  // other, without drifting into blue/purple or yellow.
  static const Color rose = Color(0xFFC43D6E);
  static const Color tangerine = Color(0xFFE07830);

  /// Hue-shifts [base] toward a more saturated "glow" partner for a gradient
  /// second stop: +18° hue, +22% saturation, but only +7% lightness. The
  /// small lightness delta is deliberate -- whatever text color already
  /// reads fine on [base] stays legible across the whole gradient, instead
  /// of gambling on contrast at a dramatically brighter end.
  static Color _glowPartner(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withHue((hsl.hue + 18) % 360)
        .withSaturation((hsl.saturation + 0.22).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + 0.07).clamp(0.0, 1.0))
        .toColor();
  }

  /// A vivid two-stop gradient for title bars and filled buttons: [base]
  /// through to its [_glowPartner]. Same lightness band as [base], so this
  /// is a drop-in replacement for a flat [base] fill wherever text color was
  /// already chosen for [base].
  static LinearGradient glow(
    Color base, {
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(begin: begin, end: end, colors: [base, _glowPartner(base)]);
  }

  /// A pale two-stop tint gradient for content-heavy hero cards, where a
  /// full-strength [glow] would risk contrast against arbitrary body text.
  /// Both stops stay mostly [background], tinted by [base] and its glow
  /// partner respectively.
  static LinearGradient glowTint(
    Color base, {
    Color background = paper,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [
        Color.alphaBlend(base.withValues(alpha: 0.14), background),
        Color.alphaBlend(_glowPartner(base).withValues(alpha: 0.14), background),
      ],
    );
  }
}
