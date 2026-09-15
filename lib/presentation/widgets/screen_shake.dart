import 'dart:math';
import 'package:flutter/material.dart';

/// Controller for orchestrating 2D harmonic screen shakes.
class ScreenShakeController {
  _ScreenShakeState? _state;

  void _attach(_ScreenShakeState state) => _state = state;
  void _detach() => _state = null;

  void shake({
    double? intensity,
    Duration? duration,
  }) {
    _state?.shake(intensity: intensity, duration: duration);
  }

  void stop() => _state?.stop();
  bool get isShaking => _state?.isShaking ?? false;
  double get value => _state?._animController.value ?? 0.0;
  AnimationStatus? get status => _state?._animController.status;
}

/// 8-Bit Retro Screen Shake Widget (Feature 28).
/// Applies 2D asymmetric harmonic displacement with quadratic decay.
/// Formula:
///   dx(t) = sin(t * 10 * pi) * intensity * (1 - t)^2
///   dy(t) = cos(t * 7 * pi) * (0.45 * intensity) * (1 - t)^2
class ScreenShake extends StatefulWidget {
  final Widget child;
  final ScreenShakeController? controller;
  final double defaultIntensity;
  final Duration defaultDuration;
  final bool enabled;

  /// Global master toggle for accessibility / reduced-motion preferences.
  static bool globalEnabled = true;

  const ScreenShake({
    super.key,
    required this.child,
    this.controller,
    this.defaultIntensity = 10.0,
    this.defaultDuration = const Duration(milliseconds: 350),
    this.enabled = true,
  });

  @override
  State<ScreenShake> createState() => _ScreenShakeState();
}

class _ScreenShakeState extends State<ScreenShake>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  double _currentIntensity = 10.0;

  bool get isShaking =>
      _animController.isAnimating && _animController.value < 1.0;

  @override
  void initState() {
    super.initState();
    _currentIntensity = widget.defaultIntensity;
    _animController = AnimationController(
      vsync: this,
      duration: widget.defaultDuration,
    );
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(ScreenShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _animController.dispose();
    super.dispose();
  }

  void shake({double? intensity, Duration? duration}) {
    if (!widget.enabled || !ScreenShake.globalEnabled || !mounted) return;
    _currentIntensity = intensity ?? widget.defaultIntensity;
    if (duration != null) {
      _animController.duration = duration;
    }
    _animController.forward(from: 0.0);
  }

  void stop() {
    if (_animController.isAnimating) {
      _animController.stop();
      _animController.value = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !ScreenShake.globalEnabled) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final bool isShaking =
            _animController.isAnimating && _animController.value < 1.0;
        final double t = _animController.value;
        final double decay = (1.0 - t) * (1.0 - t);
        final double dx =
            isShaking ? sin(t * 10 * pi) * _currentIntensity * decay : 0.0;
        final double dy = isShaking
            ? cos(t * 7 * pi) * (_currentIntensity * 0.45) * decay
            : 0.0;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
