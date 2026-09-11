# Project: 《罪普拉 RPG》（Tsumi-Pura RPG）

## Architecture
Clean Architecture with Domain-Driven Design tailored for Flutter:
```
lib/
├── core/
│   ├── constants/        # Multipliers, Grades, Timer presets, Theme colors
│   └── audio/            # 8-bit retro sound manager (zero-cost, Web/Windows compatible)
├── domain/
│   ├── models/           # Pure Dart entities: KitItem, CraftLog, PomodoroSession
│   └── battle/           # Pure Dart: BattleEngine, DamageCalculator, MercyRule
├── data/
│   ├── storage/          # Local persistence abstraction & SharedPreferences/JSON engine
│   └── repositories/     # KitRepository, CraftLogRepository implementations
├── presentation/
│   ├── screens/          # BattleScreen, HangarScreen, ShowcaseScreen, LogHistoryScreen
│   ├── widgets/          # PixelHpBar, FloatingDamage, ScreenShake, PixelButton, RetroDialog
│   └── theme/            # Retro 8-bit typography (Press Start 2P/VT323), palettes
└── main.dart             # App entry point, dependency injection, route management
```

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Pomodoro 25m/5m Timer | Standard 25m work / 5m rest cycle | M1 | SPEC §1, ORIGINAL_REQUEST §R1 |
| 2 | Pomodoro 50m/10m Timer | Deep focus 50m work / 10m rest cycle | M1 | SPEC §1, spec_analysis.md |
| 3 | Fast Debug Mode | 5s session timer for rapid verification and debugging | M1 | ORIGINAL_REQUEST §R1 |
| 4 | Snap-fit Multiplier | 1.0x damage multiplier for Snap-fit / 素組 | M1 | SPEC §2, ORIGINAL_REQUEST §R1 |
| 5 | Sanding Multiplier | 1.2x damage multiplier for Sanding / 打磨 | M1 | SPEC §2, ORIGINAL_REQUEST §R1 |
| 6 | Detailing Multiplier | 1.5x damage multiplier for Detailing / 刻線 | M1 | SPEC §2, ORIGINAL_REQUEST §R1 |
| 7 | Airbrush Multiplier | 2.0x damage multiplier for Airbrush / 噴塗 | M1 | SPEC §2, ORIGINAL_REQUEST §R1 |
| 8 | Finishing Multiplier | 2.5x damage multiplier for Finishing / 水貼消光 | M1 | SPEC §2, ORIGINAL_REQUEST §R1 |
| 9 | Finishing Execution Gate | Locked when Boss HP > 20%, unlocked when HP <= 20% | M1 | SPEC §2, ORIGINAL_REQUEST §R1 |
| 10 | Mercy Rule Damage Floor | On interruption: (elapsed/total) * base * mult * 0.5 floor | M1 | SPEC §2, ORIGINAL_REQUEST §R1 |
| 11 | Battle Engine Pure Math | Decoupled pure Dart calculation with integer rounding | M1 | spec_analysis.md |
| 12 | Lint Issue Fixes | Fix 6 `unnecessary_underscores` in existing code | M1 | codebase_analysis.md |
| 13 | KitItem Data Model | UUID, title, grade, totalHp, currentHp, status, timestamps | M2 | SPEC §7, ORIGINAL_REQUEST §R2 |
| 14 | CraftLog Data Model | UUID, kitId, phase, durationMinutes, damageDealt, isCompleted | M2 | SPEC §7, ORIGINAL_REQUEST §R2 |
| 15 | Local Persistence Service | Offline repository using SharedPreferences JSON engine | M2 | SPEC §7, ORIGINAL_REQUEST §R2 |
| 16 | Auto-save & State Hydration | Progress restored on app reload / web refresh | M2 | ORIGINAL_REQUEST §R2 |
| 17 | CraftLog History & Stats View | Per-kit & global craft log review and elapsed work time | M2 | ORIGINAL_REQUEST §R2 |
| 18 | Model Hangar Screen | Backlog list view, kit status indicators, active kit switch | M3 | SPEC §3, ORIGINAL_REQUEST §R3 |
| 19 | Model CRUD Management | Add new kit, edit kit info, delete kit from hangar | M3 | ORIGINAL_REQUEST §R3 |
| 20 | Grade & HP Defaults | Presets: EG 300, HG 500, RG 800, MG 1500, PG 5000 HP | M3 | SPEC §3, ORIGINAL_REQUEST §R3 |
| 21 | Custom HP Input | Allow user to override default HP with custom positive value | M3 | ORIGINAL_REQUEST §R3 |
| 22 | Active Kit Battle Link | Selected kit in Hangar becomes the active Boss in Battle | M3 | ORIGINAL_REQUEST §R3 |
| 23 | Boss Defeat Transition | HP <= 0 marks kit as completed and moves to Showcase | M3 | SPEC §1, ORIGINAL_REQUEST §R3 |
| 24 | Showcase Gallery Screen | Grid/card view of all completed model kits | M3 | SPEC §5, ORIGINAL_REQUEST §R3 |
| 25 | Showcase Details & Metrics | Display completion date, total craft time, session count | M3 | ORIGINAL_REQUEST §R3 |
| 26 | 8-Bit Pixel UI Consistency | Pixelated borders, retro workbench dark theme, retro HUD | M4 | ORIGINAL_REQUEST §R4 |
| 27 | Retro Typography | Pixel fonts (Press Start 2P / VT323 / monospace fallback) | M4 | ORIGINAL_REQUEST §R4 |
| 28 | Battle Juice Screen Shake | Violent screen shake animation on dealing damage | M4 | ORIGINAL_REQUEST §R4 |
| 29 | Floating Damage Numbers | Bouncing retro damage popup indicators over Boss | M4 | ORIGINAL_REQUEST §R4 |
| 30 | Boss Hurt Flash | Red flashing hurt feedback animation on hit | M4 | ORIGINAL_REQUEST §R4 |
| 31 | Zero-Cost Retro Audio | Web/Windows compatible 8-bit sound synth / audio player | M4 | ORIGINAL_REQUEST §R4 |
| 32 | Automated Unit Test Suite | Comprehensive unit tests for math, models, storage, battle | M5 | Acceptance Criteria |
| 33 | 0 Errors / 0 Warnings Analyzer | `flutter analyze` passes cleanly with 0 issues | M5 | Acceptance Criteria |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| E2E | E2E Testing Track | Independent requirement-driven test suite (Tiers 1-4), publishes TEST_READY.md | none | PLANNED |
| M1 | Pomodoro & Battle Engine | Features 1-12: Core battle engine, timers (25m/5m, 50m/10m, 5s debug), 5 multipliers, execution lock, Mercy Rule 50%, lint fix | none | DONE |
| M2 | Local Persistence & CraftLog | Features 13-17: KitItem & CraftLog models, storage service, offline repository, auto-hydration, CraftLog stats view | M1 | DONE |
| M3 | Model Hangar & Showcase | Features 18-25: Hangar CRUD, Grade presets & custom HP, active kit switching, victory transition, Showcase Gallery | M2 | IN_PROGRESS |
| M4 | 8-Bit Retro Game Juice | Features 26-31: Pixel UI styling, typography, screen shake, floating damage text, hurt flash, zero-cost retro audio | M1, M3 | PLANNED |
| M5 | Final Milestone & Coverage | Features 32-33: 100% E2E test pass, Tier 5 Adversarial Coverage Hardening, `flutter analyze` 0 errors | M1, M2, M3, M4, E2E | PLANNED |
| M6 | Forensic Victory Audit | Mandatory forensic audit for integrity, zero-cost, and genuine logic before reporting to Sentinel | M5 | PLANNED |

## Interface Contracts
### BattleEngine ↔ Storage / Repository
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

### Storage ↔ Presentation
```dart
abstract class IKitRepository {
  Future<List<KitItem>> getAllKits();
  Future<KitItem?> getActiveKit();
  Future<void> saveKit(KitItem kit);
  Future<void> deleteKit(String kitId);
  Future<void> setActiveKit(String kitId);
}

abstract class ICraftLogRepository {
  Future<List<CraftLog>> getLogsForKit(String kitId);
  Future<List<CraftLog>> getAllLogs();
  Future<void> addLog(CraftLog log);
}
```

## Code Layout
- `lib/core/constants/game_constants.dart`
- `lib/core/audio/retro_audio_service.dart`
- `lib/domain/models/kit_item.dart`
- `lib/domain/models/craft_log.dart`
- `lib/domain/battle/battle_engine.dart`
- `lib/data/storage/local_storage_service.dart`
- `lib/data/repositories/kit_repository.dart`
- `lib/data/repositories/craft_log_repository.dart`
- `lib/presentation/theme/retro_theme.dart`
- `lib/presentation/widgets/pixel_widgets.dart`
- `lib/presentation/widgets/battle_effects.dart`
- `lib/presentation/screens/battle_screen.dart`
- `lib/presentation/screens/hangar_screen.dart`
- `lib/presentation/screens/showcase_screen.dart`
- `lib/presentation/screens/craft_log_screen.dart`
- `lib/main.dart`
- `test/unit/battle_engine_test.dart`
- `test/unit/models_test.dart`
- `test/unit/storage_test.dart`
- `test/e2e/` (Tiers 1-4 test suite)
