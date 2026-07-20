import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/typography.dart';

/// A small colored box/pill used for tags and status labels.
///
/// 2px ink border and a smaller 2px hard shadow so it reads as a stamped chip.
/// Optionally [selectable] + [selected] to act as a toggle (used by the role
/// selector on the login screen).
class BrutalBadge extends StatelessWidget {
  const BrutalBadge({
    super.key,
    required this.label,
    this.color = Palette.mustard,
    this.textColor = Palette.ink,
    this.onTap,
    this.selected = true,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  /// When false, the badge renders "dimmed" (unfilled) — used for unselected
  /// options in a tappable group.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? color : Palette.paper;

    final badge = Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: Palette.ink, width: 2),
        borderRadius: BorderRadius.circular(6),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Palette.ink,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ]
            : const [],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        label.toUpperCase(),
        style: AppType.mono(
          size: 12,
          color: selected ? textColor : Palette.ink400,
          weight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );

    if (onTap == null) return badge;
    return GestureDetector(onTap: onTap, child: badge);
  }
}
