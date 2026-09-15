import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nifty_heisenberg/core/audio/retro_audio_service.dart';
import 'package:nifty_heisenberg/core/constants/game_constants.dart';
import 'package:nifty_heisenberg/main.dart';
import 'package:nifty_heisenberg/presentation/theme/retro_colors.dart';
import 'package:nifty_heisenberg/presentation/theme/retro_typography.dart';
import 'package:nifty_heisenberg/presentation/widgets/boss_hurt_flash.dart';
import 'package:nifty_heisenberg/presentation/widgets/floating_damage_text.dart';
import 'package:nifty_heisenberg/presentation/widgets/pixel_button.dart';
import 'package:nifty_heisenberg/presentation/widgets/pixel_frame.dart';
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

  group('RetroTypography & RetroColors Tests', () {
    test('RetroTypography safely returns monospace fallback when offline/testing', () {
      expect(RetroTypography.isTestOrOffline, isTrue);

      final headerStyle = RetroTypography.pixelHeader(fontSize: 14);
      expect(headerStyle.fontFamily, equals('Press Start 2P'));
      expect(headerStyle.fontFamilyFallback, contains('VT323'));
      expect(headerStyle.fontFamilyFallback, contains('Courier New'));

      final bodyStyle = RetroTypography.pixelBody(fontSize: 12);
      expect(bodyStyle.fontFamily, equals('VT323'));
      expect(bodyStyle.fontFamilyFallback, contains('monospace'));
    });

    test('RetroColors defines correct palette values', () {
      expect(RetroColors.darkSlate, equals(const Color(0xFF12141F)));
      expect(RetroColors.darkSlateDeep, equals(const Color(0xFF0D0E15)));
      expect(RetroColors.retroAmber, equals(const Color(0xFFFFD54F)));
      expect(RetroColors.neonGreen, equals(const Color(0xFF50FA7B)));
      expect(RetroColors.crimsonRed, equals(const Color(0xFFFF5252)));
      expect(RetroColors.cyberCyan, equals(const Color(0xFF8BE9FD)));
    });
  });

  group('PixelFrame & PixelButton Widget Tests', () {
    testWidgets('PixelFrame renders child and handles tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PixelFrame(
              onTap: () => tapped = true,
              child: const Text('Pixel Frame Content'),
            ),
          ),
        ),
      );

      expect(find.text('Pixel Frame Content'), findsOneWidget);
      await tester.tap(find.text('Pixel Frame Content'));
      expect(tapped, isTrue);
    });

    testWidgets('PixelButton renders 8-bit bevel, pressed offset and fires onPressed', (
      tester,
    ) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PixelButton(
                onPressed: () => pressed = true,
                child: const Text('ARCADE TAP'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('ARCADE TAP'), findsOneWidget);

      // Verify Transform at resting state (offset 0, 0)
      Transform transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(PixelButton),
          matching: find.byType(Transform),
        ),
      );
      expect(transform.transform.getTranslation().y, equals(0.0));

      // Tap down triggers pressed offset of 2.0
      final gesture = await tester.startGesture(tester.getCenter(find.text('ARCADE TAP')));
      await tester.pump();

      transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(PixelButton),
          matching: find.byType(Transform),
        ),
      );
      expect(transform.transform.getTranslation().y, equals(2.0));

      // Release triggers callback and restores offset
      await gesture.up();
      await tester.pump();
      expect(pressed, isTrue);

      transform = tester.widget<Transform>(
        find.descendant(
          of: find.byType(PixelButton),
          matching: find.byType(Transform),
        ),
      );
      expect(transform.transform.getTranslation().y, equals(0.0));
    });

    testWidgets('Disabled PixelButton does not trigger callback', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PixelButton(
              enabled: false,
              onPressed: () => pressed = true,
              child: const Text('DISABLED'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('DISABLED'));
      await tester.pump();
      expect(pressed, isFalse);
    });
  });

  group('PixelHpBar Color Transition Tests', () {
    test('Color thresholds match >50% green, >20% amber, <=20% red', () {
      expect(PixelHpBar.getHpColor(1.0), equals(RetroColors.neonGreen));
      expect(PixelHpBar.getHpColor(0.51), equals(RetroColors.neonGreen));
      expect(PixelHpBar.getHpColor(0.50), equals(RetroColors.retroAmber));
      expect(PixelHpBar.getHpColor(0.21), equals(RetroColors.retroAmber));
      expect(PixelHpBar.getHpColor(0.20), equals(RetroColors.crimsonRed));
      expect(PixelHpBar.getHpColor(0.05), equals(RetroColors.crimsonRed));
      expect(PixelHpBar.getHpColor(0.0), equals(RetroColors.crimsonRed));
    });

    testWidgets('PixelHpBar renders HP label, percentage, and fraction', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PixelHpBar(
              currentHp: 250,
              maxHp: 500,
              showLabel: true,
              showPercentage: true,
              showFraction: true,
            ),
          ),
        ),
      );

      expect(find.text('HP '), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('250 / 500 HP (250/500)'), findsOneWidget);
    });
  });

  group('ScreenShake & ScreenShakeController Tests', () {
    testWidgets('ScreenShake shakes with non-zero offset and restores to zero', (
      tester,
    ) async {
      final controller = ScreenShakeController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenShake(
              controller: controller,
              defaultDuration: const Duration(milliseconds: 300),
              child: const Text('SHAKE TARGET'),
            ),
          ),
        ),
      );

      expect(find.text('SHAKE TARGET'), findsOneWidget);
      expect(controller.isShaking, isFalse);

      // Trigger shake
      controller.shake(intensity: 12.0);
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.isShaking, isTrue);

      // Find Transform and verify displacement
      final transforms = tester.widgetList<Transform>(
        find.ancestor(
          of: find.text('SHAKE TARGET'),
          matching: find.byType(Transform),
        ),
      );
      expect(transforms.isNotEmpty, isTrue);

      // Pump to completion
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(controller.isShaking, isFalse);
    });

    testWidgets('ScreenShake allows hit-testing during active shake', (tester) async {
      final controller = ScreenShakeController();
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenShake(
              controller: controller,
              child: ElevatedButton(
                onPressed: () => tapped = true,
                child: const Text('TAP WHILE SHAKING'),
              ),
            ),
          ),
        ),
      );

      controller.shake(intensity: 15.0);
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('TAP WHILE SHAKING'));
      expect(tapped, isTrue);

      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('FloatingDamageOverlay & DamageColorPalette Tests', () {
    test('DamageColorPalette formats strings and colors for all craft phases', () {
      expect(
        DamageColorPalette.formatDamageText(
          damage: 20,
          phase: CraftPhases.snapFit,
          isInterrupted: false,
        ),
        equals('-20'),
      );
      expect(
        DamageColorPalette.getColorForPhase(CraftPhases.snapFit),
        equals(DamageColorPalette.snapFit),
      );

      expect(
        DamageColorPalette.formatDamageText(
          damage: 40,
          phase: CraftPhases.sanding,
          isInterrupted: false,
        ),
        equals('PIERCE! -40'),
      );
      expect(
        DamageColorPalette.getColorForPhase(CraftPhases.sanding),
        equals(DamageColorPalette.sanding),
      );

      expect(
        DamageColorPalette.formatDamageText(
          damage: 60,
          phase: CraftPhases.detailing,
          isInterrupted: false,
        ),
        equals('CRIT! -60'),
      );
      expect(
        DamageColorPalette.getColorForPhase(CraftPhases.detailing),
        equals(DamageColorPalette.detailing),
      );

      expect(
        DamageColorPalette.formatDamageText(
          damage: 120,
          phase: CraftPhases.airbrush,
          isInterrupted: false,
        ),
        equals('BURST! -120'),
      );
      expect(
        DamageColorPalette.getColorForPhase(CraftPhases.airbrush),
        equals(DamageColorPalette.airbrush),
      );

      expect(
        DamageColorPalette.formatDamageText(
          damage: 250,
          phase: CraftPhases.finishing,
          isInterrupted: false,
        ),
        equals('FINISH! -250'),
      );
      expect(
        DamageColorPalette.getColorForPhase(CraftPhases.finishing),
        equals(DamageColorPalette.finishing),
      );

      expect(
        DamageColorPalette.formatDamageText(
          damage: 50,
          phase: CraftPhases.snapFit,
          isInterrupted: true,
        ),
        equals('-50 (MERCY 50%)'),
      );
      expect(
        DamageColorPalette.getColorForPhase(CraftPhases.snapFit, isInterrupted: true),
        equals(DamageColorPalette.mercy),
      );
    });

    testWidgets('FloatingDamageOverlay spawns bubbles and self-dismisses after 900ms', (
      tester,
    ) async {
      final controller = FloatingDamageController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: FloatingDamageOverlay(
                controller: controller,
                child: const Text('OVERLAY BASE'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('OVERLAY BASE'), findsOneWidget);
      expect(find.text('BURST! -150'), findsNothing);

      // Spawn damage
      controller.spawn(
        damage: 150,
        phase: CraftPhases.airbrush,
        isInterrupted: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('BURST! -150'), findsOneWidget);

      // Advance past 900ms animation duration
      await tester.pump(const Duration(milliseconds: 850));
      await tester.pump();

      // Bubble should self-remove
      expect(find.text('BURST! -150'), findsNothing);
    });
  });

  group('BossHurtFlash Tests', () {
    testWidgets('BossHurtFlash activates color filter on flash and restores', (
      tester,
    ) async {
      final controller = BossHurtFlashController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BossHurtFlash(
              controller: controller,
              defaultDuration: const Duration(milliseconds: 220),
              child: const Icon(Icons.smart_toy, size: 60),
            ),
          ),
        ),
      );

      expect(controller.isFlashing, isFalse);

      controller.flash();
      await tester.pump(const Duration(milliseconds: 30));
      expect(controller.isFlashing, isTrue);

      final colorFilters = tester.widgetList<ColorFiltered>(
        find.byType(ColorFiltered),
      );
      expect(colorFilters.isNotEmpty, isTrue);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(controller.isFlashing, isFalse);
    });
  });

  group('Header HUD Mute Toggle & Combat Integration in TsumiPuraApp', () {
    testWidgets('Header HUD mute button (btn_mute_toggle) toggles SFX and MUTE', (
      tester,
    ) async {
      final mockAudio = MockRetroAudioService();
      RetroAudioService.setCustomInstance(mockAudio);

      await tester.pumpWidget(const TsumiPuraApp());
      await tester.pump();

      // Verify Mute toggle is present
      final muteBtn = find.byKey(const Key('btn_mute_toggle'));
      expect(muteBtn, findsOneWidget);

      // Initial state: SFX active
      expect(find.text('SFX'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(mockAudio.isMuted, isFalse);

      // Tap mute toggle -> becomes MUTE
      await tester.tap(muteBtn);
      await tester.pump();

      expect(find.text('MUTE'), findsOneWidget);
      expect(find.byIcon(Icons.volume_off), findsOneWidget);
      expect(mockAudio.isMuted, isTrue);

      // Tap again -> unmuted
      await tester.tap(muteBtn);
      await tester.pump();

      expect(find.text('SFX'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(mockAudio.isMuted, isFalse);
    });

    testWidgets('Complete 5s pomodoro session triggers combat juice & audio', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockAudio = MockRetroAudioService();
      RetroAudioService.setCustomInstance(mockAudio);

      await tester.pumpWidget(const TsumiPuraApp());
      await tester.pump();

      // Tap 5s debug button
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      // Countdown 5s
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 200));

      // Verify timer tick was sounded during the countdown
      expect(mockAudio.timerTickCount, greaterThanOrEqualTo(1));

      // Verify attack hit audio sounded
      expect(mockAudio.attackHitCount, greaterThanOrEqualTo(1));

      // Verify ScreenShake and FloatingDamageOverlay are present in tree
      expect(find.byType(ScreenShake), findsOneWidget);
      expect(find.byType(FloatingDamageOverlay), findsOneWidget);
      expect(find.byType(BossHurtFlash), findsOneWidget);
      expect(find.byType(PixelHpBar), findsOneWidget);

      // Allow remaining juice animations to complete cleanly
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
