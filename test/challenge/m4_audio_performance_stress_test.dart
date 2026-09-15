import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nifty_heisenberg/core/audio/retro_audio_service.dart';
import 'package:nifty_heisenberg/core/audio/retro_audio_service_io.dart';
import 'package:nifty_heisenberg/main.dart';
import 'package:nifty_heisenberg/presentation/widgets/boss_hurt_flash.dart';
import 'package:nifty_heisenberg/presentation/widgets/screen_shake.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    RetroAudioService.resetInstance();
  });

  tearDown(() {
    RetroAudioService.resetInstance();
  });

  group('Milestone 4 Adversarial Stress 1: Rapid Audio Triggers (50+ spam)', () {
    test('1.1: Rapid-fire 100 consecutive sound triggers per sound effect without loss', () {
      final service = MockRetroAudioService();
      const int spamCount = 100;

      for (int i = 0; i < spamCount; i++) {
        service.playAttackHit();
        service.playCriticalStrike();
        service.playFinishingKill();
        service.playTimerTick();
        service.playButtonClick();
        service.playVictoryFanfare();
      }

      expect(service.attackHitCount, equals(spamCount));
      expect(service.criticalStrikeCount, equals(spamCount));
      expect(service.finishingKillCount, equals(spamCount));
      expect(service.timerTickCount, equals(spamCount));
      expect(service.buttonClickCount, equals(spamCount));
      expect(service.victoryFanfareCount, equals(spamCount));
    });

    test('1.2: Concurrent async burst of 200 mixed sound triggers across microtasks', () async {
      final service = MockRetroAudioService();
      const int burstCount = 200;

      await Future.wait(
        List.generate(burstCount, (i) async {
          await Future.microtask(() {
            if (i % 4 == 0) {
              service.playAttackHit();
            } else if (i % 4 == 1) {
              service.playCriticalStrike();
            } else if (i % 4 == 2) {
              service.playTimerTick();
            } else {
              service.playButtonClick();
            }
          });
        }),
      );

      final totalInvocations = service.attackHitCount +
          service.criticalStrikeCount +
          service.timerTickCount +
          service.buttonClickCount;
      expect(totalInvocations, equals(burstCount));
      expect(service.finishingKillCount, equals(0));
    });

    test('1.3: Audio buffer flood (500+ triggers) followed by reset retains consistency', () {
      final service = MockRetroAudioService();
      for (int i = 0; i < 500; i++) {
        service.playAttackHit();
        service.playTimerTick();
      }
      expect(service.attackHitCount, equals(500));
      expect(service.timerTickCount, equals(500));

      service.resetCounts();
      expect(service.attackHitCount, equals(0));
      expect(service.timerTickCount, equals(0));
    });
  });

  group('Milestone 4 Adversarial Stress 2: Mute Toggle HUD & Persistence', () {
    testWidgets('2.1: Rapidly toggle mute in Header HUD 50 times and verify final state parity', (
      WidgetTester tester,
    ) async {
      final mockAudio = MockRetroAudioService();
      RetroAudioService.setCustomInstance(mockAudio);

      await tester.pumpWidget(const TsumiPuraApp());
      await tester.pump();

      final muteBtn = find.byKey(const Key('btn_mute_toggle'));
      expect(muteBtn, findsOneWidget);
      expect(mockAudio.isMuted, isFalse);

      // Perform 50 rapid taps
      const int toggleTaps = 50;
      for (int i = 0; i < toggleTaps; i++) {
        await tester.tap(muteBtn);
        await tester.pump();
      }

      // Even number of toggles -> unmuted
      expect(mockAudio.isMuted, isFalse);
      expect(find.text('SFX'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);

      // 51st tap -> muted
      await tester.tap(muteBtn);
      await tester.pump();
      expect(mockAudio.isMuted, isTrue);
      expect(find.text('MUTE'), findsOneWidget);
      expect(find.byIcon(Icons.volume_off), findsOneWidget);
    });

    testWidgets('2.2: Audio stays 100% silent during rapid combat spam when muted in HUD', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockAudio = MockRetroAudioService();
      RetroAudioService.setCustomInstance(mockAudio);

      await tester.pumpWidget(const TsumiPuraApp());
      await tester.pump();

      // Mute audio via HUD button
      await tester.tap(find.byKey(const Key('btn_mute_toggle')));
      await tester.pump();
      expect(mockAudio.isMuted, isTrue);

      // Trigger 5-second pomodoro combat
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      // Countdown 5 seconds
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 200));

      // Assert 0 audio triggers occurred across ALL sounds
      expect(mockAudio.attackHitCount, equals(0));
      expect(mockAudio.criticalStrikeCount, equals(0));
      expect(mockAudio.finishingKillCount, equals(0));
      expect(mockAudio.timerTickCount, equals(0));
      expect(mockAudio.victoryFanfareCount, equals(0));
    });

    test('2.3: SharedPreferences persistence across service reconstruction', () async {
      final service1 = MockRetroAudioService();
      service1.setMuted(true);

      // Settle SharedPreferences async write
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(BaseRetroAudioService.mutePrefKey), isTrue);

      // Reconstruct service and verify persisted state is restored
      final service2 = MockRetroAudioService();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(service2.isMuted, isTrue);

      // Unmute and verify persistence updates
      service2.setMuted(false);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(prefs.getBool(BaseRetroAudioService.mutePrefKey), isFalse);

      final service3 = MockRetroAudioService();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(service3.isMuted, isFalse);
    });
  });

  group('Milestone 4 Adversarial Stress 3: Cross-Platform Safety & Desktop Fallback', () {
    test('3.1: Test environment factory unconditionally returns silent MockRetroAudioService', () {
      final service = createPlatformAudioService();
      expect(service, isA<MockRetroAudioService>());
      expect(service.isMuted, isFalse);
    });

    test('3.2: DesktopRetroAudioService gracefully handles MissingPluginException on SystemChannels without unhandled async error', () async {
      // Simulate platform where SystemSound is not supported or native channel fails
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
        if (call.method == 'SystemSound.play') {
          throw MissingPluginException('No native implementation found for SystemSound.play');
        }
        return null;
      });

      try {
        final desktop = DesktopRetroAudioService();
        expect(desktop.isMuted, isFalse);

        // Spam 50 calls to verify unhandled asynchronous errors do not escape
        for (int i = 0; i < 50; i++) {
          desktop.playAttackHit();
          desktop.playCriticalStrike();
          desktop.playFinishingKill();
          desktop.playTimerTick();
          desktop.playButtonClick();
          desktop.playVictoryFanfare();
        }

        // Allow any microtasks / futures to settle
        await Future<void>.delayed(const Duration(milliseconds: 100));
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      }
    });

    test('3.3: DesktopRetroAudioService handles PlatformException without unhandled async error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
        if (call.method == 'SystemSound.play') {
          throw PlatformException(code: 'AUDIO_FAILURE', message: 'Audio hardware busy');
        }
        return null;
      });

      try {
        final desktop = DesktopRetroAudioService();
        for (int i = 0; i < 50; i++) {
          desktop.playAttackHit();
        }

        await Future<void>.delayed(const Duration(milliseconds: 100));
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      }
    });
  });

  group('Milestone 4 Adversarial Stress 4: Visual & Audio Concurrency Performance', () {
    testWidgets('4.1: ScreenShake does not destroy child BossHurtFlash animation state on first frame', (
      WidgetTester tester,
    ) async {
      final shakeController = ScreenShakeController();
      final flashController = BossHurtFlashController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenShake(
              controller: shakeController,
              child: BossHurtFlash(
                controller: flashController,
                child: const Center(child: Text('COMBAT TARGET')),
              ),
            ),
          ),
        ),
      );

      expect(find.text('COMBAT TARGET'), findsOneWidget);

      // Trigger simultaneous shake and flash (as occurs in _applyDamage in main.dart)
      shakeController.shake(intensity: 10.0);
      flashController.flash();

      expect(flashController.isFlashing, isTrue);

      // Advance by 30ms. BossHurtFlash duration is 220ms, so it must still be active!
      await tester.pump(const Duration(milliseconds: 30));

      // If ScreenShake replaces child with Transform.translate, Flutter tears down
      // the child subtree and BossHurtFlash is reset/killed.
      expect(
        flashController.isFlashing,
        isTrue,
        reason: 'BossHurtFlash animation was destroyed by ScreenShake rebuilding widget tree',
      );

      // Settle all juice animations
      await tester.pump(const Duration(seconds: 1));
      expect(shakeController.isShaking, isFalse);
      expect(flashController.isFlashing, isFalse);
    });
  });
}
