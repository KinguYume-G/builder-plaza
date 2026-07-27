import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/typography.dart';

/// A bordered dropdown matching the Brutal design system, for compact
/// single-choice filters/switches (view mode, stage, role) that would
/// otherwise need a row of selectable badges.
class BrutalDropdown<T> extends StatelessWidget {
  const BrutalDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.borderColor = Palette.ink,
    this.expanded = false,
  });

  final T value;

  /// (value, label) pairs, in display order.
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final Color borderColor;

  /// When true, the dropdown fills the width of its parent (e.g. it's the
  /// only control on its line) instead of sizing to its selected label.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.paper,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: expanded,
          icon: const Icon(Icons.expand_more, size: 16, color: Palette.ink),
          style: AppType.mono(size: 12, weight: FontWeight.w700, color: Palette.ink),
          dropdownColor: Palette.paper,
          borderRadius: BorderRadius.circular(6),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: [
            for (final (itemValue, label) in items)
              DropdownMenuItem(value: itemValue, child: Text(label)),
          ],
        ),
      ),
    );
  }
}
