import 'package:flutter/material.dart';
import '../../core/constants/game_constants.dart';

/// ---------------------------------------------------------------------------
/// Damage Color & Style Palette (SPEC §2, Features 28 & 29)
/// ---------------------------------------------------------------------------
class DamageColorPalette {
  static const Color snapFit = Color(0xFFFFFFFF); // Clean White (1.0x)
  static const Color sanding = Color(0xFFFFEE58); // Piercing Yellow (1.2x)
  static const Color detailing = Color(0xFFF1FA8C); // Neon Weakpoint Yellow (1.5x)
  static const Color airbrush = Color(0xFF8BE9FD); // Cyber Cyan (2.0x)
  static const Color finishing = Color(0xFFFFD700); // Radiant Gold (2.5x)
  static const Color mercy = Color(0xFFFFA726); // Warning Amber (50% floor)
  static const Color blocked = Color(0xFF90A4AE); // Steel Gray (0 dmg)
  static const Color hurtFlash = Color(0xFFFF1744); // Arcade Crimson Red

  static Color getColorForPhase(
    String phase, {
    bool isInterrupted = false,
    int damage = 1,
  }) {
    if (damage <= 0) return blocked;
    if (isInterrupted) return mercy;
    switch (phase) {
      case CraftPhases.finishing:
        return finishing;
      case CraftPhases.airbrush:
        return airbrush;
      case CraftPhases.detailing:
        return detailing;
      case CraftPhases.sanding:
        return sanding;
      case CraftPhases.snapFit:
      default:
        return snapFit;
    }
  }

  static double getShakeIntensity(
    String phase, {
    bool isInterrupted = false,
    int damage = 1,
  }) {
    if (damage <= 0) return 3.0;
    if (isInterrupted) return 6.0;
    switch (phase) {
      case CraftPhases.finishing:
        return 22.0; // Screen-shattering execution slam
      case CraftPhases.airbrush:
        return 16.0; // Heavy pressurized burst
      case CraftPhases.detailing:
        return 13.0; // Sharp weakpoint shock
      case CraftPhases.sanding:
        return 9.0; // Gritty friction rumble
      case CraftPhases.snapFit:
      default:
        return 7.0; // Light crisp snip
    }
  }

  static String formatDamageText({
    required int damage,
    required String phase,
    required bool isInterrupted,
  }) {
    if (damage <= 0) return 'BLOCKED! 0';
    if (isInterrupted) return '-$damage (MERCY 50%)';
    switch (phase) {
      case CraftPhases.finishing:
        return 'FINISH! -$damage';
      case CraftPhases.airbrush:
        return 'BURST! -$damage';
      case CraftPhases.detailing:
        return 'CRIT! -$damage';
      case CraftPhases.sanding:
        return 'PIERCE! -$damage';
      case CraftPhases.snapFit:
      default:
        return '-$damage';
    }
  }
}

/// ---------------------------------------------------------------------------
/// Data item for an active floating damage bubble
/// ---------------------------------------------------------------------------
class FloatingDamageData {
  final Key key;
  final String text;
  final Color color;
  final double xJitter;

  FloatingDamageData({
    required this.key,
    required this.text,
    required this.color,
    this.xJitter = 0.0,
  });
}

/// Controller to trigger floating damage popups dynamically.
class FloatingDamageController {
  _FloatingDamageOverlayState? _state;

  void _attach(_FloatingDamageOverlayState state) => _state = state;
  void _detach() => _state = null;

  void spawn({
    required int damage,
    required String phase,
    required bool isInterrupted,
  }) {
    _state?.spawn(damage: damage, phase: phase, isInterrupted: isInterrupted);
  }

  void clear() => _state?.clear();
}

/// Overlay that renders floating damage popup numbers.
class FloatingDamageOverlay extends StatefulWidget {
  final FloatingDamageController? controller;
  final Widget? child;

  const FloatingDamageOverlay({
    super.key,
    this.controller,
    this.child,
  });

  @override
  State<FloatingDamageOverlay> createState() => _FloatingDamageOverlayState();
}

class _FloatingDamageOverlayState extends State<FloatingDamageOverlay> {
  final List<FloatingDamageData> _activeDamages = [];
  int _counter = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(FloatingDamageOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    super.dispose();
  }

  void spawn({
    required int damage,
    required String phase,
    required bool isInterrupted,
  }) {
    if (!mounted) return;
    _counter++;
    final Color color = DamageColorPalette.getColorForPhase(
      phase,
      isInterrupted: isInterrupted,
      damage: damage,
    );
    final String text = DamageColorPalette.formatDamageText(
      damage: damage,
      phase: phase,
      isInterrupted: isInterrupted,
    );
    final double jitter = (_counter % 3 - 1) * 12.0;

    final item = FloatingDamageData(
      key: ValueKey('floating_damage_${_counter}_$damage'),
      text: text,
      color: color,
      xJitter: jitter,
    );

    setState(() {
      _activeDamages.add(item);
    });
  }

  void _removeItem(FloatingDamageData item) {
    if (mounted) {
      setState(() {
        _activeDamages.remove(item);
      });
    }
  }

  void clear() {
    if (mounted) {
      setState(() {
        _activeDamages.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (widget.child != null) widget.child!,
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              clipBehavior: Clip.none,
              children: _activeDamages.map((item) {
                return _FloatingDamageBubble(
                  key: item.key,
                  item: item,
                  onComplete: () => _removeItem(item),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingDamageBubble extends StatefulWidget {
  final FloatingDamageData item;
  final VoidCallback onComplete;

  const _FloatingDamageBubble({
    super.key,
    required this.item,
    required this.onComplete,
  });

  @override
  State<_FloatingDamageBubble> createState() => _FloatingDamageBubbleState();
}

class _FloatingDamageBubbleState extends State<_FloatingDamageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _anim.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final double t = _anim.value;

        // Scale pop-in with overshoot: 0.5 -> 1.35 -> 1.0
        double scale;
        if (t < 0.25) {
          scale = 0.5 + (1.35 - 0.5) * Curves.easeOut.transform(t / 0.25);
        } else if (t < 0.5) {
          scale = 1.35 - (0.35) * Curves.easeInOut.transform((t - 0.25) / 0.25);
        } else {
          scale = 1.0;
        }

        // Upward float: -48px
        final double translateY = -48.0 * Curves.easeOutCubic.transform(t);

        // Opacity: solid until 0.65, then fade to 0
        final double opacity = t < 0.65
            ? 1.0
            : (1.0 - (t - 0.65) / 0.35).clamp(0.0, 1.0);

        return Positioned(
          top: 30 + translateY,
          right: 50 + widget.item.xJitter,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xEE0D0E15),
                  border: Border.all(color: widget.item.color, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: widget.item.color.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  widget.item.text,
                  style: TextStyle(
                    color: widget.item.color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Press Start 2P',
                    fontFamilyFallback: const ['VT323', 'monospace'],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
