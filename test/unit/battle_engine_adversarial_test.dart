import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:nifty_heisenberg/core/constants/game_constants.dart';
import 'package:nifty_heisenberg/domain/battle/battle_engine.dart';

void main() {
  late BattleEngine engine;

  setUp(() {
    engine = const BattleEngine();
  });

  group('Adversarial - Extreme Elapsed & Total Seconds Matrix', () {
    test('Negative elapsed seconds returns 0 across various phases and modes', () {
      final phases = [
        CraftPhases.snapFit,
        CraftPhases.sanding,
        CraftPhases.detailing,
        CraftPhases.airbrush,
        CraftPhases.finishing,
      ];
      final extremeNegatives = [-1, -2, -10, -100, -1500, -9999999, -2147483648];

      for (final phase in phases) {
        for (final negElapsed in extremeNegatives) {
          final dmg = engine.calculateDamage(
            basePoints: 100,
            phase: phase,
            elapsedSeconds: negElapsed,
            totalSeconds: 1500,
            isInterrupted: false,
            currentHp: 10,
            maxHp: 500,
          );
          expect(dmg, 0, reason: 'Negative elapsed  with phase  must yield 0');
        }
      }
    });

    test('Zero elapsed seconds returns 0 even with isInterrupted = true/false', () {
      for (final interrupted in [true, false]) {
        for (final phase in CraftPhases.all) {
          final dmg = engine.calculateDamage(
            basePoints: 100,
            phase: phase,
            elapsedSeconds: 0,
            totalSeconds: 1500,
            isInterrupted: interrupted,
            currentHp: 10,
            maxHp: 500,
          );
          expect(dmg, 0, reason: '0s elapsed must always yield 0 damage');
        }
      }
    });

    test('Negative or zero totalSeconds returns 0 and does not throw division by zero', () {
      final invalidTotals = [0, -1, -50, -1500, -2147483648];
      for (final total in invalidTotals) {
        final dmg = engine.calculateDamage(
          basePoints: 100,
          phase: CraftPhases.snapFit,
          elapsedSeconds: 50,
          totalSeconds: total,
          isInterrupted: false,
          currentHp: 500,
          maxHp: 500,
        );
        expect(dmg, 0, reason: 'totalSeconds  must yield 0 damage without throw');
      }
    });

    test('elapsedSeconds exceeding totalSeconds is strictly clamped to 100% of max damage', () {
      // At 25m (1500s) Snap-fit = 100 max damage
      final extremeExceeding = [1501, 2000, 5000, 100000, 1000000000];
      for (final elapsed in extremeExceeding) {
        final dmg = engine.calculateDamage(
          basePoints: 100,
          phase: CraftPhases.snapFit,
          elapsedSeconds: elapsed,
          totalSeconds: 1500,
          isInterrupted: false,
          currentHp: 500,
          maxHp: 500,
        );
        expect(dmg, 100, reason: 'Elapsed  should be clamped to 1500s yielding exactly 100');
      }
    });

    test('Negative base points returns 0 and never heals the boss', () {
      final invalidBase = [0, -1, -100, -220, -999999];
      for (final bp in invalidBase) {
        final dmg = engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.snapFit,
          elapsedSeconds: 1500,
          totalSeconds: 1500,
          isInterrupted: false,
          currentHp: 500,
          maxHp: 500,
        );
        expect(dmg, 0, reason: 'basePoints  must return 0');
      }
    });
  });

  group('Adversarial - Extreme HP Values & canExecuteFinishing Boundary Precision', () {
    test('maxHp <= 0 always returns false for canExecuteFinishing', () {
      final invalidMaxHp = [0, -1, -10, -500, -2147483648];
      for (final mHp in invalidMaxHp) {
        expect(engine.canExecuteFinishing(currentHp: 0, maxHp: mHp), isFalse);
        expect(engine.canExecuteFinishing(currentHp: -10, maxHp: mHp), isFalse);
        expect(engine.canExecuteFinishing(currentHp: 100, maxHp: mHp), isFalse);
      }
    });

    test('currentHp <= 0 with valid maxHp always returns true (boss already defeated/execute ready)', () {
      final zeroOrNegativeHp = [0, -1, -50, -500, -999999];
      for (final cHp in zeroOrNegativeHp) {
        expect(
          engine.canExecuteFinishing(currentHp: cHp, maxHp: 500),
          isTrue,
          reason: 'currentHp  should be considered executable',
        );
      }
    });

    test('currentHp > maxHp always returns false', () {
      expect(engine.canExecuteFinishing(currentHp: 501, maxHp: 500), isFalse);
      expect(engine.canExecuteFinishing(currentHp: 15000, maxHp: 1500), isFalse);
      expect(engine.canExecuteFinishing(currentHp: 999999, maxHp: 500), isFalse);
    });

    test('Exact 20.000% threshold returns true across all standard grades', () {
      // EG (300) -> 60
      expect(engine.canExecuteFinishing(currentHp: 60, maxHp: 300), isTrue);
      // HG (500) -> 100
      expect(engine.canExecuteFinishing(currentHp: 100, maxHp: 500), isTrue);
      // RG (800) -> 160
      expect(engine.canExecuteFinishing(currentHp: 160, maxHp: 800), isTrue);
      // MG (1500) -> 300
      expect(engine.canExecuteFinishing(currentHp: 300, maxHp: 1500), isTrue);
      // PG (5000) -> 1000
      expect(engine.canExecuteFinishing(currentHp: 1000, maxHp: 5000), isTrue);
      // Arbitrary ratio 1/5
      expect(engine.canExecuteFinishing(currentHp: 1, maxHp: 5), isTrue);
      expect(engine.canExecuteFinishing(currentHp: 20000, maxHp: 100000), isTrue);
    });

    test('Above 20% strictly returns false for canExecuteFinishing', () {
      // 20.2% on HG: 101/500
      expect(engine.canExecuteFinishing(currentHp: 101, maxHp: 500), isFalse);
      // 20.33% on EG: 61/300
      expect(engine.canExecuteFinishing(currentHp: 61, maxHp: 300), isFalse);
      // 20.125% on RG: 161/800
      expect(engine.canExecuteFinishing(currentHp: 161, maxHp: 800), isFalse);
      // 20.067% on MG: 301/1500
      expect(engine.canExecuteFinishing(currentHp: 301, maxHp: 1500), isFalse);
      // 20.02% on PG: 1001/5000
      expect(engine.canExecuteFinishing(currentHp: 1001, maxHp: 5000), isFalse);
      // Extremely close to 20%: 20.001% (20001 / 100000)
      expect(engine.canExecuteFinishing(currentHp: 20001, maxHp: 100000), isFalse);
      // 20.0001% (200001 / 1000000)
      expect(engine.canExecuteFinishing(currentHp: 200001, maxHp: 1000000), isFalse);
    });

    test('Below 20% strictly returns true for canExecuteFinishing', () {
      // 19.8% on HG: 99/500
      expect(engine.canExecuteFinishing(currentHp: 99, maxHp: 500), isTrue);
      // 19.67% on EG: 59/300
      expect(engine.canExecuteFinishing(currentHp: 59, maxHp: 300), isTrue);
      // 19.875% on RG: 159/800
      expect(engine.canExecuteFinishing(currentHp: 159, maxHp: 800), isTrue);
      // 19.933% on MG: 299/1500
      expect(engine.canExecuteFinishing(currentHp: 299, maxHp: 1500), isTrue);
      // 19.98% on PG: 999/5000
      expect(engine.canExecuteFinishing(currentHp: 999, maxHp: 5000), isTrue);
      // Extremely close below 20%: 19.999% (19999 / 100000)
      expect(engine.canExecuteFinishing(currentHp: 19999, maxHp: 100000), isTrue);
      // 19.9999% (199999 / 1000000)
      expect(engine.canExecuteFinishing(currentHp: 199999, maxHp: 1000000), isTrue);
    });
  });

  group('Adversarial - Mercy Rule (50% Interruption Floor) Invariants', () {
    test('Mercy Rule NEVER produces 0 damage if elapsedSeconds > 0 for standard skills', () {
      // Test all possible elapsed seconds from 1 to 1500 in 25m session
      for (int sec = 1; sec <= 1500; sec++) {
        for (final phase in [
          CraftPhases.snapFit,
          CraftPhases.sanding,
          CraftPhases.detailing,
          CraftPhases.airbrush,
        ]) {
          final dmg = engine.calculateDamage(
            basePoints: 100,
            phase: phase,
            elapsedSeconds: sec,
            totalSeconds: 1500,
            isInterrupted: true,
            currentHp: 500,
            maxHp: 500,
          );
          expect(
            dmg >= 1,
            isTrue,
            reason: 'At elapsed  with phase , Mercy Rule produced  (must be >= 1)',
          );
        }
      }
    });

    test('Mercy Rule with 1 second elapsed on 50m (3000s) deep focus still outputs at least 1 damage', () {
      final dmg = engine.calculateDamage(
        basePoints: 220,
        phase: CraftPhases.snapFit,
        elapsedSeconds: 1,
        totalSeconds: 3000,
        isInterrupted: true,
        currentHp: 500,
        maxHp: 500,
      );
      // 220 * (1 / 3000) * 1.0 * 0.5 = 0.0366 -> round() is 0, floor triggers -> 1
      expect(dmg, 1);
    });

    test('Mercy Rule interrupted damage is monotonically non-decreasing with elapsed seconds', () {
      int previousDmg = 0;
      for (int sec = 1; sec <= 1500; sec += 10) {
        final currentDmg = engine.calculateDamage(
          basePoints: 100,
          phase: CraftPhases.detailing,
          elapsedSeconds: sec,
          totalSeconds: 1500,
          isInterrupted: true,
          currentHp: 500,
          maxHp: 500,
        );
        expect(
          currentDmg >= previousDmg,
          isTrue,
          reason: 'Damage at  () should be >= previous ()',
        );
        previousDmg = currentDmg;
      }
    });
  });

  group('Adversarial - Finishing Skill Strict Gate Invariant', () {
    test('Finishing skill NEVER deals damage when currentHp > 20% maxHp regardless of params', () {
      final testElapsedList = [1, 10, 500, 1500, 3000, 10000];
      final testBasePoints = [1, 100, 220, 10000];
      final testInterrupted = [true, false];
      final invalidHpPairs = [
        const [101, 500],
        const [102, 500],
        const [250, 500],
        const [499, 500],
        const [500, 500],
        const [301, 1500],
        const [1001, 5000],
        const [20001, 100000],
      ];

      for (final elapsed in testElapsedList) {
        for (final bp in testBasePoints) {
          for (final isInt in testInterrupted) {
            for (final pair in invalidHpPairs) {
              final dmg = engine.calculateDamage(
                basePoints: bp,
                phase: CraftPhases.finishing,
                elapsedSeconds: elapsed,
                totalSeconds: 1500,
                isInterrupted: isInt,
                currentHp: pair[0],
                maxHp: pair[1],
              );
              expect(
                dmg,
                0,
                reason:
                    'Finishing with HP=/ (>20%), elapsed=, bp=, isInt= must be 0, got ',
              );
            }
          }
        }
      }
    });

    test('Finishing skill deals proper non-zero damage when currentHp <= 20% maxHp and elapsed > 0', () {
      final validHpPairs = [
        const [100, 500],
        const [99, 500],
        const [50, 500],
        const [1, 500],
        const [0, 500],
        const [300, 1500],
        const [1000, 5000],
      ];

      for (final pair in validHpPairs) {
        final dmg = engine.calculateDamage(
          basePoints: 100,
          phase: CraftPhases.finishing,
          elapsedSeconds: 1500,
          totalSeconds: 1500,
          isInterrupted: false,
          currentHp: pair[0],
          maxHp: pair[1],
        );
        expect(dmg, 250, reason: 'Valid finishing should deliver 250 damage');
      }
    });
  });

  group('Adversarial - Property-Based Pseudo-Random Fuzzing (10,000 iterations)', () {
    test('10,000 randomized configurations satisfy all core mathematical invariants', () {
      final random = Random(42); // Deterministic seed
      final phases = [
        CraftPhases.snapFit,
        CraftPhases.sanding,
        CraftPhases.detailing,
        CraftPhases.airbrush,
        CraftPhases.finishing,
        'CustomPhase',
      ];

      for (int i = 0; i < 10000; i++) {
        final int basePoints = random.nextInt(1000) - 50; // -50 to 949
        final String phase = phases[random.nextInt(phases.length)];
        final int elapsedSeconds = random.nextInt(4000) - 100; // -100 to 3899
        final int totalSeconds = random.nextInt(3500) - 100; // -100 to 3399
        final bool isInterrupted = random.nextBool();
        final int maxHp = random.nextInt(6000) - 500; // -500 to 5499
        final int currentHp = random.nextInt(6000) - 500; // -500 to 5499

        final int damage = engine.calculateDamage(
          basePoints: basePoints,
          phase: phase,
          elapsedSeconds: elapsedSeconds,
          totalSeconds: totalSeconds,
          isInterrupted: isInterrupted,
          currentHp: currentHp,
          maxHp: maxHp,
        );

        // Invariant 1: Damage is never negative
        expect(damage >= 0, isTrue, reason: 'Damage must never be negative ()');

        // Invariant 2: Invalid inputs yield 0
        if (totalSeconds <= 0 || elapsedSeconds <= 0 || basePoints <= 0) {
          expect(damage, 0, reason: 'Invalid timing/base must yield 0 damage');
          continue;
        }

        // Invariant 3: Finishing gate above 20% yields 0
        if (phase == CraftPhases.finishing) {
          final bool canExecute = engine.canExecuteFinishing(
            currentHp: currentHp,
            maxHp: maxHp,
          );
          if (!canExecute) {
            expect(damage, 0, reason: 'Finishing without execution unlock must yield 0 damage');
            continue;
          }
        }

        // Invariant 4: If valid and elapsed > 0, damage is at least 1 (Mercy floor / minimum floor)
        expect(damage >= 1, isTrue, reason: 'Valid run with elapsed > 0 must deal at least 1 damage');

        // Invariant 5: Damage never exceeds theoretical maximum
        final double multiplier = GameConstants.phaseMultipliers[phase] ?? 1.0;
        final int maxPossible = (basePoints * multiplier * (isInterrupted ? 0.5 : 1.0)).round();
        // Due to clamp floor at 1 when maxPossible is 0, ceiling is max(1, maxPossible)
        final int expectedCeiling = max(1, maxPossible);
        expect(
          damage <= expectedCeiling,
          isTrue,
          reason: 'Damage  exceeded ceiling ',
        );
      }
    });
  });
}
