# Feature 31: Zero-Cost Retro Audio Technical Analysis

## Executive Summary
Feature 31 requires a 100% zero-cost retro audio solution for Flutter on Web and Windows desktop with 0 paid APIs, 0 cloud tokens, and 0 native C++ library complications. The recommended and optimal architecture is a **Procedural Web Audio API Chiptune Oscillator Engine on Web** coupled with a **Safe Platform Fallback on Windows Desktop** and a **Deterministic In-Memory Mock Engine for Tests**, unified under the `IRetroAudioService` contract.

---

## 1. Problem Space & Technical Constraints Analysis

### 1.1 Cross-Platform Matrix & Constraints
| Target Environment | Key Challenges | Solution Strategy |
| :--- | :--- | :--- |
| **Web Browser** | Audio autoplay restrictions, asset load latency, bundle size | Pure Dart Web Audio API interop synthesizing authentic 8-bit square/triangle/noise waves directly in the browser. 0 asset download delay, sub-millisecond trigger latency. |
| **Windows Desktop** | Heavy C++ dependencies (CMake/MSVC), missing Windows SDKs in CI, DLL incompatibilities | Graceful platform fallback via Flutter's built-in `SystemSound.play` and safe no-op. 0 C++ plugins to compile, 100% compile guarantee. |
| **Headless CI & `flutter test`** | `MissingPluginException`, missing audio hardware, async timer leaks | Complete decoupling via `IRetroAudioService` and `MockRetroAudioService`. Automated fallback when running under test harness. Silent, deterministic execution. |

### 1.2 Evaluation of Candidate Solutions
1. **Candidate A: Heavy Third-Party Plugins (`audioplayers`, `just_audio`)**:
   - *Pros*: Out-of-the-box support for mp3/wav playback.
   - *Cons*: On Windows, requires native C++ plugins (`audioplayers_windows`). Lacks MSVC/CMake compatibility across heterogeneous developer and CI environments. Causes `MissingPluginException` in `flutter test` unless complex channel mocks are configured. Large binary footprint.
   - *Verdict*: **Rejected** due to native C++ compilation complications and test fragility.

2. **Candidate B: Bundled Audio Files (`soundpool`)**:
   - *Pros*: Low latency audio caching on mobile/web.
   - *Cons*: Windows desktop support is unmaintained or experimental. Requires bundling binary audio assets (`.mp3`/`.wav`), bloating repo and asset manifests.
   - *Verdict*: **Rejected**.

3. **Candidate C: Procedural Web Audio API Synthesis + Platform Fallback (Recommended)**:
   - *Pros*:
     - **0 Cost & 0 Cloud Tokens**: 100% free and local.
     - **0 C++ Native Compilation**: Zero extra dependencies in `pubspec.yaml`, compiles seamlessly on all platforms.
     - **Authentic 8-Bit Chiptune Timbre**: Emulates the NES/Game Boy APU using square waves (lead bleeps, fanfare), triangle waves (soft ticks), and noise buffers (critical hit crunch, explosion).
     - **Instant Playback**: Zero network or disk I/O latency.
     - **100% Testable**: Zero platform channel errors during `flutter test`.
   - *Verdict*: **Adopted as primary blueprint**.

---

## 2. Sound Trigger Matrix & Acoustic Design

Every game action in 《罪普拉 RPG》 maps to a distinct retro chiptune waveform:

| Sound Identifier | APU / Waveform Type | Frequency / Pitch Trajectory | Duration | Volume / Envelope | In-Game Trigger Point |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Attack Hit** (`playAttackHit`) | Square Wave (50% duty) | 320 Hz → 120 Hz downward sweep | ~120 ms | Exponential decay (0.25 → 0.001) | Standard work session damage application (Snap-fit, Sanding, Detailing). |
| **Critical Strike** (`playCriticalStrike`) | Dual Layer: Sawtooth + Sub-Square | Sawtooth 640 Hz → 160 Hz + Sub-octave 320 Hz → 80 Hz | ~220 ms | High impact punch (0.35 → 0.001) | Airbrush bomb, Detailing weak-point critical, or damage >= 150. |
| **Finishing Kill** (`playFinishingKill`) | Dual Layer: Multi-stage descent + Noise blast | Square 880 Hz → 110 Hz + Random noise buffer | ~450 ms | Dramatic explosion (0.40 → 0.001) | Boss HP reaches 0 or Finishing execution blow. |
| **Timer Tick** (`playTimerTick`) | Triangle Wave | 880 Hz stable blip | ~30 ms | Soft blip (0.08 → 0.001) | Final 5 seconds of Pomodoro work/rest countdown. |
| **Button Click** (`playButtonClick`) | Square Wave | D5 (587 Hz) → A5 (880 Hz) chirp | ~40 ms | Crisp UI feedback (0.12 → 0.001) | UI interaction: mode switch, phase switch, start/stop, mute toggle. |
| **Victory Fanfare** (`playVictoryFanfare`) | 4-Note Chiptune Arpeggio (Square) | C5 (523 Hz) → E5 (659 Hz) → G5 (784 Hz) → C6 (1046 Hz) | ~800 ms | Staccato triumphant melody (0.25 gain) | Quest Clear modal opening (`_showQuestClearDialog()`). |

---

## 3. Header HUD Mute Toggle Integration

### 3.1 UI & Layout Specifications
- **Location**: `BattleAtelierScreen._buildHeaderHUD()` in `lib/main.dart`.
- **Widget Key**: `Key('btn_mute_toggle')`.
- **Visual Presentation**:
  - **Unmuted (Active)**:
    - Border: `#BD93F9` (Retro Arcade Purple, 1.2px)
    - Icon: `Icons.volume_up` (size 10)
    - Text: `'SFX'` (fontSize 7, bold)
  - **Muted**:
    - Border: `Colors.white38` (Dimmed Slate, 1.2px)
    - Icon: `Icons.volume_off` (size 10)
    - Text: `'MUTE'` (fontSize 7, bold)
- **Persistence**:
  - Stored in `SharedPreferences` under key `pref_retro_audio_muted`.
  - Hydrated on app launch so user audio preference is preserved across reloads.

---

## 4. Architecture & Interface Blueprint

### 4.1 Interface Contract: `IRetroAudioService`
```dart
// lib/core/audio/retro_audio_service.dart

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
```

### 4.2 Platform Decoupling via Conditional Compilation
Dart's conditional imports allow seamless separation between Web (`dart:html`) and Desktop/VM (`dart:io`):
```dart
// lib/core/audio/retro_audio_platform.dart
import 'retro_audio_service.dart';
import 'retro_audio_stub.dart'
    if (dart.library.html) 'retro_audio_web.dart'
    if (dart.library.io) 'retro_audio_io.dart';

IRetroAudioService createDefaultAudioService() => createPlatformAudioService();
```

- **`retro_audio_web.dart`**: Implements `WebRetroAudioService` using `dart:html.AudioContext`, `OscillatorNode`, and `GainNode`. Includes automatic user gesture detection via `AudioContext.resume()`.
- **`retro_audio_io.dart`**: Implements `DesktopRetroAudioService` using `SystemSound.play(SystemSoundType.click)`. Detects `Platform.environment.containsKey('FLUTTER_TEST')` to automatically return `MockRetroAudioService`.
- **`mock_retro_audio_service.dart`**: Implements `IRetroAudioService` with invocation tracking counters (`playAttackHitCount`, etc.) for zero-side-effect test assertions.

---

## 5. Implementation Roadmap & Verification Plan

1. **Phase 1: Core Audio Layer**:
   - Create `lib/core/audio/retro_audio_service.dart` (Interface & Singleton accessor).
   - Create `lib/core/audio/retro_audio_web.dart` (Web Audio API procedural synth).
   - Create `lib/core/audio/retro_audio_io.dart` (Desktop fallback & test detector).
   - Create `lib/core/audio/mock_retro_audio_service.dart` (In-memory test mock).
   - Create `lib/core/audio/retro_audio_platform.dart` (Conditional factory).

2. **Phase 2: UI & Main Integration**:
   - Inject `IRetroAudioService` into `BattleAtelierScreen` in `lib/main.dart`.
   - Add Mute Toggle button (`btn_mute_toggle`) in `_buildHeaderHUD()`.
   - Hook audio triggers into `_triggerHitJuice`, `_showQuestClearDialog`, `_startWorkPhase` (timer countdown), and UI buttons.

3. **Phase 3: Automated Testing & Verification**:
   - Write `test/unit/retro_audio_service_test.dart` covering contract, mute toggling, and sound triggers.
   - Write `test/widget/retro_audio_widget_test.dart` testing the mute HUD button and combat audio trigger integration.
   - Run full regression test suite (`flutter test`) to verify all 171+ existing tests remain green.
   - Run `flutter analyze` to verify 0 errors, 0 warnings.
