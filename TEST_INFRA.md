# Test Infrastructure Specification (TEST_INFRA.md)

## 1. Executive Summary & Philosophy
《罪普拉 RPG》（Tsumi-Pura RPG） employs an opaque-box, requirement-driven test infrastructure. Testing is conducted strictly through user-facing surfaces (Widget keys, simulated touch gestures, rendered text nodes, and domain repository outputs) without bypassing private application state or using facade shortcuts.

## 2. Test Harness Architecture & Isolation
- **Framework**: Flutter WidgetTester (`flutter_test`).
- **Storage Isolation**: In-memory `SharedPreferences.setMockInitialValues({})` for every test run, preventing cross-test pollution and zero disk/cloud dependency.
- **Audio Isolation**: `MockRetroAudioService` implementing `IRetroAudioService` with invocation tracking counters (`timerTickCount`, `attackHitCount`, `criticalStrikeCount`, `finishingKillCount`, `victoryFanfareCount`) and HUD mute toggle verification.
- **Asset/Font Isolation**: `GoogleFonts.config.allowRuntimeFetching = false` set in test fixtures, guaranteeing 100% offline, zero-network execution with safe monospace fallbacks.
- **Concurrency & State Synchronization**: Repository operations are protected by pure Dart `AsyncLock` ensuring atomic write transactions across kits and craft logs.

## 3. Test Pyramid & Directory Layout
```
test/
├── unit/                               # Domain models, pure math, battle engine
│   ├── async_lock_test.dart
│   ├── audio_service_test.dart
│   ├── battle_engine_adversarial_test.dart
│   ├── battle_engine_test.dart
│   ├── models_test.dart
│   └── storage_test.dart
├── widget/                             # Screen and widget component tests
│   ├── battle_autosave_test.dart
│   ├── craft_log_screen_test.dart
│   ├── hangar_screen_test.dart
│   ├── navigation_and_active_kit_test.dart
│   ├── retro_juice_test.dart
│   ├── showcase_screen_test.dart
│   └── visual_juice_stress_test.dart
├── challenge/                          # Adversarial stress & boundary hardening
│   ├── hangar_crud_challenge_test.dart
│   ├── m3_metrics_and_navigation_challenge_test.dart
│   ├── m4_audio_performance_stress_test.dart
│   ├── pomodoro_challenge_test.dart
│   ├── storage_stress_challenge_test.dart
│   └── ui_state_autosave_stress_test.dart
└── e2e/                                # End-to-end full application suites (Tiers 1-4)
    ├── e2e_tier1_r1_r2_test.dart       # Tier 1: Features 1-17 Happy Paths (>=5 tests/feat)
    ├── e2e_tier1_r3_r4_test.dart       # Tier 1: Features 18-31 Happy Paths (>=5 tests/feat)
    ├── e2e_tier2_r1_r2_test.dart       # Tier 2: Features 1-17 Boundaries & Corners
    ├── e2e_tier2_r3_r4_test.dart       # Tier 2: Features 18-31 Boundaries & Corners
    ├── e2e_tier3_pairwise_test.dart    # Tier 3: 25 Cross-Feature Pairwise Combinations
    └── e2e_tier4_scenarios_test.dart   # Tier 4: Real-world Multi-step Player Workflows
```

## 4. Test Fixtures & Setup Standards

### 4.1 Virtual Viewport Configuration
To eliminate layout boundary clipping across test runner environments, all widget and E2E tests enforce a standardized 1080x1920 virtual screen:
```dart
tester.view.physicalSize = const Size(1080, 1920);
tester.view.devicePixelRatio = 1.0;
addTearDown(() => tester.view.resetPhysicalSize());
```

### 4.2 Application Bootstrapping Fixture
```dart
Future<void> pumpTsumiPuraApp(
  WidgetTester tester, {
  IKitRepository? kitRepo,
  ICraftLogRepository? craftLogRepo,
  IRetroAudioService? audioService,
}) async {
  final mockAudio = audioService ?? MockRetroAudioService();
  RetroAudioService.setCustomInstance(mockAudio);
  addTearDown(() => RetroAudioService.resetInstance());

  await tester.pumpWidget(
    TsumiPuraApp(
      kitRepository: kitRepo,
      craftLogRepository: craftLogRepo,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}
```

### 4.3 Deterministic Pomodoro Clock Advancement (N+1 Rule)
The Pomodoro timer uses a 1-second `PeriodicTimer`. At tick `T = totalSeconds`, the clock reaches `00:00`. At tick `T + 1`, the work session completes and transitions to the rest phase:
```dart
// For a 5-second debug session:
for (int i = 0; i < 6; i++) {
  await tester.pump(const Duration(seconds: 1));
}
await tester.pump(const Duration(milliseconds: 300));
```

## 5. UI Key & Finder Dictionary
All tests drive and assert interactions via registered Keys:
- **Battle HUD**: `btn_hangar`, `btn_showcase`, `btn_craft_log`, `btn_mute_toggle`, `btn_nav_battle`, `btn_nav_hangar`, `btn_nav_showcase`, `btn_nav_craft_log`.
- **Hangar**: `btn_hangar_back`, `btn_add_kit`, `btn_refresh_hangar`, `filter_all`, `filter_unstarted`, `filter_in_progress`, `filter_completed`, `kit_card_<id>`, `btn_set_active_<id>`, `btn_edit_kit_<id>`, `btn_delete_kit_<id>`, `btn_confirm_delete`.
- **Form**: `input_kit_title`, `chip_grade_<grade>`, `checkbox_custom_hp`, `input_kit_hp`, `checkbox_set_active`, `checkbox_reset_hp`, `btn_dialog_save`, `btn_dialog_cancel`.
- **Showcase**: `btn_showcase_back`, `btn_refresh_showcase`, `showcase_card_<id>`, `showcase_detail_dialog`, `btn_showcase_close_detail`, `btn_showcase_view_logs_<id>`.
- **CraftLog**: `btn_craft_log_back`.
- **Juice**: `ScreenShake`, `BossHurtFlash`, `FloatingDamageOverlay`, `PixelHpBar`.

## 6. Execution & Pipeline Commands
- **Static Analysis**:
  ```bash
  flutter analyze
  ```
- **Full Test Suite Execution**:
  ```bash
  flutter test
  ```
- **E2E Test Suite Execution**:
  ```bash
  flutter test test/e2e/
  ```
- **Targeted Test Execution**:
  ```bash
  flutter test test/e2e/e2e_tier1_r1_r2_test.dart
  flutter test test/e2e/e2e_tier1_r3_r4_test.dart
  flutter test test/e2e/e2e_tier2_r1_r2_test.dart
  flutter test test/e2e/e2e_tier2_r3_r4_test.dart
  flutter test test/e2e/e2e_tier3_pairwise_test.dart
  flutter test test/e2e/e2e_tier4_scenarios_test.dart
  ```
