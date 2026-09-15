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
import 'package:nifty_heisenberg/presentation/widgets/floating_damage_text.dart';
import 'package:nifty_heisenberg/presentation/widgets/screen_shake.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    RetroAudioService.resetInstance();
    ScreenShake.globalEnabled = true;
  });

  tearDown(() {
    RetroAudioService.resetInstance();
    ScreenShake.globalEnabled = true;
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
  // Suite 1: Active Kit Switch During Countdown
  // Interacting: Features 1-3 (Pomodoro) x Feature 22 (Active Kit Switch)
  // =========================================================================
  group('Pairwise Suite 1: Active Kit Switch During Countdown', () {
    testWidgets('T3-P1-01: Dynamic Active Kit Adoption During Active Countdown', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kitA = KitItem(
        id: 'p1-kit-a',
        title: 'EG RX-78-2',
        grade: 'EG',
        totalHp: 300,
        currentHp: 300,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      final kitB = KitItem(
        id: 'p1-kit-b',
        title: 'MG Sazabi',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 1500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kitA);
      await kitRepo.saveKit(kitB);
      await kitRepo.setActiveKit(kitA.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Start countdown in 5s debug mode
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Open Hangar and switch to Kit B
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_set_active_p1-kit-b')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Battle HUD reflects new target
      expect(find.text('Lv.15 MG Sazabi'), findsOneWidget);
      expect(find.textContaining('1500 / 1500 HP'), findsOneWidget);
      expect(find.textContaining('已鎖定新討伐目標'), findsOneWidget);

      // Work phase continues
      expect(find.textContaining('WORK - 專注組裝中'), findsOneWidget);
    });

    testWidgets('T3-P1-02: Auto-Reset of Finishing Technique on Target Switch to High-HP Kit', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kitLow = KitItem(
        id: 'p1-low-a',
        title: 'Low Boss A',
        grade: 'HG',
        totalHp: 500,
        currentHp: 50, // 10% <= 20%
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      final kitHigh = KitItem(
        id: 'p1-high-b',
        title: 'High Boss B',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 1500, // 100% > 20%
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kitLow);
      await kitRepo.saveKit(kitHigh);
      await kitRepo.setActiveKit(kitLow.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Finishing is available on kitLow
      expect(find.text('水貼\n2.5x'), findsOneWidget);
      await tester.tap(find.text('水貼\n2.5x'));
      await tester.pump();

      // Open Hangar and switch to kitHigh
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_set_active_p1-high-b')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Finishing is auto-reset to Snap-fit and locked on High Boss
      expect(find.text('水貼\n🔒20%'), findsOneWidget);
      expect(find.textContaining('已鎖定新討伐目標'), findsOneWidget);
    });

    testWidgets('T3-P1-03: Damage and CraftLog Routing to Switched Kit on Work Completion', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kitA = KitItem(
        id: 'p1-rout-a',
        title: 'Target A',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      final kitB = KitItem(
        id: 'p1-rout-b',
        title: 'Target B',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 1500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kitA);
      await kitRepo.saveKit(kitB);
      await kitRepo.setActiveKit(kitA.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Start countdown
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      // Switch to Kit B during countdown
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_set_active_p1-rout-b')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Complete the 5s session (20 damage)
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));

      final kits = await kitRepo.getAllKits();
      final freshA = kits.firstWhere((k) => k.id == 'p1-rout-a');
      final freshB = kits.firstWhere((k) => k.id == 'p1-rout-b');

      // Kit A remains untouched at 500 HP
      expect(freshA.currentHp, equals(500));
      // Kit B received the 20 damage (1500 -> 1480)
      expect(freshB.currentHp, equals(1480));

      // CraftLog belongs exclusively to Kit B
      final logsA = await logRepo.getLogsForKit('p1-rout-a');
      final logsB = await logRepo.getLogsForKit('p1-rout-b');
      expect(logsA.isEmpty, isTrue);
      expect(logsB.length, equals(1));
      expect(logsB.first.damageDealt, equals(20));
    });

    testWidgets('T3-P1-04: Mercy Rule Interruption After Kit Switch Applies to New Kit', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kitA = KitItem(
        id: 'p1-mercy-a',
        title: 'Mercy Kit A',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      final kitB = KitItem(
        id: 'p1-mercy-b',
        title: 'Mercy Kit B',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 1500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kitA);
      await kitRepo.saveKit(kitB);
      await kitRepo.setActiveKit(kitA.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Start 5s session
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Switch to Kit B
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_set_active_p1-mercy-b')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Trigger mercy interruption
      await tester.tap(find.textContaining('中途中斷'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('中途急停！觸發 Mercy 保底防護'), findsOneWidget);

      final logsB = await logRepo.getLogsForKit('p1-mercy-b');
      expect(logsB.length, equals(1));
      expect(logsB.first.isCompletedSession, isFalse);
    });

    testWidgets('T3-P1-05: Rest Phase Continuity Across Kit Switch', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kit1 = KitItem(
        id: 'p1-rest-1',
        title: 'Rest Kit 1',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      final kit2 = KitItem(
        id: 'p1-rest-2',
        title: 'Rest Kit 2',
        grade: 'RG',
        totalHp: 800,
        currentHp: 800,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit1);
      await kitRepo.saveKit(kit2);
      await kitRepo.setActiveKit(kit1.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Run 5s session to enter rest phase
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('REST'), findsOneWidget);

      // Open hangar and switch to Kit 2
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_set_active_p1-rest-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Still in rest phase on new kit
      expect(find.textContaining('REST'), findsOneWidget);
      expect(find.text('Lv.15 Rest Kit 2'), findsOneWidget);

      // Skip rest returns to idle
      await tester.tap(find.textContaining('略過休息'));
      await tester.pump();
      expect(find.textContaining('POMODORO WORKBENCH CLOCK'), findsOneWidget);
    });
  });

  // =========================================================================
  // Suite 2: Delete Active Kit and Auto-Reassign
  // Interacting: Feature 19 (Kit Deletion) x Feature 22 (Active Reassignment)
  // =========================================================================
  group('Pairwise Suite 2: Delete Active Kit and Auto-Reassign', () {
    testWidgets('T3-P2-01: Reassignment to Next In-Progress or Backlog Kit', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kitA = KitItem(
        id: 'p2-del-a',
        title: 'Active Kit A',
        grade: 'HG',
        totalHp: 500,
        currentHp: 200,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      final kitB = KitItem(
        id: 'p2-del-b',
        title: 'Backlog Kit B',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 1500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      final kitC = KitItem(
        id: 'p2-del-c',
        title: 'Completed Kit C',
        grade: 'RG',
        totalHp: 800,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kitA);
      await kitRepo.saveKit(kitB);
      await kitRepo.saveKit(kitC);
      await kitRepo.setActiveKit(kitA.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Delete active Kit A
      await tester.tap(find.byKey(const Key('btn_delete_kit_p2-del-a')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_confirm_delete')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Kit B is now active
      final active = await kitRepo.getActiveKit();
      expect(active?.id, equals('p2-del-b'));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Lv.15 Backlog Kit B'), findsOneWidget);
    });

    testWidgets('T3-P2-02: Fallback to First Kit When Only Completed Kits Remain', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kitA = KitItem(
        id: 'p2-active-only',
        title: 'Active Target',
        grade: 'HG',
        totalHp: 500,
        currentHp: 100,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      final kitC = KitItem(
        id: 'p2-comp-only',
        title: 'Trophy Shelf Kit',
        grade: 'RG',
        totalHp: 800,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kitA);
      await kitRepo.saveKit(kitC);
      await kitRepo.setActiveKit(kitA.id);

      await kitRepo.deleteKit(kitA.id);

      final active = await kitRepo.getActiveKit();
      expect(active?.id, equals('p2-comp-only'));
    });

    testWidgets('T3-P2-03: Sole Kit Deletion Spawns Default Seed Kit', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final soloKit = KitItem(
        id: 'p2-solo',
        title: 'Solo Doomed Kit',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(soloKit);
      await kitRepo.setActiveKit(soloKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_delete_kit_p2-solo')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_confirm_delete')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Hangar automatically seeded default kit
      expect(find.text(GameConstants.defaultKitTitle), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining(GameConstants.defaultKitTitle), findsOneWidget);
    });

    testWidgets('T3-P2-04: Active Kit Deletion Mid-Session Graceful Recovery', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final k1 = KitItem(
        id: 'p2-mid-1',
        title: 'Mid Session 1',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      final k2 = KitItem(
        id: 'p2-mid-2',
        title: 'Mid Session 2',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 1500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(k1);
      await kitRepo.saveKit(k2);
      await kitRepo.setActiveKit(k1.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Start timer on k1
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Navigate to Hangar and delete active k1
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_delete_kit_p2-mid-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_confirm_delete')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Return to Battle
      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Battle recovers cleanly with k2
      expect(find.text('Lv.15 Mid Session 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T3-P2-05: Persistence Verification of Reassigned Target', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kA = KitItem(id: 'p2-persist-a', title: 'Persist A', grade: 'HG', totalHp: 500, currentHp: 500, status: KitStatus.unstarted, createdAt: DateTime.now());
      final kB = KitItem(id: 'p2-persist-b', title: 'Persist B', grade: 'MG', totalHp: 1500, currentHp: 1500, status: KitStatus.unstarted, createdAt: DateTime.now());
      await kitRepo.saveKit(kA);
      await kitRepo.saveKit(kB);
      await kitRepo.setActiveKit(kA.id);

      await kitRepo.deleteKit(kA.id);

      // Fresh instance reading same storage
      final freshKitRepo = KitRepository(storage, logRepo);
      final active = await freshKitRepo.getActiveKit();
      expect(active?.id, equals('p2-persist-b'));
    });
  });

  // =========================================================================
  // Suite 3: Custom HP Finishing Lock Transition
  // Interacting: Feature 21 (Custom HP) x Feature 9 (Finishing Gate)
  // =========================================================================
  group('Pairwise Suite 3: Custom HP Finishing Lock Transition', () {
    testWidgets('T3-P3-01: Small Custom HP (50 HP) Threshold Precision', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kitSmall = KitItem(
        id: 'p3-small-50',
        title: 'Small Custom 50',
        grade: 'HG',
        totalHp: 50,
        currentHp: 11, // 11/50 = 22% > 20%
        isCustomBoss: true,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kitSmall);
      await kitRepo.setActiveKit(kitSmall.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Locked at 22%
      expect(find.text('水貼\n🔒20%'), findsOneWidget);

      // Deal 2 damage to reach 9 HP (18% <= 20%)
      final updated = kitSmall.copyWith(currentHp: 9);
      await kitRepo.saveKit(updated);

      // Re-hydrate by entering and exiting Hangar
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Now unlocked at 18%
      expect(find.text('水貼\n2.5x'), findsOneWidget);
    });

    testWidgets('T3-P3-02: Large Custom HP (10,000 HP) Threshold Precision', (tester) async {
      final engine = const BattleEngine();
      // 2,001 / 10,000 = 20.01% -> false
      expect(engine.canExecuteFinishing(currentHp: 2001, maxHp: 10000), isFalse);
      // 2,000 / 10,000 = 20.00% -> true
      expect(engine.canExecuteFinishing(currentHp: 2000, maxHp: 10000), isTrue);
    });

    testWidgets('T3-P3-03: Forced Selection Rejection & SnackBar Feedback', (tester) async {
      await pumpApp(tester);

      // Initially at 500/500 HP (100%), Finishing is locked
      expect(find.text('水貼\n🔒20%'), findsOneWidget);
      final segmentedButton = tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));
      final finishingSegment = segmentedButton.segments.firstWhere((s) => s.value == 'Finishing');
      expect(finishingSegment.enabled, isFalse);

      const engine = BattleEngine();
      expect(engine.canExecuteFinishing(currentHp: 500, maxHp: 500), isFalse);

      // Attempt tap on locked button
      await tester.tap(find.text('水貼\n🔒20%'));
      await tester.pump();

      // Selected phase remains Snap-fit
      expect(segmentedButton.selected, equals({'Snap-fit'}));
    });

    testWidgets('T3-P3-04: Kit Edit in Hangar Invalidating Finishing Selection', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final lowKit = KitItem(
        id: 'p3-edit-inv',
        title: 'Low Target',
        grade: 'HG',
        totalHp: 500,
        currentHp: 50, // 10% <= 20%
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(lowKit);
      await kitRepo.setActiveKit(lowKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Select Finishing
      await tester.tap(find.text('水貼\n2.5x'));
      await tester.pump();
      expect(find.textContaining('處決水貼'), findsOneWidget);

      // Edit kit in Hangar, checking resetHp
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_edit_kit_p3-edit-inv')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('checkbox_reset_hp')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Return to Battle
      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // HP is back to full, Finishing is auto-locked and phase reverted to Snap-fit
      expect(find.text('水貼\n🔒20%'), findsOneWidget);
      final segBtn = tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));
      expect(segBtn.selected, contains(CraftPhases.snapFit));
    });

    testWidgets('T3-P3-05: Finishing 2.5x Execution and Quest Clear Trigger', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);
      final mockAudio = MockRetroAudioService();

      final dyingKit = KitItem(
        id: 'p3-fin-kill',
        title: 'Doomed Boss',
        grade: 'HG',
        totalHp: 500,
        currentHp: 20, // <= 20%
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(dyingKit);
      await kitRepo.setActiveKit(dyingKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo, mockAudio: mockAudio);

      // Select Finishing
      await tester.tap(find.text('水貼\n2.5x'));
      await tester.pump();

      // Run 5s debug session (20 base * 2.5 = 50 damage >= 20 HP)
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      // Quest Clear modal appears
      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);
      expect(mockAudio.victoryFanfareCount, greaterThanOrEqualTo(1));
    });
  });

  // =========================================================================
  // Suite 4: Mute State During Defeat Fanfare & Visual Feedback
  // Interacting: Feature 31 (Audio & Mute) x Feature 23 (Defeat Fanfare)
  // =========================================================================
  group('Pairwise Suite 4: Mute State During Defeat Fanfare & Visual Feedback', () {
    testWidgets('T3-P4-01: Defeat Fanfare Suppression When Muted', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);
      final mockAudio = MockRetroAudioService();

      final lowKit = KitItem(
        id: 'p4-mute-kill',
        title: 'Silent Defeat',
        grade: 'HG',
        totalHp: 500,
        currentHp: 10,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(lowKit);
      await kitRepo.setActiveKit(lowKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo, mockAudio: mockAudio);

      // Toggle Mute ON
      await tester.tap(find.byKey(const Key('btn_mute_toggle')));
      await tester.pump();
      expect(mockAudio.isMuted, isTrue);

      // Defeat boss
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      // Modal appears
      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);
      // Fanfare was suppressed
      expect(mockAudio.victoryFanfareCount, equals(0));
    });

    testWidgets('T3-P4-02: Fanfare Playback When Unmuted', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);
      final mockAudio = MockRetroAudioService();

      final lowKit = KitItem(
        id: 'p4-unmute-kill',
        title: 'Loud Defeat',
        grade: 'HG',
        totalHp: 500,
        currentHp: 10,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(lowKit);
      await kitRepo.setActiveKit(lowKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo, mockAudio: mockAudio);

      // Ensure unmuted
      expect(mockAudio.isMuted, isFalse);

      // Defeat boss
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);
      expect(mockAudio.victoryFanfareCount, greaterThanOrEqualTo(1));
    });

    testWidgets('T3-P4-03: Persistence of Mute State Across Navigation', (tester) async {
      final mockAudio = MockRetroAudioService();
      await pumpApp(tester, mockAudio: mockAudio);

      // Mute in Battle
      await tester.tap(find.byKey(const Key('btn_mute_toggle')));
      await tester.pump();
      expect(find.text('MUTE'), findsOneWidget);
      expect(mockAudio.isMuted, isTrue);

      // Navigate Hangar -> back
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('MUTE'), findsOneWidget);
      expect(mockAudio.isMuted, isTrue);
    });

    testWidgets('T3-P4-04: Decoupled Visual Combat Juice When Muted', (tester) async {
      final mockAudio = MockRetroAudioService();
      await pumpApp(tester, mockAudio: mockAudio);

      // Mute
      await tester.tap(find.byKey(const Key('btn_mute_toggle')));
      await tester.pump();

      // Attack
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));

      // Visual floating damage text appears
      expect(find.byType(FloatingDamageOverlay), findsOneWidget);
      // Audio hits remain 0
      expect(mockAudio.attackHitCount, equals(0));
    });

    testWidgets('T3-P4-05: Rapid Mute Toggling Stress', (tester) async {
      final mockAudio = MockRetroAudioService();
      await pumpApp(tester, mockAudio: mockAudio);

      for (int i = 0; i < 15; i++) {
        await tester.tap(find.byKey(const Key('btn_mute_toggle')));
        await tester.pump();
      }

      // 15 taps (odd) -> Muted
      expect(find.text('MUTE'), findsOneWidget);
      expect(mockAudio.isMuted, isTrue);
    });
  });

  // =========================================================================
  // Suite 5: Cascade Deletion of Craft Logs
  // Interacting: Feature 19 (Kit Deletion) x Feature 14/17 (CraftLog & Stats)
  // =========================================================================
  group('Pairwise Suite 5: Cascade Deletion of Craft Logs', () {
    testWidgets('T3-P5-01: Deleting Kit Removes All Associated Craft Logs', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);
      kitRepo.bindCraftLogRepository(logRepo);

      final kitA = KitItem(id: 'p5-kit-a', title: 'Kit A', grade: 'HG', totalHp: 500, currentHp: 500, status: KitStatus.unstarted, createdAt: DateTime.now());
      final kitB = KitItem(id: 'p5-kit-b', title: 'Kit B', grade: 'MG', totalHp: 1500, currentHp: 1500, status: KitStatus.unstarted, createdAt: DateTime.now());
      await kitRepo.saveKit(kitA);
      await kitRepo.saveKit(kitB);

      for (int i = 0; i < 3; i++) {
        await logRepo.addLog(CraftLog(id: 'la-$i', kitId: kitA.id, phase: CraftPhases.snapFit, durationMinutes: 25, damageDealt: 100, isCompletedSession: true, timestamp: DateTime.now()));
      }
      for (int i = 0; i < 2; i++) {
        await logRepo.addLog(CraftLog(id: 'lb-$i', kitId: kitB.id, phase: CraftPhases.sanding, durationMinutes: 25, damageDealt: 120, isCompletedSession: true, timestamp: DateTime.now()));
      }

      await kitRepo.deleteKit(kitA.id);

      final logsA = await logRepo.getLogsForKit(kitA.id);
      final allLogs = await logRepo.getAllLogs();
      expect(logsA.isEmpty, isTrue);
      expect(allLogs.length, equals(2));
    });

    testWidgets('T3-P5-02: CraftLogScreen Reflection After Kit Deletion', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);
      kitRepo.bindCraftLogRepository(logRepo);

      final kitA = KitItem(id: 'p5-scr-a', title: 'Kit A Scrn', grade: 'HG', totalHp: 500, currentHp: 500, status: KitStatus.unstarted, createdAt: DateTime.now());
      final kitB = KitItem(id: 'p5-scr-b', title: 'Kit B Scrn', grade: 'HG', totalHp: 500, currentHp: 500, status: KitStatus.unstarted, createdAt: DateTime.now());
      await kitRepo.saveKit(kitA);
      await kitRepo.saveKit(kitB);
      await kitRepo.setActiveKit(kitB.id);

      await logRepo.addLog(CraftLog(id: 'la-1', kitId: kitA.id, phase: CraftPhases.snapFit, durationMinutes: 30, damageDealt: 100, isCompletedSession: true, timestamp: DateTime.now()));
      await logRepo.addLog(CraftLog(id: 'lb-1', kitId: kitB.id, phase: CraftPhases.sanding, durationMinutes: 20, damageDealt: 80, isCompletedSession: true, timestamp: DateTime.now()));

      // Delete Kit A
      await kitRepo.deleteKit(kitA.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Only Kit B's 20m and 80pt are displayed
      expect(find.text('20m'), findsOneWidget);
      expect(find.text('80 pt'), findsOneWidget);
      expect(find.text('1 次'), findsWidgets);
    });

    testWidgets('T3-P5-03: Showcase Detail Invariance After Other Kit Deletion', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);
      kitRepo.bindCraftLogRepository(logRepo);

      final kitDelete = KitItem(id: 'p5-del-other', title: 'To Delete', grade: 'HG', totalHp: 500, currentHp: 500, status: KitStatus.unstarted, createdAt: DateTime.now());
      final kitKeep = KitItem(id: 'p5-keep-show', title: 'Showcase Keep', grade: 'RG', totalHp: 800, currentHp: 0, status: KitStatus.completed, completedAt: DateTime.now(), createdAt: DateTime.now());
      await kitRepo.saveKit(kitDelete);
      await kitRepo.saveKit(kitKeep);

      await logRepo.addLog(CraftLog(id: 'lk-1', kitId: kitKeep.id, phase: CraftPhases.snapFit, durationMinutes: 40, damageDealt: 800, isCompletedSession: true, timestamp: DateTime.now()));

      // Delete the other kit
      await kitRepo.deleteKit(kitDelete.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('showcase_card_p5-keep-show')), findsOneWidget);
      expect(find.text('Showcase Keep'), findsOneWidget);
    });

    testWidgets('T3-P5-04: Cascade Deletion with Zero Logs', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);
      kitRepo.bindCraftLogRepository(logRepo);

      final zeroLogKit = KitItem(id: 'p5-zero', title: 'Zero Logs', grade: 'HG', totalHp: 500, currentHp: 500, status: KitStatus.unstarted, createdAt: DateTime.now());
      await kitRepo.saveKit(zeroLogKit);

      // Should complete cleanly without error
      await kitRepo.deleteKit(zeroLogKit.id);
      final allKits = await kitRepo.getAllKits();
      expect(allKits.any((k) => k.id == 'p5-zero'), isFalse);
    });

    testWidgets('T3-P5-05: SharedPreferences Raw JSON Integrity', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);
      kitRepo.bindCraftLogRepository(logRepo);

      final kitWithLogs = KitItem(id: 'p5-json-test', title: 'JSON Test', grade: 'HG', totalHp: 500, currentHp: 500, status: KitStatus.unstarted, createdAt: DateTime.now());
      await kitRepo.saveKit(kitWithLogs);
      await logRepo.addLog(CraftLog(id: 'json-1', kitId: kitWithLogs.id, phase: CraftPhases.snapFit, durationMinutes: 10, damageDealt: 20, isCompletedSession: true, timestamp: DateTime.now()));

      await kitRepo.deleteKit(kitWithLogs.id);

      final rawLogs = await storage.getJsonList(StorageKeys.craftLogs);
      expect(rawLogs.any((item) => item['kitId'] == 'p5-json-test'), isFalse);
    });
  });
}
