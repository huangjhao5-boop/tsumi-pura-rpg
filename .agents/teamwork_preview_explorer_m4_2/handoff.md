# Handoff Report: Milestone 4 Battle Juice Animations (Features 28, 29, 30)

## 1. Observation
1. **Existing Shake Prototype** (`lib/main.dart:934-945`):
   - Current implementation:
     ```dart
     double shakeOffset = sin(_shakeController.value * pi * 8) * 8 * (1 - _shakeController.value);
     return Transform.translate(offset: Offset(shakeOffset, 0), child: child);
     ```
   - Only shakes along the X-axis (`Offset(shakeOffset, 0)`), only wraps `_buildBattleStage()`, and uses fixed 8px intensity regardless of craft phase or damage dealt.
2. **Existing Damage Popup Prototype** (`lib/main.dart:1056-1078`):
   - Current implementation:
     ```dart
     if (_floatingDamageText != null)
       Positioned(
         top: 30,
         right: 70,
         child: Container(... Text(_floatingDamageText! ...)),
       )
     ```
   - Lacks pop-in scale bounce, vertical rise translation, and fade out. Color is binary (amber for Mercy, red for others at `lib/main.dart:373-375`). Does not reflect SPEC §2 phase colors (Snap-fit white, Sanding yellow, Detailing neon yellow, Airbrush cyan, Finishing gold).
3. **Existing Boss Hurt Flash Prototype** (`lib/main.dart:983-987`):
   - Current implementation:
     ```dart
     colorFilter: _isHurt ? const ColorFilter.mode(Color(0x99FF0000), BlendMode.srcATop) : ...
     ```
   - `_isHurt` is a raw boolean bound to `_shakeController.forward()` completion (`Duration(milliseconds: 400)`). It lacks dedicated 150–250ms arcade strobe or opacity decay.
4. **Existing Test Suite Baseline**:
   - `flutter test` was executed via `run_command` (task id: `820ce54c-a5ae-4fe7-b1ac-abe24bb83ff7/task-36`).
   - Verbatim result:
     `00:47 +171: All tests passed!`
   - Tests trigger pomodoro completions with `pump(const Duration(seconds: 1))`.
   - Zero tests assert on `CRITICAL!` or `MERCY 50%` text strings or `_isHurt`.

## 2. Logic Chain
1. From Observation 1: The current screen shake is 1D horizontal wobble hardcoded inside `main.dart`. Wrapping `BattleScreen` / `BattleAtelierScreen` in a decoupled `ScreenShake` widget driven by `ScreenShakeController` with a 2D asymmetric harmonic formula ($\Delta x = \sin(10\pi t) \cdot I \cdot (1-t)^2$, $\Delta y = \cos(7\pi t) \cdot 0.45 I \cdot (1-t)^2$) provides authentic 8-bit arcade rumble with customizable intensity (e.g., 7px for Snap-fit, 16px for Airbrush, 22px for Finishing).
2. From Observation 2: Decoupling floating damage numbers into `FloatingDamageOverlay` with `FloatingDamageController` enables dynamic spawning of pop-up bubbles that scale up with overshoot (`Curves.easeOutBack`), rise $-48$ px (`Curves.easeOutCubic`), and fade to zero over 900ms. Mapping colors via `DamageColorPalette` cleanly implements the SPEC §2 requirement (White for Snap-fit, Yellow for Sanding, Neon Yellow for Detailing, Cyan for Airbrush, Radiant Gold for Finishing, Warning Amber for Mercy).
3. From Observation 3: Decoupling the hurt flash into `BossHurtFlash` driven by `BossHurtFlashController` with a 220ms dual-pulse arcade strobe (`BlendMode.srcATop` over sprite alpha) and recoil squeeze cleanly satisfies the ~150–300ms requirement without being tethered to the 400ms shake.
4. From Observation 4: Existing widget tests pump 1 second per step (`pump(Duration(seconds: 1))`). Because all three juice animations have finite durations $\le 900$ ms and run on `AnimationController` through `TickerProvider` (with zero raw `Timer` instances), all animations settle completely within a single 1-second pump. No tests will hang, timeout, or experience pending timer warnings.

## 3. Caveats
1. **Accessibility / Reduced Motion**: While `Transform.translate` does not block interactions or cause reflows, users sensitive to motion may want an option to disable screen shake. A static boolean `ScreenShake.enabled` (default `true`) is provided in the blueprint so it can be globally disabled at any time.
2. **Audio Coordination**: Feature 31 (Zero-Cost Retro Audio) is assigned to Explorer 3 (`teamwork_preview_explorer_m4_3`). The trigger points identified in `_calculateAndApplyDamage` (`_triggerBattleJuice`) are the exact same sites where audio sound effects (`IRetroAudioService.playHit()`, `playCrit()`, `playFinishing()`) will be hooked.
3. **Typography Coordination**: Explorer 1 (`teamwork_preview_explorer_m4_1`) is standardizing `retro_theme.dart`. The floating damage bubbles in `battle_effects.dart` specify `fontFamily: 'Press Start 2P'` with fallback `['VT323', 'monospace']`, which is 100% aligned with Explorer 1's work.

## 4. Conclusion
Features 28, 29, and 30 can be cleanly implemented in a single cohesive, decoupled widget library at `lib/presentation/widgets/battle_effects.dart`.
- `ScreenShake` + `ScreenShakeController`: 2D asymmetric arcade shake with quadratic decay and phase-scaled intensity (7px to 22px).
- `FloatingDamageOverlay` + `FloatingDamageController` + `DamageColorPalette`: 900ms pop-up bubble with overshoot bounce, $-48$px rise, fade out, and exact SPEC §2 color coding.
- `BossHurtFlash` + `BossHurtFlashController`: 220ms dual-pulse crimson strobe overlay with impact squeeze.
- Hooked cleanly into `main.dart` via `_triggerBattleJuice()` called inside `_calculateAndApplyDamage`.
- Fully documented in `analysis.md` with complete, drop-in Dart code ready for the implementation worker.

## 5. Verification Method
1. **Build & Static Analysis**:
   ```powershell
   flutter analyze
   ```
   Must pass with 0 errors and 0 warnings.
2. **Regression Verification**:
   ```powershell
   flutter test
   ```
   All 171 existing unit, challenge, and widget tests must pass cleanly.
3. **New Automated Widget Test Suite**:
   Create and execute `test/widget/battle_effects_test.dart` to verify:
   - `ScreenShake` transforms and restores to `Offset.zero`, allowing non-blocking hit tests.
   - `FloatingDamageOverlay` renders correct texts and colors for Snap-fit, Sanding, Detailing, Airbrush, Finishing, and Mercy, self-removing after 900ms.
   - `BossHurtFlash` applies crimson tint and decays back to transparent within 220ms.
   - Complete 5s Pomodoro combat cycle in `BattleAtelierScreen` dispatches all three effects without throwing.
