# DISPATCH — Worker for Milestone 2 (Retry Iteration 2): Storage Hardening & Integrity

## Identity
- Role: Implementation Worker for Milestone 2 Retry (teamwork_preview_worker)
- Working Directory: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_worker_m2_2
- Parent Conversation ID: 6fa20b7c-dc2d-40cc-9d90-84e64adeddcf

## MANDATORY INTEGRITY WARNING
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Mandatory Input Files
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\ORIGINAL_REQUEST.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\SPEC.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\PROJECT.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_challenger_m2_1\handoff.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m2_retry_1\analysis.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m2_retry_2\analysis.md
- c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m2_retry_3\analysis.md

## File Ownership (Exclusively owned by this Worker)
- `lib/core/utils/async_lock.dart`
- `lib/core/constants/game_constants.dart`
- `lib/domain/models/kit_item.dart`
- `lib/data/repositories/kit_repository.dart`
- `lib/data/repositories/craft_log_repository.dart`
- `lib/main.dart`
- `test/unit/models_test.dart`
- `test/unit/storage_test.dart`
- `test/challenge/storage_stress_challenge_test.dart`

## Implementation Tasks
Address all 4 findings from Challenger 1's handoff using the designs from the 3 retry Explorers:

1. **[Critical] Concurrent Async Writes (AsyncLock)**:
   - Create `lib/core/utils/async_lock.dart` with FIFO asynchronous queuing (`synchronized<T>(Future<T> Function() computation)`).
   - Integrate `AsyncLock` into `CraftLogRepository` and `KitRepository` so all mutating methods (`saveKit`, `deleteKit`, `addLog`, `deleteLogsForKit`) execute through `_lock.synchronized(...)`.
2. **[Medium] `KitStatus.isValid` Strict Validation**:
   - In `lib/domain/models/kit_item.dart`, implement `KitStatus.tryNormalize(status)` returning `null` on unrecognized strings.
   - Update `KitStatus.isValid(status)` to return `tryNormalize(status) != null`.
   - Keep `KitStatus.normalize(status, {fallback = unstarted})` returning fallback for defensive deserialization in `fromMap`.
3. **[Medium] Cascade Deletion per SPEC §7**:
   - In `lib/data/repositories/kit_repository.dart`, inject or accept `ICraftLogRepository?` (e.g. constructor parameter and `bindCraftLogRepository`).
   - In `deleteKit(kitId)`, first call `_craftLogRepository?.deleteLogsForKit(kitId)` before removing the kit and writing to storage.
   - Connect both repositories in `lib/main.dart` so cascade deletion is active in production.
4. **[Low] Consolidate Default Seed Kit ID**:
   - Define `GameConstants.defaultKitId = 'default-box-mimic-hg-001'` and `GameConstants.defaultKitGrade = 'HG 1/144'` in `lib/core/constants/game_constants.dart`.
   - Update `KitItem.initialSeedKit()`, `KitRepository`, and `BattleAtelierScreen` in `lib/main.dart` to reference this single constant.
5. **Testing & Verification**:
   - Update `test/challenge/storage_stress_challenge_test.dart` so all 18 challenge tests pass 100% (including concurrent write tests and cascade deletion).
   - Update `test/unit/models_test.dart` to verify `KitStatus.isValid('BOGUS') == false` and `KitItem.validate()` flags it.
   - Update `test/unit/storage_test.dart` to verify cascade deletion and concurrent write atomicity.
   - Run `flutter analyze` and confirm 0 errors and 0 warnings.
   - Run `flutter test` and confirm 100% tests pass.

## Output Requirements
Write all code, execute verification commands, write `handoff.md` in your working directory, and notify parent via `send_message`.

## 2026-09-11T07:50:58Z
<USER_REQUEST>
You are teamwork_preview_worker (Worker for Milestone 2 Retry: Storage Hardening & Integrity).
Working directory: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_worker_m2_2
Mandatory original request path: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\ORIGINAL_REQUEST.md
SPEC path: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\SPEC.md
PROJECT path: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\PROJECT.md

Please read your DISPATCH.md at c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_worker_m2_2\DISPATCH.md.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Follow the instructions in DISPATCH.md:
1. Implement lib/core/utils/async_lock.dart and protect KitRepository and CraftLogRepository write methods with atomic locking.
2. Fix KitStatus.isValid strict validation while preserving normalize for deserialization.
3. Wire cascade deletion in KitRepository.deleteKit to purge craft logs per SPEC §7.
4. Consolidate default seed kit ID in GameConstants across KitItem, KitRepository, and main.dart.
5. Verify test/challenge/storage_stress_challenge_test.dart passes 100% and test/unit/ passes 100%.
6. Run 'flutter analyze' (0 errors, 0 warnings) and 'flutter test'.

Document all changes and test outputs in handoff.md and notify parent via send_message when done.
</USER_REQUEST>
