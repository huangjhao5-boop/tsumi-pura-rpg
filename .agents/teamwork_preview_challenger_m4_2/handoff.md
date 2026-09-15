# Milestone 4 Adversarial Challenge Report: Audio & Performance Stress

**Verdict**: **REQUEST_CHANGES**

---

## 1. Observation

### 1.1 Tool Execution Results
1. **Static Analysis**:
   - Command: `flutter analyze`
   - Result: Exit code 0 (`No issues found! (ran in 4.2s)`).
2. **Baseline Test Suite**:
   - Command: `flutter test`
   - Result: Exit code 0 (`00:38 +190: All tests passed!`).
3. **Milestone 4 Adversarial Challenge Suite**:
   - Authored test file: `test/challenge/m4_audio_performance_stress_test.dart`
   - Command: `flutter test test/challenge/m4_audio_performance_stress_test.dart`
   - Result: Exit code 1 (8 passed, 2 failed).

### 1.2 Verbatim Errors & Observed Failure Modes

#### Failure A: Unhandled Asynchronous Exception in `DesktopRetroAudioService._safeClick`
- **File**: `lib/core/audio/retro_audio_service_io.dart` (lines 20–26)
- **Verbatim Code**:
  ```dart
  class DesktopRetroAudioService extends BaseRetroAudioService {
    void _safeClick() {
      if (isMuted) return;
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  ```
- **Observed Error in Test Execution**:
  ```
  PlatformException(AUDIO_FAILURE, Audio hardware busy, null, null)
  package:flutter/src/services/message_codecs.dart 168:7                 JSONMethodCodec.decodeEnvelope
  package:flutter/src/services/platform_channel.dart 367:18              MethodChannel._invokeMethod
  ===== asynchronous gap ===========================
  dart:async                                                             _CustomZone.registerBinaryCallback
  package:flutter/src/services/system_sound.dart 44:5                    SystemSound.play
  package:nifty_heisenberg/core/audio/retro_audio_service_io.dart 24:19  DesktopRetroAudioService._safeClick
  package:nifty_heisenberg/core/audio/retro_audio_service_io.dart 29:27  DesktopRetroAudioService.playAttackHit
  ```
- **Description**: `SystemSound.play` returns a `Future<void>`. Synchronous `try {} catch (_) {}` cannot catch errors from unawaited Futures. When `SystemChannels.platform` throws `MissingPluginException` or `PlatformException` (e.g. absent audio device, busy audio device, or unsupported desktop environment), the rejected Future escapes as an unhandled asynchronous error into the Zone, crashing tests and breaking the app's error boundary.

#### Failure B: `ScreenShake` Dynamic Tree Restructuring Destroys Child `BossHurtFlash` Animation
- **File**: `lib/presentation/widgets/screen_shake.dart` (lines 84–101)
- **Verbatim Code**:
  ```dart
  return AnimatedBuilder(
    animation: _animController,
    builder: (context, child) {
      if (!_animController.isAnimating || _animController.value >= 1.0) {
        return child!;
      }

      final double t = _animController.value;
      final double decay = (1.0 - t) * (1.0 - t);
      final double dx = sin(t * 10 * pi) * _currentIntensity * decay;
      final double dy = cos(t * 7 * pi) * (_currentIntensity * 0.45) * decay;

      return Transform.translate(
        offset: Offset(dx, dy),
        child: child,
      );
    },
    child: widget.child,
  );
  ```
- **Observed Error in Test Execution**:
  ```
  00:04 +8 -1: Milestone 4 Adversarial Stress 4: Visual & Audio Concurrency Performance 4.1: ScreenShake does not destroy child BossHurtFlash animation state on first frame
  ══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
  The following TestFailure was thrown running a test:
  Expected: true
    Actual: <false>
  BossHurtFlash animation was destroyed by ScreenShake rebuilding widget tree
  ```
- **Description**: In `lib/main.dart` lines 390–394, when damage is dealt:
  ```dart
  _screenShakeController.shake(intensity: intensity);
  _bossHurtFlashController.flash();
  ```
  `ScreenShake` wraps `BossHurtFlash`. When resting, `ScreenShake` returns `child!`. When animating, it returns `Transform.translate(child: child)`. In Flutter's element reconciliation, inserting an intermediate `Transform` widget without key-based preservation alters the element hierarchy, causing Flutter to unmount the entire child subtree on frame 1. This unmounts `BossHurtFlash`, calls `dispose()`, detaches `_bossHurtFlashController`, and mounts a new idle instance with `isFlashing == false`. The 220ms boss hurt flash animation is therefore instantly destroyed on frame 1 whenever a hit triggers a screen shake.

### 1.3 Verified Passing Behaviors
1. **MockRetroAudioService Stress**:
   - 100 consecutive invocations per sound method (600 total) tracked with exact counter parity and 0 dropped triggers.
   - Concurrent async burst of 200 mixed triggers across microtasks completed without race conditions.
   - 500+ trigger flood followed by `resetCounts()` operates reliably.
2. **Mute Toggle HUD & Persistence**:
   - 50 rapid taps on `btn_mute_toggle` in header HUD preserve parity (50 taps -> SFX unmuted; 51 taps -> MUTE muted).
   - Combat silence: With mute enabled, 5-second pomodoro combat produces exactly 0 audio triggers across all 6 sound types.
   - Persistence: Mute state persists into `SharedPreferences` (`pref_retro_audio_muted`) and is loaded across service reconstructions.
3. **Silent Test Environment**:
   - `createPlatformAudioService()` safely detects `WidgetsBinding` test environment and returns `MockRetroAudioService`.

---

## 2. Logic Chain

1. **From Observation 1.2 (Failure A) to Platform Instability**:
   - In Dart, an unawaited `Future` returned by an asynchronous function (`SystemSound.play`) does not throw synchronously.
   - The synchronous `try {} catch (_) {}` block in `DesktopRetroAudioService._safeClick` exits immediately while the `invokeMethod` call is still pending on the event loop.
   - When the native platform channel throws `MissingPluginException` or `PlatformException`, the error is unhandled, triggering `Zone.handleUncaughtError`.
   - Therefore, claims of "safe desktop fallback" are invalid whenever native platform channels throw or audio hardware is busy.
2. **From Observation 1.2 (Failure B) to Juice Animation Bug**:
   - In `lib/main.dart`, `ScreenShake` wraps `FloatingDamageOverlay` and `BossHurtFlash`.
   - In `_applyDamage()`, both `_screenShakeController.shake()` and `_bossHurtFlashController.flash()` are triggered in the same event.
   - When `ScreenShake` switches from returning `child!` to returning `Transform.translate(child: child)`, Flutter's element tree structure changes: `ScreenShakeElement` -> `TransformElement` -> `ComponentElement`.
   - Because `Transform` was not in the previous tree, the existing `StatefulElement` of `BossHurtFlash` is deactivated and unmounted, triggering `_BossHurtFlashState.dispose()`.
   - This resets `_bossHurtFlashController.isFlashing` from `true` to `false` on the very first frame, completely neutralizing the visual impact of Feature 30 (Boss Hurt Flash) during combat.

---

## 3. Caveats

- Web Audio API procedural synthesis was validated via static analysis and mock abstraction; live audio buffer rendering requires a headless browser runtime with Web Audio support.
- No other caveats.

---

## 4. Conclusion

**Verdict: REQUEST_CHANGES**

The implementation is high quality and passes existing baseline tests, but adversarial stress testing has revealed two bugs that must be corrected:

1. **Fix `DesktopRetroAudioService._safeClick`**:
   In `lib/core/audio/retro_audio_service_io.dart`, attach `.catchError((_) {})` to `SystemSound.play`:
   ```dart
   void _safeClick() {
     if (isMuted) return;
     try {
       SystemSound.play(SystemSoundType.click).catchError((_) {});
     } catch (_) {}
   }
   ```
2. **Fix `ScreenShake.build` to maintain element hierarchy stability**:
   In `lib/presentation/widgets/screen_shake.dart`, always return `Transform.translate` rather than conditionally returning `child!`:
   ```dart
   @override
   Widget build(BuildContext context) {
     if (!widget.enabled || !ScreenShake.globalEnabled) {
       return widget.child;
     }
     return AnimatedBuilder(
       animation: _animController,
       builder: (context, child) {
         final bool isShaking =
             _animController.isAnimating && _animController.value < 1.0;
         final double t = _animController.value;
         final double decay = (1.0 - t) * (1.0 - t);
         final double dx =
             isShaking ? sin(t * 10 * pi) * _currentIntensity * decay : 0.0;
         final double dy = isShaking
             ? cos(t * 7 * pi) * (_currentIntensity * 0.45) * decay
             : 0.0;

         return Transform.translate(
           offset: Offset(dx, dy),
           child: child,
         );
       },
       child: widget.child,
     );
   }
   ```

---

## 5. Verification Method

1. **Run Static Analysis**:
   ```powershell
   flutter analyze
   ```
   *Expected*: `No issues found!`
2. **Run Baseline Tests**:
   ```powershell
   flutter test
   ```
   *Expected*: 190 tests pass.
3. **Run Adversarial Stress Test Suite**:
   ```powershell
   flutter test test/challenge/m4_audio_performance_stress_test.dart
   ```
   *Expected*: Once the two fixes above are applied, all 9 challenge tests pass with 0 failures and 0 unhandled exceptions.
