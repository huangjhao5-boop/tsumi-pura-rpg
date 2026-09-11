# DISPATCH — Worker for Milestone 3: Model Hangar & Showcase Gallery

## Identity
- Role: Implementation Worker for Milestone 3 (teamwork_preview_worker)
- Working Directory: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_worker_m3_1
- Parent Conversation ID: 6fa20b7c-dc2d-40cc-9d90-84e64adeddcf

## MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Mandatory Input Files
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\ORIGINAL_REQUEST.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\SPEC.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\PROJECT.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m3_1\analysis.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m3_2\analysis.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m3_3\analysis.md

## File Ownership (Exclusively owned by this Worker)
- `lib/presentation/screens/hangar_screen.dart`
- `lib/presentation/screens/showcase_screen.dart`
- `lib/presentation/widgets/retro_bottom_nav_bar.dart`
- `lib/main.dart`
- `test/widget/hangar_screen_test.dart`
- `test/widget/showcase_screen_test.dart`
- `test/widget/navigation_and_active_kit_test.dart`
- `test/widget_test.dart`

## Implementation Tasks
Implement Features 18–25 per the specifications and Explorer blueprints:

1. **HangarScreen & Model CRUD (Features 18–21)**:
   - Create `lib/presentation/screens/hangar_screen.dart`.
   - List all kits from `KitRepository` with Backlog / InProgress / Completed status badges.
   - Add Kit dialog: title, grade selection (EG, HG, RG, MG, PG), default HP auto-population from `GameConstants.gradeHpDefaults`, custom HP toggle and input field (> 0 validation).
   - Edit Kit dialog: edit title, grade, HP.
   - Delete Kit with confirmation dialog (warning about cascade craft log deletion).
   - Active kit indicator and "出擊" / "設為目標" button calling `KitRepository.setActiveKit(kitId)`.
2. **ShowcaseScreen & Completion Metrics (Features 24–25)**:
   - Create `lib/presentation/screens/showcase_screen.dart`.
   - Query completed kits (`status == KitStatus.completed`).
   - Empty state: "尚無完工模型，快去討伐堆積吧！".
   - Trophy cards with title, grade badge, formatted completion date (YYYY-MM-DD), and aggregated metrics computed from `CraftLogRepository` (total craft hours/minutes, session count).
   - Phase breakdown detail dialog (Snap-fit, Sanding, Detailing, Airbrush, Finishing).
3. **Navigation & Active Kit Link (Features 22–23)**:
   - In `lib/main.dart`, provide dual-tier navigation:
     - Header buttons: `Key('btn_hangar')`, `Key('btn_showcase')`, `Key('btn_craft_log')`.
     - Optional bottom navigation bar or smooth modal routing.
   - Active Kit battle link: when switching active kit in Hangar, returning to Battle Screen immediately updates the Boss HUD with the selected kit's Title, Grade, Max HP, and Current HP, resetting the Finishing lock if new HP > 20%.
   - Boss Defeat Transition: when Boss HP <= 0, mark kit as `completed` with `completedAt = DateTime.now()` in storage, and Quest Clear modal offers "前往展示櫃觀看" (pushes ShowcaseScreen) or "返回機庫挑選新目標" (pushes HangarScreen), while retaining "收錄至展示櫃 (Showcase)" for backward compatibility.
4. **Automated Tests**:
   - `test/widget/hangar_screen_test.dart`: Test list rendering, Add Kit dialog, Grade HP auto-fill, Custom HP, Edit, Delete, and Set Active.
   - `test/widget/showcase_screen_test.dart`: Test empty state, completed kit card display, date format, duration aggregation, and detail dialog.
   - `test/widget/navigation_and_active_kit_test.dart`: Test navigating between Battle, Hangar, Showcase, and CraftLog, and test active kit switching and boss defeat transition.
   - Ensure all existing 137 tests still pass!
5. **Verification**:
   - Run `flutter analyze` and confirm 0 errors and 0 warnings.
   - Run `flutter test` and confirm 100% tests pass.

## Output Requirements
Write all code, execute tests and analyze commands, document results in `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_worker_m3_1\handoff.md`, and report back via send_message.

## 2026-09-11T08:10:25Z
User Request:
You are teamwork_preview_worker (Worker for Milestone 3: Model Hangar & Showcase Gallery).
Working directory: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_worker_m3_1
Mandatory original request path: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\ORIGINAL_REQUEST.md
SPEC path: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\SPEC.md
PROJECT path: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\PROJECT.md

Please read your DISPATCH.md at c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_worker_m3_1\DISPATCH.md.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Follow the instructions in DISPATCH.md:
1. Implement lib/presentation/screens/hangar_screen.dart (Kit cards, backlog/inProgress/completed status, add/edit dialog with grade presets EG/HG/RG/MG/PG and custom HP > 0 validation, delete confirmation with cascade warning, set active kit).
2. Implement lib/presentation/screens/showcase_screen.dart (completed kits trophy cards, empty state, formatted completion date YYYY-MM-DD, aggregated craft duration hours/minutes from CraftLogRepository, phase breakdown detail dialog).
3. Update lib/main.dart for dual navigation (header buttons btn_hangar, btn_showcase, btn_craft_log), active kit battle link (Boss HUD updates immediately to selected kit title/grade/maxHp/currentHp and resets finishing lock), and boss defeat transition to completed kit with completedAt timestamp in storage and modal routing.
4. Implement automated widget tests:
   - test/widget/hangar_screen_test.dart
   - test/widget/showcase_screen_test.dart
   - test/widget/navigation_and_active_kit_test.dart
   and verify all existing 137 tests still pass!
5. Run 'flutter analyze' (must have 0 errors, 0 warnings) and 'flutter test' (100% pass).

