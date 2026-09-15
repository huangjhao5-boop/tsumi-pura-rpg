import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'retro_audio_service_stub.dart'
    if (dart.library.html) 'retro_audio_service_web.dart'
    if (dart.library.io) 'retro_audio_service_io.dart';

/// Abstract Contract for Zero-Cost Retro Audio (Feature 31).
abstract class IRetroAudioService {
  bool get isMuted;
  void toggleMute();
  void setMuted(bool muted);

  void playAttackHit();
  void playCriticalStrike();
  void playFinishingKill();
  void playTimerTick();
  void playButtonClick();
  void playVictoryFanfare();

  void dispose();
}

/// Base class managing mute state and persistent storage in SharedPreferences.
abstract class BaseRetroAudioService implements IRetroAudioService {
  static const String mutePrefKey = 'pref_retro_audio_muted';
  bool _isMuted = false;

  BaseRetroAudioService() {
    _loadMutePreference();
  }

  Future<void> _loadMutePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(mutePrefKey);
      if (saved != null) {
        _isMuted = saved;
      }
    } catch (_) {}
  }

  @override
  bool get isMuted => _isMuted;

  @override
  void toggleMute() {
    setMuted(!_isMuted);
  }

  @override
  void setMuted(bool muted) {
    _isMuted = muted;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(mutePrefKey, muted);
    }).catchError((_) {});
  }

  @override
  void dispose() {}
}

/// Mock / In-memory test audio service that runs completely silent
/// and tracks invocation counts for deterministic verification.
class MockRetroAudioService extends BaseRetroAudioService {
  int attackHitCount = 0;
  int criticalStrikeCount = 0;
  int finishingKillCount = 0;
  int timerTickCount = 0;
  int buttonClickCount = 0;
  int victoryFanfareCount = 0;

  void resetCounts() {
    attackHitCount = 0;
    criticalStrikeCount = 0;
    finishingKillCount = 0;
    timerTickCount = 0;
    buttonClickCount = 0;
    victoryFanfareCount = 0;
  }

  @override
  void playAttackHit() {
    if (!isMuted) attackHitCount++;
  }

  @override
  void playCriticalStrike() {
    if (!isMuted) criticalStrikeCount++;
  }

  @override
  void playFinishingKill() {
    if (!isMuted) finishingKillCount++;
  }

  @override
  void playTimerTick() {
    if (!isMuted) timerTickCount++;
  }

  @override
  void playButtonClick() {
    if (!isMuted) buttonClickCount++;
  }

  @override
  void playVictoryFanfare() {
    if (!isMuted) victoryFanfareCount++;
  }
}

/// Service locator / accessor for the active retro audio engine.
class RetroAudioService {
  static IRetroAudioService? _customInstance;
  static IRetroAudioService? _platformInstance;

  static IRetroAudioService get instance {
    if (_customInstance != null) return _customInstance!;
    _platformInstance ??= createPlatformAudioService();
    return _platformInstance!;
  }

  static void setCustomInstance(IRetroAudioService? service) {
    _customInstance = service;
  }

  static void resetInstance() {
    _customInstance = null;
    _platformInstance = null;
  }
}
