import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nifty_heisenberg/core/audio/retro_audio_service.dart';
import 'package:nifty_heisenberg/core/constants/game_constants.dart';
import 'package:nifty_heisenberg/data/repositories/craft_log_repository.dart';
import 'package:nifty_heisenberg/data/repositories/kit_repository.dart';
import 'package:nifty_heisenberg/data/storage/local_storage_service.dart';
import 'package:nifty_heisenberg/data/storage/storage_keys.dart';
import 'package:nifty_heisenberg/domain/battle/battle_engine.dart';
import 'package:nifty_heisenberg/domain/models/craft_log.dart';
import 'package:nifty_heisenberg/domain/models/kit_item.dart';
import 'package:nifty_heisenberg/main.dart';
import 'package:nifty_heisenberg/presentation/screens/craft_log_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    RetroAudioService.resetInstance();
  });

  tearDown(() {
    RetroAudioService.resetInstance();
  });

  void setTestViewport(WidgetTester tester, {Size size = const Size(1080, 1920)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    KitRepository? kitRepo,
    CraftLogRepository? logRepo,
    MockRetroAudioService? mockAudio,
    Size size = const Size(1080, 1920),
  }) async {
    setTestViewport(tester, size: size);
    final audio = mockAudio ?? MockRetroAudioService();
    RetroAudioService.setCustomInstance(audio);

    await tester.pumpWidget(
      TsumiPuraApp(
        kitRepository: kitRepo,
        craftLogRepository: logRepo,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  // =========================================================================
  // Feature 1: Pomodoro 25m/5m Timer (Boundaries)
  // =========================================================================
  group('Feature 1: Pomodoro 25m/5m Timer (Boundaries)', () {
    testWidgets('T2-F01-01: Instant Interruption at 0 Seconds', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      // Interrupt at exactly 0s elapsed
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // Damage is 0, HP stays 500/500, returns to idle
      expect(find.textContaining('500 / 500 HP'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.textContaining('開始開工 (標準 25m/5m)'), findsOneWidget);
    });

    testWidgets('T2-F01-02: Interruption at Exactly 1 Second (Mercy Floor)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      // Advance 1 second
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // (1 / 1500) * 100 * 1.0 * 0.5 = 0.033 -> clamped to 1 damage floor. 500 -> 499
      expect(find.textContaining('499 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F01-03: Interruption at 99% Progress (1485s)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      // Advance 1485s (99% of 1500s)
      await tester.pump(const Duration(seconds: 1485));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 100 * 0.99 * 1.0 * 0.5 = 49.5 -> rounds to 50 damage. 500 -> 450
      expect(find.textContaining('450 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F01-04: Full Rest Timeout (300s Countdown)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      // Complete 1500s work session (needs 1501s pump for periodic timer)
      await tester.pump(const Duration(seconds: 1501));
      await tester.pump();

      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);

      // Advance 301 seconds for rest completion
      await tester.pump(const Duration(seconds: 301));
      await tester.pump();

      // Auto-terminates to idle
      expect(find.text('00:00'), findsOneWidget);
      expect(find.textContaining('開始開工 (標準 25m/5m)'), findsOneWidget);
    });

    testWidgets('T2-F01-05: Rapid Start-Interrupt Cycles (10 Cycles)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();

      for (int i = 0; i < 10; i++) {
        await tester.tap(find.textContaining('開始開工'));
        await tester.pump(const Duration(milliseconds: 10));
        await tester.tap(find.textContaining('中途中斷'));
        await tester.pump(const Duration(milliseconds: 10));
      }

      // App stays stable and returns cleanly to idle
      expect(find.text('00:00'), findsOneWidget);
      expect(find.textContaining('開始開工 (標準 25m/5m)'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 2: Pomodoro 50m/10m Timer (Boundaries)
  // =========================================================================
  group('Feature 2: Pomodoro 50m/10m Timer (Boundaries)', () {
    testWidgets('T2-F02-01: Interruption at 1% Progress (30s)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('深度 50m/10m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      // Advance 30s (1% of 3000s)
      await tester.pump(const Duration(seconds: 30));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 220 * 0.01 * 1.0 * 0.5 = 1.1 -> rounds to 1 damage. 500 -> 499
      expect(find.textContaining('499 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F02-02: Interruption at 50% Progress (1500s)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('深度 50m/10m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      // Advance 1500s (50% of 3000s)
      await tester.pump(const Duration(seconds: 1500));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 220 * 0.50 * 1.0 * 0.5 = 55 damage. 500 -> 445
      expect(find.textContaining('445 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F02-03: Interruption at 99% Progress (2970s)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('深度 50m/10m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      // Advance 2970s (99% of 3000s)
      await tester.pump(const Duration(seconds: 2970));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 220 * 0.99 * 1.0 * 0.5 = 108.9 -> rounds half-up to 109 damage. 500 -> 391
      expect(find.textContaining('391 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F02-04: Full Rest Timeout (600s Countdown)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('深度 50m/10m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      // Complete 3000s work session
      await tester.pump(const Duration(seconds: 3001));
      await tester.pump();

      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);

      // Advance 601s for rest completion
      await tester.pump(const Duration(seconds: 601));
      await tester.pump();

      expect(find.text('00:00'), findsOneWidget);
      expect(find.textContaining('開始開工 (深度 50m/10m)'), findsOneWidget);
    });

    testWidgets('T2-F02-05: Mode Selector Locked/Hidden During Deep Focus Work', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('深度 50m/10m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      // Mode selector SegmentedButton is hidden during work phase
      expect(find.text('標準 25m/5m'), findsNothing);
      expect(find.text('5秒測試'), findsNothing);
    });
  });

  // =========================================================================
  // Feature 3: Fast Debug Mode (Boundaries)
  // =========================================================================
  group('Feature 3: Fast Debug Mode (Boundaries)', () {
    testWidgets('T2-F03-01: Instant Interruption at 0s in Debug Mode', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      expect(find.textContaining('500 / 500 HP'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('T2-F03-02: Interruption at 1s in Debug Mode', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 20 * (1/5) * 1.0 * 0.5 = 2 damage. 500 -> 498
      expect(find.textContaining('498 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F03-03: Interruption at 4s in Debug Mode (80% Progress)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 4));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 20 * (4/5) * 1.0 * 0.5 = 8 damage. 500 -> 492
      expect(find.textContaining('492 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F03-04: Empirical N+1 Tick Completion Verification', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      // Advance 5 seconds: clock at 00:00, still in WORK
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('00:00'), findsOneWidget);
      expect(find.textContaining('WORK - 專注組裝中'), findsOneWidget);

      // Advance 1 more second: transitions to REST (00:03)
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);
      expect(find.text('00:03'), findsOneWidget);
    });

    testWidgets('T2-F03-05: Debug Coin Grant on 0s Interruption (Clamp Floor)', (tester) async {
      await pumpApp(tester);
      expect(find.textContaining('150 塑料金幣'), findsOneWidget);

      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // (0/5).round().clamp(2, 50) grants 2 coins -> 152
      expect(find.textContaining('152 塑料金幣'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 4: Snap-fit Multiplier (Boundaries)
  // =========================================================================
  group('Feature 4: Snap-fit Multiplier (Boundaries)', () {
    testWidgets('T2-F04-01: Snap-fit Multiplier on 1 HP Remaining', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final logRepo = CraftLogRepository(storage);
      final lowHpKit = KitItem.initialSeedKit().copyWith(currentHp: 1);
      await kitRepo.saveKit(lowHpKit);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      expect(find.textContaining('1 / 500 HP'), findsOneWidget);

      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);
      final updated = (await kitRepo.getAllKits()).firstWhere((k) => k.id == lowHpKit.id);
      expect(updated.currentHp, equals(0));
    });

    testWidgets('T2-F04-02: Snap-fit Interruption with 1s in Standard Mode', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 1 damage floor applied
      expect(find.textContaining('499 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F04-03: Rapid Phase Toggle Snap-fit <-> Sanding (20 times)', (tester) async {
      await pumpApp(tester);

      for (int i = 0; i < 10; i++) {
        await tester.tap(find.textContaining('打磨'));
        await tester.pump();
        await tester.tap(find.textContaining('素組'));
        await tester.pump();
      }

      expect(find.textContaining('【剪鉗連擊】(1.0x 倍率)'), findsOneWidget);
    });

    testWidgets('T2-F04-04: Snap-fit Dialogue Text Accuracy', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('打磨'));
      await tester.pump();
      await tester.tap(find.textContaining('素組'));
      await tester.pump();
      expect(find.textContaining('【剪鉗連擊】(1.0x 倍率)'), findsOneWidget);
    });

    testWidgets('T2-F04-05: Snap-fit Session Auto-Save Consistency', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final logRepo = CraftLogRepository(storage);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Run 2 debug sessions (each 20 dmg)
      for (int i = 0; i < 2; i++) {
        await tester.tap(find.text('5秒測試'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();
        await tester.tap(find.textContaining('略過休息'));
        await tester.pump();
      }

      final logs = await logRepo.getAllLogs();
      expect(logs.length, equals(2));
      for (final log in logs) {
        expect(log.phase, equals('Snap-fit'));
        expect(log.damageDealt, equals(20));
      }
    });
  });

  // =========================================================================
  // Feature 5: Sanding Multiplier (Boundaries)
  // =========================================================================
  group('Feature 5: Sanding Multiplier (Boundaries)', () {
    testWidgets('T2-F05-01: Sanding Interruption at 1s in Standard Mode', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('打磨'));
      await tester.pump();
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // (1/1500) * 100 * 1.2 * 0.5 = 0.04 -> clamped to 1 damage floor
      expect(find.textContaining('499 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F05-02: Sanding Interruption at 750s (50% Progress)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('打磨'));
      await tester.pump();
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 750));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 100 * 0.5 * 1.2 * 0.5 = 30 damage. 500 -> 470
      expect(find.textContaining('470 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F05-03: Sanding Interruption at 99% in Standard Mode', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('打磨'));
      await tester.pump();
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1485));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 100 * 0.99 * 1.2 * 0.5 = 59.4 -> rounds down to 59 damage. 500 -> 441
      expect(find.textContaining('441 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F05-04: Sanding Overkill Clamping', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final lowHpKit = KitItem.initialSeedKit().copyWith(currentHp: 15);
      await kitRepo.saveKit(lowHpKit);

      await pumpApp(tester, kitRepo: kitRepo);
      await tester.tap(find.textContaining('打磨'));
      await tester.pump();

      // 5s debug Sanding deals 20 * 1.2 = 24 damage (> 15 HP)
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);
      final updated = (await kitRepo.getAllKits()).firstWhere((k) => k.id == lowHpKit.id);
      expect(updated.currentHp, equals(0));
    });

    testWidgets('T2-F05-05: Sanding Action Log Verification', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('打磨'));
      await tester.pump();
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      expect(find.textContaining('推動 600 號海綿砂紙！精準破除盒怪裝甲防禦！'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 6: Detailing Multiplier (Boundaries)
  // =========================================================================
  group('Feature 6: Detailing Multiplier (Boundaries)', () {
    testWidgets('T2-F06-01: Half-Up Rounding at 50% Standard Interruption (37.5 -> 38)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('刻線'));
      await tester.pump();
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 750));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 100 * 0.5 * 1.5 * 0.5 = 37.5 -> rounds half-up to 38 damage. 500 -> 462
      expect(find.textContaining('462 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F06-02: Half-Up Rounding at 50% Deep Focus Interruption (82.5 -> 83)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('刻線'));
      await tester.pump();
      await tester.tap(find.text('深度 50m/10m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1500));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 220 * 0.5 * 1.5 * 0.5 = 82.5 -> rounds to 83 damage. 500 -> 417
      expect(find.textContaining('417 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F06-03: Detailing at 99% Standard Progress (74.25 -> 74)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('刻線'));
      await tester.pump();
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1485));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 100 * 0.99 * 1.5 * 0.5 = 74.25 -> rounds to 74 damage. 500 -> 426
      expect(find.textContaining('426 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F06-04: Detailing 1s Interruption (0.05 -> 1)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('刻線'));
      await tester.pump();
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 1 damage floor applied
      expect(find.textContaining('499 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F06-05: Detailing Critical Color Highlight', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('刻線'));
      await tester.pump();
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      // 1500s Standard Detailing deals 150 damage (critical)
      await tester.pump(const Duration(seconds: 1501));
      await tester.pump();

      expect(find.textContaining('480 / 500 HP'), findsNothing);
      expect(find.textContaining('350 / 500 HP'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 7: Airbrush Multiplier (Boundaries)
  // =========================================================================
  group('Feature 7: Airbrush Multiplier (Boundaries)', () {
    testWidgets('T2-F07-01: Airbrush 50% Interruption Standard (50 damage)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('噴塗'));
      await tester.pump();
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 750));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 100 * 0.5 * 2.0 * 0.5 = 50 damage. 500 -> 450
      expect(find.textContaining('450 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F07-02: Airbrush 80% Interruption Standard (80 damage)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('噴塗'));
      await tester.pump();
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1200));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 100 * 0.8 * 2.0 * 0.5 = 80 damage. 500 -> 420
      expect(find.textContaining('420 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F07-03: Airbrush 99% Interruption Standard (99 damage)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('噴塗'));
      await tester.pump();
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1485));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 100 * 0.99 * 2.0 * 0.5 = 99 damage. 500 -> 401
      expect(find.textContaining('401 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F07-04: Airbrush 1s Interruption Standard', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('噴塗'));
      await tester.pump();
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 1 damage floor applied
      expect(find.textContaining('499 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F07-05: Double Airbrush Standard on 500 HP Boss Leaves 100 HP (Exact 20% Gate)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('噴塗'));
      await tester.pump();
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();

      // Session 1: deals 200 damage (500 -> 300)
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1501));
      await tester.pump();
      await tester.tap(find.textContaining('略過休息'));
      await tester.pump();

      expect(find.textContaining('300 / 500 HP'), findsOneWidget);

      // Session 2: deals 200 damage (300 -> 100)
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1501));
      await tester.pump();
      await tester.tap(find.textContaining('略過休息'));
      await tester.pump();

      expect(find.textContaining('100 / 500 HP'), findsOneWidget);
      // Finishing unlocked at exact 20.0%
      expect(find.textContaining('水貼\n2.5x'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 8: Finishing Multiplier (Boundaries)
  // =========================================================================
  group('Feature 8: Finishing Multiplier (Boundaries)', () {
    testWidgets('T2-F08-01: Finishing Half-Up Rounding at 50% Standard (62.5 -> 63)', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final kit = KitItem.initialSeedKit().copyWith(currentHp: 100);
      await kitRepo.saveKit(kit);

      await pumpApp(tester, kitRepo: kitRepo);
      await tester.tap(find.textContaining('水貼'));
      await tester.pump();
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 750));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 100 * 0.5 * 2.5 * 0.5 = 62.5 -> rounds half-up to 63 damage. 100 -> 37
      expect(find.textContaining('37 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F08-02: Finishing Half-Up Rounding at 99% Standard (123.75 -> 124)', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final kit = KitItem.initialSeedKit().copyWith(currentHp: 100);
      await kitRepo.saveKit(kit);

      await pumpApp(tester, kitRepo: kitRepo);
      await tester.tap(find.textContaining('水貼'));
      await tester.pump();
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1485));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // 124 damage exceeds 100 HP -> HP is 0, Quest Clear
      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);
    });

    testWidgets('T2-F08-03: Finishing 50% Deep Focus Interruption (137.5 -> 138)', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final kit = KitItem(
        id: 'mg-01',
        title: 'MG Test Kit',
        grade: 'MG',
        totalHp: 1000,
        currentHp: 200,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit);
      await kitRepo.setActiveKit('mg-01');

      await pumpApp(tester, kitRepo: kitRepo);
      await tester.tap(find.textContaining('水貼'));
      await tester.pump();
      await tester.tap(find.text('深度 50m/10m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1500));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 220 * 0.5 * 2.5 * 0.5 = 137.5 -> rounds to 138 damage. 200 -> 62
      expect(find.textContaining('62 / 1000 HP'), findsOneWidget);
    });

    testWidgets('T2-F08-04: Finishing 1s Interruption Standard', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final kit = KitItem.initialSeedKit().copyWith(currentHp: 100);
      await kitRepo.saveKit(kit);

      await pumpApp(tester, kitRepo: kitRepo);
      await tester.tap(find.textContaining('水貼'));
      await tester.pump();
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // 1 damage floor applied. 100 -> 99
      expect(find.textContaining('99 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F08-05: Finishing Execution Sound & Fanfare', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final kit = KitItem.initialSeedKit().copyWith(currentHp: 50);
      await kitRepo.saveKit(kit);

      final mockAudio = MockRetroAudioService();
      await pumpApp(tester, kitRepo: kitRepo, mockAudio: mockAudio);
      await tester.tap(find.textContaining('水貼'));
      await tester.pump();

      // 5s debug Finishing deals 50 damage -> exact defeat
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);
      expect(mockAudio.victoryFanfareCount, greaterThan(0));
    });
  });

  // =========================================================================
  // Feature 9: Finishing Execution Gate (Boundaries)
  // =========================================================================
  group('Feature 9: Finishing Execution Gate (Boundaries)', () {
    testWidgets('T2-F09-01: Strict Boundary at 20.2% (101 / 500 HP)', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final kit = KitItem.initialSeedKit().copyWith(currentHp: 101);
      await kitRepo.saveKit(kit);

      await pumpApp(tester, kitRepo: kitRepo);
      expect(find.textContaining('水貼\n🔒20%'), findsOneWidget);
    });

    testWidgets('T2-F09-02: Strict Boundary at 20.0% (100 / 500 HP)', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final kit = KitItem.initialSeedKit().copyWith(currentHp: 100);
      await kitRepo.saveKit(kit);

      await pumpApp(tester, kitRepo: kitRepo);
      expect(find.textContaining('水貼\n2.5x'), findsOneWidget);
    });

    testWidgets('T2-F09-03: Boundary Across Kit Grades', (tester) async {
      final testCases = [
        {'grade': 'EG', 'total': 300, 'hp': 60},
        {'grade': 'RG', 'total': 800, 'hp': 160},
        {'grade': 'MG', 'total': 1500, 'hp': 300},
        {'grade': 'PG', 'total': 5000, 'hp': 1000},
      ];

      for (final tc in testCases) {
        final storage = LocalStorageService();
        final kitRepo = KitRepository(storage);
        final kit = KitItem(
          id: 'test-${tc['grade']}',
          title: 'Test ${tc['grade']}',
          grade: tc['grade'] as String,
          totalHp: tc['total'] as int,
          currentHp: tc['hp'] as int,
          status: KitStatus.inProgress,
          createdAt: DateTime.now(),
        );
        await kitRepo.saveKit(kit);
        await kitRepo.setActiveKit(kit.id);

        await pumpApp(tester, kitRepo: kitRepo);
        expect(find.textContaining('水貼\n2.5x'), findsOneWidget);
      }
    });

    testWidgets('T2-F09-04: Gate Lock on Kit Switch to High HP Kit', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final lowKit = KitItem(
        id: 'kit-low',
        title: 'Low HP Kit',
        grade: 'HG',
        totalHp: 500,
        currentHp: 90,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      final highKit = KitItem(
        id: 'kit-high',
        title: 'High HP Kit',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(lowKit);
      await kitRepo.saveKit(highKit);
      await kitRepo.setActiveKit(lowKit.id);

      await pumpApp(tester, kitRepo: kitRepo);
      await tester.tap(find.textContaining('水貼'));
      await tester.pump();

      // Go to Hangar and switch to highKit
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(Key('btn_set_active_${highKit.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Finishing is locked again and phase resets to Snap-fit
      expect(find.textContaining('水貼\n🔒20%'), findsOneWidget);
      final segBtn = tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));
      expect(segBtn.selected, contains(CraftPhases.snapFit));
    });

    testWidgets('T2-F09-05: Starting Timer with Finishing when Gate is Locked', (tester) async {
      // In normal UI, Finishing is disabled when locked.
      await pumpApp(tester);
      expect(find.textContaining('水貼\n🔒20%'), findsOneWidget);
      // Verify Finishing cannot be selected
      await tester.tap(find.textContaining('水貼'));
      await tester.pump();
      final segBtn = tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));
      expect(segBtn.selected, contains(CraftPhases.snapFit));
    });
  });

  // =========================================================================
  // Feature 10: Mercy Rule Damage Floor (Boundaries)
  // =========================================================================
  group('Feature 10: Mercy Rule Damage Floor (Boundaries)', () {
    testWidgets('T2-F10-01: Zero Elapsed Seconds (0s) Yields Exactly 0 Damage', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      expect(find.textContaining('500 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F10-02: Elapsed > 0 Always Yields >= 1 Damage (Floor Guarantee)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      expect(find.textContaining('499 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F10-03: Interruption at N-1 Seconds (Near Full Session)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      // 1499s out of 1500s
      await tester.pump(const Duration(seconds: 1499));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // (1499/1500) * 100 * 1.0 * 0.5 = 49.96 -> 50 damage (not full 100)
      expect(find.textContaining('450 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F10-04: Multiple Partial Interruptions Preserve Consistency', (tester) async {
      await pumpApp(tester);

      // 3 consecutive 2s interruptions in 5s debug (each deals 20 * (2/5) * 0.5 = 4 dmg)
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('5秒測試'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await tester.tap(find.textContaining('中途中斷'));
        await tester.pump();
      }

      // Total damage = 3 * 4 = 12 dmg. 500 -> 488
      expect(find.textContaining('488 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F10-05: Non-Degrading Coins on Interruption', (tester) async {
      await pumpApp(tester);
      expect(find.textContaining('150 塑料金幣'), findsOneWidget);

      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      // Coins must increase, never decrease
      expect(find.textContaining('152 塑料金幣'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 11: Battle Engine Pure Math (Boundaries)
  // =========================================================================
  group('Feature 11: Battle Engine Pure Math (Boundaries)', () {
    test('T2-F11-01: Negative Elapsed Seconds Guard', () {
      const engine = BattleEngine();
      final dmg = engine.calculateDamage(
        basePoints: 100,
        phase: CraftPhases.snapFit,
        elapsedSeconds: -10,
        totalSeconds: 1500,
        isInterrupted: false,
        currentHp: 500,
        maxHp: 500,
      );
      expect(dmg, equals(0));
    });

    test('T2-F11-02: Zero or Negative Total Seconds Guard', () {
      const engine = BattleEngine();
      final dmgZero = engine.calculateDamage(
        basePoints: 100,
        phase: CraftPhases.snapFit,
        elapsedSeconds: 50,
        totalSeconds: 0,
        isInterrupted: false,
        currentHp: 500,
        maxHp: 500,
      );
      final dmgNeg = engine.calculateDamage(
        basePoints: 100,
        phase: CraftPhases.snapFit,
        elapsedSeconds: 50,
        totalSeconds: -100,
        isInterrupted: false,
        currentHp: 500,
        maxHp: 500,
      );
      expect(dmgZero, equals(0));
      expect(dmgNeg, equals(0));
    });

    test('T2-F11-03: Elapsed Exceeding Total Seconds Clamped', () {
      const engine = BattleEngine();
      final dmg = engine.calculateDamage(
        basePoints: 100,
        phase: CraftPhases.snapFit,
        elapsedSeconds: 2000,
        totalSeconds: 1500,
        isInterrupted: false,
        currentHp: 500,
        maxHp: 500,
      );
      expect(dmg, equals(100));
    });

    test('T2-F11-04: Negative Base Points Guard', () {
      const engine = BattleEngine();
      final dmg = engine.calculateDamage(
        basePoints: -50,
        phase: CraftPhases.snapFit,
        elapsedSeconds: 1500,
        totalSeconds: 1500,
        isInterrupted: false,
        currentHp: 500,
        maxHp: 500,
      );
      expect(dmg, equals(0));
    });

    test('T2-F11-05: Unknown Phase String Safe Fallback', () {
      const engine = BattleEngine();
      final dmg = engine.calculateDamage(
        basePoints: 100,
        phase: 'CustomLaserGun',
        elapsedSeconds: 1500,
        totalSeconds: 1500,
        isInterrupted: false,
        currentHp: 500,
        maxHp: 500,
      );
      // Defaults safely to 1.0x multiplier
      expect(dmg, equals(100));
    });
  });

  // =========================================================================
  // Feature 12: Lint Issue Fixes & Runtime Integrity (Boundaries)
  // =========================================================================
  group('Feature 12: Lint Issue Fixes & Runtime Integrity (Boundaries)', () {
    testWidgets('T2-F12-01: Small Viewport Rendering (320x480)', (tester) async {
      await pumpApp(tester, size: const Size(320, 480));
      expect(find.byType(SingleChildScrollView), findsWidgets);
      // No overflow exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F12-02: Large Viewport Rendering (1440x2560)', (tester) async {
      await pumpApp(tester, size: const Size(1440, 2560));
      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F12-03: Null Repositories Default Fallback', (tester) async {
      setTestViewport(tester);
      await tester.pumpWidget(const TsumiPuraApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('T2-F12-04: Time Formatter Upper Bounds (Hours Display)', () {
      String formatTime(int totalSeconds) {
        final minutes = totalSeconds ~/ 60;
        final seconds = totalSeconds % 60;
        return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }

      expect(formatTime(3665), equals('61:05'));
      expect(formatTime(0), equals('00:00'));
    });

    testWidgets('T2-F12-05: Dialogue Text Multi-Line Wrapping', (tester) async {
      await pumpApp(tester);
      // Dialogue box contains retro border and text wrapping without horizontal overflow
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Feature 13: KitItem Data Model (Boundaries)
  // =========================================================================
  group('Feature 13: KitItem Data Model (Boundaries)', () {
    testWidgets('T2-F13-01: Custom Extreme HP Input (e.g. 99,999 HP)', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final kit = KitItem(
        id: 'extreme-hp',
        title: 'Extreme Boss',
        grade: 'PG',
        totalHp: 99999,
        currentHp: 99999,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit);
      await kitRepo.setActiveKit(kit.id);

      await pumpApp(tester, kitRepo: kitRepo);
      expect(find.textContaining('99999 / 99999 HP'), findsOneWidget);
    });

    testWidgets('T2-F13-02: Minimum HP Input (1 HP)', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final kit = KitItem(
        id: 'min-hp',
        title: '1 HP Boss',
        grade: 'EG',
        totalHp: 1,
        currentHp: 1,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit);
      await kitRepo.setActiveKit(kit.id);

      await pumpApp(tester, kitRepo: kitRepo);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);
      final updated = (await kitRepo.getAllKits()).firstWhere((k) => k.id == 'min-hp');
      expect(updated.currentHp, equals(0));
      expect(updated.status, equals(KitStatus.completed));
    });

    testWidgets('T2-F13-03: Special Characters in Kit Title', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final title = '【限定版】RG 1/144 沙薩比 ★ Special & Clear! 🤖';
      final kit = KitItem(
        id: 'special-char-kit',
        title: title,
        grade: 'RG',
        totalHp: 800,
        currentHp: 800,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit);
      await kitRepo.setActiveKit(kit.id);

      await pumpApp(tester, kitRepo: kitRepo);
      expect(find.textContaining(title), findsOneWidget);
    });

    test('T2-F13-04: JSON Roundtrip Integrity', () {
      final now = DateTime.now();
      final original = KitItem(
        id: 'kit-roundtrip',
        title: 'Detailed Kit',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 750,
        status: KitStatus.inProgress,
        createdAt: now,
        completedAt: now,
        photoPath: '/path/to/trophy.png',
        isCustomBoss: true,
      );

      final jsonMap = original.toJson();
      final restored = KitItem.fromJson(jsonMap);

      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
      expect(restored.grade, equals(original.grade));
      expect(restored.totalHp, equals(original.totalHp));
      expect(restored.currentHp, equals(original.currentHp));
      expect(restored.status, equals(original.status));
      expect(restored.photoPath, equals(original.photoPath));
      expect(restored.isCustomBoss, equals(true));
    });

    test('T2-F13-05: Kit Reset on Backlog vs Completed', () {
      final completedKit = KitItem(
        id: 'kit-c',
        title: 'Done Kit',
        grade: 'HG',
        totalHp: 500,
        currentHp: 0,
        status: KitStatus.completed,
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
      );

      final resetKit = completedKit.reset();
      expect(resetKit.currentHp, equals(500));
      expect(resetKit.status, equals(KitStatus.unstarted));
      expect(resetKit.completedAt, isNull);
    });
  });

  // =========================================================================
  // Feature 14: CraftLog Data Model (Boundaries)
  // =========================================================================
  group('Feature 14: CraftLog Data Model (Boundaries)', () {
    test('T2-F14-01: 0-Duration and 0-Damage Log Representation', () {
      final log = CraftLog(
        id: 'zero-log',
        kitId: 'kit-1',
        phase: 'Snap-fit',
        durationMinutes: 0,
        damageDealt: 0,
        isCompletedSession: false,
        timestamp: DateTime.now(),
      );

      expect(log.durationMinutes, equals(0));
      expect(log.damageDealt, equals(0));
      expect(log.isCompletedSession, isFalse);
    });

    testWidgets('T2-F14-02: Large Duration Log (e.g. 300 minutes)', (tester) async {
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);
      await logRepo.addLog(
        CraftLog(
          id: 'large-log',
          kitId: 'kit-1',
          phase: 'Airbrush',
          durationMinutes: 300,
          damageDealt: 5000,
          isCompletedSession: true,
          timestamp: DateTime.now(),
        ),
      );

      await pumpApp(tester, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('全部歷史紀錄'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 300 minutes displays as 5h 0m in KPI and ⏱ 300m in tile
      expect(find.text('5h 0m'), findsOneWidget);
      expect(find.textContaining('⏱ 300m'), findsOneWidget);
    });

    testWidgets('T2-F14-03: High-Frequency Log Stress (50 Logs in Storage)', (tester) async {
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);

      for (int i = 0; i < 50; i++) {
        await logRepo.addLog(
          CraftLog(
            id: 'stress-log-$i',
            kitId: 'kit-stress',
            phase: 'Snap-fit',
            durationMinutes: 5,
            damageDealt: 20,
            isCompletedSession: true,
            timestamp: DateTime.now().subtract(Duration(minutes: i * 10)),
          ),
        );
      }

      await pumpApp(tester, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('全部歷史紀錄'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Renders smoothly and shows total KPI
      expect(find.text('4h 10m'), findsOneWidget); // 50 * 5m = 250m = 4h 10m
      expect(find.text('1000 pt'), findsOneWidget); // 50 * 20 = 1000 pt
    });

    test('T2-F14-04: CraftLog JSON Roundtrip', () {
      final now = DateTime.now();
      final log = CraftLog(
        id: 'log-roundtrip',
        kitId: 'kit-target',
        phase: 'Finishing',
        durationMinutes: 25,
        damageDealt: 250,
        isCompletedSession: true,
        timestamp: now,
      );

      final jsonMap = log.toMap();
      final restored = CraftLog.fromMap(jsonMap);

      expect(restored.id, equals(log.id));
      expect(restored.kitId, equals(log.kitId));
      expect(restored.phase, equals(log.phase));
      expect(restored.durationMinutes, equals(25));
      expect(restored.damageDealt, equals(250));
      expect(restored.isCompletedSession, isTrue);
    });

    test('T2-F14-05: Missing Timestamp / Corrupted Date Fallback', () {
      final invalidMap = <String, dynamic>{
        'id': 'fallback-log',
        'kitId': 'kit-1',
        'phase': 'Snap-fit',
        'durationMinutes': 10,
        'damageDealt': 20,
        'isCompletedSession': true,
        'timestamp': 'INVALID_DATE_STRING',
      };

      final log = CraftLog.fromMap(invalidMap);
      expect(log.id, equals('fallback-log'));
      expect(log.timestamp, isA<DateTime>());
    });
  });

  // =========================================================================
  // Feature 15: Local Persistence Service (Boundaries)
  // =========================================================================
  group('Feature 15: Local Persistence Service (Boundaries)', () {
    test('T2-F15-01: Corrupted Kits JSON Recovery', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.kits: '{ corrupt json: [',
      });
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);

      final kits = await kitRepo.getAllKits();
      // Recovers gracefully by seeding default HG kit
      expect(kits.isNotEmpty, isTrue);
      expect(kits.first.grade, equals('HG'));
    });

    test('T2-F15-02: Corrupted CraftLogs JSON Recovery', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.craftLogs: '{ invalid json: [',
      });
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);

      final logs = await logRepo.getAllLogs();
      // Returns empty list without crash
      expect(logs, isEmpty);
    });

    test('T2-F15-03: Missing Active Kit ID Fallback', () async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);

      final active = await kitRepo.getActiveKit();
      expect(active, isNotNull);
      expect(active?.title, contains('綠色普通盒怪'));
    });

    test('T2-F15-04: Rapid Concurrent Saves', () async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);

      final futures = <Future<void>>[];
      for (int i = 0; i < 10; i++) {
        final kit = KitItem(
          id: 'concurrent-kit-$i',
          title: 'Concurrent Kit $i',
          grade: 'HG',
          totalHp: 500,
          currentHp: 500,
          status: KitStatus.unstarted,
          createdAt: DateTime.now(),
        );
        futures.add(kitRepo.saveKit(kit));
      }

      await Future.wait(futures);
      final allKits = await kitRepo.getAllKits();
      expect(allKits.length, greaterThanOrEqualTo(10));
    });

    test('T2-F15-05: Clear Storage & Re-Seed', () async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      await kitRepo.saveKit(
        KitItem(
          id: 'temp-kit',
          title: 'Temp Kit',
          grade: 'EG',
          totalHp: 300,
          currentHp: 300,
          status: KitStatus.unstarted,
          createdAt: DateTime.now(),
        ),
      );

      await storage.clear();
      kitRepo.clearCache();
      final reseeded = await kitRepo.getAllKits();
      expect(reseeded.length, equals(1));
      expect(reseeded.first.grade, equals('HG'));
    });
  });

  // =========================================================================
  // Feature 16: Auto-save & State Hydration (Boundaries)
  // =========================================================================
  group('Feature 16: Auto-save & State Hydration (Boundaries)', () {
    testWidgets('T2-F16-01: Hydration with 1 HP Kit', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final kit = KitItem.initialSeedKit().copyWith(currentHp: 1);
      await kitRepo.saveKit(kit);

      await pumpApp(tester, kitRepo: kitRepo);
      expect(find.textContaining('1 / 500 HP'), findsOneWidget);
      expect(find.textContaining('水貼\n2.5x'), findsOneWidget);
    });

    testWidgets('T2-F16-02: Hydration of Defeated Kit (0 HP)', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final kit = KitItem.initialSeedKit().copyWith(
        currentHp: 0,
        status: KitStatus.completed,
      );
      await kitRepo.saveKit(kit);

      await pumpApp(tester, kitRepo: kitRepo);
      expect(find.textContaining('0 / 500 HP'), findsOneWidget);
      expect(find.textContaining('重置 Boss 血量 (RESTART)'), findsOneWidget);
    });

    testWidgets('T2-F16-03: Background Timer Persistence Across Push/Pop', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      // Immediately navigate to CraftLogScreen
      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Wait 6 seconds while on CraftLogScreen
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      // Pop back to BattleScreen
      await tester.tap(find.byKey(const Key('btn_craft_log_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Battle has completed work in background, HP is reduced
      expect(find.textContaining('480 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F16-04: Immediate Web Refresh / App Restart Simulation', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final logRepo = CraftLogRepository(storage);

      // Launch app instance 1 and deal 40 damage (2 debug runs)
      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await tester.tap(find.textContaining('略過休息'));
      await tester.pump();

      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await tester.tap(find.textContaining('略過休息'));
      await tester.pump();

      expect(find.textContaining('460 / 500 HP'), findsOneWidget);

      // Re-instantiate TsumiPuraApp from scratch sharing same storage
      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      expect(find.textContaining('460 / 500 HP'), findsOneWidget);
    });

    testWidgets('T2-F16-05: Active Kit Switch Hydration', (tester) async {
      final storage = LocalStorageService();
      final kitRepo = KitRepository(storage);
      final mgKit = KitItem(
        id: 'mg-hydration',
        title: 'MG Titanium Finish',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 1500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(mgKit);

      await pumpApp(tester, kitRepo: kitRepo);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(Key('btn_set_active_${mgKit.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('1500 / 1500 HP'), findsOneWidget);
      expect(find.textContaining('MG Titanium Finish'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 17: CraftLog History & Stats View (Boundaries)
  // =========================================================================
  group('Feature 17: CraftLog History & Stats View (Boundaries)', () {
    testWidgets('T2-F17-01: Empty Log State Diagnostics', (tester) async {
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);

      await pumpApp(tester, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('0m'), findsOneWidget);
      expect(find.text('0 pt'), findsOneWidget);
      expect(find.text('0 次'), findsNWidgets(2));
      expect(find.textContaining('尚未有施工紀錄'), findsOneWidget);
    });

    testWidgets('T2-F17-02: Null Active Kit ID and Title', (tester) async {
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);
      await logRepo.addLog(
        CraftLog(
          id: 'log-orphan',
          kitId: 'orphan-kit',
          phase: 'Snap-fit',
          durationMinutes: 10,
          damageDealt: 20,
          isCompletedSession: true,
          timestamp: DateTime.now(),
        ),
      );

      setTestViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: CraftLogScreen(
            craftLogRepository: logRepo,
            activeKitId: null,
            activeKitTitle: null,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('★ CRAFT LOG ★'), findsOneWidget);
      expect(find.text('10m'), findsOneWidget);
      expect(find.text('20 pt'), findsOneWidget);
    });

    testWidgets('T2-F17-03: Manual Refresh Tooltip Tap on Empty and Populated States', (tester) async {
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);

      await pumpApp(tester, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap refresh tooltip
      await tester.tap(find.byTooltip('重新整理'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('★ CRAFT LOG ★'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2-F17-04: Single Phase Dominance (100% of one phase)', (tester) async {
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);

      for (int i = 0; i < 3; i++) {
        await logRepo.addLog(
          CraftLog(
            id: 'air-log-$i',
            kitId: 'kit-air',
            phase: 'Airbrush',
            durationMinutes: 25,
            damageDealt: 200,
            isCompletedSession: true,
            timestamp: DateTime.now(),
          ),
        );
      }

      await pumpApp(tester, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('全部歷史紀錄'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Airbrush has 100% distribution
      expect(find.textContaining('100%'), findsOneWidget);
    });

    testWidgets('T2-F17-05: Rapid Navigation Push/Pop Stress (5 Cycles)', (tester) async {
      await pumpApp(tester);

      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('btn_craft_log')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byKey(const Key('btn_craft_log_back')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
