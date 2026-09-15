import 'package:flutter/material.dart';
import '../theme/retro_colors.dart';

/// Controller for orchestrating Boss hurt flash animations.
class BossHurtFlashController {
  _BossHurtFlashState? _state;

  void _attach(_BossHurtFlashState state) => _state = state;
  void _detach() => _state = null;

  void flash({
    Color? flashColor,
    Duration duration = const Duration(milliseconds: 220),
  }) {
    _state?.flash(flashColor: flashColor, duration: duration);
  }

  bool get isFlashing => _state?.isFlashing ?? false;
}

/// 8-Bit Boss Hurt Flash Widget (Feature 30).
/// Applies a 220ms arcade red strobe overlay and physical impact recoil squeeze.
class BossHurtFlash extends StatefulWidget {
  final Widget child;
  final BossHurtFlashController? controller;
  final Color flashColor;
  final Duration defaultDuration;

  const BossHurtFlash({
    super.key,
    required this.child,
    this.controller,
    this.flashColor = RetroColors.crimsonRed,
    this.defaultDuration = const Duration(milliseconds: 220),
  });

  @override
  State<BossHurtFlash> createState() => _BossHurtFlashState();
}

class _BossHurtFlashState extends State<BossHurtFlash>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Color? _activeFlashColor;

  bool get isFlashing => _controller.isAnimating;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.defaultDuration,
    );
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(BossHurtFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _controller.dispose();
    super.dispose();
  }

  void flash({Color? flashColor, Duration? duration}) {
    if (!mounted) return;
    _activeFlashColor = flashColor ?? widget.flashColor;
    if (duration != null) {
      _controller.duration = duration;
    }
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (!_controller.isAnimating) return child!;

        final double t = _controller.value;

        // Dual-pulse arcade strobe curve
        double alpha;
        if (t < 0.25) {
          alpha = 0.85;
        } else if (t < 0.50) {
          alpha = 0.35;
        } else if (t < 0.75) {
          alpha = 0.70 * (1.0 - (t - 0.50) / 0.25);
        } else {
          alpha = 0.35 * (1.0 - (t - 0.75) / 0.25);
        }

        final Color currentTint =
            (_activeFlashColor ?? widget.flashColor).withValues(alpha: alpha);

        // Recoil squeeze during first ~70ms
        final double scale = t < 0.30 ? (1.0 - (0.30 - t) * 0.15) : 1.0;

        return Transform.scale(
          scale: scale,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(currentTint, BlendMode.srcATop),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
