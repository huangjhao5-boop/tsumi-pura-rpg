import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nifty_heisenberg/core/constants/game_constants.dart';
import 'package:nifty_heisenberg/domain/battle/battle_engine.dart';
import 'package:nifty_heisenberg/main.dart';

void main() {
  group('Challenge Task 3: Mercy Rule at Arbitrary Progress Percentages', () {
    late BattleEngine engine;

    setUp(() {
      engine = const BattleEngine();
    });

    test('Standard Mode (100 BP, 1500s) Mercy Rule at 1%, 5%, 50%, 99%', () {
      const int bp = 100;
      const int total = 1500;
      const int hp500 = 500;
      const int hp100 = 100; // <= 20% for finishing

      // 1% progress: elapsed = 15s
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.snapFit,
          elapsedSeconds: 15,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp500,
          maxHp: hp500,
        ),
        1, // 100 * 0.01 * 1.0 * 0.5 = 0.5 -> 1
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.sanding,
          elapsedSeconds: 15,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp500,
          maxHp: hp500,
        ),
        1, // 100 * 0.01 * 1.2 * 0.5 = 0.6 -> 1
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.detailing,
          elapsedSeconds: 15,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp500,
          maxHp: hp500,
        ),
        1, // 100 * 0.01 * 1.5 * 0.5 = 0.75 -> 1
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.airbrush,
          elapsedSeconds: 15,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp500,
          maxHp: hp500,
        ),
        1, // 100 * 0.01 * 2.0 * 0.5 = 1.0 -> 1
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.finishing,
          elapsedSeconds: 15,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp100,
          maxHp: hp500,
        ),
        1, // 100 * 0.01 * 2.5 * 0.5 = 1.25 -> 1
      );

      // 5% progress: elapsed = 75s
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.snapFit,
          elapsedSeconds: 75,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp500,
          maxHp: hp500,
        ),
        3, // 100 * 0.05 * 1.0 * 0.5 = 2.5 -> 3
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.sanding,
          elapsedSeconds: 75,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp500,
          maxHp: hp500,
        ),
        3, // 100 * 0.05 * 1.2 * 0.5 = 3.0 -> 3
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.detailing,
          elapsedSeconds: 75,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp500,
          maxHp: hp500,
        ),
        4, // 100 * 0.05 * 1.5 * 0.5 = 3.75 -> 4
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.airbrush,
          elapsedSeconds: 75,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp500,
          maxHp: hp500,
        ),
        5, // 100 * 0.05 * 2.0 * 0.5 = 5.0 -> 5
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.finishing,
          elapsedSeconds: 75,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp100,
          maxHp: hp500,
        ),
        6, // 100 * 0.05 * 2.5 * 0.5 = 6.25 -> 6
      );

      // 50% progress: elapsed = 750s
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.snapFit,
          elapsedSeconds: 750,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp500,
          maxHp: hp500,
        ),
        25, // 100 * 0.50 * 1.0 * 0.5 = 25
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.sanding,
          elapsedSeconds: 750,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp500,
          maxHp: hp500,
        ),
        30, // 100 * 0.50 * 1.2 * 0.5 = 30
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.detailing,
          elapsedSeconds: 750,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp500,
          maxHp: hp500,
        ),
        38, // 100 * 0.50 * 1.5 * 0.5 = 37.5 -> 38
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.airbrush,
          elapsedSeconds: 750,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp500,
          maxHp: hp500,
        ),
        50, // 100 * 0.50 * 2.0 * 0.5 = 50
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.finishing,
          elapsedSeconds: 750,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp100,
          maxHp: hp500,
        ),
        63, // 100 * 0.50 * 2.5 * 0.5 = 62.5 -> 63
      );

      // 99% progress: elapsed = 1485s
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.snapFit,
          elapsedSeconds: 1485,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp500,
          maxHp: hp500,
        ),
        50, // 100 * 0.99 * 1.0 * 0.5 = 49.5 -> 50
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.sanding,
          elapsedSeconds: 1485,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp500,
          maxHp: hp500,
        ),
        59, // 100 * 0.99 * 1.2 * 0.5 = 59.4 -> 59
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.detailing,
          elapsedSeconds: 1485,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp500,
          maxHp: hp500,
        ),
        74, // 100 * 0.99 * 1.5 * 0.5 = 74.25 -> 74
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.airbrush,
          elapsedSeconds: 1485,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp500,
          maxHp: hp500,
        ),
        99, // 100 * 0.99 * 2.0 * 0.5 = 99.0 -> 99
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.finishing,
          elapsedSeconds: 1485,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp100,
          maxHp: hp500,
        ),
        124, // 100 * 0.99 * 2.5 * 0.5 = 123.75 -> 124
      );
    });

    test('Deep Focus Mode (220 BP, 3000s) Mercy Rule at 1%, 5%, 50%, 99%', () {
      const int bp = 220;
      const int total = 3000;
      const int hp1000 = 1000;
      const int hp200 = 200; // <= 20% for finishing

      // 1% progress: elapsed = 30s
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.snapFit,
          elapsedSeconds: 30,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp1000,
          maxHp: hp1000,
        ),
        1, // 220 * 0.01 * 1.0 * 0.5 = 1.1 -> 1
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.airbrush,
          elapsedSeconds: 30,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp1000,
          maxHp: hp1000,
        ),
        2, // 220 * 0.01 * 2.0 * 0.5 = 2.2 -> 2
      );

      // 5% progress: elapsed = 150s
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.snapFit,
          elapsedSeconds: 150,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp1000,
          maxHp: hp1000,
        ),
        6, // 220 * 0.05 * 1.0 * 0.5 = 5.5 -> 6
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.airbrush,
          elapsedSeconds: 150,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp1000,
          maxHp: hp1000,
        ),
        11, // 220 * 0.05 * 2.0 * 0.5 = 11.0 -> 11
      );

      // 50% progress: elapsed = 1500s
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.snapFit,
          elapsedSeconds: 1500,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp1000,
          maxHp: hp1000,
        ),
        55, // 220 * 0.50 * 1.0 * 0.5 = 55.0 -> 55
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.finishing,
          elapsedSeconds: 1500,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp200,
          maxHp: hp1000,
        ),
        138, // 220 * 0.50 * 2.5 * 0.5 = 137.5 -> 138
      );

      // 99% progress: elapsed = 2970s
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.snapFit,
          elapsedSeconds: 2970,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp1000,
          maxHp: hp1000,
        ),
        109, // 220 * 0.99 * 1.0 * 0.5 = 108.9 -> 109
      );
      expect(
        engine.calculateDamage(
          basePoints: bp,
          phase: CraftPhases.finishing,
          elapsedSeconds: 2970,
          totalSeconds: total,
          isInterrupted: true,
          currentHp: hp200,
          maxHp: hp1000,
        ),
        272, // 220 * 0.99 * 2.5 * 0.5 = 272.25 -> 272
      );
    });

    test('Finishing Gate locks Mercy Rule damage if HP > 20%', () {
      // Even if 99% progress is reached, if Boss HP > 20%, Finishing must deal 0
      final damage = engine.calculateDamage(
        basePoints: 100,
        phase: CraftPhases.finishing,
        elapsedSeconds: 1485,
        totalSeconds: 1500,
        isInterrupted: true,
        currentHp: 101, // 101/500 > 20%
        maxHp: 500,
      );
      expect(damage, 0);
    });

    test('Mercy Rule at 0% elapsed returns 0 damage', () {
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

    test('Mercy Rule at ultra-tiny progress (1s/1500s = 0.067%) guarantees 1 damage floor', () {
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
  });

  group('Challenge Task 1: Rapid Mode Switching & Rapid Start/Cancel Cycles', () {
    void setViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
    }

    testWidgets('Rapid mode switching when idle does not crash or corrupt state', (
      WidgetTester tester,
    ) async {
      setViewport(tester);
      await tester.pumpWidget(const TsumiPuraApp());
      await tester.pump();

      // Rapidly switch between modes 15 times
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('深度 50m/10m'));
        await tester.pump();
        expect(find.textContaining('開始開工 (深度 50m/10m)'), findsOneWidget);

        await tester.tap(find.text('除錯 5s/3s'));
        await tester.pump();
        expect(find.textContaining('開始開工 (除錯 5s/3s)'), findsOneWidget);

        await tester.tap(find.text('標準 25m/5m'));
        await tester.pump();
        expect(find.textContaining('開始開工 (標準 25m/5m)'), findsOneWidget);
      }
    });

    testWidgets('Rapid start and cancel cycles execute cleanly and reset to idle', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const TsumiPuraApp());
      await tester.pump();

      // Cycle Start -> Cancel 10 times rapidly
      for (int i = 0; i < 10; i++) {
        // Tap Start
        final startBtn = find.textContaining('開始開工');
        expect(startBtn, findsOneWidget);
        await tester.tap(startBtn);
        await tester.pump();

        // Immediately verify Work state
        expect(find.textContaining('WORK - 專注組裝中'), findsOneWidget);
        final cancelBtn = find.textContaining('中途中斷');
        expect(cancelBtn, findsOneWidget);

        // Tap Cancel
        await tester.tap(cancelBtn);
        await tester.pump();

        // Verify Idle state restored
        expect(find.textContaining('POMODORO WORKBENCH CLOCK'), findsOneWidget);
        expect(find.text('00:00'), findsOneWidget);
        expect(find.textContaining('開始開工'), findsOneWidget);
      }
    });

    testWidgets('Mode switching is disabled during active work session', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const TsumiPuraApp());
      await tester.pump();

      // Start Standard mode
      await tester.tap(find.textContaining('開始開工 (標準 25m/5m)'));
      await tester.pump();

      expect(find.textContaining('WORK - 專注組裝中 (標準 25m/5m)'), findsOneWidget);

      // Attempt to tap other modes - mode selector is disabled/hidden while working
      expect(find.text('深度 50m/10m'), findsNothing);
    });
  });

  group('Challenge Task 2: Work -> Rest Transition and Skip Rest Button', () {
    testWidgets('Completing 5s work phase transitions to rest phase, and skip rest resets to idle', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const TsumiPuraApp());
      await tester.pump();

      // Start 5s debug mode
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      expect(find.textContaining('WORK - 專注組裝中 (除錯 5s/3s)'), findsOneWidget);
      expect(find.text('00:05'), findsOneWidget);

      // Advance through 5 seconds of work
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:04'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:03'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:02'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:01'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:00'), findsOneWidget);

      // Next tick triggers _completeWorkSession and transitions to rest
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);
      expect(find.text('00:03'), findsOneWidget);
      expect(find.textContaining('略過休息 (提前開工)'), findsOneWidget);

      // Advance 1s in rest
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:02'), findsOneWidget);

      // Tap Skip Rest button
      await tester.tap(find.textContaining('略過休息 (提前開工)'));
      await tester.pump();

      // Verify returned to idle
      expect(find.textContaining('POMODORO WORKBENCH CLOCK'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.textContaining('開始開工'), findsOneWidget);
      expect(find.textContaining('已略過休息，隨時可再次開工討伐！'), findsOneWidget);
    });

    testWidgets('Rest phase completes fully after restSeconds and returns to idle', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const TsumiPuraApp());
      await tester.pump();

      // Start 5s debug mode
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      // Advance 5 work seconds + 1 transition tick
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // In Rest phase (3s)
      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);
      expect(find.text('00:03'), findsOneWidget);

      // Advance 3 rest seconds
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:02'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:01'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:00'), findsOneWidget);

      // Next tick triggers _completeRestSession
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('POMODORO WORKBENCH CLOCK'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.textContaining('休息完畢！精力充沛'), findsOneWidget);
    });
  });

  group('Challenge Task 4: Empirical Edge Cases & Timer Drift Analysis', () {
    testWidgets('Timer countdown empirical observation: work completion takes N+1 ticks', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const TsumiPuraApp());
      await tester.pump();

      // Start 5s debug mode
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      // After exactly 5 seconds, remainingSeconds is 00:00, but still in WORK phase!
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('00:00'), findsOneWidget);
      expect(find.textContaining('WORK - 專注組裝中'), findsOneWidget);
      expect(find.textContaining('中途中斷'), findsOneWidget);

      // Exactly at tick 6, it transitions to REST
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('REST - 工坊整備休息中'), findsOneWidget);
    });

    testWidgets('Coin grant observation during 0-second interruption', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const TsumiPuraApp());
      await tester.pump();

      // Initial coins: 150
      expect(find.textContaining('150 塑料金幣'), findsOneWidget);

      // Start and immediately cancel without letting 1 second elapse
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // Notice: lib/main.dart line 225 does:
      // final int earnedCoins = (actualElapsedSeconds / 5).round().clamp(2, 50);
      // Because actualElapsedSeconds == 0, clamp(2, 50) grants 2 coins!
      // This increases coins from 150 to 152 despite 0s work!
      expect(find.textContaining('152 塑料金幣'), findsOneWidget);
    });

    testWidgets('Boss HP drops accurately and triggers Quest Clear when reduced to 0', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const TsumiPuraApp());
      await tester.pump();

      // Boss initial HP: 500
      expect(find.textContaining('500 / 500 HP'), findsOneWidget);

      // Complete 5s debug mode with Snap-fit (deals 20 damage)
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // Boss HP should now be 480 / 500 HP
      expect(find.textContaining('480 / 500 HP'), findsOneWidget);
    });
  });
}
