# E2E Test Coverage Specification: R1 & R2 (Milestone 5)

## 1. Executive Summary & Problem Boundary

This document establishes the end-to-end (E2E) opaque-box testing specifications for **R1 (Complete Pomodoro & Battle Engine, Features 1–12)** and **R2 (Local Persistence & CraftLog, Features 13–17)** of the *Tsumi-Pura RPG* project.

In accordance with strict opaque-box testing principles:
- All interactions simulate real user gestures (`tester.tap`, `tester.enterText`, `tester.pump`).
- All validations verify user-facing UI elements (`Text`, `Icon`, `PixelHpBar`, dialogs, SnackBar alerts) and outward state persistence in repositories (`IKitRepository`, `ICraftLogRepository`).
- No private member variables or internal implementation hooks are bypassed.
- Two dedicated test suites are specified:
  - `test/e2e/e2e_tier1_r1_r2_test.dart`: Tier 1 Feature Coverage (>=5 test cases per feature across Features 1–17, covering happy paths in isolation).
  - `test/e2e/e2e_tier2_r1_r2_test.dart`: Tier 2 Boundary & Corner Cases (>=5 test cases per feature across Features 1–17, covering empty states, extreme values, interruptions, thresholds, and mercy floors).

---

## 2. Codebase & Existing Test Inventory Review

### 2.1 Existing Test Analysis
1. **Unit Tests (`test/unit/`)**:
   - `battle_engine_test.dart`: Validates pure mathematical formulas for base points (100, 220), multipliers (1.0x to 2.5x), mercy interruptions (50% floor), and execution gates (<=20%).
   - `battle_engine_adversarial_test.dart`: Tests negative seconds, extreme numbers (2^31-1), division-by-zero guards, and threshold edge cases.
   - `models_test.dart`: Tests `KitItem` and `CraftLog` factories, JSON serialization, status transitions, and copyWith.
   - `storage_test.dart`: Tests `LocalStorageService` with mocked `SharedPreferences`, JSON list serialization, and repository auto-seeding.

2. **Widget Tests (`test/widget/`)**:
   - `battle_autosave_test.dart`: Tests that completing a work session or interrupting saves kit HP and writes a craft log.
   - `craft_log_screen_test.dart`: Tests `CraftLogScreen` rendering empty state, KPI cards, phase breakdown, and active kit filter.
   - `hangar_screen_test.dart`: Tests kit CRUD in Hangar UI.
   - `navigation_and_active_kit_test.dart`: Tests navigation flow between Battle, Hangar, Showcase, and CraftLog.

3. **Challenge Tests (`test/challenge/`)**:
   - `pomodoro_challenge_test.dart`: Verifies timer countdown empirical behavior (N+1 ticks for phase transitions), skip rest button, and rapid start/cancel stability.
   - `ui_state_autosave_stress_test.dart`: Verifies consecutive combat cycles, hydration on app reload, background timer continuation during navigation, and zero-log diagnostics.

### 2.2 Gap Analysis for E2E Tier 1 & Tier 2
While existing unit and widget tests cover isolated components well, an integrated, requirement-driven E2E suite covering every feature in R1 (Features 1–12) and R2 (Features 13–17) is required. Specifically:
- Full end-to-end user journeys linking timer progression, visual combat feedback, damage application, dialogue updates, automatic persistence, and CraftLog aggregation.
- Systematic happy-path test coverage (>=5 test cases per feature) executed exclusively via user-facing widgets and keys.
- Comprehensive boundary and corner-case test coverage (>=5 test cases per feature) verifying edge thresholds, 0-second / 1-second interruptions, mercy rule floors, and invalid/extreme states.

---

## 3. UI Widget Keys & Finder Registry

The following registry specifies all finder patterns and widget keys used for opaque-box testing:

### 3.1 Battle Screen (`lib/main.dart`)
| Element | Key / Finder | Expected Role / Semantic Meaning |
| :--- | :--- | :--- |
| Hangar Nav Button | `find.byKey(const Key('btn_hangar'))` or `find.byKey(const Key('btn_nav_hangar'))` | Navigates to Hangar Screen |
| Showcase Nav Button | `find.byKey(const Key('btn_showcase'))` or `find.byKey(const Key('btn_nav_showcase'))` | Navigates to Showcase Gallery |
| CraftLog Nav Button | `find.byKey(const Key('btn_craft_log'))` or `find.byKey(const Key('btn_nav_craft_log'))` | Navigates to CraftLog Screen |
| Battle Nav Tab | `find.byKey(const Key('btn_nav_battle'))` | Bottom nav bar battle tab |
| Mute Toggle | `find.byKey(const Key('btn_mute_toggle'))` | Toggles audio SFX mute |
| Boss Status Card | `find.byType(PixelFrame).first` | Displays Boss Lv, Title, Grade |
| Boss HP Bar | `find.byType(PixelHpBar)` | Displays HP text: `X / Y HP (Z%)` |
| Dialogue Box | `find.textContaining('▶ ')` | Combat log and status messages |
| Process: Snap-fit | `find.textContaining('素組')` | Selects Snap-fit (1.0x) |
| Process: Sanding | `find.textContaining('打磨')` | Selects Sanding (1.2x) |
| Process: Detailing | `find.textContaining('刻線')` | Selects Detailing (1.5x) |
| Process: Airbrush | `find.textContaining('噴塗')` | Selects Airbrush (2.0x) |
| Process: Finishing | `find.textContaining('水貼')` | Displays `水貼\n🔒20%` (locked) or `水貼\n2.5x` (unlocked) |
| Mode: Standard | `find.text('標準 25m/5m')` | Selects 25m work / 5m rest mode |
| Mode: Deep Focus | `find.text('深度 50m/10m')` | Selects 50m work / 10m rest mode |
| Mode: Debug | `find.text('除錯 5s/3s')` | Selects 5s work / 3s rest mode |
| Start Button | `find.textContaining('開始開工')` | Initiates Pomodoro work session |
| Fast Debug Button | `find.text('5秒測試')` | One-tap start for 5s debug work session |
| Interrupt Button | `find.textContaining('中途中斷')` | Triggers Mercy Rule early stop and 50% settlement |
| Skip Rest Button | `find.textContaining('略過休息')` | Skips rest phase and returns to idle |
| Restart Button | `find.textContaining('重置 Boss 血量')` | Appears when HP <= 0 to revive active boss |
| Timer Clock | `find.text(RegExp(r'\d{2}:\d{2}'))` | Displays remaining minutes and seconds |
| Quest Clear Dialog | `find.text('★ QUEST CLEAR ★')` | Pops up 700ms after Boss defeat |
| Clear -> Showcase | `find.byKey(const Key('btn_clear_to_showcase'))` | Navigates from victory dialog to showcase |
| Clear -> Hangar | `find.byKey(const Key('btn_clear_to_hangar'))` | Navigates from victory dialog to hangar |
| Clear -> Restart | `find.byKey(const Key('btn_clear_restart'))` | Closes victory dialog and resets HP to max |

### 3.2 CraftLog Screen (`lib/presentation/screens/craft_log_screen.dart`)
| Element | Key / Finder | Expected Role / Semantic Meaning |
| :--- | :--- | :--- |
| CraftLog Back Button | `find.byKey(const Key('btn_craft_log_back'))` | Pops screen back to BattleScreen |
| Header Title | `find.text('★ CRAFT LOG ★')` | Verifies screen is loaded |
| Refresh Button | `find.byTooltip('重新整理')` | Reloads all craft logs from storage |
| Filter: Active Kit | `find.textContaining('當前:')` | Filters logs to active kit only |
| Filter: All Kits | `find.text('全部歷史紀錄')` | Shows cumulative logs across all kits |
| KPI: Work Time | `find.text('累計工時')` | Displays aggregated time (e.g. `40m`, `1h 15m`) |
| KPI: Total Damage | `find.text('總輸出傷害')` | Displays aggregated damage (e.g. `136 pt`) |
| KPI: Completed Count | `find.text('完整完工')` | Displays completed session count |
| KPI: Interrupted Count| `find.text('中途保底')` | Displays interrupted session count |
| Empty Placeholder | `find.textContaining('尚未有施工紀錄')` | Rendered when log list is empty |

---

## 4. Tier 1 Test Specifications: Feature Coverage (Happy Paths)

Tier 1 covers happy paths in isolation via user-facing widgets and keys. Each feature has at least 5 distinct test cases.

### Feature 1: Pomodoro 25m/5m Timer (Standard Mode)
- **T1-F01-01: Mode Selection & HUD Label**
  - *Setup*: Launch `TsumiPuraApp`.
  - *Action*: Tap `find.text('標準 25m/5m')`.
  - *Assertions*: Verify `find.textContaining('開始開工 (標準 25m/5m)')` is displayed. Clock displays `00:00`. Status label displays `POMODORO WORKBENCH CLOCK`.
- **T1-F01-02: Work Phase Initiation**
  - *Setup*: Standard mode selected.
  - *Action*: Tap `find.textContaining('開始開工')`. Pump 1 frame.
  - *Assertions*: Verify status label displays `WORK - 專注組裝中 (標準 25m/5m)`. Clock displays `25:00`. Interrupt button `find.textContaining('中途中斷')` appears.
- **T1-F01-03: Real-Time Timer Decrement**
  - *Setup*: Standard work session active at 25:00.
  - *Action*: Pump `const Duration(seconds: 10)`.
  - *Assertions*: Clock displays `24:50`. Status remains `WORK - 專注組裝中`.
- **T1-F01-04: Full Work Completion & Rest Phase Transition**
  - *Setup*: Standard work session active with Snap-fit (1.0x).
  - *Action*: Advance 1500 work seconds + 1 completion tick (`pump(Duration(seconds: 1500))` + `pump(Duration(seconds: 1))`).
  - *Assertions*: Boss HP decreases by 100 pt (500 -> 400 HP). Status transitions to `REST - 工坊整備休息中 ☕`. Clock displays `05:00`. Button `略過休息 (提前開工)` appears.
- **T1-F01-05: Rest Early Skip to Idle**
  - *Setup*: In Rest phase at 05:00.
  - *Action*: Tap `find.textContaining('略過休息')`. Pump.
  - *Assertions*: Status returns to `POMODORO WORKBENCH CLOCK`. Clock resets to `00:00`. Dialogue displays `已略過休息，隨時可再次開工討伐！`. Start button reappears.

### Feature 2: Pomodoro 50m/10m Timer (Deep Focus Mode)
- **T2-F02-01: Deep Focus Mode Selection**
  - *Setup*: Launch app.
  - *Action*: Tap `find.text('深度 50m/10m')`. Pump.
  - *Assertions*: Start button updates to `find.textContaining('開始開工 (深度 50m/10m)')`.
- **T2-F02-02: Deep Focus Work Start**
  - *Setup*: Deep Focus selected.
  - *Action*: Tap `find.textContaining('開始開工')`. Pump.
  - *Assertions*: Status shows `WORK - 專注組裝中 (深度 50m/10m)`. Clock displays `50:00`.
- **T2-F02-03: Clock Decrement at 1 Minute Interval**
  - *Setup*: Deep Focus work active at 50:00.
  - *Action*: Pump `const Duration(seconds: 60)`.
  - *Assertions*: Clock displays `49:00`. Dialogue shows active craft phase message.
- **T2-F02-04: Deep Focus Full Session 220 Base Points Damage**
  - *Setup*: Deep Focus work active with Snap-fit (1.0x) on 500 HP boss.
  - *Action*: Pump 3000 seconds + 1 tick.
  - *Assertions*: Boss HP reduced by 220 pt (500 -> 280 HP). Rest phase begins with `10:00` clock. Dialogue reflects massive hit.
- **T2-F02-05: Deep Focus Rest Skip & State Cleanliness**
  - *Setup*: In 10m rest phase.
  - *Action*: Tap `find.textContaining('略過休息')`. Pump.
  - *Assertions*: Returns cleanly to idle. Mode remains `深度 50m/10m`. HP remains 280.

### Feature 3: Fast Debug Mode (5s Timer)
- **T1-F03-01: Quick '5秒測試' Button Tap**
  - *Setup*: Launch app in idle.
  - *Action*: Tap `find.text('5秒測試')`. Pump.
  - *Assertions*: Immediately initiates work session in `除錯 5s/3s` mode. Clock displays `00:05`.
- **T1-F03-02: Segmented Mode Selector Debug Mode**
  - *Setup*: Launch app in idle.
  - *Action*: Tap `find.text('除錯 5s/3s')`. Tap `find.textContaining('開始開工')`.
  - *Assertions*: Work session starts with clock at `00:05`.
- **T1-F03-03: Exact Countdown from 5 to 0**
  - *Setup*: 5s debug work session active.
  - *Action*: Advance 1 second 5 times, checking each step.
  - *Assertions*: Clock displays `00:04`, `00:03`, `00:02`, `00:01`, `00:00`.
- **T1-F03-04: Debug Completion & 3s Rest Phase**
  - *Setup*: Clock at 00:00 in debug work.
  - *Action*: Advance 1 transition tick.
  - *Assertions*: Transitions to `REST - 工坊整備休息中 ☕`. Clock displays `00:03`. Boss HP drops by 20 pt (500 -> 480).
- **T1-F03-05: Debug Rest Auto-Completion to Idle**
  - *Setup*: In 3s rest phase.
  - *Action*: Advance 3 seconds + 1 completion tick.
  - *Assertions*: Status returns to idle without user tapping skip. Clock is `00:00`. Dialogue displays `✨ 休息完畢！精力充沛`.

### Feature 4: Snap-fit Multiplier (1.0x)
- **T1-F04-01: Default Craft Phase Selection**
  - *Setup*: App launch.
  - *Action*: Inspect SegmentedButton.
  - *Assertions*: Snap-fit is pre-selected (`selected: {'Snap-fit'}`). Dialogue shows weapon ready.
- **T1-F04-02: Snap-fit Switching Dialogue**
  - *Setup*: Switch to Sanding, then tap `find.textContaining('素組')`.
  - *Action*: Pump.
  - *Assertions*: Dialogue displays `已切換武器：【剪鉗連擊】(1.0x 倍率)`.
- **T1-F04-03: Debug Mode Damage Math (20 BP * 1.0 = 20)**
  - *Setup*: Snap-fit selected, HP 500.
  - *Action*: Run 5s debug session to completion (pump 6s).
  - *Assertions*: Boss HP displays `480 / 500 HP`. Dialogue displays `造成 20 點爆發傷害！`.
- **T1-F04-04: Standard Mode Damage Math (100 BP * 1.0 = 100)**
  - *Setup*: Snap-fit selected, HP 500, Standard mode.
  - *Action*: Run 1500s session to completion.
  - *Assertions*: Boss HP displays `400 / 500 HP`. Dialogue displays `造成 100 點爆發傷害！`.
- **T1-F04-05: CraftLog Entry for Snap-fit**
  - *Setup*: Complete Snap-fit session, tap `Key('btn_craft_log')`.
  - *Action*: Pump 300ms.
  - *Assertions*: First log entry shows badge `Snap-fit`, text `剪鉗連擊`, damage `💥 -20 HP` (or -100 HP), status `完工`.

### Feature 5: Sanding Multiplier (1.2x)
- **T1-F05-01: Select Sanding Phase**
  - *Setup*: App in idle.
  - *Action*: Tap `find.textContaining('打磨')`. Pump.
  - *Assertions*: Dialogue displays `已切換武器：【破甲打磨】(1.2x 倍率)`.
- **T1-F05-02: Debug Mode Sanding Damage (20 * 1.2 = 24)**
  - *Setup*: Sanding selected, HP 500.
  - *Action*: Run 5s debug session to completion.
  - *Assertions*: Boss HP displays `476 / 500 HP` (500 - 24). Dialogue shows `造成 24 點爆發傷害！`.
- **T1-F05-03: Standard Mode Sanding Damage (100 * 1.2 = 120)**
  - *Setup*: Sanding selected, HP 500, Standard mode.
  - *Action*: Run 1500s session to completion.
  - *Assertions*: Boss HP displays `380 / 500 HP` (500 - 120). Dialogue shows `造成 120 點爆發傷害！`.
- **T1-F05-04: Deep Focus Sanding Damage (220 * 1.2 = 264)**
  - *Setup*: Sanding selected, HP 500, Deep Focus mode.
  - *Action*: Run 3000s session to completion.
  - *Assertions*: Boss HP displays `236 / 500 HP` (500 - 264). Dialogue shows `造成 264 點爆發傷害！`.
- **T1-F05-05: CraftLog Sanding Breakdown & Entry**
  - *Setup*: Run Sanding session, navigate to CraftLog.
  - *Action*: Pump.
  - *Assertions*: Sanding row in phase breakdown displays positive damage and percentage. Log list displays `Sanding` and `破甲打磨`.

### Feature 6: Detailing Multiplier (1.5x)
- **T1-F06-01: Select Detailing Phase**
  - *Setup*: App in idle.
  - *Action*: Tap `find.textContaining('刻線')`. Pump.
  - *Assertions*: Dialogue displays `已切換武器：【弱點刻線】(1.5x 倍率)`.
- **T1-F06-02: Debug Mode Detailing Damage (20 * 1.5 = 30)**
  - *Setup*: Detailing selected, HP 500.
  - *Action*: Run 5s debug session to completion.
  - *Assertions*: Boss HP displays `470 / 500 HP`. Dialogue shows `造成 30 點爆發傷害！`.
- **T1-F06-03: Standard Mode Detailing Damage (100 * 1.5 = 150)**
  - *Setup*: Detailing selected, Standard mode.
  - *Action*: Run 1500s session to completion.
  - *Assertions*: Boss HP displays `350 / 500 HP`. Dialogue shows `造成 150 點爆發傷害！`.
- **T1-F06-04: Floating Damage Feedback**
  - *Setup*: Complete Detailing session in Standard mode (150 damage).
  - *Action*: Observe UI immediately after session finishes.
  - *Assertions*: Floating damage text `CRITICAL! -150` or `-30` appears on stage.
- **T1-F06-05: CraftLog Detailing Verification**
  - *Setup*: Open CraftLogScreen.
  - *Action*: Pump.
  - *Assertions*: KPI total damage includes detailing damage. Log tile displays `Detailing` and `弱點刻線`.

### Feature 7: Airbrush Multiplier (2.0x)
- **T1-F07-01: Select Airbrush Phase**
  - *Setup*: App in idle.
  - *Action*: Tap `find.textContaining('噴塗')`. Pump.
  - *Assertions*: Dialogue displays `已切換武器：【噴筆重砲】(2.0x 倍率)`.
- **T1-F07-02: Debug Mode Airbrush Damage (20 * 2.0 = 40)**
  - *Setup*: Airbrush selected, HP 500.
  - *Action*: Run 5s debug session to completion.
  - *Assertions*: Boss HP displays `460 / 500 HP`. Dialogue shows `造成 40 點爆發傷害！`.
- **T1-F07-03: Standard Mode Airbrush Damage (100 * 2.0 = 200)**
  - *Setup*: Airbrush selected, Standard mode.
  - *Action*: Run 1500s session to completion.
  - *Assertions*: Boss HP displays `300 / 500 HP`. Dialogue shows `造成 200 點爆發傷害！`.
- **T1-F07-04: Deep Focus Airbrush Damage (220 * 2.0 = 440)**
  - *Setup*: Airbrush selected, Deep Focus mode on 500 HP boss.
  - *Action*: Run 3000s session to completion.
  - *Assertions*: Boss HP displays `60 / 500 HP` (500 - 440 = 60). Boss HP drops into Finishing range (<=20%).
- **T1-F07-05: Action Log Display During Combat**
  - *Setup*: Start Airbrush session.
  - *Action*: Inspect dialogue during work phase.
  - *Assertions*: Dialogue displays `⚔️ 開工中：噴筆重砲！時間滴答倒數...`.

### Feature 8: Finishing Multiplier (2.5x)
- **T1-F08-01: Finishing Unlocked Label at <= 20% HP**
  - *Setup*: Active kit seeded with 100/500 HP (20%). Launch app.
  - *Action*: Inspect SegmentedButton.
  - *Assertions*: Finishing button displays `水貼\n2.5x` (unlocked, no lock icon).
- **T1-F08-02: Select Finishing Phase**
  - *Setup*: Kit at 100/500 HP.
  - *Action*: Tap `find.text('水貼\n2.5x')`. Pump.
  - *Assertions*: Dialogue displays `已切換武器：【處決水貼 (水貼・仕上げ)】(2.5x 倍率)`.
- **T1-F08-03: Debug Mode Finishing Damage (20 * 2.5 = 50)**
  - *Setup*: Kit at 100/500 HP, Finishing selected.
  - *Action*: Run 5s debug session to completion.
  - *Assertions*: Boss HP drops from 100 to 50 HP (`50 / 500 HP`). Dialogue shows `造成 50 點爆發傷害！`.
- **T1-F08-04: Lethal Finishing Strike Triggers Quest Clear**
  - *Setup*: Kit at 50/500 HP, Finishing selected.
  - *Action*: Run 5s debug session to completion. Pump 800ms.
  - *Assertions*: Boss HP drops to 0 (`0 / 500 HP`). Victory dialog `★ QUEST CLEAR ★` appears.
- **T1-F08-05: CraftLog Finishing Record**
  - *Setup*: Close victory dialog, open CraftLogScreen.
  - *Action*: Pump.
  - *Assertions*: Log tile shows `Finishing`, `處決水貼`, damage `💥 -50 HP`.

### Feature 9: Finishing Execution Gate
- **T1-F09-01: Locked State at > 20% HP**
  - *Setup*: Boss at 500/500 HP.
  - *Action*: Inspect SegmentedButton.
  - *Assertions*: Segment displays `水貼\n🔒20%`.
- **T1-F09-02: Tapping Locked Gate Displays SnackBar**
  - *Setup*: Boss at 500/500 HP.
  - *Action*: Tap `find.text('水貼\n🔒20%')`. Pump.
  - *Assertions*: SnackBar appears with `⚠️ 水貼處決技限定 Boss 殘血 20% 以下！`. Selected phase remains Snap-fit.
- **T1-F09-03: Dynamic Unlock when HP reaches <= 20%**
  - *Setup*: Boss at 120/500 HP (24%). Run Sanding 5s session (24 dmg) -> 96/500 HP (19.2%).
  - *Action*: Complete session and skip rest. Pump.
  - *Assertions*: Finishing button transitions from `水貼\n🔒20%` to `水貼\n2.5x`.
- **T1-F09-04: Threshold Exact 20% Unlocked**
  - *Setup*: Boss with 100/500 HP.
  - *Action*: Inspect segment.
  - *Assertions*: `水貼\n2.5x` is displayed and selectable.
- **T1-F09-05: Lock Re-enforced on Boss Restart**
  - *Setup*: Boss defeated (0 HP). Tap `重置 Boss 血量 (RESTART)`.
  - *Action*: Pump.
  - *Assertions*: HP resets to 500/500. Finishing locks back to `水貼\n🔒20%`. Selected phase is Snap-fit.

### Feature 10: Mercy Rule Damage Floor (Interruption Settlement)
- **T1-F10-01: Mid-Session Interruption Button**
  - *Setup*: Start any work session.
  - *Action*: Inspect controls during work phase.
  - *Assertions*: Red button `中途中斷 (結算 50% 保底傷害)` is present and clickable.
- **T1-F10-02: Standard Mode 50% Interruption Math (100 * 0.5 * 1.0 * 0.5 = 25)**
  - *Setup*: Standard mode, Snap-fit, 500 HP. Start work.
  - *Action*: Advance 750 seconds (12.5m). Tap `find.textContaining('中途中斷')`. Pump.
  - *Assertions*: Boss HP displays `475 / 500 HP` (500 - 25). Dialogue states `⚠️ 中途急停！觸發 Mercy 保底防護，結算 50% 造成 25 點傷害`.
- **T1-F10-03: Visual Mercy Feedback**
  - *Setup*: Trigger interruption as above.
  - *Action*: Inspect stage overlay.
  - *Assertions*: Amber text `-25 (MERCY 50%)` appears.
- **T1-F10-04: Idle State Cleanly Restored After Interruption**
  - *Setup*: Interrupt session.
  - *Action*: Pump.
  - *Assertions*: Timer returns to `00:00`. Status label returns to `POMODORO WORKBENCH CLOCK`. Start button is re-enabled.
- **T1-F10-05: CraftLog Records Interrupted Session**
  - *Setup*: Navigate to CraftLogScreen after interruption.
  - *Action*: Pump.
  - *Assertions*: Log tile displays badge `中斷 50%` in amber, `⏱ 12m` (or 13m), `💥 -25 HP`. KPI `中途保底` increments by 1.

### Feature 11: Battle Engine Pure Math Integration
- **T1-F11-01: Multi-Turn Cumulative HP Subtraction Accuracy**
  - *Setup*: 500 HP boss.
  - *Action*: Run Snap-fit (20 dmg) -> Sanding (24 dmg) -> Detailing (30 dmg) -> Airbrush (40 dmg).
  - *Assertions*: Current HP exactly matches `500 - 20 - 24 - 30 - 40 = 386 HP`. HP bar displays `386 / 500 HP`.
- **T1-F11-02: Clamped HP at Zero upon Overkill**
  - *Setup*: Boss at 30 HP. Airbrush deals 40 dmg.
  - *Action*: Complete session.
  - *Assertions*: Current HP clamps to 0, never negative (`0 / 500 HP`).
- **T1-F11-03: Integer Rounding in UI Dialogue**
  - *Setup*: Detailing 1.5x interrupted at 50% in Standard mode (37.5 dmg).
  - *Action*: Complete interruption.
  - *Assertions*: Dialogue displays exact integer `38 點傷害` (half-up rounding).
- **T1-F11-04: Recycled Plastic Coin Calculation**
  - *Setup*: Run 5s session to completion (5s elapsed).
  - *Action*: Complete session.
  - *Assertions*: Formula `(5 / 5).round().clamp(2, 50) = 2` coins added to userCoins (e.g. 150 -> 152 塑料金幣).
- **T1-F11-05: Boss HP Percentage Bar Visual Width**
  - *Setup*: Boss at 250 / 500 HP.
  - *Action*: Inspect `PixelHpBar`.
  - *Assertions*: Label displays `50%`. Fraction visually spans half width.

### Feature 12: Lint Issue Fixes & Runtime Integrity
- **T1-F12-01: Clean App Bootstrap Without Assertion Failure**
  - *Setup*: Launch `TsumiPuraApp`.
  - *Action*: Pump 200ms.
  - *Assertions*: App mounts cleanly, 0 exceptions in tester binding.
- **T1-F12-02: Clean Route Transition Cycle (Battle -> Hangar -> Showcase -> CraftLog -> Battle)**
  - *Setup*: From BattleScreen.
  - *Action*: Push Hangar -> Pop -> Push Showcase -> Pop -> Push CraftLog -> Pop.
  - *Assertions*: All screens mount and unmount without assertion errors or unhandled asynchronous exceptions.
- **T1-F12-03: Audio Service Safe Invocation in Test Environment**
  - *Setup*: Launch app in test mode (`Platform.environment.containsKey('FLUTTER_TEST')`).
  - *Action*: Tap mute toggle (`Key('btn_mute_toggle')`), start timer, trigger critical hit.
  - *Assertions*: SFX methods invoke harmlessly without MissingPluginException or audio crash.
- **T1-F12-04: Ticker and Controller Clean Disposal**
  - *Setup*: Screen shake, floating damage, and idle controllers running.
  - *Action*: Unmount widget tree or navigate back.
  - *Assertions*: No `A Timer is still pending` or `AnimationController.dispose() called more than once` errors.
- **T1-F12-05: Missing Asset Fallback Render**
  - *Setup*: Render boss image card when image asset is unavailable.
  - *Action*: Inspect fallback.
  - *Assertions*: `errorBuilder` displays fallback Icon (`Icons.military_tech` or `Icons.smart_toy`) without crash.

### Feature 13: KitItem Data Model Persistence
- **T1-F13-01: Auto-Seeded Default Kit on Clean Start**
  - *Setup*: Clear SharedPreferences. Launch app.
  - *Action*: Pump 200ms.
  - *Assertions*: Boss card displays `綠色普通盒怪`, `規格: HG 1/144`, `500 / 500 HP`.
- **T1-F13-02: Status Progression from Unstarted to InProgress**
  - *Setup*: Fresh unstarted kit.
  - *Action*: Deal 20 damage via debug session.
  - *Assertions*: Repository stores updated kit with `status == KitStatus.inProgress`.
- **T1-F13-03: Status Progression to Completed on Lethal Hit**
  - *Setup*: Kit with 20 HP. Deal 20 damage.
  - *Action*: Pump to completion.
  - *Assertions*: Repository stores kit with `status == KitStatus.completed` and non-null `completedAt`.
- **T1-F13-04: Kit Reset Restores Full HP and Clears CompletedAt**
  - *Setup*: Completed kit (0 HP). Tap restart button.
  - *Action*: Pump.
  - *Assertions*: Stored kit has `currentHp == 500`, `status == KitStatus.unstarted`, `completedAt == null`.
- **T1-F13-05: Grade Presets Matching SPEC §3**
  - *Setup*: Inspect `GameConstants.gradeHpDefaults`.
  - *Action*: Verify map entries.
  - *Assertions*: EG=300, HG=500, RG=800, MG=1500, PG=5000.

### Feature 14: CraftLog Data Model Persistence
- **T1-F14-01: Complete Session Generates Valid CraftLog**
  - *Setup*: Run 5s debug session with Snap-fit.
  - *Action*: Session completes. Query repository.
  - *Assertions*: Log has unique UUID, matching kitId, `phase == 'Snap-fit'`, `damageDealt == 20`, `isCompletedSession == true`, valid `createdAt`.
- **T1-F14-02: Interrupted Session Generates Interrupted CraftLog**
  - *Setup*: Run session, tap interrupt at 2s.
  - *Action*: Query repository.
  - *Assertions*: Log has `isCompletedSession == false`, `damageDealt == 4`, `durationMinutes >= 0`.
- **T1-F14-03: Duration Minute Normalization**
  - *Setup*: Run 25-minute standard session to completion.
  - *Action*: Query repository.
  - *Assertions*: `durationMinutes == 25`. (Sub-minute test: 5s session records `durationMinutes == 1` for UI readability).
- **T1-F14-04: Log Ordering (Newest First)**
  - *Setup*: Run session A, then session B.
  - *Action*: Open CraftLogScreen.
  - *Assertions*: Session B appears above Session A in ListView.
- **T1-F14-05: CraftLog Referential Link to Kit**
  - *Setup*: Seed two kits, kit1 and kit2. Run battle on kit1.
  - *Action*: Open CraftLogScreen.
  - *Assertions*: Log is associated with kit1 ID; filter shows kit1 title.

### Feature 15: Local Persistence Service
- **T1-F15-01: SharedPreferences JSON Storage Format**
  - *Setup*: Complete a battle session.
  - *Action*: Read raw SharedPreferences string for key `StorageKeys.kits`.
  - *Assertions*: Returns valid JSON array containing serialized kit item map.
- **T1-F15-02: Active Kit ID Persistence**
  - *Setup*: Select or seed kit with ID `kit-xyz`.
  - *Action*: Read raw SharedPreferences string for key `StorageKeys.activeKitId`.
  - *Assertions*: Value equals `kit-xyz`.
- **T1-F15-03: CraftLog JSON Storage Format**
  - *Setup*: Complete a session.
  - *Action*: Read raw SharedPreferences string for key `StorageKeys.craftLogs`.
  - *Assertions*: Returns valid JSON array containing serialized log items.
- **T1-F15-04: Existing Data Preserved on Subsequent App Launch**
  - *Setup*: Save kit with 350 HP. Re-launch `TsumiPuraApp` with same storage.
  - *Action*: Pump 200ms.
  - *Assertions*: Loaded kit has 350 HP; does NOT re-seed default 500 HP kit.
- **T1-F15-05: Multi-Entity Write Isolation**
  - *Setup*: Save an updated kit and a new craft log.
  - *Action*: Check storage keys.
  - *Assertions*: `StorageKeys.kits` and `StorageKeys.craftLogs` update independently without clobbering each other.

### Feature 16: Auto-save & State Hydration
- **T1-F16-01: Auto-Save Triggered on Session Completion**
  - *Setup*: Fresh launch. Run 5s debug combat.
  - *Action*: Session completes. Immediately check repository without extra user saves.
  - *Assertions*: Repository reflects 480 HP and 1 craft log.
- **T1-F16-02: Auto-Save Triggered on Interruption**
  - *Setup*: Run session, interrupt at 1s.
  - *Action*: Immediately check repository.
  - *Assertions*: Repository reflects damaged HP and interrupted log.
- **T1-F16-03: State Hydration on App Launch (Zero-Flicker)**
  - *Setup*: Pre-seed storage with kit at 320/800 HP. Launch `TsumiPuraApp`.
  - *Action*: Pump 200ms.
  - *Assertions*: Boss Card immediately displays `320 / 800 HP`.
- **T1-F16-04: Hydration Restores Finishing Unlock if Pre-seeded <= 20%**
  - *Setup*: Pre-seed storage with kit at 80/500 HP (16%). Launch app.
  - *Action*: Pump 200ms.
  - *Assertions*: Finishing button immediately displays `水貼\n2.5x` (unlocked).
- **T1-F16-05: Defeated Boss Hydration Shows Restart Button**
  - *Setup*: Pre-seed storage with kit at 0/500 HP (`KitStatus.completed`). Launch app.
  - *Action*: Pump 200ms.
  - *Assertions*: Current HP is 0. Button `重置 Boss 血量 (RESTART)` is displayed.

### Feature 17: CraftLog History & Stats View
- **T1-F17-01: Screen Entry & Header Display**
  - *Setup*: Launch app.
  - *Action*: Tap `Key('btn_craft_log')`. Pump 300ms.
  - *Assertions*: Header `★ CRAFT LOG ★` is visible. Back button `Key('btn_craft_log_back')` is present.
- **T1-F17-02: KPI Metric Calculation**
  - *Setup*: Seed 2 logs: Log 1 (25m, 100 pt, completed), Log 2 (15m, 36 pt, interrupted).
  - *Action*: Open CraftLogScreen.
  - *Assertions*: `累計工時` shows `40m`. `總輸出傷害` shows `136 pt`. `完整完工` shows `1 次`. `中途保底` shows `1 次`.
- **T1-F17-03: 5 Phase Breakdown Representation**
  - *Setup*: Open CraftLogScreen with seeded logs.
  - *Action*: Inspect Phase Breakdown section.
  - *Assertions*: Phase lines for `Snap-fit` and `Sanding` display time, points, and percentage.
- **T1-F17-04: Filter Toggle between Active Kit and All History**
  - *Setup*: Seed log for active kit (100 pt) and log for other kit (440 pt). Open screen.
  - *Action*: Verify initial active kit shows `100 pt`. Tap `全部歷史紀錄`. Pump.
  - *Assertions*: Total damage updates to `540 pt` (100 + 440).
- **T1-F17-05: Back Navigation Restores Battle Screen**
  - *Setup*: On CraftLogScreen.
  - *Action*: Tap `Key('btn_craft_log_back')`. Pump 300ms.
  - *Assertions*: Returned to BattleScreen (`TSUMI-PURA RPG`), Boss card and previous battle controls intact.

---

## 5. Tier 2 Test Specifications: Boundary & Corner Cases

Tier 2 covers empty states, extreme values, interruptions, thresholds, mercy floors, and stress cycles. Each feature has at least 5 distinct test cases.

### Feature 1: Pomodoro 25m/5m Timer (Boundaries)
- **T2-F01-01: Instant Interruption at 0 Seconds**
  - *Setup*: Standard mode. Tap start then tap interrupt immediately (0s elapsed).
  - *Action*: Pump.
  - *Assertions*: Damage is 0. HP stays 500/500. Duration is 0m. Dialogue shows mercy protection. Returns cleanly to idle.
- **T2-F01-02: Interruption at Exactly 1 Second (Mercy Floor)**
  - *Setup*: Standard mode (100 BP, 1500s). Start work, advance 1s.
  - *Action*: Tap interrupt.
  - *Assertions*: `(1/1500) * 100 * 1.0 * 0.5 = 0.033` -> clamped to minimum **1 damage floor**. Boss HP is 499.
- **T2-F01-03: Interruption at 99% Progress (1485s)**
  - *Setup*: Standard mode, Snap-fit. Start work, advance 1485s.
  - *Action*: Tap interrupt.
  - *Assertions*: `100 * 0.99 * 1.0 * 0.5 = 49.5` -> rounds half-up to **50 damage**. Boss HP drops to 450.
- **T2-F01-04: Full Rest Timeout (300s Countdown)**
  - *Setup*: Complete standard work phase -> in 5m rest (05:00).
  - *Action*: Pump 300s + 1 tick without tapping skip.
  - *Assertions*: Rest auto-terminates to idle. Clock is `00:00`. Status label is idle.
- **T2-F01-05: Rapid Start-Interrupt Cycles (10 Cycles)**
  - *Setup*: Standard mode.
  - *Action*: Loop 10 times: Tap start -> Pump 1 frame -> Tap interrupt -> Pump 1 frame.
  - *Assertions*: App handles rapid cycling without timer leak, crash, or corrupted clock. Final state is clean idle.

### Feature 2: Pomodoro 50m/10m Timer (Boundaries)
- **T2-F02-01: Interruption at 1% Progress (30s)**
  - *Setup*: Deep Focus (220 BP, 3000s), Snap-fit. Start work, advance 30s.
  - *Action*: Tap interrupt.
  - *Assertions*: `220 * 0.01 * 1.0 * 0.5 = 1.1` -> rounds to **1 damage**. Boss HP is 499.
- **T2-F02-02: Interruption at 50% Progress (1500s)**
  - *Setup*: Deep Focus (220 BP, 3000s), Snap-fit. Start work, advance 1500s.
  - *Action*: Tap interrupt.
  - *Assertions*: `220 * 0.50 * 1.0 * 0.5 = 55.0` -> exactly **55 damage**. Boss HP is 445.
- **T2-F02-03: Interruption at 99% Progress (2970s)**
  - *Setup*: Deep Focus (220 BP, 3000s), Snap-fit. Start work, advance 2970s.
  - *Action*: Tap interrupt.
  - *Assertions*: `220 * 0.99 * 1.0 * 0.5 = 108.9` -> rounds half-up to **109 damage**. Boss HP is 391.
- **T2-F02-04: Full Rest Timeout (600s Countdown)**
  - *Setup*: Complete 50m session -> in 10m rest (10:00).
  - *Action*: Pump 600s + 1 tick.
  - *Assertions*: Rest completes automatically. Dialogue states `✨ 休息完畢！精力充沛`.
- **T2-F02-05: Mode Selector Locked/Hidden During Deep Focus Work**
  - *Setup*: Start Deep Focus work.
  - *Action*: Attempt to find or tap mode selector segments.
  - *Assertions*: Mode selector SegmentedButton is hidden during work phase (`_buildModeSelector` is omitted in `_pomodoroPhase == work`).

### Feature 3: Fast Debug Mode (Boundaries)
- **T2-F03-01: Instant Interruption at 0s in Debug Mode**
  - *Setup*: Tap '5秒測試', immediately tap interrupt.
  - *Action*: Pump.
  - *Assertions*: 0 damage, returns to idle, log records 0m and 0 dmg.
- **T2-F03-02: Interruption at 1s in Debug Mode**
  - *Setup*: Tap '5秒測試', advance 1s.
  - *Action*: Tap interrupt.
  - *Assertions*: `20 * (1/5) * 1.0 * 0.5 = 2 damage`. HP drops from 500 to 498.
- **T2-F03-03: Interruption at 4s in Debug Mode (80% Progress)**
  - *Setup*: Tap '5秒測試', advance 4s.
  - *Action*: Tap interrupt.
  - *Assertions*: `20 * (4/5) * 1.0 * 0.5 = 8 damage`. HP drops from 500 to 492.
- **T2-F03-04: Empirical N+1 Tick Completion Verification**
  - *Setup*: Start 5s debug mode. Advance exactly 5s.
  - *Action*: Inspect state at tick 5 vs tick 6.
  - *Assertions*: At tick 5, clock is `00:00` and phase is still WORK. At tick 6, phase transitions to REST (`00:03`).
- **T2-F03-05: Debug Coin Grant on 0s Interruption (Clamp Floor)**
  - *Setup*: Coins at 150. Start debug and immediately interrupt at 0s.
  - *Action*: Pump.
  - *Assertions*: `(0/5).round().clamp(2, 50)` grants 2 coins -> coins display `152 塑料金幣`.

### Feature 4: Snap-fit Multiplier (Boundaries)
- **T2-F04-01: Snap-fit Multiplier on 1 HP Remaining**
  - *Setup*: Boss HP is 1. Snap-fit (1.0x) debug completion (20 dmg).
  - *Action*: Complete session.
  - *Assertions*: HP clamped to 0, triggers Quest Clear, does not become negative.
- **T2-F04-02: Snap-fit Interruption with 1s in Standard Mode**
  - *Setup*: Standard Snap-fit (100 BP). Interrupted at 1s.
  - *Action*: Complete interruption.
  - *Assertions*: `(1/1500)*100*1.0*0.5` -> 1 damage floor.
- **T2-F04-03: Rapid Phase Toggle Snap-fit <-> Sanding (20 times)**
  - *Setup*: In idle.
  - *Action*: Alternate tapping Snap-fit and Sanding 20 times.
  - *Assertions*: App does not throw, final selected phase matches last tap.
- **T2-F04-04: Snap-fit Dialogue Text Accuracy**
  - *Setup*: Select Snap-fit.
  - *Action*: Inspect dialogue text.
  - *Assertions*: String exactly contains `【剪鉗連擊】(1.0x 倍率)`.
- **T2-F04-05: Snap-fit Session Auto-Save Consistency**
  - *Setup*: Complete 5 consecutive Snap-fit debug runs.
  - *Action*: Query repository logs.
  - *Assertions*: Exactly 5 logs created, each with `phase == 'Snap-fit'` and `damageDealt == 20`.

### Feature 5: Sanding Multiplier (Boundaries)
- **T2-F05-01: Sanding Interruption at 1s in Standard Mode**
  - *Setup*: Standard Sanding (100 BP, 1.2x). Interrupted at 1s.
  - *Action*: Complete interruption.
  - *Assertions*: `(1/1500) * 100 * 1.2 * 0.5 = 0.04` -> clamped to **1 damage floor**.
- **T2-F05-02: Sanding Interruption at 750s (50% Progress)**
  - *Setup*: Standard Sanding. Interrupted at 750s.
  - *Action*: Complete interruption.
  - *Assertions*: `100 * 0.5 * 1.2 * 0.5 = 30 damage`. HP drops by exactly 30.
- **T2-F05-03: Sanding Interruption at 99% in Standard Mode**
  - *Setup*: Standard Sanding. Interrupted at 1485s.
  - *Action*: Complete interruption.
  - *Assertions*: `100 * 0.99 * 1.2 * 0.5 = 59.4` -> rounds down to **59 damage**.
- **T2-F05-04: Sanding Overkill Clamping**
  - *Setup*: Boss HP is 15. Standard Sanding deals 120.
  - *Action*: Complete session.
  - *Assertions*: Boss HP clamps to 0. Defeated status saved.
- **T2-F05-05: Sanding Action Log Verification**
  - *Setup*: Start Sanding work.
  - *Action*: Observe dialogue during work.
  - *Assertions*: Text includes `推動 600 號海綿砂紙！精準破除盒怪裝甲防禦！`.

### Feature 6: Detailing Multiplier (Boundaries)
- **T2-F06-01: Half-Up Rounding at 50% Standard Interruption (37.5 -> 38)**
  - *Setup*: Standard Detailing (100 BP, 1.5x). Interrupted at 750s.
  - *Action*: Complete interruption.
  - *Assertions*: `100 * 0.5 * 1.5 * 0.5 = 37.5` -> rounds strictly to **38 damage**. Boss HP drops by 38.
- **T2-F06-02: Half-Up Rounding at 50% Deep Focus Interruption (82.5 -> 83)**
  - *Setup*: Deep Focus Detailing (220 BP, 1.5x). Interrupted at 1500s.
  - *Action*: Complete interruption.
  - *Assertions*: `220 * 0.5 * 1.5 * 0.5 = 82.5` -> rounds strictly to **83 damage**.
- **T2-F06-03: Detailing at 99% Standard Progress (74.25 -> 74)**
  - *Setup*: Standard Detailing. Interrupted at 1485s.
  - *Action*: Complete interruption.
  - *Assertions*: `100 * 0.99 * 1.5 * 0.5 = 74.25` -> rounds to **74 damage**.
- **T2-F06-04: Detailing 1s Interruption (0.05 -> 1)**
  - *Setup*: Standard Detailing. Interrupted at 1s.
  - *Action*: Complete interruption.
  - *Assertions*: Clamps to **1 damage floor**.
- **T2-F06-05: Detailing Critical Color Highlight**
  - *Setup*: Complete Detailing session (>=150 damage).
  - *Action*: Check floating damage widget.
  - *Assertions*: Floating damage text appears in red/amber with critical text.

### Feature 7: Airbrush Multiplier (Boundaries)
- **T2-F07-01: Airbrush 50% Interruption Standard (50 damage)**
  - *Setup*: Standard Airbrush (100 BP, 2.0x). Interrupted at 750s.
  - *Action*: Complete interruption.
  - *Assertions*: `100 * 0.5 * 2.0 * 0.5 = 50 damage`. Boss HP drops by 50.
- **T2-F07-02: Airbrush 80% Interruption Standard (80 damage)**
  - *Setup*: Standard Airbrush. Interrupted at 1200s.
  - *Action*: Complete interruption.
  - *Assertions*: `100 * 0.8 * 2.0 * 0.5 = 80 damage`. Boss HP drops by 80.
- **T2-F07-03: Airbrush 99% Interruption Standard (99 damage)**
  - *Setup*: Standard Airbrush. Interrupted at 1485s.
  - *Action*: Complete interruption.
  - *Assertions*: `100 * 0.99 * 2.0 * 0.5 = 99.0` -> exactly **99 damage**.
- **T2-F07-04: Airbrush 1s Interruption Standard**
  - *Setup*: Standard Airbrush. Interrupted at 1s.
  - *Action*: Complete interruption.
  - *Assertions*: `(1/1500)*100*2.0*0.5 = 0.067` -> **1 damage floor**.
- **T2-F07-05: Double Airbrush Standard on 500 HP Boss Leaves 100 HP (Exact 20% Gate)**
  - *Setup*: 500 HP boss.
  - *Action*: Run 2 complete Standard Airbrush sessions (200 + 200 = 400 damage).
  - *Assertions*: Remaining HP is exactly 100 / 500 HP (20.0%). Finishing unlocks immediately.

### Feature 8: Finishing Multiplier (Boundaries)
- **T2-F08-01: Finishing Half-Up Rounding at 50% Standard (62.5 -> 63)**
  - *Setup*: Kit at 100/500 HP. Standard Finishing (100 BP, 2.5x). Interrupted at 750s.
  - *Action*: Complete interruption.
  - *Assertions*: `100 * 0.5 * 2.5 * 0.5 = 62.5` -> strictly **63 damage**. HP drops from 100 to 37.
- **T2-F08-02: Finishing Half-Up Rounding at 99% Standard (123.75 -> 124)**
  - *Setup*: Kit at 100/500 HP. Standard Finishing. Interrupted at 1485s.
  - *Action*: Complete interruption.
  - *Assertions*: `100 * 0.99 * 2.5 * 0.5 = 123.75` -> **124 damage** (exceeds 100 HP, clamps to 0, triggers defeat).
- **T2-F08-03: Finishing 50% Deep Focus Interruption (137.5 -> 138)**
  - *Setup*: Kit at 200/1000 HP (20%). Deep Focus Finishing (220 BP). Interrupted at 1500s.
  - *Action*: Complete interruption.
  - *Assertions*: `220 * 0.5 * 2.5 * 0.5 = 137.5` -> **138 damage**.
- **T2-F08-04: Finishing 1s Interruption Standard**
  - *Setup*: Kit at 100/500 HP. Interrupted at 1s.
  - *Action*: Complete interruption.
  - *Assertions*: **1 damage floor** applied. HP drops to 99.
- **T2-F08-05: Finishing Execution Sound & Fanfare**
  - *Setup*: Finishing lethal hit defeats Boss.
  - *Action*: Complete session. Pump 800ms.
  - *Assertions*: Fanfare dialog appears, kit status is completed in storage.

### Feature 9: Finishing Execution Gate (Boundaries)
- **T2-F09-01: Strict Boundary at 20.2% (101 / 500 HP)**
  - *Setup*: Seed kit with 101/500 HP. Launch app.
  - *Action*: Inspect segment.
  - *Assertions*: Displays `水貼\n🔒20%`. Tapping shows SnackBar alert.
- **T2-F09-02: Strict Boundary at 20.0% (100 / 500 HP)**
  - *Setup*: Seed kit with 100/500 HP. Launch app.
  - *Action*: Inspect segment.
  - *Assertions*: Displays `水貼\n2.5x` (unlocked). Selectable without alert.
- **T2-F09-03: Boundary Across Kit Grades**
  - *Setup*: Test ratios: EG (60/300), RG (160/800), MG (300/1500), PG (1000/5000).
  - *Action*: Check unlock state for each grade at exactly 20.0%.
  - *Assertions*: All unlock to `水貼\n2.5x` at exact 20.0% threshold.
- **T2-F09-04: Gate Lock on Kit Switch to High HP Kit**
  - *Setup*: Current kit at 100/500 HP has Finishing selected. Switch active kit in Hangar to a new kit with 500/500 HP.
  - *Action*: Return to BattleScreen.
  - *Assertions*: Selected phase auto-resets to Snap-fit; Finishing locks back to `水貼\n🔒20%` (M3 regression guard).
- **T2-F09-05: Starting Timer with Finishing when Gate is Locked**
  - *Setup*: If somehow Finishing was selected but HP > 20%.
  - *Action*: Tap Start button.
  - *Assertions*: `_startTimer` validates `_battleEngine.canExecuteFinishing`, shows SnackBar alert, and halts start.

### Feature 10: Mercy Rule Damage Floor (Boundaries)
- **T2-F10-01: Zero Elapsed Seconds (0s) Yields Exactly 0 Damage**
  - *Setup*: Start work, tap interrupt at t=0s.
  - *Action*: Complete interruption.
  - *Assertions*: Damage is 0, Boss HP is not reduced, log damage is 0.
- **T2-F10-02: Elapsed > 0 Always Yields >= 1 Damage (Floor Guarantee)**
  - *Setup*: Any timer mode, any phase, interrupt at smallest possible non-zero time (1s).
  - *Action*: Complete interruption.
  - *Assertions*: Damage is at least 1, never 0.
- **T2-F10-03: Interruption at N-1 Seconds (Near Full Session)**
  - *Setup*: Standard mode (1500s). Interrupt at 1499s.
  - *Action*: Complete interruption.
  - *Assertions*: Damage is 50% of near-full session (approx 50 dmg for Snap-fit), not 100%.
- **T2-F10-04: Multiple Partial Interruptions Preserve Consistency**
  - *Setup*: 500 HP. Interrupt at 2s (4 dmg) -> Interrupt at 2s (4 dmg) -> Interrupt at 2s (4 dmg).
  - *Action*: Complete 3 interruptions.
  - *Assertions*: Total HP dropped by 12 (500 -> 488). 3 interrupted logs saved.
- **T2-F10-05: Non-Degrading Coins on Interruption**
  - *Setup*: User coins at 150.
  - *Action*: Interrupt session at 1s.
  - *Assertions*: Coins increase to at least 152 (never decrease).

### Feature 11: Battle Engine Pure Math (Boundaries)
- **T2-F11-01: Negative Elapsed Seconds Guard**
  - *Setup*: Pass negative elapsed seconds to BattleEngine.
  - *Action*: Evaluate damage calculation.
  - *Assertions*: Returns strictly 0; does not invert damage or heal boss.
- **T2-F11-02: Zero or Negative Total Seconds Guard**
  - *Setup*: Pass `totalSeconds == 0` or negative.
  - *Action*: Evaluate damage calculation.
  - *Assertions*: Returns strictly 0 without division-by-zero exception.
- **T2-F11-03: Elapsed Exceeding Total Seconds Clamped**
  - *Setup*: Pass `elapsedSeconds == 2000` when `totalSeconds == 1500`.
  - *Action*: Evaluate damage calculation.
  - *Assertions*: Damage is clamped to 100% (100 dmg for Snap-fit), does not scale infinitely.
- **T2-F11-04: Negative Base Points Guard**
  - *Setup*: Pass `basePoints < 0`.
  - *Action*: Evaluate damage calculation.
  - *Assertions*: Returns strictly 0.
- **T2-F11-05: Unknown Phase String Safe Fallback**
  - *Setup*: Pass unknown phase string (e.g. `'CustomLaser'`).
  - *Action*: Evaluate damage calculation.
  - *Assertions*: Defaults safely to 1.0x multiplier without throwing.

### Feature 12: Lint Issue Fixes & Runtime Integrity (Boundaries)
- **T2-F12-01: Small Viewport Rendering (320x480)**
  - *Setup*: Set tester physical size to 320x480.
  - *Action*: Pump BattleScreen and scroll.
  - *Assertions*: No RenderFlex overflow yellow/black bars in SingleChildScrollView.
- **T2-F12-02: Large Viewport Rendering (1440x2560)**
  - *Setup*: Set physical size to 1440x2560.
  - *Action*: Pump app.
  - *Assertions*: ConstrainedBox (maxWidth: 540) centers cleanly, borders render without distortion.
- **T2-F12-03: Null Repositories Default Fallback**
  - *Setup*: Instantiate `TsumiPuraApp(kitRepository: null, craftLogRepository: null)`.
  - *Action*: Pump widget.
  - *Assertions*: App instantiates internal repositories and launches cleanly without null errors.
- **T2-F12-04: Time Formatter Upper Bounds (Hours Display)**
  - *Setup*: Inspect timer formatting with large numbers (e.g. 3665s -> `61:05`).
  - *Action*: Format time.
  - *Assertions*: String renders clean two-digit minutes and seconds without exception.
- **T2-F12-05: Dialogue Text Multi-Line Wrapping**
  - *Setup*: Set long battle dialogue string.
  - *Action*: Pump frame.
  - *Assertions*: Expanded Text wraps inside dialogue box without horizontal overflow.

### Feature 13: KitItem Data Model (Boundaries)
- **T2-F13-01: Custom Extreme HP Input (e.g. 99,999 HP)**
  - *Setup*: Create KitItem with `totalHp == 99999`.
  - *Action*: Render in Boss Card.
  - *Assertions*: Displays `99999 / 99999 HP (100%)`.
- **T2-F13-02: Minimum HP Input (1 HP)**
  - *Setup*: Create KitItem with `totalHp == 1`, `currentHp == 1`.
  - *Action*: Deal 1 damage.
  - *Assertions*: Transitions immediately to completed, currentHp is 0.
- **T2-F13-03: Special Characters in Kit Title**
  - *Setup*: Kit title with symbols and emojis: `【限定版】RG 1/144 沙薩比 ★ Special & Clear! 🤖`.
  - *Action*: Save and render in Boss Card and CraftLog.
  - *Assertions*: Title renders verbatim without unicode escaping issues.
- **T2-F13-04: JSON Roundtrip Integrity**
  - *Setup*: Kit with non-null `photoPath`, `completedAt`, `isCustomBoss: true`.
  - *Action*: Serialize to JSON, deserialize back to `KitItem`.
  - *Assertions*: All fields identical, types preserved.
- **T2-F13-05: Kit Reset on Backlog vs Completed**
  - *Setup*: Call `.reset()` on in-progress vs completed kit.
  - *Action*: Verify output.
  - *Assertions*: `currentHp == totalHp`, `status == KitStatus.unstarted`, `completedAt == null`.

### Feature 14: CraftLog Data Model (Boundaries)
- **T2-F14-01: 0-Duration and 0-Damage Log Representation**
  - *Setup*: Instant interruption at 0s.
  - *Action*: Save log.
  - *Assertions*: Stored with `durationMinutes == 0`, `damageDealt == 0`, `isCompletedSession == false`.
- **T2-F14-02: Large Duration Log (e.g. 300 minutes)**
  - *Setup*: Log with `durationMinutes == 300`, `damageDealt == 5000`.
  - *Action*: Render in CraftLogScreen.
  - *Assertions*: Displays `5h 0m` in KPI and `⏱ 300m` in tile without text clipping.
- **T2-F14-03: High-Frequency Log Stress (50 Logs in Storage)**
  - *Setup*: Seed 50 logs into repository.
  - *Action*: Open CraftLogScreen.
  - *Assertions*: Screen loads and scrolls smoothly; ListView builds items lazily.
- **T2-F14-04: CraftLog JSON Roundtrip**
  - *Setup*: Serialize `CraftLog` to JSON string and parse back.
  - *Action*: Compare fields.
  - *Assertions*: Timestamps and booleans match exactly.
- **T2-F14-05: Missing Timestamp / Corrupted Date Fallback**
  - *Setup*: Log JSON with missing timestamp.
  - *Action*: Deserialize.
  - *Assertions*: Defaults safely to `DateTime.now()` without crashing.

### Feature 15: Local Persistence Service (Boundaries)
- **T2-F15-01: Corrupted Kits JSON Recovery**
  - *Setup*: Set SharedPreferences `StorageKeys.kits` to invalid string `"{ corrupt json: ["`.
  - *Action*: Call `getAllKits()`.
  - *Assertions*: Recovers gracefully by seeding default HG kit without throwing unhandled parse exception.
- **T2-F15-02: Corrupted CraftLogs JSON Recovery**
  - *Setup*: Set SharedPreferences `StorageKeys.craftLogs` to malformed string.
  - *Action*: Call `getAllLogs()`.
  - *Assertions*: Returns empty list `[]` without crash.
- **T2-F15-03: Missing Active Kit ID Fallback**
  - *Setup*: `StorageKeys.activeKitId` is null or deleted.
  - *Action*: Call `getActiveKit()`.
  - *Assertions*: Returns first available kit or default seed kit.
- **T2-F15-04: Rapid Concurrent Saves**
  - *Setup*: Trigger 10 simultaneous `saveKit` futures.
  - *Action*: Await `Future.wait`.
  - *Assertions*: Storage finishes without race condition corruption; final kit list length is consistent.
- **T2-F15-05: Clear Storage & Re-Seed**
  - *Setup*: Clear SharedPreferences.
  - *Action*: Re-query repository.
  - *Assertions*: Cleanly re-seeds single default kit with HG specifications.

### Feature 16: Auto-save & State Hydration (Boundaries)
- **T2-F16-01: Hydration with 1 HP Kit**
  - *Setup*: Pre-seed kit with 1/500 HP. Launch app.
  - *Action*: Pump 200ms.
  - *Assertions*: Boss card shows `1 / 500 HP`. Finishing unlocked (`水貼\n2.5x`).
- **T2-F16-02: Hydration of Defeated Kit (0 HP)**
  - *Setup*: Pre-seed kit with 0/500 HP (`KitStatus.completed`). Launch app.
  - *Action*: Pump 200ms.
  - *Assertions*: Boss card shows `0 / 500 HP`. Restart button is present. Timer controls disabled.
- **T2-F16-03: Background Timer Persistence Across Push/Pop**
  - *Setup*: Start 5s debug timer. Immediately push CraftLogScreen.
  - *Action*: Wait 6s on CraftLogScreen. Pop back to BattleScreen.
  - *Assertions*: Work completed in background, HP reduced, CraftLog recorded, rested state shown.
- **T2-F16-04: Immediate Web Refresh / App Restart Simulation**
  - *Setup*: Deal 40 damage. Re-instantiate `TsumiPuraApp` from scratch with same storage.
  - *Action*: Pump 200ms.
  - *Assertions*: New app instance immediately hydrates and displays 460 HP.
- **T2-F16-05: Active Kit Switch Hydration**
  - *Setup*: Change active kit in Hangar to Kit B (MG, 1500 HP). Pop to BattleScreen.
  - *Action*: Pump 200ms.
  - *Assertions*: BattleScreen updates to Kit B (1500 HP), dialogue shows target lock message.

### Feature 17: CraftLog History & Stats View (Boundaries)
- **T2-F17-01: Empty Log State Diagnostics**
  - *Setup*: Fresh storage with 0 logs. Open CraftLogScreen.
  - *Action*: Inspect UI.
  - *Assertions*: No division-by-zero crashes. Displays `0m`, `0 pt`, `0 次`, all 5 phase bars display `0%`, placeholder `尚未有施工紀錄` is visible.
- **T2-F17-02: Null Active Kit ID and Title**
  - *Setup*: Open `CraftLogScreen(craftLogRepository: repo, activeKitId: null, activeKitTitle: null)`.
  - *Action*: Pump 300ms.
  - *Assertions*: Segmented filter is omitted, screen renders all logs cleanly without error.
- **T2-F17-03: Manual Refresh Tooltip Tap on Empty and Populated States**
  - *Setup*: On CraftLogScreen.
  - *Action*: Tap `find.byTooltip('重新整理')`.
  - *Assertions*: Reloads logs cleanly and re-renders without layout flicker.
- **T2-F17-04: Single Phase Dominance (100% of one phase)**
  - *Setup*: Seed 5 logs all in Airbrush phase (total 1000 pt).
  - *Action*: Open CraftLogScreen.
  - *Assertions*: Airbrush phase bar displays `100%`, other phase bars display `0%`.
- **T2-F17-05: Rapid Navigation Push/Pop Stress (5 Cycles)**
  - *Setup*: On BattleScreen.
  - *Action*: Alternate tapping `Key('btn_craft_log')` and `Key('btn_craft_log_back')` 5 times rapidly.
  - *Assertions*: No memory leaks, no animation controller errors, BattleScreen remains fully functional.

---

## 6. Implementation Blueprint for Test Writer

### 6.1 Test Suite Targets
1. **`test/e2e/e2e_tier1_r1_r2_test.dart`**:
   - Contains all Tier 1 happy-path test cases for Features 1–17.
   - Grouped into:
     - `group('Tier 1: Feature Coverage - R1 Pomodoro & Battle Engine (Features 1-12)', ...)`
     - `group('Tier 1: Feature Coverage - R2 Local Persistence & CraftLog (Features 13-17)', ...)`
2. **`test/e2e/e2e_tier2_r1_r2_test.dart`**:
   - Contains all Tier 2 boundary and corner-case test cases for Features 1–17.
   - Grouped into:
     - `group('Tier 2: Boundary & Corner Cases - R1 Pomodoro & Battle Engine (Features 1-12)', ...)`
     - `group('Tier 2: Boundary & Corner Cases - R2 Local Persistence & CraftLog (Features 13-17)', ...)`

### 6.2 Standard Test Setup & Boilerplate Pattern
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nifty_heisenberg/main.dart';
import 'package:nifty_heisenberg/core/constants/game_constants.dart';
import 'package:nifty_heisenberg/data/storage/local_storage_service.dart';
import 'package:nifty_heisenberg/data/repositories/kit_repository.dart';
import 'package:nifty_heisenberg/data/repositories/craft_log_repository.dart';
import 'package:nifty_heisenberg/domain/models/kit_item.dart';
import 'package:nifty_heisenberg/domain/models/craft_log.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void setViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    IKitRepository? kitRepo,
    ICraftLogRepository? logRepo,
  }) async {
    setViewport(tester);
    await tester.pumpWidget(
      TsumiPuraApp(
        kitRepository: kitRepo,
        craftLogRepository: logRepo,
      ),
    );
    await tester.pump();
    // Allow zero-flicker async hydration to settle
    await tester.pump(const Duration(milliseconds: 200));
  }
}
```

### 6.3 Critical Flakiness Mitigations
1. **Async Hydration**: Always `pump(const Duration(milliseconds: 200))` after mounting `TsumiPuraApp` to permit `_hydrateActiveKit()` to complete before evaluating HP.
2. **Timer Advancements**: Remember that timer phase completion in `lib/main.dart` requires `N` seconds for countdown + `1` second tick for `_completeWorkSession()` / `_completeRestSession()` execution.
3. **Quest Clear Dialog Delay**: Always `pump(const Duration(milliseconds: 800))` after fatal damage is applied to wait for the 700ms `Future.delayed` before asserting dialog elements.
4. **Physical Size**: Always set viewport to `Size(1080, 1920)` to avoid scroll offsets hiding controls.
