# DISPATCH — Explorer 1 for Milestone 3: Hangar Screen & CRUD

## Identity
- Role: Explorer 1 for Milestone 3 (teamwork_preview_explorer)
- Working Directory: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m3_1
- Parent Conversation ID: 6fa20b7c-dc2d-40cc-9d90-84e64adeddcf

## Milestone Description
Milestone 3: Model Hangar & Showcase Gallery (Features 18–25 in PROJECT.md)
Focus:
- Feature 18: Model Hangar Screen (`lib/presentation/screens/hangar_screen.dart`)
  - List view of all model kits (backlog / unstarted, in_progress, completed)
  - Status indicators (Backlog badge, In Progress badge, Completed badge)
  - Active kit indicator
- Feature 19: Kit CRUD Management
  - Add kit dialog / form: title, grade selection, HP selection
  - Edit kit dialog / form: modify title, grade, HP
  - Delete kit with confirmation dialog (and cascade deletion of logs via `KitRepository.deleteKit`)
- Feature 20: Grade & HP Defaults
  - EG: 300 HP, HG: 500 HP, RG: 800 HP, MG: 1500 HP, PG: 5000 HP (from `GameConstants.gradeHpDefaults`)
  - Selecting a grade auto-fills the default HP
- Feature 21: Custom HP Input
  - User can toggle or override default HP with custom integer value (> 0)

## Mandatory Input Files
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\ORIGINAL_REQUEST.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\SPEC.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\PROJECT.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\lib\domain\models\kit_item.dart
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\lib\data\repositories\kit_repository.dart

## Investigation Focus
Design `HangarScreen` with retro 8-bit aesthetic (Press Start 2P/VT323, pixel borders, dark workbench theme).
Design Add/Edit Kit dialogs with Grade dropdown / segmented buttons, automatic HP population, custom HP input field, validation, and optimistic UI updates.
Provide concrete code blueprints and unit/widget test specifications for Worker.

## Output Requirements

## 2026-09-11T08:03:38Z
You are teamwork_preview_explorer (Explorer 1 for Milestone 3: Hangar Screen & CRUD).
Working directory: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m3_1
Mandatory original request path: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\ORIGINAL_REQUEST.md
SPEC path: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\SPEC.md
PROJECT path: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\PROJECT.md

Please read your DISPATCH.md at c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m3_1\DISPATCH.md.
Investigate HangarScreen, kit list view, status indicators, and full CRUD dialogs with grade presets (EG/HG/RG/MG/PG) and custom HP input.
Write your analysis to analysis.md and your handoff to handoff.md in your working directory.
When done, notify parent via send_message.
