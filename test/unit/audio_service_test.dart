import 'package:flutter_test/flutter_test.dart';
import 'package:nifty_heisenberg/core/audio/retro_audio_service.dart';
import 'package:nifty_heisenberg/core/audio/retro_audio_service_io.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RetroAudioService.resetInstance();
  });

  tearDown(() {
    RetroAudioService.resetInstance();
  });

  group('IRetroAudioService & MockRetroAudioService Unit Tests', () {
    test('MockRetroAudioService tracks sound invocations correctly', () {
      final service = MockRetroAudioService();

      expect(service.isMuted, isFalse);
      expect(service.attackHitCount, equals(0));
      expect(service.criticalStrikeCount, equals(0));
      expect(service.finishingKillCount, equals(0));
      expect(service.timerTickCount, equals(0));
      expect(service.buttonClickCount, equals(0));
      expect(service.victoryFanfareCount, equals(0));

      service.playAttackHit();
      service.playCriticalStrike();
      service.playFinishingKill();
      service.playTimerTick();
      service.playButtonClick();
      service.playVictoryFanfare();

      expect(service.attackHitCount, equals(1));
      expect(service.criticalStrikeCount, equals(1));
      expect(service.finishingKillCount, equals(1));
      expect(service.timerTickCount, equals(1));
      expect(service.buttonClickCount, equals(1));
      expect(service.victoryFanfareCount, equals(1));

      service.resetCounts();
      expect(service.attackHitCount, equals(0));
      expect(service.criticalStrikeCount, equals(0));
      expect(service.finishingKillCount, equals(0));
      expect(service.timerTickCount, equals(0));
      expect(service.buttonClickCount, equals(0));
      expect(service.victoryFanfareCount, equals(0));
    });

    test('Mute toggle suppresses sound triggers in MockRetroAudioService', () {
      final service = MockRetroAudioService();

      expect(service.isMuted, isFalse);
      service.toggleMute();
      expect(service.isMuted, isTrue);

      // Invocations while muted should NOT increment counts
      service.playAttackHit();
      service.playCriticalStrike();
      service.playFinishingKill();
      service.playTimerTick();
      service.playButtonClick();
      service.playVictoryFanfare();

      expect(service.attackHitCount, equals(0));
      expect(service.criticalStrikeCount, equals(0));
      expect(service.finishingKillCount, equals(0));
      expect(service.timerTickCount, equals(0));
      expect(service.buttonClickCount, equals(0));
      expect(service.victoryFanfareCount, equals(0));

      // Unmute restores counting
      service.setMuted(false);
      expect(service.isMuted, isFalse);

      service.playAttackHit();
      expect(service.attackHitCount, equals(1));
    });

    test('Mute preference persists in SharedPreferences', () async {
      final service = MockRetroAudioService();
      service.setMuted(true);

      // Allow SharedPreferences async write to settle
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(BaseRetroAudioService.mutePrefKey), isTrue);

      // Create another service and verify it loads the persisted preference
      final service2 = MockRetroAudioService();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(service2.isMuted, isTrue);
    });

    test('DesktopRetroAudioService runs safely without throwing', () {
      final desktop = DesktopRetroAudioService();
      expect(desktop.isMuted, isFalse);

      // Calling play methods should not throw any exceptions
      expect(() => desktop.playAttackHit(), returnsNormally);
      expect(() => desktop.playCriticalStrike(), returnsNormally);
      expect(() => desktop.playFinishingKill(), returnsNormally);
      expect(() => desktop.playTimerTick(), returnsNormally);
      expect(() => desktop.playButtonClick(), returnsNormally);
      expect(() => desktop.playVictoryFanfare(), returnsNormally);

      desktop.setMuted(true);
      expect(desktop.isMuted, isTrue);
      expect(() => desktop.playAttackHit(), returnsNormally);
    });

    test('RetroAudioService locator supports custom instances and reset', () {
      final customMock = MockRetroAudioService();
      RetroAudioService.setCustomInstance(customMock);

      expect(identical(RetroAudioService.instance, customMock), isTrue);

      RetroAudioService.resetInstance();
      // Should now return default service (which in test environment is a mock)
      expect(identical(RetroAudioService.instance, customMock), isFalse);
      expect(RetroAudioService.instance, isA<IRetroAudioService>());
    });
  });
}
