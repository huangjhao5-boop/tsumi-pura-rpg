# Milestone 5 Challenger 2 Plan: Lifecycle & Concurrency Invariants

## Objectives
Adversarially challenge and empirically prove:
1. **Application Lifecycle Invariants**:
   - Rapid navigation between Battle, Hangar, Showcase, and CraftLog while timers and animations run.
   - Background timer expiration while viewing secondary routes without state desync or missed log creation.
   - Active target mutation in Hangar reflected immediately upon popping to Battle.
   - Mid-flight animation interruption (screen shake, floating damage popups, boss flash) across navigation events without ticker leaks.
   - Boss defeat transition to Showcase and Hangar consistency.
2. **Concurrency Invariants**:
   - High-concurrency burst transactions on `KitRepository` (50 parallel writes + 20 parallel reads, verifying zero data loss).
   - High-concurrency burst transactions on `CraftLogRepository` (100 parallel writes + 25 parallel reads, verifying zero data loss).
   - Interleaved concurrent cascade deletions and concurrent log additions (verifying cascade deletion invariant without collateral log loss).
   - Active kit deletion under concurrent mutation and querying.
   - Multi-instance cache invalidation and re-hydration consistency across repository instances sharing storage.

## Step-by-Step Execution Plan
1. [x] Baseline check: `flutter analyze` clean (0 errors, 0 warnings).
2. [x] Analyze architecture of `lib/main.dart`, `KitRepository`, `CraftLogRepository`, and navigation routes.
3. [ ] Author `test/challenge/m5_lifecycle_concurrency_challenge_test.dart` implementing the full suite of adversarial tests.
4. [ ] Run `flutter test test/challenge/m5_lifecycle_concurrency_challenge_test.dart` and verify all tests pass.
5. [ ] Run `flutter test` across entire repository test fleet to confirm zero regressions.
6. [ ] Run `flutter analyze` to ensure 0 lints and 0 errors.
7. [ ] Document findings, logic chain, caveats, conclusion, and verification method in `handoff.md`.
8. [ ] Send completion message with verdict to parent agent.
