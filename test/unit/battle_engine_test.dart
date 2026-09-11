import 'package:flutter_test/flutter_test.dart';
import 'package:nifty_heisenberg/core/constants/game_constants.dart';
import 'package:nifty_heisenberg/domain/battle/battle_engine.dart';

void main() {
  late BattleEngine engine;

  setUp(() {
    engine = const BattleEngine();
  });

  group('BattleEngine - Full Completion Damage (25m, 100 BP)', () {
    const int basePoints = 100;
    const int totalSeconds = 1500;
    const int elapsedSeconds = 1500;
    const int maxHp = 500;
    const int currentHp = 500;
    const int executeHp = 100; // <= 20%

    test('Snap-fit deals 1.0x damage (100 pts)', () {
      final damage = engine.calculateDamage(
        basePoints: basePoints,
        phase: CraftPhases.snapFit,
        elapsedSeconds: elapsedSeconds,
        totalSeconds: totalSeconds,
        isInterrupted: false,
        currentHp: currentHp,
        maxHp: maxHp,
      );
      expect(damage, 100);
    });

    test('Sanding deals 1.2x damage (120 pts)', () {
      final damage = engine.calculateDamage(
        basePoints: basePoints,
        phase: CraftPhases.sanding,
        elapsedSeconds: elapsedSeconds,
        totalSeconds: totalSeconds,
        isInterrupted: false,
        currentHp: currentHp,
        maxHp: maxHp,
      );
      expect(damage, 120);
    });

    test('Detailing deals 1.5x damage (150 pts)', () {
      final damage = engine.calculateDamage(
        basePoints: basePoints,
        phase: CraftPhases.detailing,
        elapsedSeconds: elapsedSeconds,
        totalSeconds: totalSeconds,
        isInterrupted: false,
        currentHp: currentHp,
        maxHp: maxHp,
      );
      expect(damage, 150);
    });

    test('Airbrush deals 2.0x damage (200 pts)', () {
      final damage = engine.calculateDamage(
        basePoints: basePoints,
        phase: CraftPhases.airbrush,
        elapsedSeconds: elapsedSeconds,
        totalSeconds: totalSeconds,
        isInterrupted: false,
        currentHp: currentHp,
        maxHp: maxHp,
      );
      expect(damage, 200);
    });

    test('Finishing deals 2.5x damage when Boss HP <= 20% (250 pts)', () {
      final damage = engine.calculateDamage(
        basePoints: basePoints,
        phase: CraftPhases.finishing,
        elapsedSeconds: elapsedSeconds,
        totalSeconds: totalSeconds,
        isInterrupted: false,
        currentHp: executeHp,
        maxHp: maxHp,
      );
      expect(damage, 250);
    });
  });

  group('BattleEngine - Deep Focus Mode (50m, 220 BP)', () {
    const int basePoints = 220;
    const int totalSeconds = 3000;
    const int elapsedSeconds = 3000;
    const int maxHp = 1000;

    test('Snap-fit deals 220 damage', () {
      final damage = engine.calculateDamage(
        basePoints: basePoints,
        phase: CraftPhases.snapFit,
        elapsedSeconds: elapsedSeconds,
        totalSeconds: totalSeconds,
        isInterrupted: false,
        currentHp: 1000,
        maxHp: maxHp,
      );
      expect(damage, 220);
    });

    test('Sanding deals 264 damage', () {
      final damage = engine.calculateDamage(
        basePoints: basePoints,
        phase: CraftPhases.sanding,
        elapsedSeconds: elapsedSeconds,
        totalSeconds: totalSeconds,
        isInterrupted: false,
        currentHp: 1000,
        maxHp: maxHp,
      );
      expect(damage, 264);
    });

    test('Detailing deals 330 damage', () {
      final damage = engine.calculateDamage(
        basePoints: basePoints,
        phase: CraftPhases.detailing,
        elapsedSeconds: elapsedSeconds,
        totalSeconds: totalSeconds,
        isInterrupted: false,
        currentHp: 1000,
        maxHp: maxHp,
      );
      expect(damage, 330);
    });

    test('Airbrush deals 440 damage', () {
      final damage = engine.calculateDamage(
        basePoints: basePoints,
        phase: CraftPhases.airbrush,
        elapsedSeconds: elapsedSeconds,
        totalSeconds: totalSeconds,
        isInterrupted: false,
        currentHp: 1000,
        maxHp: maxHp,
      );
      expect(damage, 440);
    });

    test('Finishing deals 550 damage when HP <= 20%', () {
      final damage = engine.calculateDamage(
        basePoints: basePoints,
        phase: CraftPhases.finishing,
        elapsedSeconds: elapsedSeconds,
        totalSeconds: totalSeconds,
        isInterrupted: false,
        currentHp: 200, // 200/1000 = 20%
        maxHp: maxHp,
      );
      expect(damage, 550);
    });
  });

  group('BattleEngine - Mercy Rule Interrupted Damage (50% floor)', () {
    const int basePoints = 100;
    const int totalSeconds = 1500;

    test('Snap-fit 50% elapsed (750s) deals 25 damage', () {
      // 100 * (750/1500) * 1.0 * 0.5 = 25
      final damage = engine.calculateDamage(
        basePoints: basePoints,
        phase: CraftPhases.snapFit,
        elapsedSeconds: 750,
        totalSeconds: totalSeconds,
        isInterrupted: true,
        currentHp: 500,
        maxHp: 500,
      );
      expect(damage, 25);
    });

    test('Sanding 50% elapsed (750s) deals 30 damage', () {
      // 100 * (750/1500) * 1.2 * 0.5 = 30
      final damage = engine.calculateDamage(
        basePoints: basePoints,
        phase: CraftPhases.sanding,
        elapsedSeconds: 750,
        totalSeconds: totalSeconds,
        isInterrupted: true,
        currentHp: 500,
        maxHp: 500,
      );
      expect(damage, 30);
    });

    test('Detailing 50% elapsed (750s) rounds half-up to 38 damage', () {
      // 100 * (750/1500) * 1.5 * 0.5 = 37.5 -> 38
      final damage = engine.calculateDamage(
        basePoints: basePoints,
        phase: CraftPhases.detailing,
        elapsedSeconds: 750,
        totalSeconds: totalSeconds,
        isInterrupted: true,
        currentHp: 500,
        maxHp: 500,
      );
      expect(damage, 38);
    });

    test('Airbrush 80% elapsed (1200s) deals 80 damage', () {
      // 100 * (1200/1500) * 2.0 * 0.5 = 80
      final damage = engine.calculateDamage(
        basePoints: basePoints,
        phase: CraftPhases.airbrush,
        elapsedSeconds: 1200,
        totalSeconds: totalSeconds,
        isInterrupted: true,
        currentHp: 500,
        maxHp: 500,
      );
      expect(damage, 80);
    });

    test('Finishing 50% elapsed (750s, HP<=20%) rounds half-up to 63 damage', () {
      // 100 * (750/1500) * 2.5 * 0.5 = 62.5 -> 63
      final damage = engine.calculateDamage(
        basePoints: basePoints,
        phase: CraftPhases.finishing,
        elapsedSeconds: 750,
        totalSeconds: totalSeconds,
        isInterrupted: true,
        currentHp: 100,
        maxHp: 500,
      );
      expect(damage, 63);
    });

    test('Deep Focus interrupted 50% elapsed deals proportional damage', () {
      // 220 * (1500/3000) * 1.5 * 0.5 = 82.5 -> 83
      final damage = engine.calculateDamage(
        basePoints: 220,
        phase: CraftPhases.detailing,
        elapsedSeconds: 1500,
        totalSeconds: 3000,
        isInterrupted: true,
        currentHp: 1000,
        maxHp: 1000,
      );
      expect(damage, 83);
    });
  });

  group('BattleEngine - Finishing Execution Gate (<20% vs >=20%)', () {
    test('canExecuteFinishing returns false when HP is above 20%', () {
      expect(engine.canExecuteFinishing(currentHp: 101, maxHp: 500), isFalse);
      expect(engine.canExecuteFinishing(currentHp: 301, maxHp: 1500), isFalse);
      expect(engine.canExecuteFinishing(currentHp: 1001, maxHp: 5000), isFalse);
    });

    test('canExecuteFinishing returns true when HP is at or below 20%', () {
      expect(engine.canExecuteFinishing(currentHp: 100, maxHp: 500), isTrue);
      expect(engine.canExecuteFinishing(currentHp: 99, maxHp: 500), isTrue);
      expect(engine.canExecuteFinishing(currentHp: 300, maxHp: 1500), isTrue);
      expect(engine.canExecuteFinishing(currentHp: 1, maxHp: 500), isTrue);
      expect(engine.canExecuteFinishing(currentHp: 0, maxHp: 500), isTrue);
    });

    test('canExecuteFinishing returns false if maxHp <= 0', () {
      expect(engine.canExecuteFinishing(currentHp: 0, maxHp: 0), isFalse);
      expect(engine.canExecuteFinishing(currentHp: 10, maxHp: -100), isFalse);
    });

    test('calculateDamage returns 0 when Finishing is attempted above 20% HP', () {
      final damage = engine.calculateDamage(
        basePoints: 100,
        phase: CraftPhases.finishing,
        elapsedSeconds: 1500,
        totalSeconds: 1500,
        isInterrupted: false,
        currentHp: 101,
        maxHp: 500,
      );
      expect(damage, 0);
    });

    test('calculateDamage delivers full 250 damage when Finishing is at 20% HP', () {
      final damage = engine.calculateDamage(
        basePoints: 100,
        phase: CraftPhases.finishing,
        elapsedSeconds: 1500,
        totalSeconds: 1500,
        isInterrupted: false,
        currentHp: 100,
        maxHp: 500,
      );
      expect(damage, 250);
    });
  });

  group('BattleEngine - Edge Cases & Defensive Guards', () {
    test('returns 0 if totalSeconds <= 0', () {
      final damage = engine.calculateDamage(
        basePoints: 100,
        phase: CraftPhases.snapFit,
        elapsedSeconds: 10,
        totalSeconds: 0,
        isInterrupted: false,
        currentHp: 500,
        maxHp: 500,
      );
      expect(damage, 0);
    });

    test('returns 0 if elapsedSeconds <= 0', () {
      final damage = engine.calculateDamage(
        basePoints: 100,
        phase: CraftPhases.snapFit,
        elapsedSeconds: 0,
        totalSeconds: 1500,
        isInterrupted: true,
        currentHp: 500,
        maxHp: 500,
      );
      expect(damage, 0);
    });

    test('returns 0 if basePoints <= 0', () {
      final damage = engine.calculateDamage(
        basePoints: 0,
        phase: CraftPhases.snapFit,
        elapsedSeconds: 1500,
        totalSeconds: 1500,
        isInterrupted: false,
        currentHp: 500,
        maxHp: 500,
      );
      expect(damage, 0);
    });

    test('clamps elapsedSeconds if it exceeds totalSeconds', () {
      final damage = engine.calculateDamage(
        basePoints: 100,
        phase: CraftPhases.snapFit,
        elapsedSeconds: 2000,
        totalSeconds: 1500,
        isInterrupted: false,
        currentHp: 500,
        maxHp: 500,
      );
      expect(damage, 100);
    });

    test('minimum damage floor: elapsedSeconds > 0 with tiny calculated damage returns 1', () {
      // 100 * (1 / 1500) * 1.0 * 0.5 = 0.0333 -> round() is 0, but floor ensures 1
      final damage = engine.calculateDamage(
        basePoints: 100,
        phase: CraftPhases.snapFit,
        elapsedSeconds: 1,
        totalSeconds: 1500,
        isInterrupted: true,
        currentHp: 500,
        maxHp: 500,
      );
      expect(damage, 1);
    });

    test('falls back to 1.0x multiplier for unknown craft phase', () {
      final damage = engine.calculateDamage(
        basePoints: 100,
        phase: 'LaserCutting',
        elapsedSeconds: 1500,
        totalSeconds: 1500,
        isInterrupted: false,
        currentHp: 500,
        maxHp: 500,
      );
      expect(damage, 100);
    });
  });

  group('BattleEngine - Helper Methods', () {
    test('calculateEarnedCoins returns 0 for <= 0 seconds', () {
      expect(engine.calculateEarnedCoins(elapsedSeconds: 0), 0);
      expect(engine.calculateEarnedCoins(elapsedSeconds: -5), 0);
    });

    test('calculateEarnedCoins clamps to minimum 2 and maximum 50', () {
      expect(engine.calculateEarnedCoins(elapsedSeconds: 1), 2);
      expect(engine.calculateEarnedCoins(elapsedSeconds: 25), 5);
      expect(engine.calculateEarnedCoins(elapsedSeconds: 1500), 50);
    });

    test('calculateHpPercentage returns clamped ratio', () {
      expect(engine.calculateHpPercentage(currentHp: 250, maxHp: 500), 0.5);
      expect(engine.calculateHpPercentage(currentHp: 0, maxHp: 500), 0.0);
      expect(engine.calculateHpPercentage(currentHp: 500, maxHp: 500), 1.0);
      expect(engine.calculateHpPercentage(currentHp: 100, maxHp: 0), 0.0);
    });
  });
}
