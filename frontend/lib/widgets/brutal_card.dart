import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// The signature Soft Brutalist container.
///
/// Paper background, a thick 2px ink border, tight 8px radius, and a HARD
/// offset shadow (offset 4,4 / blurRadius 0) — the no-blur shadow is what
/// makes the look feel like a stamped block rather than a soft Material card.
///
/// Pass an [accent] color to add a chunky left border stripe (used to tag a
/// card's meaning, e.g. green = OK, red = error).
class BrutalCard extends StatelessWidget {
  const BrutalCard({
    super.key,
    required this.child,
    this.accent,
    this.background = Palette.paper,
    this.padding = const EdgeInsets.all(16),
    this.shadowOffset = const Offset(4, 4),
  });

  final Widget child;
  final Color? accent;
  final Color background;
  final EdgeInsetsGeometry padding;
  final Offset shadowOffset;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: Palette.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          // Hard offset shadow — the brutalist signature. No blur.
          BoxShadow(
            color: Palette.ink,
            offset: shadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      // Clip so the accent stripe respects the rounded corners.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (accent != null)
                Container(width: 8, color: accent),
              Expanded(
                child: Padding(padding: padding, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
