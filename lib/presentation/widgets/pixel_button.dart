import 'package:flutter/material.dart';
import '../theme/retro_colors.dart';

/// 8-Bit Beveled Arcade Button with Pressed Offset.
/// Features a tactile 3D bevel that shifts down by 2px when pressed.
class PixelButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color color;
  final Color borderColor;
  final Color? textColor;
  final EdgeInsetsGeometry padding;
  final bool enabled;
  final double? width;
  final double? height;

  const PixelButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color = RetroColors.surfaceDark,
    this.borderColor = RetroColors.retroAmber,
    this.textColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.enabled = true,
    this.width,
    this.height,
  });

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _isPressed = false;

  bool get _canPress => widget.enabled && widget.onPressed != null;

  void _handleTapDown(TapDownDetails details) {
    if (!_canPress) return;
    setState(() {
      _isPressed = true;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_canPress) return;
    setState(() {
      _isPressed = false;
    });
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    if (!_canPress) return;
    setState(() {
      _isPressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isActionable = _canPress;
    final double opacity = isActionable ? 1.0 : 0.45;
    final double offsetY = _isPressed ? 2.0 : 0.0;

    // Bevel highlights & shadows
    final Color topBevel = _isPressed
        ? Colors.black.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.35);
    final Color bottomBevel = _isPressed
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.6);

    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Transform.translate(
            offset: Offset(0, offsetY),
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                color: widget.color,
                border: Border(
                  top: BorderSide(color: topBevel, width: 2),
                  left: BorderSide(color: topBevel, width: 2),
                  right: BorderSide(color: bottomBevel, width: 2),
                  bottom: BorderSide(color: bottomBevel, width: 2),
                ),
                boxShadow: _isPressed
                    ? null
                    : [
                        BoxShadow(
                          color: widget.borderColor.withValues(alpha: 0.35),
                          offset: const Offset(0, 2),
                          blurRadius: 0,
                        ),
                      ],
              ),
              child: Center(
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: widget.textColor ?? Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
