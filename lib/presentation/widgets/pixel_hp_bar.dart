import 'package:flutter/material.dart';
import '../theme/retro_colors.dart';

/// 8-Bit Pixel HP Bar with 3-Phase Color Transitions.
/// Thresholds:
/// - > 50%: Neon Green (#50FA7B)
/// - > 20%: Retro Amber (#FFD54F)
/// - <= 20%: Crimson Red (#FF5252)
class PixelHpBar extends StatelessWidget {
  final int currentHp;
  final int maxHp;
  final double height;
  final bool showLabel;
  final bool showPercentage;
  final bool showFraction;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const PixelHpBar({
    super.key,
    required this.currentHp,
    required this.maxHp,
    this.height = 16.0,
    this.showLabel = true,
    this.showPercentage = true,
    this.showFraction = false,
    this.labelStyle,
    this.valueStyle,
  });

  double get hpPercentage => maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

  static Color getHpColor(double percentage) {
    if (percentage > 0.5) {
      return RetroColors.neonGreen;
    } else if (percentage > 0.2) {
      return RetroColors.retroAmber;
    } else {
      return RetroColors.crimsonRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double pct = hpPercentage;
    final Color color = getHpColor(pct);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (showLabel) ...[
              Text(
                'HP ',
                style: labelStyle ??
                    const TextStyle(
                      color: RetroColors.crimsonRed,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Press Start 2P',
                      fontFamilyFallback: ['VT323', 'monospace'],
                    ),
              ),
            ],
            Expanded(
              child: Container(
                height: height,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: Colors.white70, width: 2),
                ),
                child: ClipRect(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: pct,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        gradient: LinearGradient(
                          colors: [
                            color,
                            color.withValues(alpha: 0.75),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (showPercentage) ...[
              const SizedBox(width: 8),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: valueStyle ??
                    TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Press Start 2P',
                      fontFamilyFallback: const ['VT323', 'monospace'],
                    ),
              ),
            ],
          ],
        ),
        if (showFraction) ...[
          const SizedBox(height: 4),
          Text(
            '$currentHp / $maxHp HP ($currentHp/$maxHp)',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 8,
              fontFamily: 'Press Start 2P',
              fontFamilyFallback: ['VT323', 'monospace'],
            ),
          ),
        ],
      ],
    );
  }
}
