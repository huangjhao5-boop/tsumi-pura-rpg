import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'retro_audio_service.dart';

IRetroAudioService createPlatformAudioService() {
  try {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return MockRetroAudioService();
    }
    final binding = WidgetsBinding.instance;
    if (binding.runtimeType.toString().contains('Test')) {
      return MockRetroAudioService();
    }
  } catch (_) {}
  return DesktopRetroAudioService();
}

/// Desktop / native audio service using built-in SystemSound as a safe fallback.
class DesktopRetroAudioService extends BaseRetroAudioService {
  void _safeClick() {
    if (isMuted) return;
    try {
      SystemSound.play(SystemSoundType.click).catchError((_) {});
    } catch (_) {}
  }

  @override
  void playAttackHit() => _safeClick();

  @override
  void playCriticalStrike() => _safeClick();

  @override
  void playFinishingKill() => _safeClick();

  @override
  void playTimerTick() => _safeClick();

  @override
  void playButtonClick() => _safeClick();

  @override
  void playVictoryFanfare() => _safeClick();
}
