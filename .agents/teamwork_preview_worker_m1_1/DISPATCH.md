# DISPATCH — Worker for Milestone 1: Pomodoro & Battle Engine

## Identity
- Role: Implementation Worker for Milestone 1 (teamwork_preview_worker)
- Working Directory: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_worker_m1_1
- Parent Conversation ID: 6fa20b7c-dc2d-40cc-9d90-84e64adeddcf

## MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Mandatory Input Files
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\ORIGINAL_REQUEST.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\SPEC.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\PROJECT.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m1_1\analysis.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m1_2\analysis.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m1_3\analysis.md

## File Ownership (Exclusively owned by this Worker)
- `lib/core/constants/game_constants.dart`
- `lib/domain/battle/battle_engine.dart`
- `lib/main.dart`
- `test/unit/battle_engine_test.dart`
- `test/widget_test.dart`

## Implementation Tasks
1. Create `lib/core/constants/game_constants.dart`:
   - Craft process multipliers (Snap-fit 1.0, Sanding 1.2, Detailing 1.5, Airbrush 2.0, Finishing 2.5)
   - Pomodoro modes: Standard (25m/5m), Deep Focus (50m/10m), Debug (5s/3s)
   - Base points (100 for 25m, 220 for 50m, 20 for 5s)
   - Grade HP defaults (EG 300, HG 500, RG 800, MG 1500, PG 5000)
2. Create `lib/domain/battle/battle_engine.dart`:
   - Implement `IBattleEngine` contract as specified in `PROJECT.md`
   - Damage calculation formula: `((basePoints * (elapsedSeconds / totalSeconds) * multiplier) * (isInterrupted ? 0.5 : 1.0)).round()`
   - Division-by-zero protection (if totalSeconds <= 0 return 0)
   - Minimum damage floor: if elapsedSeconds > 0 and calculated damage is 0, return 1
   - `canExecuteFinishing`: returns `true` if and only if `(currentHp / maxHp) <= 0.20`
3. Fix Linter Issues & Update `lib/main.dart`:
   - Fix all 6 `unnecessary_underscores` lints at lines 298, 676, 719 by changing `(_, __, ___)` to `(_, _, _)`
   - Integrate `BattleEngine` and `GameConstants` cleanly into `_BattleAtelierScreenState`
   - Add toggle/selector for Pomodoro modes (25m/5m standard, 50m/10m deep focus, 5s fast debug)
   - Handle work -> rest phase transition and Mercy Rule interruption with proper feedback
4. Create Automated Tests:
   - `test/unit/battle_engine_test.dart`: Exhaustive unit tests covering all 5 multipliers, Finishing execution gate (<20% vs >=20%), Mercy Rule 50% floor on interruption, edge cases (0s elapsed, full session, rounding)
   - `test/widget_test.dart`: Replace default counter test with `TsumiPuraApp` smoke test verifying initial load, title, and battle screen
5. Verification:
   - Run `flutter analyze` and confirm 0 errors and 0 warnings
   - Run `flutter test` and confirm 100% tests pass

## Output Requirements
Write changes to the codebase, verify via commands, and write a comprehensive handoff report to `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_worker_m1_1\handoff.md`.
Notify parent via send_message when done.

## 2026-09-11T05:03:30Z
<USER_REQUEST>
You are teamwork_preview_worker (Worker for Milestone 1: Pomodoro & Battle Engine).
Working directory: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_worker_m1_1
Mandatory original request path: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\ORIGINAL_REQUEST.md
SPEC path: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\SPEC.md
PROJECT path: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\PROJECT.md

Please read your DISPATCH.md at c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_worker_m1_1\DISPATCH.md.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Follow the instructions in DISPATCH.md:
1. Implement lib/core/constants/game_constants.dart
2. Implement lib/domain/battle/battle_engine.dart
3. Fix the 6 lints in lib/main.dart and integrate BattleEngine & Pomodoro mode selections
4. Implement test/unit/battle_engine_test.dart and update test/widget_test.dart
5. Run 'flutter analyze' and 'flutter test' to verify 0 errors, 0 warnings, and 100% tests passing.

Write your changes and document verification commands and results in handoff.md.
When completed, notify parent via send_message.
</USER_REQUEST>
