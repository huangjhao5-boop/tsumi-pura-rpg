import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nifty_heisenberg/core/constants/game_constants.dart';
import 'package:nifty_heisenberg/data/repositories/craft_log_repository.dart';
import 'package:nifty_heisenberg/data/repositories/kit_repository.dart';
import 'package:nifty_heisenberg/data/storage/local_storage_service.dart';
import 'package:nifty_heisenberg/domain/models/craft_log.dart';
import 'package:nifty_heisenberg/domain/models/kit_item.dart';
import 'package:nifty_heisenberg/main.dart';
import 'package:nifty_heisenberg/presentation/screens/craft_log_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void setScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('Challenge Task 1: Consecutive Combat Cycles & Autosave Integrity', () {
    testWidgets(
      'Multi-cycle consecutive combat persists damage and logs across 5 cycles without data loss',
      (WidgetTester tester) async {
        setScreenSize(tester);

        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);
        final kitRepo = KitRepository(storage);
        final logRepo = CraftLogRepository(storage);

        // Seed initial kit: 500 HP
        final kit = KitItem(
          id: 'test-consecutive-kit',
          title: '連續討伐測試機',
          grade: 'HG',
          totalHp: 500,
          currentHp: 500,
          status: KitStatus.inProgress,
          createdAt: DateTime.now(),
        );
        await kitRepo.saveKit(kit);
        await kitRepo.setActiveKit(kit.id);

        await tester.pumpWidget(
          TsumiPuraApp(
            kitRepository: kitRepo,
            craftLogRepository: logRepo,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Cycle 1: Snap-fit (1.0x, debug mode 20 pts) -> 20 dmg. HP: 480
        await tester.tap(find.text('5秒測試'));
        await tester.pump();
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('REST - 工坊整備休息中'), findsOneWidget);

        // Skip rest to ready next cycle
        await tester.tap(find.textContaining('略過休息'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Cycle 2: Sanding (1.2x on 20 pts) -> 24 dmg. HP: 480 - 24 = 456
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
        await tester.pump(const Duration(milliseconds: 100));

        // Cycle 3: Detailing (1.5x on 20 pts) -> 30 dmg. HP: 456 - 30 = 426
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
        await tester.pump(const Duration(milliseconds: 100));

        // Cycle 4: Airbrush (2.0x on 20 pts) -> 40 dmg. HP: 426 - 40 = 386
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
        await tester.pump(const Duration(milliseconds: 100));

        // Cycle 5: Snap-fit again, interrupted at 2 seconds
        // Elapsed: 2s of 5s. Snap-fit (1.0x). Mercy (0.5).
        // 20 * (2/5) * 1.0 * 0.5 = 4 dmg. HP: 386 - 4 = 382
        await tester.tap(find.textContaining('素組'));
        await tester.pump();
        await tester.tap(find.text('5秒測試'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await tester.tap(find.textContaining('中途中斷'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify In-Memory and UI State
        expect(find.textContaining('382 / 500 HP'), findsOneWidget);

        // Verify Repository Persistence
        final savedKit = await kitRepo.getActiveKit();
        expect(savedKit, isNotNull);
        expect(savedKit!.currentHp, equals(382));
        expect(savedKit.totalHp, equals(500));
        expect(savedKit.status, equals(KitStatus.inProgress));

        // Verify all 5 craft logs exist in repo, sorted newest first
        final logs = await logRepo.getAllLogs();
        expect(logs.length, equals(5));

        // Newest log is Cycle 5 (Interrupted Snap-fit, 4 dmg)
        expect(logs[0].phase, equals(CraftPhases.snapFit));
        expect(logs[0].damageDealt, equals(4));
        expect(logs[0].isCompletedSession, isFalse);

        // Cycle 4 (Airbrush, 40 dmg)
        expect(logs[1].phase, equals(CraftPhases.airbrush));
        expect(logs[1].damageDealt, equals(40));
        expect(logs[1].isCompletedSession, isTrue);

        // Cycle 3 (Detailing, 30 dmg)
        expect(logs[2].phase, equals(CraftPhases.detailing));
        expect(logs[2].damageDealt, equals(30));
        expect(logs[2].isCompletedSession, isTrue);

        // Cycle 2 (Sanding, 24 dmg)
        expect(logs[3].phase, equals(CraftPhases.sanding));
        expect(logs[3].damageDealt, equals(24));
        expect(logs[3].isCompletedSession, isTrue);

        // Cycle 1 (Snap-fit, 20 dmg)
        expect(logs[4].phase, equals(CraftPhases.snapFit));
        expect(logs[4].damageDealt, equals(20));
        expect(logs[4].isCompletedSession, isTrue);

        // Sum of damage across 5 logs: 20 + 24 + 30 + 40 + 4 = 118
        final totalDmg = logs.fold(0, (s, l) => s + l.damageDealt);
        expect(totalDmg, equals(118));
        expect(500 - totalDmg, equals(382));
      },
    );

    testWidgets(
      'Finishing execution unlock at <=20% HP and Boss defeat saves completed status in persistence',
      (WidgetTester tester) async {
        setScreenSize(tester);

        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);
        final kitRepo = KitRepository(storage);
        final logRepo = CraftLogRepository(storage);

        // Kit near finishing threshold: 500 totalHp, 100 currentHp (exactly 20%)
        final nearDeadKit = KitItem(
          id: 'kit-finishing-test',
          title: '殘血受試盒怪',
          grade: 'HG',
          totalHp: 500,
          currentHp: 100,
          status: KitStatus.inProgress,
          createdAt: DateTime.now(),
        );
        await kitRepo.saveKit(nearDeadKit);
        await kitRepo.setActiveKit(nearDeadKit.id);

        await tester.pumpWidget(
          TsumiPuraApp(
            kitRepository: kitRepo,
            craftLogRepository: logRepo,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // At 100/500 HP (20%), Finishing should be UNLOCKED: "水貼\n2.5x"
        expect(find.text('水貼\n2.5x'), findsOneWidget);

        // Select Finishing (2.5x)
        await tester.tap(find.text('水貼\n2.5x'));
        await tester.pump();

        // Run debug session: 20 base points * 2.5x = 50 damage -> 100 - 50 = 50 HP
        await tester.tap(find.text('5秒測試'));
        await tester.pump();
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.textContaining('略過休息'));
        await tester.pump();

        expect(find.textContaining('50 / 500 HP'), findsOneWidget);

        // Run another finishing session: 20 * 2.5 = 50 damage -> 50 - 50 = 0 HP (DEFEAT!)
        await tester.tap(find.text('5秒測試'));
        await tester.pump();
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.pump(const Duration(milliseconds: 300));

        // Let Quest Clear dialog animation appear (700ms delay in main.dart)
        await tester.pump(const Duration(milliseconds: 800));

        // Verify Quest Clear dialog appeared
        expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);
        expect(find.textContaining('山積淨化完畢！完成品誕生！'), findsOneWidget);

        // Verify kit in repository marked as completed
        final defeatedKit = await kitRepo.getActiveKit();
        expect(defeatedKit, isNotNull);
        expect(defeatedKit!.currentHp, equals(0));
        expect(defeatedKit.isCompleted, isTrue);

        // Tap "收錄至展示櫃 (Showcase)" button
        await tester.tap(find.textContaining('收錄至展示櫃'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Dialog dismissed, HP reset to 500
        expect(find.text('★ QUEST CLEAR ★'), findsNothing);
        expect(find.textContaining('500 / 500 HP'), findsOneWidget);

        // Repository updated with reset kit
        final resetKit = await kitRepo.getActiveKit();
        expect(resetKit!.currentHp, equals(500));
      },
    );

    testWidgets(
      'App reload hydrates preserved kit HP and renders cumulative stats in CraftLogScreen',
      (WidgetTester tester) async {
        setScreenSize(tester);

        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);
        final kitRepo = KitRepository(storage);
        final logRepo = CraftLogRepository(storage);

        // Pre-populate storage as if previous sessions ran
        final initialKit = KitItem(
          id: 'kit-persisted-777',
          title: 'RG 自由鋼彈盒怪',
          grade: 'RG',
          totalHp: 800,
          currentHp: 650,
          status: KitStatus.inProgress,
          createdAt: DateTime(2026, 9, 1),
        );
        await kitRepo.saveKit(initialKit);
        await kitRepo.setActiveKit(initialKit.id);

        await logRepo.addLog(
          CraftLog(
            id: 'log-1',
            kitId: initialKit.id,
            phase: CraftPhases.snapFit,
            durationMinutes: 25,
            damageDealt: 100,
            isCompletedSession: true,
            timestamp: DateTime(2026, 9, 10, 10, 0),
          ),
        );
        await logRepo.addLog(
          CraftLog(
            id: 'log-2',
            kitId: initialKit.id,
            phase: CraftPhases.sanding,
            durationMinutes: 15,
            damageDealt: 50,
            isCompletedSession: false,
            timestamp: DateTime(2026, 9, 11, 8, 0),
          ),
        );

        // Launch app
        await tester.pumpWidget(
          TsumiPuraApp(
            kitRepository: kitRepo,
            craftLogRepository: logRepo,
          ),
        );
        // Zero-flicker hydration requires pump to resolve async future
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Verify Boss card displays hydrated values
        expect(find.textContaining('RG 自由鋼彈盒怪'), findsOneWidget);
        expect(find.textContaining('650 / 800 HP'), findsOneWidget);

        // Open CraftLogScreen
        await tester.tap(find.byKey(const Key('btn_craft_log')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify statistics accurately reflected
        expect(find.text('40m'), findsOneWidget); // 25 + 15
        expect(find.text('150 pt'), findsOneWidget); // 100 + 50
        expect(find.text('1 次'), findsNWidgets(2)); // 1 completed, 1 interrupted
      },
    );
  });

  group('Challenge Task 2: Mercy Rule Interruption Autosave & Partial Calculation Stress', () {
    testWidgets(
      'Mercy Rule calculation across various fractional durations and modes preserves 50% floor',
      (WidgetTester tester) async {
        setScreenSize(tester);

        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);
        final kitRepo = KitRepository(storage);
        final logRepo = CraftLogRepository(storage);

        final kit = KitItem(
          id: 'mercy-test-kit',
          title: '保底傷害測試怪',
          grade: 'MG',
          totalHp: 1500,
          currentHp: 1500,
          status: KitStatus.inProgress,
          createdAt: DateTime.now(),
        );
        await kitRepo.saveKit(kit);
        await kitRepo.setActiveKit(kit.id);

        await tester.pumpWidget(
          TsumiPuraApp(
            kitRepository: kitRepo,
            craftLogRepository: logRepo,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Interruption in Standard 25m mode:
        // We select Sanding (1.2x). Base points = 100. Total = 1500s.
        // Let's start and advance 600s (10 minutes, 40% elapsed).
        // Expected damage = round(100 * (600/1500) * 1.2 * 0.5) = round(100 * 0.4 * 0.6) = 24 dmg.
        await tester.tap(find.textContaining('打磨'));
        await tester.pump();
        await tester.tap(find.textContaining('開始開工'));
        await tester.pump();

        // Advance 600 seconds
        await tester.pump(const Duration(seconds: 600));

        // Tap interrupt
        await tester.tap(find.textContaining('中途中斷'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify HP was reduced by 24 -> 1500 - 24 = 1476
        expect(find.textContaining('1476 / 1500 HP'), findsOneWidget);

        // Verify repo
        final log1 = (await logRepo.getAllLogs()).first;
        expect(log1.phase, equals(CraftPhases.sanding));
        expect(log1.damageDealt, equals(24));
        expect(log1.durationMinutes, equals(10));
        expect(log1.isCompletedSession, isFalse);

        // Second Interruption: Deep Focus 50m mode
        // Base points = 220. Total = 3000s. Select Detailing (1.5x).
        // Advance 1500s (25 minutes, 50% elapsed).
        // Expected damage = round(220 * (1500/3000) * 1.5 * 0.5) = round(220 * 0.5 * 0.75) = round(82.5) = 83 dmg.
        await tester.tap(find.textContaining('深度 50m/10m'));
        await tester.pump();
        await tester.tap(find.textContaining('刻線'));
        await tester.pump();
        await tester.tap(find.textContaining('開始開工'));
        await tester.pump();

        await tester.pump(const Duration(seconds: 1500));
        await tester.tap(find.textContaining('中途中斷'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 1476 - 83 = 1393 HP
        expect(find.textContaining('1393 / 1500 HP'), findsOneWidget);

        final log2 = (await logRepo.getAllLogs()).first;
        expect(log2.phase, equals(CraftPhases.detailing));
        expect(log2.damageDealt, equals(83));
        expect(log2.durationMinutes, equals(25));
        expect(log2.isCompletedSession, isFalse);
      },
    );

    testWidgets(
      'Immediate interruption at 0s and 1s does not crash or produce negative numbers',
      (WidgetTester tester) async {
        setScreenSize(tester);

        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);
        final kitRepo = KitRepository(storage);
        final logRepo = CraftLogRepository(storage);

        await tester.pumpWidget(
          TsumiPuraApp(
            kitRepository: kitRepo,
            craftLogRepository: logRepo,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Immediate interruption at 0s: start then stop immediately without advancing time
        await tester.tap(find.text('5秒測試'));
        await tester.pump();
        await tester.tap(find.textContaining('中途中斷'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Should return cleanly to idle
        expect(find.textContaining('開始開工'), findsOneWidget);

        final logs = await logRepo.getAllLogs();
        expect(logs.length, equals(1));
        expect(logs.first.durationMinutes, equals(0));
        expect(logs.first.damageDealt, equals(0));
        expect(logs.first.isCompletedSession, isFalse);

        // Next: Interruption at exactly 1 second in debug mode
        // 5s mode, 1s elapsed. Snap-fit (1.0x).
        // 20 * (1/5) * 1.0 * 0.5 = 2 dmg.
        // Duration: 1s < 60s -> durationMinutes normalized to 1
        await tester.tap(find.text('5秒測試'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.textContaining('中途中斷'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final updatedLogs = await logRepo.getAllLogs();
        expect(updatedLogs.length, equals(2));
        expect(updatedLogs.first.durationMinutes, equals(1));
        expect(updatedLogs.first.damageDealt, equals(2));
        expect(updatedLogs.first.isCompletedSession, isFalse);
      },
    );
  });

  group('Challenge Task 3: Empty CraftLog State & Zero-Log Diagnostics', () {
    testWidgets(
      'CraftLogScreen handles empty log repository with zero divides, correct 0 KPIs, and 0% bars',
      (WidgetTester tester) async {
        setScreenSize(tester);

        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);
        final logRepo = CraftLogRepository(storage);
        final kitRepo = KitRepository(storage);

        await tester.pumpWidget(
          MaterialApp(
            home: CraftLogScreen(
              craftLogRepository: logRepo,
              kitRepository: kitRepo,
              activeKitId: 'empty-kit-id',
              activeKitTitle: '無紀錄盒怪',
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verification of zero KPI metrics
        expect(find.text('0m'), findsOneWidget);
        expect(find.text('0 pt'), findsOneWidget);
        expect(find.text('0 次'), findsNWidgets(2)); // 0 completed, 0 interrupted

        // Verification of 5 phase bars displaying 0m · 0 pt (0%)
        expect(find.text('0m · 0 pt (0%)'), findsNWidgets(5));

        // Verification of empty placeholder container
        expect(find.textContaining('尚未有施工紀錄'), findsOneWidget);

        // Verification of filter selector toggle
        expect(find.textContaining('當前: 無紀錄盒怪'), findsOneWidget);
        expect(find.text('全部歷史紀錄'), findsOneWidget);

        // Toggling filter selector on empty state should not crash
        await tester.tap(find.text('全部歷史紀錄'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.textContaining('尚未有施工紀錄'), findsOneWidget);

        // Tapping refresh icon button on empty state should reload cleanly
        await tester.tap(find.byTooltip('重新整理'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.textContaining('尚未有施工紀錄'), findsOneWidget);
      },
    );

    testWidgets(
      'CraftLogScreen handles null kit ID and missing title gracefully',
      (WidgetTester tester) async {
        setScreenSize(tester);

        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);
        final logRepo = CraftLogRepository(storage);

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
        await tester.pump(const Duration(milliseconds: 300));

        // When activeKitId is null, filter segment should not be built
        expect(find.byType(SegmentedButton<bool>), findsNothing);
        expect(find.text('★ CRAFT LOG ★'), findsOneWidget);
        expect(find.textContaining('尚未有施工紀錄'), findsOneWidget);
      },
    );

    testWidgets(
      'CraftLogScreen dynamically updates when new log is added',
      (WidgetTester tester) async {
        setScreenSize(tester);

        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);
        final logRepo = CraftLogRepository(storage);

        await tester.pumpWidget(
          MaterialApp(
            home: CraftLogScreen(
              craftLogRepository: logRepo,
              activeKitId: 'dynamic-kit',
              activeKitTitle: '動態盒怪',
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.textContaining('尚未有施工紀錄'), findsOneWidget);

        // Add a log to repository
        await logRepo.addLog(
          CraftLog(
            id: 'dyn-log-1',
            kitId: 'dynamic-kit',
            phase: CraftPhases.airbrush,
            durationMinutes: 50,
            damageDealt: 440,
            isCompletedSession: true,
            timestamp: DateTime.now(),
          ),
        );

        // Trigger refresh in UI
        await tester.tap(find.byTooltip('重新整理'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Empty state is gone, stats are rendered
        expect(find.textContaining('尚未有施工紀錄'), findsNothing);
        expect(find.text('50m'), findsOneWidget);
        expect(find.text('440 pt'), findsOneWidget);
        expect(find.text('1 次'), findsOneWidget);
        expect(find.text('噴筆重砲'), findsOneWidget);
      },
    );
  });

  group('Challenge Task 4: Navigation State Preservation Stress', () {
    testWidgets(
      'Navigating from BattleScreen to CraftLogScreen and back preserves all selection and combat state',
      (WidgetTester tester) async {
        setScreenSize(tester);

        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);
        final kitRepo = KitRepository(storage);
        final logRepo = CraftLogRepository(storage);

        await tester.pumpWidget(
          TsumiPuraApp(
            kitRepository: kitRepo,
            craftLogRepository: logRepo,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Change mode to deepFocus and phase to Airbrush
        await tester.tap(find.textContaining('深度 50m/10m'));
        await tester.pump();
        await tester.tap(find.textContaining('噴塗'));
        await tester.pump();

        // Run 1 debug cycle to alter HP and coins
        await tester.tap(find.text('5秒測試'));
        await tester.pump();
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.textContaining('略過休息'));
        await tester.pump();

        // Select Detailing then Airbrush to trigger dialog update
        await tester.tap(find.textContaining('刻線'));
        await tester.pump();
        await tester.tap(find.textContaining('噴塗'));
        await tester.pump();

        // Check pre-navigation state
        expect(find.textContaining('460 / 500 HP'), findsOneWidget); // 500 - 40
        expect(find.textContaining('已切換武器：【噴筆重砲】(2.0x 倍率)'), findsOneWidget);

        // Open CraftLogScreen
        await tester.tap(find.byKey(const Key('btn_craft_log')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        // We are on CraftLogScreen
        expect(find.text('★ CRAFT LOG ★'), findsOneWidget);

        // Return back to Battle Screen via back button
        await tester.tap(find.byKey(const Key('btn_craft_log_back')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        // Verify Battle Screen state is 100% preserved
        expect(find.textContaining('460 / 500 HP'), findsOneWidget);
        expect(find.textContaining('TSUMI-PURA RPG'), findsOneWidget);
        expect(find.textContaining('已切換武器：【噴筆重砲】(2.0x 倍率)'), findsOneWidget);

        // Verify we can immediately start another combat session
        await tester.tap(find.text('5秒測試'));
        await tester.pump();
        expect(find.textContaining('WORK - 專注組裝中'), findsOneWidget);
      },
    );

    testWidgets(
      'Navigating to CraftLogScreen while Pomodoro work timer is ticking allows timer to continue without corruption',
      (WidgetTester tester) async {
        setScreenSize(tester);

        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);
        final kitRepo = KitRepository(storage);
        final logRepo = CraftLogRepository(storage);

        await tester.pumpWidget(
          TsumiPuraApp(
            kitRepository: kitRepo,
            craftLogRepository: logRepo,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Start 5s debug work session
        await tester.tap(find.text('5秒測試'));
        await tester.pump();
        expect(find.textContaining('WORK - 專注組裝中'), findsOneWidget);

        // Advance 2 seconds
        await tester.pump(const Duration(seconds: 2));

        // Navigate to CraftLogScreen during active countdown
        await tester.tap(find.byKey(const Key('btn_craft_log')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        // On CraftLogScreen, advance 4 more seconds (2s remaining + 1s completion + 1s rest start)
        for (int i = 0; i < 4; i++) {
          await tester.pump(const Duration(seconds: 1));
        }

        // Pop back to Battle Screen
        await tester.tap(find.byKey(const Key('btn_craft_log_back')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        // Timer finished in background, entered REST phase!
        expect(find.textContaining('REST - 工坊整備休息中'), findsOneWidget);
        expect(find.textContaining('480 / 500 HP'), findsOneWidget);

        // Repository updated while on the other screen
        final logs = await logRepo.getAllLogs();
        expect(logs.length, equals(1));
        expect(logs.first.isCompletedSession, isTrue);
      },
    );

    testWidgets(
      'Rapid back-and-forth navigation (5 push/pop cycles) is stable and leak-free',
      (WidgetTester tester) async {
        setScreenSize(tester);

        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);
        final kitRepo = KitRepository(storage);
        final logRepo = CraftLogRepository(storage);

        await tester.pumpWidget(
          TsumiPuraApp(
            kitRepository: kitRepo,
            craftLogRepository: logRepo,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        for (int i = 0; i < 5; i++) {
          await tester.tap(find.byKey(const Key('btn_craft_log')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          expect(find.text('★ CRAFT LOG ★'), findsOneWidget);

          await tester.tap(find.byKey(const Key('btn_craft_log_back')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
        }

        expect(find.textContaining('500 / 500 HP'), findsOneWidget);
      },
    );
  });
}
