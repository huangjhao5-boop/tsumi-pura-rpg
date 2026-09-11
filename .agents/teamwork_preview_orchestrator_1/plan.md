# Project Orchestration Plan: 《罪普拉 RPG》

## Architecture Overview
A Flutter-based Retro 8-Bit Pixel Pomodoro RPG where model backlog (Tsumi-Pura) acts as Boss monsters, crafted away through focused sessions with damage calculation, local storage persistence, model hangar management, and retro audiovisual feedback.

## Tracks
1. **Implementation Track**:
   - M1: R1 Pomodoro & Battle Loop (25m/5m, fast debug mode, 5 craft multipliers, Mercy Rule 50% floor).
   - M2: R2 Local Persistence & CraftLog (KitItem, CraftLog, offline local storage for web & desktop, log/stats view).
   - M3: R3 Model Hangar & Showcase Gallery (CRUD, grades EG/HG/RG/MG/PG, custom/default HP, completion gallery with completion date & elapsed time).
   - M4: R4 8-Bit Retro Game Juice (pixel UI consistency, hit effects, shake, damage numbers, free/open-source retro audio/visuals).
   - M5: Final Milestone (100% E2E test pass + Tier 5 adversarial coverage hardening).

2. **E2E Testing Track**:
   - Requirement-driven, opaque-box test suite across Tiers 1-4.
   - Publishes TEST_READY.md when complete.

## Execution Steps
1. **Phase 0: Survey**:
   - Spec Miner extracts detailed requirement matrix and edge cases from ORIGINAL_REQUEST.md and SPEC.md.
   - Explorer 1 analyzes current Flutter structure (`pubspec.yaml`, dependencies, architecture, existing screens/widgets/models).
   - Explorer 2 investigates current state of testing, buildability on Windows/Web, linting rules, assets.
   - Merge findings into `PROJECT.md` (Architecture, Feature Inventory, Milestones, Interface Contracts, Code Layout).
2. **Phase 1: Dual Track Launch**:
   - Launch E2E Testing Orchestrator.
   - Launch Sub-orchestrator for M1 (Pomodoro & Battle Loop).
3. **Phase 2: Progressive Implementation**:
   - M1 -> M2 -> M3 -> M4 -> M5.
4. **Phase 3: Verification & Victory Audit**:
   - `flutter analyze` 0 errors/0 warnings.
   - Automated unit tests passing.
   - Windows/Web build verification.
   - Mandatory Forensic/Victory Audit.
   - Report to Sentinel.
