# Handoff Report: Feature 31 (Zero-Cost Retro Audio)

## 1. Observation
- **Pubspec & Dependencies**:
  - `pubspec.yaml` (lines 30-40) contains only `flutter`, `cupertino_icons`, `google_fonts`, `uuid`, and `shared_preferences`. No audio packages (`audioplayers`, `just_audio`, `soundpool`) are present.
  - Assets declaration in `pubspec.yaml` (lines 63-65) lists only `- assets/images/`. No audio asset directories exist.
  - File system check in `assets/` shows only `images/boss_green_box.jpg` and `images/hero.jpg`.
- **Existing App & UI Structure**:
  - `lib/main.dart` (lines 681-748) implements `_buildHeaderHUD()`, containing a left row with quick links (`btn_hangar`, `btn_showcase`, `btn_craft_log`) and a right row with user coins (`$userCoins 塑料金幣`). No mute button currently exists.
  - `lib/main.dart` (lines 367-385) implements `_triggerHitJuice(int damage, bool isInterrupted)`, which updates `_floatingDamageText` and triggers `_shakeController`, but contains no audio triggers.
  - `lib/main.dart` (lines 405-436) implements `_showQuestClearDialog()`, displaying `★ QUEST CLEAR ★` upon boss defeat, without sound fanfare.
  - `lib/main.dart` (lines 197-206) implements `_startWorkPhase()`, ticking down `_remainingSeconds` every second via `Timer.periodic`.
- **Test Suite Baseline**:
  - Executed `flutter test` at workspace root: completed in 35 seconds with `All tests passed!` across 171 test cases.
  - Existing tests execute headless; any platform channel invocation without mocking or fallback triggers `MissingPluginException`.
- **SDK & Platform Constraints**:
  - Flutter version: `3.38.5`, Dart SDK `3.10.4`.
  - Web target uses browser Web Audio API (`AudioContext`, `OscillatorNode`, `GainNode`).
  - Windows desktop lacks pre-configured C++ audio plugins; introducing packages requiring MSVC/CMake compilation risks build failures in restricted environments.

## 2. Logic Chain
1. **Zero-Cost & Zero-C++-Complication Requirement**:
   - Observation shows zero audio packages in `pubspec.yaml` and zero audio assets in `assets/`.
   - Introducing `audioplayers` or `just_audio` introduces `audioplayers_windows` or `just_audio_windows`, requiring C++ CMake toolchains on Windows desktop, which violates the constraint of "0 native C++ library complications" and causes `MissingPluginException` in headless `flutter test`.
   - In contrast, pure procedural synthesis via the browser's native **Web Audio API** on Web (`dart:html`) requires 0 external dependencies, 0 network bandwidth, and generates authentic 8-bit chiptune square/triangle/noise waves directly in hardware buffers.
2. **Cross-Platform Decoupling via `IRetroAudioService`**:
   - Defining `IRetroAudioService` with implementations `WebRetroAudioService`, `DesktopRetroAudioService`, and `MockRetroAudioService` cleanly isolates platform differences.
   - Using Dart conditional imports (`dart.library.html` vs `dart.library.io`) prevents Web code from leaking into Windows/test compilation, and vice versa.
   - Detecting `Platform.environment.containsKey('FLUTTER_TEST')` in `retro_audio_io.dart` guarantees that any test running without explicit DI automatically defaults to `MockRetroAudioService`.
3. **Sound Trigger Matrix Mapping**:
   - `playAttackHit`: Triggers in `_triggerHitJuice` on standard session completion (frequency drop 320 Hz -> 120 Hz).
   - `playCriticalStrike`: Triggers in `_triggerHitJuice` for high damage (>=150) or Airbrush/Detailing phases (sawtooth/square dual layer).
   - `playFinishingKill`: Triggers in `_triggerHitJuice` when boss HP reaches 0 (multi-stage explosion sweep).
   - `playTimerTick`: Triggers in `_startWorkPhase` countdown during the final 5 seconds (triangle soft blip at 880 Hz).
   - `playButtonClick`: Triggers on phase selection, mode switch, and navigation badges (D5 -> A5 chirp).
   - `playVictoryFanfare`: Triggers in `_showQuestClearDialog` (4-note arpeggio C5-E5-G5-C6).
4. **Header HUD Mute Integration**:
   - Placing `Key('btn_mute_toggle')` in `_buildHeaderHUD()` alongside user coins provides intuitive user control.
   - Persisting state in `SharedPreferences` (`pref_retro_audio_muted`) preserves mute preference across reloads.

## 3. Caveats
- **Browser Autoplay Policy**:
  - Web browsers require user interaction (click/touch) before an `AudioContext` can transition from `'suspended'` to `'running'`. The implementation handles this by invoking `ctx.resume()` on the first user action (e.g. clicking start, changing tabs, or toggling mute).
- **Windows Audio Scope**:
  - On Windows desktop, to guarantee 0 native C++ build complications, `DesktopRetroAudioService` utilizes Flutter's built-in `SystemSound.play(SystemSoundType.click)` for tactile feedback and graceful fallback rather than heavy C++ COM players.
- **Timer Tick Cadence**:
  - To prevent auditory fatigue during 25-minute or 50-minute sessions, `playTimerTick` is designed to sound during the final 5 seconds of countdown rather than every single second of the entire session.

## 4. Conclusion
The optimal, zero-cost, zero-C++-complication solution for Feature 31 is a **Procedural Web Audio API Chiptune Engine** on Web, a **Safe SystemSound Fallback** on Windows desktop, and an **In-Memory Mock Engine** for automated tests, unified behind `IRetroAudioService`. This delivers 100% authentic 8-bit retro audio, sub-millisecond latency, zero external asset downloads, and zero test regression risk.

## 5. Verification Method
1. **Unit Test Verification**:
   - Run `flutter test test/unit/retro_audio_service_test.dart` to verify `IRetroAudioService` contract, mute toggling, and sound trigger counters.
2. **Widget Test Verification**:
   - Run `flutter test test/widget/retro_audio_widget_test.dart` to verify Header HUD mute button rendering (`btn_mute_toggle`), icon/text toggling between `SFX` and `MUTE`, and combat sound invocations.
3. **Full Regression Suite**:
   - Run `flutter test` across all existing tests; all 171+ tests must pass with 0 failures and 0 warnings.
4. **Static Analysis**:
   - Run `flutter analyze` to ensure 0 errors and 0 lint warnings.
5. **Invalidation Conditions**:
   - Any requirement to add heavy native C++ binary packages that fail Windows compilation or throw `MissingPluginException` in CI tests invalidates this design.
