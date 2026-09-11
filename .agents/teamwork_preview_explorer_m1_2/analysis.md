# Milestone 1: Battle Engine Numerical Exactness, Edge Cases & Unit Testing Strategy

- **Author**: Explorer 2 for Milestone 1 (`teamwork_preview_explorer`)
- **Working Directory**: `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m1_2`
- **Date**: 2026-09-11
- **Target Deliverables**:
  - `lib/domain/battle/battle_engine.dart`
  - `lib/core/constants/game_constants.dart`
  - `test/unit/battle_engine_test.dart`
  - Lint fixes in `lib/main.dart` (lines 298, 676, 719)

---

## 1. Executive Summary

Milestone 1 implements Features 1–12 of `PROJECT.md`:
1. Pomodoro 25m/5m timer cycle
2. Pomodoro 50m/10m deep focus timer cycle
3. Fast Debug Mode (5s session for testing)
4. Snap-fit Multiplier (1.0x)
5. Sanding Multiplier (1.2x)
6. Detailing Multiplier (1.5x)
7. Airbrush Multiplier (2.0x)
8. Finishing Multiplier (2.5x Execution Skill)
9. Finishing Execution Gate (Locked when Boss HP > 20%, unlocked when HP <= 20%)
10. Mercy Rule Damage Floor (proportional elapsed time x 50% damage floor on cancellation)
11. Battle Engine Pure Math (decouple pure Dart `lib/domain/battle/battle_engine.dart`)
12. Lint Issue Fixes (fix 6 `unnecessary_underscores` in `lib/main.dart:298, 676, 719`)

This analysis provides the rigorous mathematical definitions, rounding mechanics, edge-case handling, and a comprehensive test specification for the Worker to achieve 100% test coverage and 0 lint warnings.

---

## 2. Numerical Exactness & Mathematical Specifications

### 2.1 Base Points & Timer Configurations
According to `SPEC.md §2.1` and `PROJECT.md`:
- **Standard Pomodoro**: 25 minutes work ($1,500$ seconds) = **100 Base Points (BP)**, 5 minutes rest ($300$ seconds).
- **Deep Focus Mode**: 50 minutes work ($3,000$ seconds) = **220 Base Points (BP)** (includes 10% focus bonus: $200 \times 1.10 = 220$), 10 minutes rest ($600$ seconds).
- **Fast Debug Mode**: 5 seconds work ($5$ seconds) = **100 Base Points (BP)** (rapid developer verification).

### 2.2 Craft Multipliers Matrix
According to `SPEC.md §2.2` and `PROJECT.md`:

| Craft Phase (Enum / Key) | Localized Name | Multiplier ($M$) | Execution Gate / Condition |
| :--- | :--- | :---: | :--- |
| `Snap-fit` | 素組 / 仮組み | **1.0x** | Unconditional (Default) |
| `Sanding` | 打磨 / ヤスリ掛け | **1.2x** | Unconditional |
| `Detailing` | 刻線 / スジ彫り | **1.5x** | Unconditional |
| `Airbrush` | 噴塗 / エアブラシ | **2.0x** | Unconditional |
| `Finishing` | 水貼 / デカール・仕上げ | **2.5x** | **Restricted: $\text{CurrentHP} / \text{MaxHP} \le 0.20$ (<=20% HP)** |

### 2.3 Damage Formulas

#### 1. Full Completion Damage (`isInterrupted == false`):
$$\text{Damage}_{\text{completed}} = \text{round}\left( \text{BasePoints} \times M_{\text{phase}} \right)$$
- When completed, the full session elapsed ratio is $1.0$.

#### 2. Mercy Rule Interrupted Damage (`isInterrupted == true`):
$$\text{Damage}_{\text{interrupted}} = \text{round}\left( \text{BasePoints} \times \frac{t_{\text{elapsed}}}{t_{\text{total}}} \times M_{\text{phase}} \times 0.50 \right)$$
- $t_{\text{elapsed}}$ is clamped to $[0, t_{\text{total}}]$.
- $0.50$ is the 50% Mercy Rule floor protection.

### 2.4 Integer Rounding Rules in Dart
- Dart `num.round()` returns the integer closest to the number.
- In Dart (IEEE-754 binary64), when a number is halfway between two integers, it rounds away from zero:
  - `(37.5).round() == 38`
  - `(62.5).round() == 63`
  - `(82.5).round() == 83`
  - `(137.5).round() == 138`
  - `(0.5).round() == 1`
  - `(0.4999).round() == 0`
- Damage must never be negative: `finalDamage = max(0, rawDamage.round())`.

### 2.5 Plastic Coins Reward Formula
According to `SPEC.md §4.3` and prototype `main.dart:193`:
$$\text{Coins} = \text{clamp}\left( \text{round}\left(\frac{t_{\text{elapsed}}}{5}\right), 2, 50 \right)$$
- If $t_{\text{elapsed}} \le 0$, $\text{Coins} = 0$.

---

## 3. Finishing Execution Gate Deep Dive

### 3.1 Gate Rule & Boundary Conditions
- **Condition**: $\text{CurrentHP} \le \text{MaxHP} \times 0.20$.
- **Boundary Behavior**:
  - `maxHp = 500`: 20% threshold is exactly 100 HP.
    - `currentHp = 101` ($20.2\%$): **LOCKED** (`canExecuteFinishing == false`).
    - `currentHp = 100` ($20.0\%$): **UNLOCKED** (`canExecuteFinishing == true`).
    - `currentHp = 99` ($19.8\%$): **UNLOCKED** (`canExecuteFinishing == true`).
    - `currentHp = 0` ($0\%$): **UNLOCKED** (or Boss Defeated).
  - `maxHp = 1500` (MG): 20% threshold is 300 HP.
    - `currentHp = 301`: **LOCKED**.
    - `currentHp = 300`: **UNLOCKED**.
  - `maxHp = 5000` (PG): 20% threshold is 1000 HP.
    - `currentHp = 1001`: **LOCKED**.
    - `currentHp = 1000`: **UNLOCKED**.

### 3.2 BattleEngine Behavior on Locked Finishing
When `calculateDamage` is called with `phase == 'Finishing'`:
- If `canExecuteFinishing(currentHp: currentHp, maxHp: maxHp) == false`:
  - **The engine MUST return `0` damage.**
  - This guarantees that even if UI state desyncs or an invalid command is triggered, no illegal damage can be inflicted.

### 3.3 Defensive Guards for Floating-Point & Zero Division
- To prevent IEEE floating-point inaccuracy, the gate condition can be safely evaluated as:
  ```dart
  bool canExecuteFinishing({required int currentHp, required int maxHp}) {
    if (maxHp <= 0) return false;
    return (currentHp / maxHp) <= 0.2000001; // Or currentHp * 5 <= maxHp
  }
  ```
- If `maxHp <= 0`, return `false` immediately to prevent division by zero.

---

## 4. Edge Cases & Defensive Architecture

| # | Edge Case Scenario | Expected Engine Behavior | Rationale / Risk Prevented |
|---|-------------------|--------------------------|----------------------------|
| E1 | `totalSeconds <= 0` | Return `0` | Prevents `NaN` or `Infinity` causing `UnsupportedError` on `.round()` |
| E2 | `elapsedSeconds <= 0` | Return `0` | Prevents free damage on immediate abort at 0 seconds |
| E3 | `elapsedSeconds > totalSeconds` (timer drift) | Clamp to `totalSeconds` | Prevents damage overshooting 100% |
| E4 | `basePoints <= 0` | Return `0` | Protects against invalid configuration |
| E5 | `currentHp <= 0` | Allow calculation or return `0`, HP clamped to 0 | Protects against negative HP values |
| E6 | `maxHp <= 0` | `canExecuteFinishing` returns `false`, damage returns `0` | Prevents division by zero in gate check |
| E7 | Unknown phase string (e.g. `'Nuke'`) | Fallback to `1.0x` or throw `ArgumentError` | Graceful degradation without crashing |
| E8 | 1 second elapsed Mercy Rule | Returns `0` (e.g. $100 \times \frac{1}{1500} \times 0.5 = 0.033 \rightarrow 0$) | Correct integer rounding near zero |
| E9 | 15 seconds elapsed Mercy Rule | Returns `1` ($100 \times \frac{15}{1500} \times 0.5 = 0.50 \rightarrow 1$) | Correct half-up rounding boundary |
| E10| Finishing phase with Boss HP > 20% | Returns `0` | Enforces execution skill gate |

---

## 5. Pure Dart Decoupling & Interface Contract

### 5.1 Architecture
Decouple all battle math into `lib/domain/battle/battle_engine.dart` and constants into `lib/core/constants/game_constants.dart`.
Zero imports of `package:flutter` in `lib/domain/battle/battle_engine.dart`. Pure Dart for fast, deterministic unit testing.

### 5.2 Interface Contract (from PROJECT.md)
```dart
abstract class IBattleEngine {
  int calculateDamage({
    required int basePoints,
    required String phase,
    required int elapsedSeconds,
    required int totalSeconds,
    required bool isInterrupted,
    required int currentHp,
    required int maxHp,
  });

  bool canExecuteFinishing({required int currentHp, required int maxHp});
}
```

### 5.3 Concrete Implementation Recommendation

#### `lib/core/constants/game_constants.dart`:
```dart
class GameConstants {
  // Craft Multipliers
  static const String phaseSnapFit = 'Snap-fit';
  static const String phaseSanding = 'Sanding';
  static const String phaseDetailing = 'Detailing';
  static const String phaseAirbrush = 'Airbrush';
  static const String phaseFinishing = 'Finishing';

  static const Map<String, double> craftMultipliers = {
    phaseSnapFit: 1.0,
    phaseSanding: 1.2,
    phaseDetailing: 1.5,
    phaseAirbrush: 2.0,
    phaseFinishing: 2.5,
  };

  // Execution Gate & Mercy Rule
  static const double finishingHpThreshold = 0.20; // 20%
  static const double mercyRuleFactor = 0.50;      // 50%

  // Timer Presets
  static const int standardWorkMinutes = 25;
  static const int standardWorkSeconds = 25 * 60; // 1500
  static const int standardBreakMinutes = 5;
  static const int standardBasePoints = 100;

  static const int deepFocusWorkMinutes = 50;
  static const int deepFocusWorkSeconds = 50 * 60; // 3000
  static const int deepFocusBreakMinutes = 10;
  static const int deepFocusBasePoints = 220;

  static const int debugWorkSeconds = 5;
  static const int debugBasePoints = 100;
}
```

#### `lib/domain/battle/battle_engine.dart`:
```dart
import '../../core/constants/game_constants.dart';

abstract class IBattleEngine {
  int calculateDamage({
    required int basePoints,
    required String phase,
    required int elapsedSeconds,
    required int totalSeconds,
    required bool isInterrupted,
    required int currentHp,
    required int maxHp,
  });

  bool canExecuteFinishing({required int currentHp, required int maxHp});
}

class BattleEngine implements IBattleEngine {
  const BattleEngine();

  @override
  bool canExecuteFinishing({required int currentHp, required int maxHp}) {
    if (maxHp <= 0) return false;
    return (currentHp / maxHp) <= (GameConstants.finishingHpThreshold + 1e-7);
  }

  @override
  int calculateDamage({
    required int basePoints,
    required String phase,
    required int elapsedSeconds,
    required int totalSeconds,
    required bool isInterrupted,
    required int currentHp,
    required int maxHp,
  }) {
    if (totalSeconds <= 0 || basePoints <= 0 || elapsedSeconds <= 0) {
      return 0;
    }

    if (phase == GameConstants.phaseFinishing &&
        !canExecuteFinishing(currentHp: currentHp, maxHp: maxHp)) {
      return 0;
    }

    final double multiplier = GameConstants.craftMultipliers[phase] ?? 1.0;
    final int clampedElapsed = elapsedSeconds.clamp(0, totalSeconds);
    final double elapsedRatio = clampedElapsed / totalSeconds;

    double rawDamage;
    if (isInterrupted) {
      rawDamage = basePoints * elapsedRatio * multiplier * GameConstants.mercyRuleFactor;
    } else {
      rawDamage = basePoints * multiplier;
    }

    final int finalDamage = rawDamage.round();
    return finalDamage > 0 ? finalDamage : 0;
  }

  int calculateCoins(int elapsedSeconds) {
    if (elapsedSeconds <= 0) return 0;
    return (elapsedSeconds / 5).round().clamp(2, 50);
  }
}
```

---

## 6. Unit Testing Strategy (`test/unit/battle_engine_test.dart`)

The test suite must cover 6 primary areas with deterministic assertion values:

### 6.1 Test Matrix & Concrete Values

```dart
// 1. Full Completion Damage (25m, 100 BP)
Snap-fit (1.0x)   => 100 damage
Sanding (1.2x)    => 120 damage
Detailing (1.5x)  => 150 damage
Airbrush (2.0x)   => 200 damage
Finishing (2.5x, HP<=20%) => 250 damage

// 2. Full Completion Damage (50m Deep Focus, 220 BP)
Snap-fit (1.0x)   => 220 damage
Sanding (1.2x)    => 264 damage
Detailing (1.5x)  => 330 damage
Airbrush (2.0x)   => 440 damage
Finishing (2.5x, HP<=20%) => 550 damage

// 3. Full Completion Damage (5s Fast Debug, 100 BP)
Snap-fit (1.0x)   => 100 damage
Sanding (1.2x)    => 120 damage
Detailing (1.5x)  => 150 damage
Airbrush (2.0x)   => 200 damage
Finishing (2.5x, HP<=20%) => 250 damage

// 4. Mercy Rule Interrupted Damage (25m, 100 BP)
Snap-fit, 750s/1500s (50%)  => round(100 * 0.5 * 1.0 * 0.5 = 25.0) = 25
Sanding, 750s/1500s (50%)   => round(100 * 0.5 * 1.2 * 0.5 = 30.0) = 30
Detailing, 750s/1500s (50%) => round(100 * 0.5 * 1.5 * 0.5 = 37.5) = 38
Airbrush, 1200s/1500s (80%) => round(100 * 0.8 * 2.0 * 0.5 = 80.0) = 80
Finishing, 750s/1500s (50%, HP<=20%) => round(100 * 0.5 * 2.5 * 0.5 = 62.5) = 63

// 5. Mercy Rule Interrupted Damage (50m Deep Focus, 220 BP)
Snap-fit, 1500s/3000s (50%) => round(220 * 0.5 * 1.0 * 0.5 = 55.0) = 55
Sanding, 1500s/3000s (50%)  => round(220 * 0.5 * 1.2 * 0.5 = 66.0) = 66
Detailing, 1500s/3000s (50%)=> round(220 * 0.5 * 1.5 * 0.5 = 82.5) = 83
Airbrush, 1500s/3000s (50%) => round(220 * 0.5 * 2.0 * 0.5 = 110.0) = 110
Finishing, 1500s/3000s (50%, HP<=20%) => round(220 * 0.5 * 2.5 * 0.5 = 137.5) = 138

// 6. Mercy Rule Interrupted Damage (5s Fast Debug, 100 BP)
Sanding, 3s/5s (60%)   => round(100 * 0.6 * 1.2 * 0.5 = 36.0) = 36
Airbrush, 4s/5s (80%)  => round(100 * 0.8 * 2.0 * 0.5 = 80.0) = 80

// 7. Finishing Gate Tests
canExecuteFinishing(currentHp: 101, maxHp: 500) => false
canExecuteFinishing(currentHp: 100, maxHp: 500) => true
canExecuteFinishing(currentHp: 99, maxHp: 500)  => true
canExecuteFinishing(currentHp: 0, maxHp: 500)   => true
canExecuteFinishing(currentHp: 100, maxHp: 0)   => false
calculateDamage(phase: 'Finishing', currentHp: 101, maxHp: 500) => 0
calculateDamage(phase: 'Finishing', currentHp: 100, maxHp: 500) => 250 (complete)

// 8. Rounding & Boundary Tests
1s / 1500s Snap-fit interrupted  => 0 damage
15s / 1500s Snap-fit interrupted => 1 damage (half-up from 0.50)
0s elapsed                       => 0 damage
Negative elapsed (-10s)          => 0 damage
totalSeconds <= 0                => 0 damage
elapsedSeconds > totalSeconds    => clamped to full damage
```

---

## 7. Static Analysis & Lint Fixes

### 7.1 Current Analyzer Feedback
Running `flutter analyze` currently outputs 6 info issues:
- `lib\main.dart:298:37` - `unnecessary_underscores`
- `lib\main.dart:298:41` - `unnecessary_underscores`
- `lib\main.dart:676:39` - `unnecessary_underscores`
- `lib\main.dart:676:43` - `unnecessary_underscores`
- `lib\main.dart:719:39` - `unnecessary_underscores`
- `lib\main.dart:719:43` - `unnecessary_underscores`

### 7.2 Immediate Fix
In modern Dart (wildcard variables enabled), multiple underscores are deprecated when single underscores can be reused.
Replace:
```dart
// Line 298, Line 676, Line 719:
errorBuilder: (_, __, ___) => const Icon(...)
```
With:
```dart
errorBuilder: (_, _, _) => const Icon(...)
```
This instantly resolves all 6 analyzer issues, achieving 0 errors and 0 warnings.

---

## 8. Guidance for Worker Implementation

1. Create `lib/core/constants/game_constants.dart` with all multiplier maps and timing constants.
2. Create `lib/domain/battle/battle_engine.dart` implementing `IBattleEngine` with pure Dart math and defensive zero-guards.
3. Fix the 6 `unnecessary_underscores` in `lib/main.dart:298, 676, 719`.
4. Update `lib/main.dart` to instantiate and utilize `BattleEngine` instead of inline calculations.
5. Create `test/unit/battle_engine_test.dart` implementing the full test matrix detailed in §6.
6. Replace the broken dummy counter test in `test/widget_test.dart` with a proper app smoke test or delete/update it so `flutter test` passes 100%.
