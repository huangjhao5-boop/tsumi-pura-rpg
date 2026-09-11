# DISPATCH — Challenger 1 for Milestone 1

## Identity
- Role: Adversarial Challenger 1 (teamwork_preview_challenger)
- Working Directory: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_challenger_m1_1
- Parent Conversation ID: 6fa20b7c-dc2d-40cc-9d90-84e64adeddcf

## Milestone Under Test
Milestone 1: Pomodoro & Battle Engine (Features 1-12)
Target code:
- `lib/core/constants/game_constants.dart`
- `lib/domain/battle/battle_engine.dart`
- `lib/main.dart`

## Mandatory Input Files
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\ORIGINAL_REQUEST.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\SPEC.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\PROJECT.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_worker_m1_1\handoff.md

## Challenge Tasks
Empirically stress-test the `BattleEngine` and math logic:
1. Write and execute property-based / adversarial tests for `BattleEngine.calculateDamage` and `canExecuteFinishing`:
   - Test extreme elapsed seconds (e.g. elapsed > total, negative elapsed, negative totalSeconds, 0s).
   - Test extreme HP values (HP = 0, currentHp > maxHp, negative HP, boundary exactly 20.000%, 20.001%, 19.999%).
   - Verify Mercy rule never produces 0 damage if elapsed > 0.
   - Verify Finishing skill NEVER deals damage if HP > 20%.
2. Emit an explicit verdict in your handoff: `APPROVE` or `REQUEST_CHANGES`.

## Output Requirements
Write your adversarial test findings and handoff to `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_challenger_m1_1\handoff.md`.
Notify parent via send_message when done.

## 2026-09-11T05:11:00Z
You are teamwork_preview_challenger (Challenger 1 for Milestone 1).
Working directory: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_challenger_m1_1
Mandatory original request path: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\ORIGINAL_REQUEST.md
SPEC path: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\SPEC.md
PROJECT path: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\PROJECT.md

Please read your DISPATCH.md at c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_challenger_m1_1\DISPATCH.md.
Adversarially challenge the BattleEngine: edge cases, extreme HP/elapsed values, 20% finishing gate, 50% Mercy rule floor.
Emit your verdict (APPROVE or REQUEST_CHANGES) in handoff.md.
When done, notify parent via send_message.

