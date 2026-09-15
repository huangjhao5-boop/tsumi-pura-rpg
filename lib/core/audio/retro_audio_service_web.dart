import 'dart:async';
import 'dart:js_interop';
import 'retro_audio_service.dart';

IRetroAudioService createPlatformAudioService() {
  return WebRetroAudioService();
}

@JS('AudioContext')
extension type AudioContext._(JSObject _) implements JSObject {
  external AudioContext();
  external OscillatorNode createOscillator();
  external GainNode createGain();
  external AudioDestinationNode get destination;
  external double get currentTime;
  external JSPromise resume();
  external JSPromise close();
  external String get state;
}

@JS('OscillatorNode')
extension type OscillatorNode._(JSObject _) implements JSObject {
  external set type(String value);
  external AudioParam get frequency;
  external void connect(JSObject destination);
  external void start([double when]);
  external void stop([double when]);
}

@JS('GainNode')
extension type GainNode._(JSObject _) implements JSObject {
  external AudioParam get gain;
  external void connect(JSObject destination);
}

@JS('AudioDestinationNode')
extension type AudioDestinationNode._(JSObject _) implements JSObject {}

@JS('AudioParam')
extension type AudioParam._(JSObject _) implements JSObject {
  external void setValueAtTime(double value, double startTime);
  external void exponentialRampToValueAtTime(double value, double endTime);
}

/// Web procedural chiptune synthesizer using browser Web Audio API via dart:js_interop.
class WebRetroAudioService extends BaseRetroAudioService {
  AudioContext? _audioContext;

  AudioContext? get _ctx {
    try {
      _audioContext ??= AudioContext();
      if (_audioContext!.state == 'suspended') {
        _audioContext!.resume();
      }
      return _audioContext;
    } catch (_) {
      return null;
    }
  }

  void _playBeep({
    required String waveType,
    required double startFreq,
    required double endFreq,
    required double durationSeconds,
    double startGain = 0.2,
  }) {
    if (isMuted) return;
    try {
      final ctx = _ctx;
      if (ctx == null) return;
      final double now = ctx.currentTime;
      final osc = ctx.createOscillator();
      final gain = ctx.createGain();

      osc.type = waveType;
      osc.frequency.setValueAtTime(startFreq, now);
      osc.frequency.exponentialRampToValueAtTime(
        endFreq > 0 ? endFreq : 0.001,
        now + durationSeconds,
      );

      gain.gain.setValueAtTime(startGain, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + durationSeconds);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start(now);
      osc.stop(now + durationSeconds);
    } catch (_) {}
  }

  @override
  void playAttackHit() {
    _playBeep(
      waveType: 'square',
      startFreq: 320.0,
      endFreq: 120.0,
      durationSeconds: 0.12,
      startGain: 0.25,
    );
  }

  @override
  void playCriticalStrike() {
    _playBeep(
      waveType: 'sawtooth',
      startFreq: 640.0,
      endFreq: 160.0,
      durationSeconds: 0.22,
      startGain: 0.35,
    );
  }

  @override
  void playFinishingKill() {
    _playBeep(
      waveType: 'square',
      startFreq: 880.0,
      endFreq: 110.0,
      durationSeconds: 0.45,
      startGain: 0.40,
    );
  }

  @override
  void playTimerTick() {
    _playBeep(
      waveType: 'triangle',
      startFreq: 880.0,
      endFreq: 880.0,
      durationSeconds: 0.04,
      startGain: 0.08,
    );
  }

  @override
  void playButtonClick() {
    _playBeep(
      waveType: 'square',
      startFreq: 587.0,
      endFreq: 880.0,
      durationSeconds: 0.05,
      startGain: 0.12,
    );
  }

  @override
  void playVictoryFanfare() {
    if (isMuted) return;
    final notes = [523.25, 659.25, 784.0, 1046.5];
    double delay = 0.0;
    for (final note in notes) {
      Timer(Duration(milliseconds: (delay * 1000).toInt()), () {
        _playBeep(
          waveType: 'square',
          startFreq: note,
          endFreq: note,
          durationSeconds: 0.15,
          startGain: 0.25,
        );
      });
      delay += 0.18;
    }
  }

  @override
  void dispose() {
    if (_audioContext != null) {
      try {
        _audioContext!.close();
      } catch (_) {}
      _audioContext = null;
    }
    super.dispose();
  }
}
