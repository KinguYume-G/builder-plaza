import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/typography.dart';

/// A labelled text field styled to match the Soft Brutalist system: a mono
/// caption label, a 2px ink border that turns cobalt on focus, and an optional
/// inline tomato error line beneath.
///
/// Used across the project form (title, needs, demo URL, team division, repos).
class BrutalField extends StatelessWidget {
  const BrutalField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.errorText,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final String? errorText;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppType.mono(
              size: 11, color: Palette.ink400, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: AppType.body(size: 15, weight: FontWeight.w500),
          cursorColor: Palette.cobalt,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofocus: autofocus,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppType.body(size: 15, color: Palette.ink400),
            counterText: '',
            filled: true,
            fillColor: Palette.paper,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                  color: hasError ? Palette.tomato : Palette.ink, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                  color: hasError ? Palette.tomato : Palette.cobalt,
                  width: 2.5),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: AppType.mono(
                size: 12, color: Palette.tomato, weight: FontWeight.w700),
          ),
        ],
      ],
    );
  }
}
