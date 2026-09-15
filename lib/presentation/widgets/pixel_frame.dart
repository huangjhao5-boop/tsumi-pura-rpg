import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/retro_colors.dart';

/// 8-Bit Stepped Pixel Frame Container.
/// Features a stepped retro border with dark slate background (#12141F)
/// and customizable border colors and widths.
class PixelFrame extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final Color backgroundColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool steppedCorners;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const PixelFrame({
    super.key,
    required this.child,
    this.borderColor = RetroColors.borderDark,
    this.backgroundColor = RetroColors.darkSlate,
    this.borderWidth = 2.0,
    this.padding,
    this.margin,
    this.steppedCorners = true,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: width,
      height: height,
      margin: margin,
      child: CustomPaint(
        painter: _PixelBorderPainter(
          borderColor: borderColor,
          backgroundColor: backgroundColor,
          borderWidth: borderWidth,
          steppedCorners: steppedCorners,
        ),
        child: Padding(
          padding: padding ?? EdgeInsets.all(borderWidth + 4),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}

class _PixelBorderPainter extends CustomPainter {
  final Color borderColor;
  final Color backgroundColor;
  final double borderWidth;
  final bool steppedCorners;

  _PixelBorderPainter({
    required this.borderColor,
    required this.backgroundColor,
    required this.borderWidth,
    required this.steppedCorners,
  });

  Path _createSteppedPath(Rect rect, double step) {
    final path = Path();
    path.moveTo(rect.left + step, rect.top);
    path.lineTo(rect.right - step, rect.top);
    path.lineTo(rect.right - step, rect.top + step);
    path.lineTo(rect.right, rect.top + step);
    path.lineTo(rect.right, rect.bottom - step);
    path.lineTo(rect.right - step, rect.bottom - step);
    path.lineTo(rect.right - step, rect.bottom);
    path.lineTo(rect.left + step, rect.bottom);
    path.lineTo(rect.left + step, rect.bottom - step);
    path.lineTo(rect.left, rect.bottom - step);
    path.lineTo(rect.left, rect.top + step);
    path.lineTo(rect.left + step, rect.top + step);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final double step = math.max(borderWidth * 1.5, 3.0);

    if (steppedCorners && size.width > step * 2 && size.height > step * 2) {
      final fillPath = _createSteppedPath(rect, step);
      final fillPaint = Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      final strokePaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawPath(fillPath, strokePaint);
    } else {
      final fillPaint = Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);

      final strokePaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawRect(rect.deflate(borderWidth / 2), strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PixelBorderPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.steppedCorners != steppedCorners;
  }
}
