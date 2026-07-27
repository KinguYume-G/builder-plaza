import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// The signature Soft Brutalist container.
///
/// A thick 2px ink border, tight 8px radius, and a HARD offset shadow
/// (offset 4,4 / blurRadius 0) — the no-blur shadow is what makes the look
/// feel like a stamped block rather than a soft Material card.
///
/// Pass an [accent] color to shallow-tint the whole background (e.g. green =
/// OK, red = error) rather than drawing a left-edge stripe. A solid stripe
/// next to a white card is a very recognisable "AI-generated dashboard"
/// pattern; a faint overall tint reads as an actual designed color system.
class BrutalCard extends StatelessWidget {
  const BrutalCard({
    super.key,
    required this.child,
    this.accent,
    this.background = Palette.paper,
    this.padding = const EdgeInsets.all(16),
    this.shadowOffset = const Offset(4, 4),
    this.flat = false,
    this.signature = false,
  });

  final Widget child;
  final Color? accent;
  final Color background;
  final EdgeInsetsGeometry padding;
  final Offset shadowOffset;

  /// When true, drops the shadow entirely and thins the border to a hairline.
  /// Use this for rows in a repeating list (timeline events, reviews, repo
  /// roles, ...) -- any per-row shadow reads as "this is a distinct,
  /// important block", and applying that to every row in a 20-30 item list
  /// just produces visual noise instead of emphasis.
  final bool flat;

  /// When true, keeps the full hard-offset "stamp" shadow + 2px ink border.
  /// This is deliberately rare: reserved for the one card per screen that
  /// represents externally-verified evidence (Trust Score, Ownership
  /// Evidence) so the stamp itself carries meaning -- "this is certified
  /// data" -- instead of being applied to every card as decoration.
  /// Ignored when [flat] is true.
  final bool signature;

  /// Flat list-row cards keep a single calm tint (no gradient) so the
  /// density fix from flattening long lists doesn't get undone; standalone
  /// hero cards get the richer two-stop gradient tint.
  Color? get _flatFill => accent == null
      ? background
      : Color.alphaBlend(accent!.withValues(alpha: 0.12), background);

  @override
  Widget build(BuildContext context) {
    final useGradient = accent != null && !flat;
    final borderColor = flat ? Palette.ink200 : Palette.ink;
    final borderWidth = flat ? 1.25 : (signature ? 2.0 : 1.5);
    return Container(
      decoration: BoxDecoration(
        color: useGradient ? null : _flatFill,
        gradient: useGradient
            ? Palette.glowTint(accent!, background: background)
            : null,
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(8),
        boxShadow: flat
            ? const []
            : (signature
                ? [
                    // Hard offset shadow — reserved for verified/certified
                    // evidence. No blur.
                    BoxShadow(
                      color: Palette.ink,
                      offset: shadowOffset,
                      blurRadius: 0,
                    ),
                  ]
                : Palette.softShadow),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
