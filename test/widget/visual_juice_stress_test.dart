import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nifty_heisenberg/core/audio/retro_audio_service.dart';
import 'package:nifty_heisenberg/core/constants/game_constants.dart';
import 'package:nifty_heisenberg/main.dart';
import 'package:nifty_heisenberg/presentation/widgets/floating_damage_text.dart';
import 'package:nifty_heisenberg/presentation/widgets/pixel_hp_bar.dart';
import 'package:nifty_heisenberg/presentation/widgets/screen_shake.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    RetroAudioService.resetInstance();
  });

  tearDown(() {
    RetroAudioService.resetInstance();
    ScreenShake.globalEnabled = true;
  });

  group('Adversarial Stress Test: ScreenShake Rapid Consecutive Hits', () {
    testWidgets(
      'Rapid consecutive shake calls do not run away unboundedly and decay to 0',
      (tester) async {
        final controller = ScreenShakeController();
        const double intensity = 25.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ScreenShake(
                  controller: controller,
                  defaultIntensity: intensity,
                  defaultDuration: const Duration(milliseconds: 350),
                  child: const Text('SHAKE_TARGET'),
                ),
              ),
            ),
          ),
        );

        // Helper to get current translation offset of SHAKE_TARGET
        Offset getShakeOffset() {
          final transforms = tester.widgetList<Transform>(
            find.ancestor(
              of: find.text('SHAKE_TARGET'),
              matching: find.byType(Transform),
            ),
          );
          if (transforms.isEmpty) return Offset.zero;
          final matrix = transforms.first.transform;
          return Offset(matrix.getTranslation().x, matrix.getTranslation().y);
        }

        // Initially at rest: offset must be zero
        expect(getShakeOffset(), equals(Offset.zero));
        expect(controller.isShaking, isFalse);

        // STRESS 1: Fire 100 consecutive shake triggers in the same frame
        for (int i = 0; i < 100; i++) {
          controller.shake(intensity: intensity);
        }

        // Pump a single frame
        await tester.pump(const Duration(milliseconds: 16));
        expect(controller.isShaking, isTrue);

        Offset offset = getShakeOffset();
        // Mathematical bounds: dx <= intensity (25.0), dy <= 0.45 * intensity (11.25)
        expect(offset.dx.abs(), lessThanOrEqualTo(intensity + 0.001));
        expect(offset.dy.abs(), lessThanOrEqualTo(intensity * 0.45 + 0.001));

        // STRESS 2: Continue spamming shake across multiple frames (rapid damage barrage)
        for (int frame = 0; frame < 20; frame++) {
          controller.shake(intensity: intensity);
          await tester.pump(const Duration(milliseconds: 20));

          offset = getShakeOffset();
          // Verify offset is NEVER unboundedly accumulating
          expect(
            offset.dx.abs(),
            lessThanOrEqualTo(intensity + 0.001),
            reason: 'dx (${offset.dx}) exceeded maximum single-hit intensity $intensity',
          );
          expect(
            offset.dy.abs(),
            lessThanOrEqualTo(intensity * 0.45 + 0.001),
            reason: 'dy (${offset.dy}) exceeded maximum single-hit y-intensity ${intensity * 0.45}',
          );
        }

        // STRESS 3: Allow shake to decay naturally without further calls
        // After defaultDuration (350ms), shake must cleanly decay to zero displacement
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        expect(controller.isShaking, isFalse);
        final finalOffset = getShakeOffset();
        expect(
          finalOffset,
          equals(Offset.zero),
          reason: 'ScreenShake did not decay to zero displacement after duration expired',
        );
      },
    );

    testWidgets('ScreenShake stop() immediately restores zero displacement', (tester) async {
      final controller = ScreenShakeController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenShake(
              controller: controller,
              defaultDuration: const Duration(milliseconds: 500),
              child: const Text('STOP_TEST_TARGET'),
            ),
          ),
        ),
      );

      controller.shake(intensity: 20.0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.isShaking, isTrue);

      controller.stop();
      await tester.pump();

      expect(controller.isShaking, isFalse);
      final transforms = tester.widgetList<Transform>(
        find.ancestor(
          of: find.text('STOP_TEST_TARGET'),
          matching: find.byType(Transform),
        ),
      );
      expect(transforms.isNotEmpty, isTrue);
      final matrix = transforms.first.transform;
      expect(Offset(matrix.getTranslation().x, matrix.getTranslation().y), equals(Offset.zero));
    });

    testWidgets('Reduced motion: globalEnabled = false completely disables shake', (tester) async {
      ScreenShake.globalEnabled = false;
      final controller = ScreenShakeController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenShake(
              controller: controller,
              child: const Text('ACCESSIBILITY_TARGET'),
            ),
          ),
        ),
      );

      controller.shake(intensity: 30.0);
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.isShaking, isFalse);
      final transforms = tester.widgetList<Transform>(
        find.ancestor(
          of: find.text('ACCESSIBILITY_TARGET'),
          matching: find.byType(Transform),
        ),
      );
      expect(transforms.isEmpty, isTrue);
    });
  });

  group('Adversarial Stress Test: Floating Damage Numbers Concurrency & Cleanup', () {
    testWidgets(
      '50 concurrent damage popups render without overflow and clean up automatically',
      (tester) async {
        final controller = FloatingDamageController();
        const int popupCount = 50;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 240,
                child: FloatingDamageOverlay(
                  controller: controller,
                  child: const Center(child: Text('BASE_STAGE')),
                ),
              ),
            ),
          ),
        );

        // Verify initially no damage bubbles exist
        expect(
          find.byWidgetPredicate((w) => w.runtimeType.toString() == '_FloatingDamageBubble'),
          findsNothing,
        );

        // STRESS: Spawn 50 concurrent damage popups simultaneously across phases
        final phases = [
          CraftPhases.snapFit,
          CraftPhases.sanding,
          CraftPhases.detailing,
          CraftPhases.airbrush,
          CraftPhases.finishing,
        ];

        for (int i = 0; i < popupCount; i++) {
          controller.spawn(
            damage: 10 + i * 5,
            phase: phases[i % phases.length],
            isInterrupted: i % 7 == 0,
          );
        }

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Verify all 50 bubbles are mounted concurrently in widget tree
        final bubblesFound = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_FloatingDamageBubble',
        );
        expect(
          bubblesFound,
          findsNWidgets(popupCount),
          reason: 'Expected exactly 50 active damage bubble widgets mounted',
        );

        // Mid-animation verification (no overflow exceptions thrown)
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);

        // Past 900ms lifetime: all bubbles must automatically self-dismiss
        await tester.pump(const Duration(milliseconds: 600)); // Total 1050ms
        await tester.pump();

        expect(
          find.byWidgetPredicate((w) => w.runtimeType.toString() == '_FloatingDamageBubble'),
          findsNothing,
          reason: 'All 50 floating damage bubbles must be automatically removed from the tree',
        );
      },
    );

    testWidgets('FloatingDamageController.clear() flushes all active bubbles instantly', (tester) async {
      final controller = FloatingDamageController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingDamageOverlay(
              controller: controller,
              child: const Text('STAGE'),
            ),
          ),
        ),
      );

      for (int i = 0; i < 20; i++) {
        controller.spawn(
          damage: 100,
          phase: CraftPhases.airbrush,
          isInterrupted: false,
        );
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_FloatingDamageBubble'),
        findsNWidgets(20),
      );

      // Instant flush
      controller.clear();
      await tester.pump();

      expect(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_FloatingDamageBubble'),
        findsNothing,
      );
    });

    testWidgets('Narrow constrained bounding box does not throw layout overflow errors', (tester) async {
      final controller = FloatingDamageController();

      // Render inside extreme tiny viewport (50x50)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 50,
              height: 50,
              child: FloatingDamageOverlay(
                controller: controller,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );

      controller.spawn(
        damage: 999999,
        phase: CraftPhases.finishing,
        isInterrupted: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // No assertion or overflow error
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
    });

    test('DamageColorPalette handles extreme edge-case values gracefully', () {
      // 0 damage
      expect(DamageColorPalette.formatDamageText(damage: 0, phase: CraftPhases.snapFit, isInterrupted: false), equals('BLOCKED! 0'));
      expect(DamageColorPalette.getColorForPhase(CraftPhases.snapFit, damage: 0), equals(DamageColorPalette.blocked));
      expect(DamageColorPalette.getShakeIntensity(CraftPhases.snapFit, damage: 0), equals(3.0));

      // Negative damage
      expect(DamageColorPalette.formatDamageText(damage: -50, phase: CraftPhases.airbrush, isInterrupted: false), equals('BLOCKED! 0'));
      expect(DamageColorPalette.getColorForPhase(CraftPhases.airbrush, damage: -50), equals(DamageColorPalette.blocked));
      expect(DamageColorPalette.getShakeIntensity(CraftPhases.airbrush, damage: -50), equals(3.0));

      // Huge damage
      expect(DamageColorPalette.formatDamageText(damage: 999999, phase: CraftPhases.finishing, isInterrupted: false), equals('FINISH! -999999'));
      expect(DamageColorPalette.getColorForPhase(CraftPhases.finishing, damage: 999999), equals(DamageColorPalette.finishing));
      expect(DamageColorPalette.getShakeIntensity(CraftPhases.finishing, damage: 999999), equals(22.0));
    });
  });

  group('Adversarial Stress Test: Extreme HP Bar Ratios & Clamping', () {
    testWidgets('0 HP clamps to 0.0 widthFactor and renders crimsonRed with 0%', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PixelHpBar(
              currentHp: 0,
              maxHp: 500,
              showFraction: true,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('0 / 500 HP (0/500)'), findsOneWidget);

      final sizedBox = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(sizedBox.widthFactor, equals(0.0));
    });

    testWidgets('1 HP edge condition renders correctly without throwing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PixelHpBar(
              currentHp: 1,
              maxHp: 500,
              showFraction: true,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // 1 / 500 = 0.002 -> 0%
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('1 / 500 HP (1/500)'), findsOneWidget);

      final sizedBox = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(sizedBox.widthFactor, closeTo(0.002, 0.0001));
    });

    testWidgets('1 HP of 1 MaxHP renders 100% green without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PixelHpBar(
              currentHp: 1,
              maxHp: 1,
              showFraction: true,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('1 / 1 HP (1/1)'), findsOneWidget);

      final sizedBox = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(sizedBox.widthFactor, equals(1.0));
    });

    testWidgets('99999 HP extreme value renders without overflow or error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PixelHpBar(
              currentHp: 99999,
              maxHp: 99999,
              showFraction: true,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('99999 / 99999 HP (99999/99999)'), findsOneWidget);

      final sizedBox = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(sizedBox.widthFactor, equals(1.0));
    });

    testWidgets('Over-max HP (currentHp > maxHp) is clamped to 1.0 widthFactor', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PixelHpBar(
              currentHp: 99999,
              maxHp: 500,
              showFraction: true,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('100%'), findsOneWidget);

      final sizedBox = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(sizedBox.widthFactor, equals(1.0));
    });

    testWidgets('Negative current HP is clamped to 0.0 widthFactor and does not crash FractionallySizedBox', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PixelHpBar(
              currentHp: -100,
              maxHp: 500,
              showFraction: true,
            ),
          ),
        ),
      );

      // FractionallySizedBox throws AssertionError if widthFactor < 0.0
      // Clamping ensures it stays 0.0
      expect(tester.takeException(), isNull);
      expect(find.text('0%'), findsOneWidget);

      final sizedBox = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(sizedBox.widthFactor, equals(0.0));
    });

    testWidgets('Zero and negative maxHp handle division safely without NaN or crash', (tester) async {
      // maxHp = 0
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PixelHpBar(
              currentHp: 50,
              maxHp: 0,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      FractionallySizedBox sizedBox = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(sizedBox.widthFactor, equals(0.0));
      expect(find.text('0%'), findsOneWidget);

      // maxHp = -100
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PixelHpBar(
              currentHp: 50,
              maxHp: -100,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      sizedBox = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(sizedBox.widthFactor, equals(0.0));
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('PixelHpBar in constrained 200px width with 8-digit numbers renders without flex overflow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: PixelHpBar(
                  currentHp: 99999999,
                  maxHp: 99999999,
                  showFraction: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('100%'), findsOneWidget);
    });
  });

  group('Adversarial Stress Test: High Load & App Integration', () {
    testWidgets('200 concurrent damage popups clean up completely without leaks', (tester) async {
      final controller = FloatingDamageController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingDamageOverlay(
              controller: controller,
              child: const SizedBox(width: 400, height: 400),
            ),
          ),
        ),
      );

      // Spawn 200 items
      for (int i = 0; i < 200; i++) {
        controller.spawn(
          damage: i * 10,
          phase: CraftPhases.snapFit,
          isInterrupted: false,
        );
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_FloatingDamageBubble'),
        findsNWidgets(200),
      );

      // Advance time past 900ms duration
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();

      expect(
        find.byWidgetPredicate((w) => w.runtimeType.toString() == '_FloatingDamageBubble'),
        findsNothing,
      );
    });

    testWidgets('ScreenShake with extreme 1000.0 intensity stays mathematically bounded', (tester) async {
      final controller = ScreenShakeController();
      const double extremeIntensity = 1000.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenShake(
              controller: controller,
              defaultIntensity: extremeIntensity,
              child: const Text('TITAN_TARGET'),
            ),
          ),
        ),
      );

      controller.shake(intensity: extremeIntensity);
      await tester.pump(const Duration(milliseconds: 20));

      final transforms = tester.widgetList<Transform>(
        find.ancestor(
          of: find.text('TITAN_TARGET'),
          matching: find.byType(Transform),
        ),
      );
      expect(transforms.isNotEmpty, isTrue);
      final offset = Offset(
        transforms.first.transform.getTranslation().x,
        transforms.first.transform.getTranslation().y,
      );

      expect(offset.dx.abs(), lessThanOrEqualTo(extremeIntensity + 0.001));
      expect(offset.dy.abs(), lessThanOrEqualTo(extremeIntensity * 0.45 + 0.001));

      // Settles cleanly to 0
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(controller.isShaking, isFalse);
    });

    testWidgets('Rapid consecutive pomodoro completions in TsumiPuraApp handle juice without crash', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockAudio = MockRetroAudioService();
      RetroAudioService.setCustomInstance(mockAudio);

      await tester.pumpWidget(const TsumiPuraApp());
      await tester.pump();

      // Run 3 rapid consecutive 5-second sessions
      for (int session = 0; session < 3; session++) {
        final startBtn = find.text('5秒測試');
        if (startBtn.evaluate().isNotEmpty) {
          await tester.tap(startBtn);
          await tester.pump();

          // Tick 6 seconds to complete session
          for (int t = 0; t < 6; t++) {
            await tester.pump(const Duration(seconds: 1));
          }
          await tester.pump(const Duration(milliseconds: 200));

          // If rest phase is active, skip rest
          final skipRest = find.text('略過休息');
          if (skipRest.evaluate().isNotEmpty) {
            await tester.tap(skipRest);
            await tester.pump();
          }
        }
      }

      // Verify ScreenShake and FloatingDamageOverlay are healthy in tree
      expect(find.byType(ScreenShake), findsOneWidget);
      expect(find.byType(FloatingDamageOverlay), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Clean settlement
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
