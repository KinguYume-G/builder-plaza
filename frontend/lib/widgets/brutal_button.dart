import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/typography.dart';

/// A filled brutalist button with a hard offset shadow and a tactile
/// "press-down" interaction.
///
/// At rest the button floats above a 4px hard shadow. On press it translates
/// down/right by the shadow offset and drops the shadow, so it visually snaps
/// flat against the surface — the physical, stamped feel of the design system.
class BrutalButton extends StatefulWidget {
  const BrutalButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = Palette.cobalt,
    this.textColor = Palette.paper,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final bool loading;

  /// Whether the button stretches to fill its parent's width.
  final bool expand;

  @override
  State<BrutalButton> createState() => _BrutalButtonState();
}

class _BrutalButtonState extends State<BrutalButton> {
  bool _pressed = false;

  static const Offset _shadowOffset = Offset(4, 4);

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _setPressed(bool value) {
    if (!_enabled) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final translate =
        _pressed ? _shadowOffset : Offset.zero;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _enabled ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(translate.dx, translate.dy, 0),
        width: widget.expand ? double.infinity : null,
        decoration: BoxDecoration(
          color: _enabled ? widget.color : Palette.ink200,
          border: Border.all(color: Palette.ink, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: _pressed
              ? const []
              : const [
                  BoxShadow(
                    color: Palette.ink,
                    offset: _shadowOffset,
                    blurRadius: 0,
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.loading) ...[
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(widget.textColor),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Text(
                widget.label.toUpperCase(),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppType.display(
                  size: 15,
                  color: _enabled ? widget.textColor : Palette.ink400,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
