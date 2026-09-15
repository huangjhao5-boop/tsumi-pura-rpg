import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nifty_heisenberg/core/audio/retro_audio_service.dart';
import 'package:nifty_heisenberg/core/constants/game_constants.dart';
import 'package:nifty_heisenberg/data/repositories/craft_log_repository.dart';
import 'package:nifty_heisenberg/data/repositories/kit_repository.dart';
import 'package:nifty_heisenberg/data/storage/local_storage_service.dart';
import 'package:nifty_heisenberg/data/storage/storage_keys.dart';
import 'package:nifty_heisenberg/domain/models/craft_log.dart';
import 'package:nifty_heisenberg/domain/models/kit_item.dart';
import 'package:nifty_heisenberg/main.dart';
import 'package:nifty_heisenberg/presentation/widgets/pixel_hp_bar.dart';
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

  void setTestViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    KitRepository? kitRepo,
    CraftLogRepository? logRepo,
    MockRetroAudioService? mockAudio,
  }) async {
    setTestViewport(tester);
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
  // Feature 1: Pomodoro 25m/5m Timer (Standard Mode)
  // =========================================================================
  group('Feature 1: Pomodoro 25m/5m Timer (Standard Mode)', () {
    testWidgets('T1-F01-01: Mode Selection & HUD Label', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();

      expect(find.textContaining('開始開工 (標準 25m/5m)'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('POMODORO WORKBENCH CLOCK'), findsOneWidget);
    });

    testWidgets('T1-F01-02: Work Phase Initiation', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      expect(find.textContaining('WORK - 專注組裝中 (標準 25m/5m)'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget);
      expect(find.textContaining('中途中斷'), findsOneWidget);
    });

    testWidgets('T1-F01-03: Real-Time Timer Decrement', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 10));
      expect(find.text('24:50'), findsOneWidget);
      expect(find.textContaining('WORK - 專注組裝中'), findsOneWidget);
    });

    testWidgets('T1-F01-04: Full Work Completion & Rest Phase Transition', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      // Advance full 1500s work session + 1 completion tick
      await tester.pump(const Duration(seconds: 1500));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('400 / 500 HP'), findsOneWidget);
      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);
      expect(find.textContaining('略過休息 (提前開工)'), findsOneWidget);
    });

    testWidgets('T1-F01-05: Rest Early Skip to Idle', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1500));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('略過休息'), findsOneWidget);
      await tester.tap(find.textContaining('略過休息'));
      await tester.pump();

      expect(find.text('POMODORO WORKBENCH CLOCK'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.textContaining('已略過休息，隨時可再次開工討伐！'), findsOneWidget);
      expect(find.textContaining('開始開工'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 2: Pomodoro 50m/10m Timer (Deep Focus Mode)
  // =========================================================================
  group('Feature 2: Pomodoro 50m/10m Timer (Deep Focus Mode)', () {
    testWidgets('T2-F02-01: Deep Focus Mode Selection', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('深度 50m/10m'));
      await tester.pump();

      expect(find.textContaining('開始開工 (深度 50m/10m)'), findsOneWidget);
    });

    testWidgets('T2-F02-02: Deep Focus Work Start', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('深度 50m/10m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      expect(find.textContaining('WORK - 專注組裝中 (深度 50m/10m)'), findsOneWidget);
      expect(find.text('50:00'), findsOneWidget);
    });

    testWidgets('T2-F02-03: Clock Decrement at 1 Minute Interval', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('深度 50m/10m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 60));
      expect(find.text('49:00'), findsOneWidget);
      expect(find.textContaining('WORK - 專注組裝中'), findsOneWidget);
    });

    testWidgets('T2-F02-04: Deep Focus Full Session 220 Base Points Damage', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('深度 50m/10m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      // 3000 seconds work + 1 completion tick
      await tester.pump(const Duration(seconds: 3000));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));

      // 500 - 220 = 280 HP
      expect(find.textContaining('280 / 500 HP'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);
    });

    testWidgets('T2-F02-05: Deep Focus Rest Skip & State Cleanliness', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('深度 50m/10m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 3000));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.textContaining('略過休息'));
      await tester.pump();

      expect(find.text('POMODORO WORKBENCH CLOCK'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.textContaining('280 / 500 HP'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 3: Fast Debug Mode (5s Timer)
  // =========================================================================
  group('Feature 3: Fast Debug Mode (5s Timer)', () {
    testWidgets('T1-F03-01: Quick 5秒測試 Button Tap', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      expect(find.textContaining('WORK - 專注組裝中 (除錯 5s/3s)'), findsOneWidget);
      expect(find.text('00:05'), findsOneWidget);
    });

    testWidgets('T1-F03-02: Segmented Mode Selector Debug Mode', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('除錯 5s/3s'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      expect(find.text('00:05'), findsOneWidget);
      expect(find.textContaining('WORK - 專注組裝中 (除錯 5s/3s)'), findsOneWidget);
    });

    testWidgets('T1-F03-03: Exact Countdown from 5 to 0', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      for (int i = 5; i > 0; i--) {
        expect(find.text('00:0$i'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('T1-F03-04: Debug Completion & 3s Rest Phase', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);
      expect(find.text('00:03'), findsOneWidget);
      expect(find.textContaining('480 / 500 HP'), findsOneWidget);
    });

    testWidgets('T1-F03-05: Debug Rest Auto-Completion to Idle', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      // 5s work + 1s completion
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);

      // 3s rest + 1s completion
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('POMODORO WORKBENCH CLOCK'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.textContaining('✨ 休息完畢！精力充沛'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 4: Snap-fit Multiplier (1.0x)
  // =========================================================================
  group('Feature 4: Snap-fit Multiplier (1.0x)', () {
    testWidgets('T1-F04-01: Default Craft Phase Selection', (tester) async {
      await pumpApp(tester);
      expect(find.textContaining('素組'), findsOneWidget);
      expect(find.textContaining('工作桌前一切就緒'), findsOneWidget);
    });

    testWidgets('T1-F04-02: Snap-fit Switching Dialogue', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('打磨'));
      await tester.pump();
      expect(find.textContaining('【破甲打磨】'), findsOneWidget);

      await tester.tap(find.textContaining('素組'));
      await tester.pump();
      expect(find.textContaining('已切換武器：【剪鉗連擊】(1.0x 倍率)'), findsOneWidget);
    });

    testWidgets('T1-F04-03: Debug Mode Damage Math (20 BP * 1.0 = 20)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('480 / 500 HP'), findsOneWidget);
      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);
    });

    testWidgets('T1-F04-04: Standard Mode Damage Math (100 BP * 1.0 = 100)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1500));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('400 / 500 HP'), findsOneWidget);
      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);
    });

    testWidgets('T1-F04-05: CraftLog Entry for Snap-fit', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('★ CRAFT LOG ★'), findsOneWidget);
      expect(find.textContaining('Snap-fit'), findsWidgets);
      expect(find.textContaining('💥 -20 HP'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 5: Sanding Multiplier (1.2x)
  // =========================================================================
  group('Feature 5: Sanding Multiplier (1.2x)', () {
    testWidgets('T1-F05-01: Select Sanding Phase', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('打磨'));
      await tester.pump();
      expect(find.textContaining('已切換武器：【破甲打磨】(1.2x 倍率)'), findsOneWidget);
    });

    testWidgets('T1-F05-02: Debug Mode Sanding Damage (20 * 1.2 = 24)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('打磨'));
      await tester.pump();

      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('476 / 500 HP'), findsOneWidget);
      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);
    });

    testWidgets('T1-F05-03: Standard Mode Sanding Damage (100 * 1.2 = 120)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('打磨'));
      await tester.pump();

      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1500));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('380 / 500 HP'), findsOneWidget);
      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);
    });

    testWidgets('T1-F05-04: Deep Focus Sanding Damage (220 * 1.2 = 264)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('打磨'));
      await tester.pump();

      await tester.tap(find.text('深度 50m/10m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 3000));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('236 / 500 HP'), findsOneWidget);
      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);
    });

    testWidgets('T1-F05-05: CraftLog Sanding Breakdown & Entry', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.textContaining('打磨'));
      await tester.pump();

      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Sanding'), findsWidgets);
      expect(find.textContaining('💥 -24 HP'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 6: Detailing Multiplier (1.5x)
  // =========================================================================
  group('Feature 6: Detailing Multiplier (1.5x)', () {
    testWidgets('T1-F06-01: Select Detailing Phase', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('刻線'));
      await tester.pump();
      expect(find.textContaining('已切換武器：【弱點刻線】(1.5x 倍率)'), findsOneWidget);
    });

    testWidgets('T1-F06-02: Debug Mode Detailing Damage (20 * 1.5 = 30)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('刻線'));
      await tester.pump();

      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('470 / 500 HP'), findsOneWidget);
      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);
    });

    testWidgets('T1-F06-03: Standard Mode Detailing Damage (100 * 1.5 = 150)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('刻線'));
      await tester.pump();

      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1500));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('350 / 500 HP'), findsOneWidget);
      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);
    });

    testWidgets('T1-F06-04: Floating Damage Feedback', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('刻線'));
      await tester.pump();

      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('CRITICAL! -30'), findsOneWidget);
    });

    testWidgets('T1-F06-05: CraftLog Detailing Verification', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.textContaining('刻線'));
      await tester.pump();

      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Detailing'), findsWidgets);
      expect(find.textContaining('💥 -30 HP'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 7: Airbrush Multiplier (2.0x)
  // =========================================================================
  group('Feature 7: Airbrush Multiplier (2.0x)', () {
    testWidgets('T1-F07-01: Select Airbrush Phase', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('噴塗'));
      await tester.pump();
      expect(find.textContaining('已切換武器：【噴筆重砲】(2.0x 倍率)'), findsOneWidget);
    });

    testWidgets('T1-F07-02: Debug Mode Airbrush Damage (20 * 2.0 = 40)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('噴塗'));
      await tester.pump();

      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('460 / 500 HP'), findsOneWidget);
      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);
    });

    testWidgets('T1-F07-03: Standard Mode Airbrush Damage (100 * 2.0 = 200)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('噴塗'));
      await tester.pump();

      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 1500));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('300 / 500 HP'), findsOneWidget);
      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);
    });

    testWidgets('T1-F07-04: Deep Focus Airbrush Damage (220 * 2.0 = 440)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('噴塗'));
      await tester.pump();

      await tester.tap(find.text('深度 50m/10m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 3000));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));

      // 500 - 440 = 60 HP (12% <= 20%)
      expect(find.textContaining('60 / 500 HP'), findsOneWidget);
      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);
    });

    testWidgets('T1-F07-05: Action Log Display During Combat', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('噴塗'));
      await tester.pump();

      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      expect(find.textContaining('⚔️ 開工中：噴筆重砲！時間滴答倒數...'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 8: Finishing Multiplier (2.5x)
  // =========================================================================
  group('Feature 8: Finishing Multiplier (2.5x)', () {
    testWidgets('T1-F08-01: Finishing Unlocked Label at <= 20% HP', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final lowHpKit = KitItem(
        id: 'low-hp-1',
        title: '殘血盒怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 100, // 20%
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(lowHpKit);
      await kitRepo.setActiveKit(lowHpKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      expect(find.text('水貼\n2.5x'), findsOneWidget);
    });

    testWidgets('T1-F08-02: Select Finishing Phase', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final lowHpKit = KitItem(
        id: 'low-hp-2',
        title: '殘血盒怪2',
        grade: 'HG',
        totalHp: 500,
        currentHp: 100,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(lowHpKit);
      await kitRepo.setActiveKit(lowHpKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('水貼\n2.5x'));
      await tester.pump();

      expect(find.textContaining('已切換武器：【處決水貼 (水貼・仕上げ)】(2.5x 倍率)'), findsOneWidget);
    });

    testWidgets('T1-F08-03: Debug Mode Finishing Damage (20 * 2.5 = 50)', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final lowHpKit = KitItem(
        id: 'low-hp-3',
        title: '殘血盒怪3',
        grade: 'HG',
        totalHp: 500,
        currentHp: 100,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(lowHpKit);
      await kitRepo.setActiveKit(lowHpKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('水貼\n2.5x'));
      await tester.pump();

      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('50 / 500 HP'), findsOneWidget);
      expect(find.textContaining('REST - 工坊整備休息中 ☕'), findsOneWidget);
    });

    testWidgets('T1-F08-04: Lethal Finishing Strike Triggers Quest Clear', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final lowHpKit = KitItem(
        id: 'low-hp-4',
        title: '瀕死盒怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 50,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(lowHpKit);
      await kitRepo.setActiveKit(lowHpKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('水貼\n2.5x'));
      await tester.pump();

      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.textContaining('0 / 500 HP'), findsOneWidget);
      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);
    });

    testWidgets('T1-F08-05: CraftLog Finishing Record', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final lowHpKit = KitItem(
        id: 'low-hp-5',
        title: '殘血盒怪5',
        grade: 'HG',
        totalHp: 500,
        currentHp: 100,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(lowHpKit);
      await kitRepo.setActiveKit(lowHpKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('水貼\n2.5x'));
      await tester.pump();

      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Finishing'), findsWidgets);
      expect(find.textContaining('💥 -50 HP'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 9: Finishing Execution Gate
  // =========================================================================
  group('Feature 9: Finishing Execution Gate', () {
    testWidgets('T1-F09-01: Locked State at > 20% HP', (tester) async {
      await pumpApp(tester);
      expect(find.text('水貼\n🔒20%'), findsOneWidget);
    });

    testWidgets('T1-F09-02: Locked Gate Rejects Selection at > 20% HP', (tester) async {
      await pumpApp(tester);
      expect(find.text('水貼\n🔒20%'), findsOneWidget);
      await tester.tap(find.text('水貼\n🔒20%'));
      await tester.pump();

      expect(find.text('水貼\n🔒20%'), findsOneWidget);
      expect(find.textContaining('開始開工 (標準 25m/5m)'), findsOneWidget);
    });

    testWidgets('T1-F09-03: Dynamic Unlock when HP reaches <= 20%', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kit = KitItem(
        id: 'gate-dynamic-1',
        title: '門檻測試怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 120, // 24% > 20%
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit);
      await kitRepo.setActiveKit(kit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      expect(find.text('水貼\n🔒20%'), findsOneWidget);

      // Deal 24 damage via Sanding debug session -> 120 - 24 = 96 HP (19.2% <= 20%)
      await tester.tap(find.textContaining('打磨'));
      await tester.pump();
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.textContaining('略過休息'));
      await tester.pump();

      expect(find.text('水貼\n2.5x'), findsOneWidget);
    });

    testWidgets('T1-F09-04: Threshold Exact 20% Unlocked', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kit = KitItem(
        id: 'gate-exact-20',
        title: '精確20%怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 100, // exactly 20.0%
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit);
      await kitRepo.setActiveKit(kit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      expect(find.text('水貼\n2.5x'), findsOneWidget);
    });

    testWidgets('T1-F09-05: Lock Re-enforced on Boss Restart', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kit = KitItem(
        id: 'gate-restart-1',
        title: '已擊敗怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 0,
        status: KitStatus.completed,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit);
      await kitRepo.setActiveKit(kit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      expect(find.textContaining('重置 Boss 血量 (RESTART)'), findsOneWidget);

      await tester.tap(find.textContaining('重置 Boss 血量'));
      await tester.pump();

      expect(find.text('水貼\n🔒20%'), findsOneWidget);
      expect(find.textContaining('500 / 500 HP'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 10: Mercy Rule Damage Floor (Interruption Settlement)
  // =========================================================================
  group('Feature 10: Mercy Rule Damage Floor', () {
    testWidgets('T1-F10-01: Mid-Session Interruption Button Present and Active', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      final interruptBtn = find.textContaining('中途中斷');
      expect(interruptBtn, findsOneWidget);
    });

    testWidgets('T1-F10-02: Standard Mode 50% Interruption Math (100 * 0.5 * 1.0 * 0.5 = 25)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      // Advance 750 seconds (50% progress)
      await tester.pump(const Duration(seconds: 750));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('475 / 500 HP'), findsOneWidget);
      expect(find.textContaining('觸發 Mercy 保底防護，結算 50% 造成 25 點傷害'), findsOneWidget);
    });

    testWidgets('T1-F10-03: Visual Mercy Feedback Text Appears', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 750));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      expect(find.textContaining('-25 (MERCY 50%)'), findsWidgets);
    });

    testWidgets('T1-F10-04: Idle State Cleanly Restored After Interruption', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      expect(find.text('POMODORO WORKBENCH CLOCK'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.textContaining('開始開工'), findsOneWidget);
    });

    testWidgets('T1-F10-05: CraftLog Records Interrupted Session', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 750));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('💥 -25 HP'), findsOneWidget);
      expect(find.textContaining('中斷 50%'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 11: Battle Engine Pure Math Integration
  // =========================================================================
  group('Feature 11: Battle Engine Pure Math Integration', () {
    testWidgets('T1-F11-01: Multi-Turn Cumulative HP Subtraction Accuracy', (tester) async {
      await pumpApp(tester);

      // Snap-fit (20 dmg)
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.textContaining('略過休息'));
      await tester.pump();

      // Sanding (24 dmg)
      await tester.tap(find.textContaining('打磨'));
      await tester.pump();
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.textContaining('略過休息'));
      await tester.pump();

      // Detailing (30 dmg)
      await tester.tap(find.textContaining('刻線'));
      await tester.pump();
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.textContaining('略過休息'));
      await tester.pump();

      // Airbrush (40 dmg)
      await tester.tap(find.textContaining('噴塗'));
      await tester.pump();
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.textContaining('略過休息'));
      await tester.pump();

      // 500 - 20 - 24 - 30 - 40 = 386 HP
      expect(find.textContaining('386 / 500 HP'), findsOneWidget);
    });

    testWidgets('T1-F11-02: Clamped HP at Zero upon Overkill', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kit = KitItem(
        id: 'math-overkill-1',
        title: '瀕死怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 15,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit);
      await kitRepo.setActiveKit(kit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      // Snap-fit deals 20 damage on 15 HP
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.textContaining('0 / 500 HP'), findsOneWidget);
    });

    testWidgets('T1-F11-03: Integer Rounding in UI Dialogue', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.textContaining('刻線'));
      await tester.pump();

      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      // 750s: 100 * 0.5 * 1.5 * 0.5 = 37.5 -> 38
      await tester.pump(const Duration(seconds: 750));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();

      expect(find.textContaining('造成 38 點傷害'), findsOneWidget);
    });

    testWidgets('T1-F11-04: Recycled Plastic Coin Calculation', (tester) async {
      await pumpApp(tester);
      expect(find.text('150 塑料金幣'), findsOneWidget);

      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));

      // (5/5).round().clamp(2, 50) = 2 -> 150 + 2 = 152
      expect(find.text('152 塑料金幣'), findsOneWidget);
    });

    testWidgets('T1-F11-05: Boss HP Percentage Bar Visual Width', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kit = KitItem(
        id: 'bar-half-hp',
        title: '半血怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 250, // 50%
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit);
      await kitRepo.setActiveKit(kit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      expect(find.textContaining('250 / 500 HP'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.byType(PixelHpBar), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 12: Lint Issue Fixes & Runtime Integrity
  // =========================================================================
  group('Feature 12: Lint Issue Fixes & Runtime Integrity', () {
    testWidgets('T1-F12-01: Clean App Bootstrap Without Assertion Failure', (tester) async {
      await pumpApp(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
    });

    testWidgets('T1-F12-02: Clean Route Transition Cycle', (tester) async {
      await pumpApp(tester);

      // Open Hangar -> Back
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('★ MODEL HANGAR ★'), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Open Showcase -> Back
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('★ SHOWCASE GALLERY ★'), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_showcase_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Open CraftLog -> Back
      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('★ CRAFT LOG ★'), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_craft_log_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
    });

    testWidgets('T1-F12-03: Audio Service Safe Invocation in Test Environment', (tester) async {
      final mockAudio = MockRetroAudioService();
      await pumpApp(tester, mockAudio: mockAudio);

      await tester.tap(find.byKey(const Key('btn_mute_toggle')));
      await tester.pump();
      expect(mockAudio.isMuted, isTrue);

      await tester.tap(find.byKey(const Key('btn_mute_toggle')));
      await tester.pump();
      expect(mockAudio.isMuted, isFalse);
    });

    testWidgets('T1-F12-04: Ticker and Controller Clean Disposal', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      // Dispose while timer is active
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('T1-F12-05: Missing Asset Fallback Render', (tester) async {
      await pumpApp(tester);
      expect(find.byType(Image), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Feature 13: KitItem Data Model Persistence
  // =========================================================================
  group('Feature 13: KitItem Data Model Persistence', () {
    testWidgets('T1-F13-01: Auto-Seeded Default Kit on Clean Start', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      final activeKit = await kitRepo.getActiveKit();
      expect(activeKit, isNotNull);
      expect(activeKit!.title, equals('綠色普通盒怪'));
      expect(activeKit.grade, equals('HG'));
      expect(activeKit.totalHp, equals(500));
      expect(activeKit.currentHp, equals(500));
    });

    testWidgets('T1-F13-02: Status Progression from Unstarted to InProgress', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));

      final activeKit = await kitRepo.getActiveKit();
      expect(activeKit!.status, equals(KitStatus.inProgress));
      expect(activeKit.currentHp, equals(480));
    });

    testWidgets('T1-F13-03: Status Progression to Completed on Lethal Hit', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kit = KitItem(
        id: 'kit-lethal-hit',
        title: '最後一擊盒怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 20,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit);
      await kitRepo.setActiveKit(kit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 800));

      final savedKit = (await kitRepo.getAllKits()).firstWhere((k) => k.id == 'kit-lethal-hit');
      expect(savedKit.status, equals(KitStatus.completed));
      expect(savedKit.completedAt, isNotNull);
      expect(savedKit.currentHp, equals(0));
    });

    testWidgets('T1-F13-04: Kit Reset Restores Full HP and Clears CompletedAt', (tester) async {
      final kit = KitItem(
        id: 'reset-test-kit',
        title: '已完成模型',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 0,
        status: KitStatus.completed,
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
      );

      final resetKit = kit.reset();
      expect(resetKit.currentHp, equals(1500));
      expect(resetKit.totalHp, equals(1500));
      expect(resetKit.status, equals(KitStatus.unstarted));
      expect(resetKit.completedAt, isNull);
    });

    testWidgets('T1-F13-05: Grade Presets Matching SPEC §3', (tester) async {
      expect(GameConstants.gradeHpDefaults['EG'], equals(300));
      expect(GameConstants.gradeHpDefaults['HG'], equals(500));
      expect(GameConstants.gradeHpDefaults['RG'], equals(800));
      expect(GameConstants.gradeHpDefaults['MG'], equals(1500));
      expect(GameConstants.gradeHpDefaults['PG'], equals(5000));
    });
  });

  // =========================================================================
  // Feature 14: CraftLog Data Model Persistence
  // =========================================================================
  group('Feature 14: CraftLog Data Model Persistence', () {
    testWidgets('T1-F14-01: Complete Session Generates Valid CraftLog', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));

      final logs = await logRepo.getAllLogs();
      expect(logs.length, equals(1));
      final log = logs.first;
      expect(log.id, isNotEmpty);
      expect(log.phase, equals(CraftPhases.snapFit));
      expect(log.damageDealt, equals(20));
      expect(log.isCompletedSession, isTrue);
    });

    testWidgets('T1-F14-02: Interrupted Session Generates Interrupted CraftLog', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final logs = await logRepo.getAllLogs();
      expect(logs.length, equals(1));
      final log = logs.first;
      expect(log.isCompletedSession, isFalse);
      expect(log.damageDealt, greaterThan(0));
    });

    testWidgets('T1-F14-03: Duration Minute Normalization', (tester) async {
      final log1 = CraftLog(
        id: 'log-norm-1',
        kitId: 'k1',
        phase: 'Snap-fit',
        durationMinutes: 1, // Sub-minute maps to 1 for display
        damageDealt: 20,
        isCompletedSession: true,
        timestamp: DateTime.now(),
      );
      expect(log1.durationMinutes, equals(1));

      final log2 = CraftLog(
        id: 'log-norm-2',
        kitId: 'k1',
        phase: 'Snap-fit',
        durationMinutes: 25,
        damageDealt: 100,
        isCompletedSession: true,
        timestamp: DateTime.now(),
      );
      expect(log2.durationMinutes, equals(25));
    });

    testWidgets('T1-F14-04: Log Ordering (Newest First)', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);

      final earlier = DateTime.now().subtract(const Duration(minutes: 10));
      final later = DateTime.now();

      await logRepo.addLog(CraftLog(
        id: 'earlier-log',
        kitId: 'kit-order',
        phase: 'Snap-fit',
        durationMinutes: 5,
        damageDealt: 20,
        isCompletedSession: true,
        timestamp: earlier,
      ));

      await logRepo.addLog(CraftLog(
        id: 'later-log',
        kitId: 'kit-order',
        phase: 'Sanding',
        durationMinutes: 5,
        damageDealt: 24,
        isCompletedSession: true,
        timestamp: later,
      ));

      final logs = await logRepo.getLogsForKit('kit-order');
      expect(logs.first.id, equals('later-log'));
      expect(logs.last.id, equals('earlier-log'));
    });

    testWidgets('T1-F14-05: CraftLog Referential Link to Kit', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);

      await logRepo.addLog(CraftLog(
        id: 'log-k1',
        kitId: 'kit-target-1',
        phase: 'Snap-fit',
        durationMinutes: 5,
        damageDealt: 20,
        isCompletedSession: true,
        timestamp: DateTime.now(),
      ));

      await logRepo.addLog(CraftLog(
        id: 'log-k2',
        kitId: 'kit-target-2',
        phase: 'Sanding',
        durationMinutes: 5,
        damageDealt: 24,
        isCompletedSession: true,
        timestamp: DateTime.now(),
      ));

      final logsK1 = await logRepo.getLogsForKit('kit-target-1');
      expect(logsK1.length, equals(1));
      expect(logsK1.first.id, equals('log-k1'));

      final logsK2 = await logRepo.getLogsForKit('kit-target-2');
      expect(logsK2.length, equals(1));
      expect(logsK2.first.id, equals('log-k2'));
    });
  });

  // =========================================================================
  // Feature 15: Local Persistence Service
  // =========================================================================
  group('Feature 15: Local Persistence Service', () {
    testWidgets('T1-F15-01: SharedPreferences JSON Storage Format', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kit = KitItem.initialSeedKit();
      await storage.setJsonList(StorageKeys.kits, [kit.toMap()]);

      final rawJson = prefs.getString(StorageKeys.kits);
      expect(rawJson, isNotNull);
      final decoded = jsonDecode(rawJson!) as List;
      expect(decoded.first['id'], equals(kit.id));
    });

    testWidgets('T1-F15-02: Active Kit ID Persistence', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      await storage.setString(StorageKeys.activeKitId, 'kit-active-123');

      final activeId = await storage.getString(StorageKeys.activeKitId);
      expect(activeId, equals('kit-active-123'));
      expect(prefs.getString(StorageKeys.activeKitId), equals('kit-active-123'));
    });

    testWidgets('T1-F15-03: CraftLog JSON Storage Format', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final log = CraftLog(
        id: 'log-json-format',
        kitId: 'kit-fmt',
        phase: 'Snap-fit',
        durationMinutes: 10,
        damageDealt: 50,
        isCompletedSession: true,
        timestamp: DateTime.now(),
      );
      await storage.setJsonList(StorageKeys.craftLogs, [log.toMap()]);

      final rawJson = prefs.getString(StorageKeys.craftLogs);
      expect(rawJson, isNotNull);
      final decoded = jsonDecode(rawJson!) as List;
      expect(decoded.first['id'], equals('log-json-format'));
    });

    testWidgets('T1-F15-04: Existing Data Preserved on Subsequent App Launch', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final existingKit = KitItem(
        id: 'persist-kit-350',
        title: '已存檔盒怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 350,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(existingKit);
      await kitRepo.setActiveKit(existingKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      expect(find.textContaining('350 / 500 HP'), findsOneWidget);
    });

    testWidgets('T1-F15-05: Multi-Entity Write Isolation', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      final kit = KitItem.initialSeedKit();
      final log = CraftLog(
        id: 'iso-log',
        kitId: kit.id,
        phase: 'Snap-fit',
        durationMinutes: 5,
        damageDealt: 20,
        isCompletedSession: true,
        timestamp: DateTime.now(),
      );

      await storage.setJsonList(StorageKeys.kits, [kit.toMap()]);
      await storage.setJsonList(StorageKeys.craftLogs, [log.toMap()]);

      final rawKits = prefs.getString(StorageKeys.kits);
      final rawLogs = prefs.getString(StorageKeys.craftLogs);

      expect(rawKits, contains(kit.id));
      expect(rawLogs, contains('iso-log'));
    });
  });

  // =========================================================================
  // Feature 16: Auto-save & State Hydration
  // =========================================================================
  group('Feature 16: Auto-save & State Hydration', () {
    testWidgets('T1-F16-01: Auto-Save Triggered on Session Completion', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));

      final activeKit = await kitRepo.getActiveKit();
      final logs = await logRepo.getAllLogs();
      expect(activeKit!.currentHp, equals(480));
      expect(logs.length, equals(1));
    });

    testWidgets('T1-F16-02: Auto-Save Triggered on Interruption', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final activeKit = await kitRepo.getActiveKit();
      final logs = await logRepo.getAllLogs();
      expect(activeKit!.currentHp, lessThan(500));
      expect(logs.first.isCompletedSession, isFalse);
    });

    testWidgets('T1-F16-03: State Hydration on App Launch', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final seededKit = KitItem(
        id: 'seed-hydrate-kit',
        title: '水合驗證怪',
        grade: 'RG',
        totalHp: 800,
        currentHp: 320,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(seededKit);
      await kitRepo.setActiveKit(seededKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      expect(find.textContaining('320 / 800 HP'), findsOneWidget);
    });

    testWidgets('T1-F16-04: Hydration Restores Finishing Unlock if Pre-seeded <= 20%', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final seededKit = KitItem(
        id: 'seed-low-hp',
        title: '殘血水合怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 80, // 16% <= 20%
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(seededKit);
      await kitRepo.setActiveKit(seededKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      expect(find.text('水貼\n2.5x'), findsOneWidget);
    });

    testWidgets('T1-F16-05: Defeated Boss Hydration Shows Restart Button', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final defeatedKit = KitItem(
        id: 'seed-defeated-kit',
        title: '陣亡水合怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 0,
        status: KitStatus.completed,
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
      );
      await kitRepo.saveKit(defeatedKit);
      await kitRepo.setActiveKit(defeatedKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      expect(find.textContaining('重置 Boss 血量 (RESTART)'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 17: CraftLog History & Stats View
  // =========================================================================
  group('Feature 17: CraftLog History & Stats View', () {
    testWidgets('T1-F17-01: Screen Entry & Header Display', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('★ CRAFT LOG ★'), findsOneWidget);
      expect(find.byKey(const Key('btn_craft_log_back')), findsOneWidget);
    });

    testWidgets('T1-F17-02: KPI Metric Calculation', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kit = KitItem.initialSeedKit();
      await kitRepo.saveKit(kit);
      await kitRepo.setActiveKit(kit.id);

      await logRepo.addLog(CraftLog(
        id: 'kpi-log-1',
        kitId: kit.id,
        phase: 'Snap-fit',
        durationMinutes: 25,
        damageDealt: 100,
        isCompletedSession: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      ));

      await logRepo.addLog(CraftLog(
        id: 'kpi-log-2',
        kitId: kit.id,
        phase: 'Sanding',
        durationMinutes: 15,
        damageDealt: 36,
        isCompletedSession: false,
        timestamp: DateTime.now(),
      ));

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('40m'), findsOneWidget);
      expect(find.text('136 pt'), findsOneWidget);
      expect(find.text('1 次'), findsWidgets);
    });

    testWidgets('T1-F17-03: 5 Phase Breakdown Representation', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kit = KitItem.initialSeedKit();
      await kitRepo.saveKit(kit);
      await kitRepo.setActiveKit(kit.id);

      await logRepo.addLog(CraftLog(
        id: 'phase-log-1',
        kitId: kit.id,
        phase: 'Snap-fit',
        durationMinutes: 25,
        damageDealt: 100,
        isCompletedSession: true,
        timestamp: DateTime.now(),
      ));

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('【5 大工序傷害與工時分佈】'), findsOneWidget);
      expect(find.textContaining('Snap-fit (剪鉗連擊)'), findsOneWidget);
    });

    testWidgets('T1-F17-04: Filter Toggle between Active Kit and All History', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kit1 = KitItem.initialSeedKit();
      final kit2 = KitItem(
        id: 'kit-other-2',
        title: '另一盒模型',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 1000,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit1);
      await kitRepo.saveKit(kit2);
      await kitRepo.setActiveKit(kit1.id);

      await logRepo.addLog(CraftLog(
        id: 'k1-log',
        kitId: kit1.id,
        phase: 'Snap-fit',
        durationMinutes: 25,
        damageDealt: 100,
        isCompletedSession: true,
        timestamp: DateTime.now(),
      ));

      await logRepo.addLog(CraftLog(
        id: 'k2-log',
        kitId: kit2.id,
        phase: 'Airbrush',
        durationMinutes: 50,
        damageDealt: 440,
        isCompletedSession: true,
        timestamp: DateTime.now(),
      ));

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially active kit filter: 100 pt
      expect(find.text('100 pt'), findsOneWidget);

      // Toggle to all history
      await tester.tap(find.text('全部歷史紀錄'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 100 + 440 = 540 pt
      expect(find.text('540 pt'), findsOneWidget);
    });

    testWidgets('T1-F17-05: Back Navigation Restores Battle Screen', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const Key('btn_craft_log_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
      expect(find.textContaining('開始開工'), findsOneWidget);
    });
  });
}
