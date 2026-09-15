# TEST READY CERTIFICATION (TEST_READY.md)

## 1. Certification Summary
- **Project**: 《罪普拉 RPG》（Tsumi-Pura RPG）
- **Track**: E2E Testing Track (Milestone 5)
- **Status**: CERTIFIED TEST READY
- **Target Platform**: Flutter (Cross-platform pure Dart / Material / Canvas)
- **Zero-Cost & Offline Guarantee**: 100% Offline, Zero external API / cloud cost, Zero network calls

---

## 2. Test Coverage Matrix Across All 4 Tiers

| Tier | Test Suite File | Scope & Focus | Case Count | Status | Pass Rate |
|---|---|---|---|---|---|
| **Tier 1 (R1 & R2)** | `test/e2e/e2e_tier1_r1_r2_test.dart` | Features 1–17: Pomodoro loop, math, multipliers, persistence, logs | 85 | PASS | 100% (85/85) |
| **Tier 1 (R3 & R4)** | `test/e2e/e2e_tier1_r3_r4_test.dart` | Features 18–31: Hangar, CRUD, HP presets, defeat, Showcase, retro juice & audio | 70 | PASS | 100% (70/70) |
| **Tier 2 (R1 & R2)** | `test/e2e/e2e_tier2_r1_r2_test.dart` | Features 1–17 Boundaries: 0s/99% interruptions, overflow clamp, corrupted JSON, cache invalidation | 85 | PASS | 100% (85/85) |
| **Tier 2 (R3 & R4)** | `test/e2e/e2e_tier2_r3_r4_test.dart` | Features 18–31 Boundaries: 50/51 char titles, 99999 HP, deletion fallbacks, mute stress | 70 | PASS | 100% (70/70) |
| **Tier 3 (Pairwise)** | `test/e2e/e2e_tier3_pairwise_test.dart` | 5 Multi-Feature Suites: Target switch mid-countdown, delete active kit, HP reset lock, mute fanfare, cascade log deletion | 25 | PASS | 100% (25/25) |
| **Tier 4 (Scenarios)** | `test/e2e/e2e_tier4_scenarios_test.dart` | 3 Real-World End-to-End Workflows: Grand PG Odyssey, Multi-Kit Juggling, Atelier Hardening Cold Restart | 3 | PASS | 100% (3/3) |
| **Existing Suites** | `test/unit/`, `test/widget/`, `test/challenge/` | Unit models, widget contracts, adversarial stress & concurrency challenge tests | 218 | PASS | 100% (218/218) |
| **TOTAL** | **Comprehensive Test Fleet** | **Full Application System Validation** | **556** | **PASS** | **100% (556/556)** |

---

## 3. Detailed Specification by Tier

### Tier 1: Requirement-Driven Happy Path (Features 1–31)
- **Features 1–3 (Timers)**: Standard 25m/5m, Deep Focus 50m/10m, Fast Debug 5s/3s mode initiation, countdown ticks, and rest phase transitions.
- **Features 4–8 (Multipliers)**: Snap-fit (1.0x), Sanding (1.2x), Detailing (1.5x), Airbrush (2.0x), Finishing Execution (2.5x).
- **Features 9–12 (Combat Rules)**: 20% Execution gate lock, Mercy Rule 50% damage floor on early interruption, pure math determinism.
- **Features 13–17 (Data & Logs)**: KitItem and CraftLog models, LocalStorageService persistence, state hydration, CraftLog history and statistics view.
- **Features 18–22 (Hangar & CRUD)**: Hangar list, grade filtering, KitItem addition, editing with HP reset, active target assignment, safe deletion.
- **Features 23–25 (Showcase & Gallery)**: Boss defeat transition, Showcase induction, 5-phase breakdown modal, per-kit log audit navigation.
- **Features 26–31 (8-Bit Retro Juice & Audio)**: Pixel frames, Press Start 2P typography, screen shake, floating damage text, hurt flash, retro audio synthesizer and mute toggle.

### Tier 2: Boundary & Corner-Case Hardening
- **Extreme Inputs**: 0s instant stop, 1s tick, 99% progress interruptions, 1 HP minimum, 99,999 HP maximum, 50-character kit titles, 51-character validation rejection.
- **Fault Recovery**: Corrupted JSON list handling in `LocalStorageService`, missing kit fallback, clearing storage and auto-reseeding default seed kit.
- **UI Responsiveness**: Responsive layout rendering without RenderFlex overflows on ultra-compact viewports (320x480) and 4K displays (1440x2560).
- **Cache Invalidation**: Synchronous and asynchronous cache coherence between memory caches and local storage across rapid CRUD cycles.

### Tier 3: Cross-Feature Pairwise Interaction Matrix
1. **Suite 1: Active Kit Switch During Countdown (T3-P1)**:
   - Dynamic target reassignment mid-countdown routes accrued damage and craft logs to the new target.
   - Auto-reset of Finishing technique if new target HP exceeds 20%.
   - Mercy Rule interruption applied properly to switched kit.
2. **Suite 2: Delete Active Kit and Auto-Reassign (T3-P2)**:
   - Auto-reassignment to next in-progress or backlog kit upon deleting active kit.
   - Fallback to first kit when only completed kits remain.
   - Deleting the sole kit gracefully reseeds the default starter kit.
3. **Suite 3: Custom HP Finishing Lock Transition (T3-P3)**:
   - Custom HP threshold precision verified from 50 HP (threshold = 10 HP) to 10,000 HP (threshold = 2000 HP).
   - Forced selection of locked Finishing triggers SnackBar feedback and maintains safe fallback.
   - Kit editing with HP reset in Hangar dynamically re-locks Finishing on Battle screen.
4. **Suite 4: Mute State During Defeat Fanfare & Visual Juice (T3-P4)**:
   - Victory fanfare suppression when muted, full audio playback when unmuted.
   - Persistence of mute setting across screen transitions and navigation push/pop.
   - Decoupled visual combat juice (screen shake, hurt flash, floating damage) executes flawlessly regardless of mute state.
5. **Suite 5: Cascade Deletion of Craft Logs (T3-P5)**:
   - Deleting a kit removes all associated craft logs from storage.
   - Other kits and showcase entries retain their log integrity without side effects.

### Tier 4: Real-World Workload Scenarios
1. **Scenario 1: "The Grand PG 1/60 Strike Freedom Odyssey" (`T4-S1`)**:
   - Complete player journey: Unbox PG kit in Hangar (5000 HP) -> Set active -> Snap-fit session (4900 HP) -> Sanding session (4780 HP) -> Detailing session interrupted at 40% with Mercy Rule (4750 HP) -> 19 Airbrush sessions down to 950 HP (19% threshold) -> Finishing unlocked -> 4 Finishing execution sessions down to 0 HP -> Victory fanfare & Quest Clear -> Showcase plaque inspection with 5-phase breakdown -> CraftLog forensic audit verifying 25 completed sessions, 1 interrupted session, and 5050 total damage points.
2. **Scenario 2: "The Multi-Kit Juggling Craftsman" (`T4-S2`)**:
   - Multi-kit lifecycle: Register Kit A ("HG 獨角獸") and Kit B ("HG 新安洲") -> Snap-fit on Kit A (400 HP) -> Switch to Kit B in Hangar -> Sanding on Kit B (380 HP) -> CraftLog isolation (Kit B: 120 pt, All: 220 pt) -> Switch back to Kit A -> Airbrush to completion -> Showcase induction for Kit A while Kit B remains in Hangar with 380 HP in "施工中" status.
3. **Scenario 3: "Atelier Hardening: Deep Focus & Storage Recovery" (`T4-S3`)**:
   - Extreme focus & recovery: Deep Focus mode (50m/10m, 220 BP) -> Custom Boss with 2000 HP ("PB 限定幽靈") -> Start session -> Tick 100s -> Interrupt session with Mercy Rule (4 damage dealt, 1996 HP remaining) -> Simulate cold app restart with clean repository instances -> Verify active kit, HP, and interrupted log completely intact with zero data corruption.

---

## 4. Verification Commands & Execution Protocol

### Full E2E Verification
```bash
flutter test test/e2e/
```

### Individual Tier Verification
```bash
# Tier 1 (Features 1–17)
flutter test test/e2e/e2e_tier1_r1_r2_test.dart

# Tier 1 (Features 18–31)
flutter test test/e2e/e2e_tier1_r3_r4_test.dart

# Tier 2 (Features 1–17 Boundaries)
flutter test test/e2e/e2e_tier2_r1_r2_test.dart

# Tier 2 (Features 18–31 Boundaries)
flutter test test/e2e/e2e_tier2_r3_r4_test.dart

# Tier 3 (Cross-Feature Pairwise)
flutter test test/e2e/e2e_tier3_pairwise_test.dart

# Tier 4 (Real-World Scenarios)
flutter test test/e2e/e2e_tier4_scenarios_test.dart
```

### Complete Project Fleet Verification
```bash
flutter test
flutter analyze
```

---

## 5. Requirement Traceability Matrix (Features 1–31)

| Requirement Domain | Features Covered | Verified In |
|---|---|---|
| **R1: Pomodoro & Battle Loop** | Features 1–12 (Timers, Multipliers, Gate, Mercy, Math, Lints) | Tier 1 (R1/R2), Tier 2 (R1/R2), Tier 3 (P1, P3), Tier 4 (S1, S2, S3) |
| **R2: Local Persistence & Logs** | Features 13–17 (KitItem, CraftLog, StorageService, Hydration, Stats) | Tier 1 (R1/R2), Tier 2 (R1/R2), Tier 3 (P2, P5), Tier 4 (S1, S2, S3) |
| **R3: Model Hangar & Showcase** | Features 18–25 (Hangar, CRUD, Presets, Defeat, Showcase, Isolation) | Tier 1 (R3/R4), Tier 2 (R3/R4), Tier 3 (P1, P2, P3, P5), Tier 4 (S1, S2) |
| **R4: 8-Bit Retro Juice & Audio** | Features 26–31 (Pixel UI, Fonts, Shake, Floating Text, Hurt Flash, Audio) | Tier 1 (R3/R4), Tier 2 (R3/R4), Tier 3 (P4), Tier 4 (S1) |

---

## 6. Sign-off Checklist

- [x] **Zero Flakiness**: Deterministic time progression using `tester.pump(Duration)` without hanging `pumpAndSettle()`.
- [x] **Zero Network Cost**: `allowRuntimeFetching = false` on GoogleFonts, in-memory SharedPreferences mocks.
- [x] **Integrity Mandate**: No facade mocks, no hardcoded pass strings, real state transitions and UI assertions.
- [x] **Static Analysis**: `flutter analyze` reports 0 errors, 0 warnings.
- [x] **100% Pass Rate**: All 556 tests pass cleanly on Windows / clean Flutter runtime.
