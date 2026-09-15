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
import 'package:nifty_heisenberg/presentation/screens/craft_log_screen.dart';
import 'package:nifty_heisenberg/presentation/screens/hangar_screen.dart';
import 'package:nifty_heisenberg/presentation/screens/showcase_screen.dart';
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
  // Group 1: Application Lifecycle & Multi-Screen Rapid Navigation Stress
  // =========================================================================
  group('Adversarial Challenge 1: Application Lifecycle & Navigation Invariants', () {
    testWidgets('1.1: Rapid Cyclic Navigation across all 4 screens with active running timers & loop animations', (
      WidgetTester tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Start 5-second debug pomodoro countdown
      expect(find.text('5秒測試'), findsOneWidget);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify timer is actively running
      expect(find.text('中途中斷 (結算 50% 保底傷害)'), findsOneWidget);

      // Perform 5 rapid navigation cycles across Hangar, Showcase, and CraftLog
      // using both header quick links and bottom arcade nav bar
      for (int cycle = 0; cycle < 5; cycle++) {
        // --- 1. Push Hangar via header badge ---
        expect(find.byKey(const Key('btn_hangar')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_hangar')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(HangarScreen), findsOneWidget);

        // Pop back to Battle
        expect(find.byKey(const Key('btn_hangar_back')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_hangar_back')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(BattleAtelierScreen), findsOneWidget);

        // --- 2. Push Showcase via bottom nav bar ---
        expect(find.byKey(const Key('btn_nav_showcase')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_nav_showcase')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(ShowcaseScreen), findsOneWidget);

        // Pop back to Battle
        expect(find.byKey(const Key('btn_showcase_back')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_showcase_back')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(BattleAtelierScreen), findsOneWidget);

        // --- 3. Push CraftLog via header badge ---
        expect(find.byKey(const Key('btn_craft_log')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_craft_log')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(CraftLogScreen), findsOneWidget);

        // Pop back to Battle
        expect(find.byKey(const Key('btn_craft_log_back')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_craft_log_back')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(BattleAtelierScreen), findsOneWidget);

        // --- 4. Push Hangar via bottom nav dock ---
        expect(find.byKey(const Key('btn_nav_hangar')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_nav_hangar')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(HangarScreen), findsOneWidget);

        // Pop back
        await tester.tap(find.byKey(const Key('btn_hangar_back')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // --- 5. Push CraftLog via bottom nav dock ---
        expect(find.byKey(const Key('btn_nav_craft_log')), findsOneWidget);
        await tester.tap(find.byKey(const Key('btn_nav_craft_log')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(CraftLogScreen), findsOneWidget);

        // Pop back
        await tester.tap(find.byKey(const Key('btn_craft_log_back')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Verify widget tree is healthy, no exceptions thrown, and battle screen is intact
      expect(find.byType(BattleAtelierScreen), findsOneWidget);
    });

    testWidgets('1.2: Background Pomodoro timer expiration & work session settle across route stack', (
      WidgetTester tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final initialKit = KitItem(
        id: 'bg-timer-kit',
        title: 'HG Gundam Aerial',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(initialKit);
      await kitRepo.setActiveKit(initialKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Start 5s debug work timer
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Immediately navigate away to HangarScreen while timer is ticking
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(HangarScreen), findsOneWidget);

      // Advance virtual clock by 6 seconds while on HangarScreen
      // This causes the background timer on BattleAtelierScreen to hit 0 and settle
      await tester.pump(const Duration(seconds: 6));

      // Now pop back to BattleAtelierScreen
      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify zero state desync:
      // 1. Battle screen transitioned into Rest phase
      expect(find.text('略過休息 (提前開工)'), findsOneWidget);
      // 2. Boss HP decreased from 500
      final updatedKit = await kitRepo.getActiveKit();
      expect(updatedKit, isNotNull);
      expect(updatedKit!.currentHp, lessThan(500));
      // 3. CraftLog was created and persisted offline
      final logs = await logRepo.getAllLogs();
      expect(logs, isNotEmpty);
      expect(logs.first.kitId, 'bg-timer-kit');
      expect(logs.first.isCompletedSession, isTrue);

      // Skip rest and return to idle
      await tester.tap(find.text('略過休息 (提前開工)'));
      await tester.pump();
      expect(find.text('5秒測試'), findsOneWidget);
    });

    testWidgets('1.3: Active target mutation across route boundaries during battle', (
      WidgetTester tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kitAlpha = KitItem(
        id: 'target-alpha',
        title: 'RG Sazabi',
        grade: 'RG',
        totalHp: 800,
        currentHp: 800,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      final kitBeta = KitItem(
        id: 'target-beta',
        title: 'PG Unleashed RX-78-2',
        grade: 'PG',
        totalHp: 5000,
        currentHp: 5000,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );

      await kitRepo.saveKit(kitAlpha);
      await kitRepo.saveKit(kitBeta);
      await kitRepo.setActiveKit(kitAlpha.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      expect(find.textContaining('RG Sazabi'), findsWidgets);

      // Open Hangar
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Switch active target to kitBeta
      final setActiveBtn = find.byKey(const Key('btn_set_active_target-beta'));
      expect(setActiveBtn, findsOneWidget);
      await tester.tap(setActiveBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Pop back to Battle
      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Invariant: Battle screen immediately re-hydrates to target-beta
      expect(find.textContaining('PG Unleashed RX-78-2'), findsWidgets);
      expect(find.textContaining('5000 / 5000 HP'), findsOneWidget);
      expect(find.text('🎯 已鎖定新討伐目標！請選擇工序開工。'), findsOneWidget);

      final activeKit = await kitRepo.getActiveKit();
      expect(activeKit!.id, 'target-beta');
    });

    testWidgets('1.4: Mid-flight combat juice animations survive rapid navigation interruption', (
      WidgetTester tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Start debug timer
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Trigger hit juice by interrupting session (Mercy Rule)
      await tester.tap(find.text('中途中斷 (結算 50% 保底傷害)'));
      // Pump partially into animation (50ms - screen shake & floating damage mid-flight)
      await tester.pump(const Duration(milliseconds: 50));

      // Immediately navigate to ShowcaseScreen mid-shake
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ShowcaseScreen), findsOneWidget);

      // Pop back to BattleAtelierScreen
      await tester.tap(find.byKey(const Key('btn_showcase_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify no assertion error or unhandled ticker exception
      expect(find.byType(BattleAtelierScreen), findsOneWidget);
    });

    testWidgets('1.5: Boss defeat transition to Showcase and Hangar synchronization', (
      WidgetTester tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      // Create a near-death boss with 10 HP
      final dyingBoss = KitItem(
        id: 'dying-boss',
        title: 'SD Knight Gundam',
        grade: 'EG',
        totalHp: 300,
        currentHp: 10,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      final backlogKit = KitItem(
        id: 'backlog-kit',
        title: 'HG Calibarn',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );

      await kitRepo.saveKit(dyingBoss);
      await kitRepo.saveKit(backlogKit);
      await kitRepo.setActiveKit(dyingBoss.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Finishing is available because HP (10/300 = 3.3%) <= 20%
      await tester.tap(find.text('水貼\n2.5x'));
      await tester.pump();

      // Start 5s timer and complete it
      await tester.tap(find.text('5秒測試'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));

      // Quest Clear dialog appears
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);

      // Navigate to Showcase from dialog
      expect(find.byKey(const Key('btn_clear_to_showcase')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_clear_to_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify ShowcaseScreen shows completed SD Knight Gundam
      expect(find.byType(ShowcaseScreen), findsOneWidget);
      expect(find.text('SD Knight Gundam'), findsWidgets);

      // Pop back to Battle
      await tester.tap(find.byKey(const Key('btn_showcase_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Navigate to Hangar to verify kit status
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Kit in Hangar
      final completedBoss = (await kitRepo.getAllKits()).firstWhere((k) => k.id == 'dying-boss');
      expect(completedBoss.isCompleted, isTrue);
      expect(completedBoss.currentHp, 0);

      // Pop back to Battle
      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(BattleAtelierScreen), findsOneWidget);
    });

    testWidgets('1.6: Button spam & rapid double tap handling without navigation crashes', (
      WidgetTester tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Rapidly tap Hangar button 3 times in quick succession with warnIfMissed: false
      final hangarBtn = find.byKey(const Key('btn_hangar'));
      await tester.tap(hangarBtn, warnIfMissed: false);
      await tester.tap(hangarBtn, warnIfMissed: false);
      await tester.tap(hangarBtn, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(HangarScreen), findsOneWidget);

      // Pop back safely
      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(BattleAtelierScreen), findsOneWidget);
    });
  });

  // =========================================================================
  // Group 2: Concurrent Repository Transactions & Data Race Invariants
  // =========================================================================
  group('Adversarial Challenge 2: Concurrent Transactions & Zero Data Loss', () {
    test('2.1: Mass concurrent writes on KitRepository guarantees zero data loss', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);

      const int writeCount = 50;
      const int readCount = 20;

      // Generate 50 unique kits
      final List<KitItem> testKits = List.generate(
        writeCount,
        (i) => KitItem(
          id: 'concurrent-kit-$i',
          title: 'Concurrent Kit #$i',
          grade: 'HG',
          totalHp: 500 + i * 10,
          currentHp: 500 + i * 10,
          status: KitStatus.unstarted,
          createdAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
        ),
      );

      // Concurrently dispatch 50 writes and 20 reads in parallel
      final writeFutures = testKits.map((kit) => kitRepo.saveKit(kit)).toList();
      final readFutures = List.generate(
        readCount,
        (_) => kitRepo.getAllKits(),
      );

      // Interleaved execution via Future.wait
      await Future.wait([
        ...writeFutures,
        ...readFutures,
      ]);

      // Read back all kits
      final allKits = await kitRepo.getAllKits();
      final allKitIds = allKits.map((k) => k.id).toSet();

      // Zero Data Loss Verification:
      // Every single kit from testKits must exist in the repository
      for (final expectedKit in testKits) {
        expect(allKitIds.contains(expectedKit.id), isTrue,
            reason: 'Kit ${expectedKit.id} must be persisted without loss');
      }

      // Verify raw storage also has all 50 items (+ optional seed kit)
      final rawList = await storage.getJsonList(StorageKeys.kits);
      final rawIds = rawList.map((m) => m['id']).toSet();
      for (final expectedKit in testKits) {
        expect(rawIds.contains(expectedKit.id), isTrue,
            reason: 'Storage must contain kit ${expectedKit.id}');
      }
    });

    test('2.2: Mass concurrent writes on CraftLogRepository guarantees zero log loss & order integrity', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);

      const int logCount = 100;
      const int queryCount = 25;

      final testLogs = List.generate(
        logCount,
        (i) => CraftLog(
          id: 'log-concurrent-$i',
          kitId: 'kit-${i % 5}',
          phase: CraftPhases.all[i % CraftPhases.all.length],
          durationMinutes: 25,
          damageDealt: 250 + i,
          isCompletedSession: i % 2 == 0,
          timestamp: DateTime(2026, 3, 1, 10).add(Duration(seconds: i)),
        ),
      );

      // Concurrently fire 100 log writes and 25 queries
      final writeFutures = testLogs.map((log) => logRepo.addLog(log)).toList();
      final queryFutures = List.generate(
        queryCount,
        (q) => (q % 2 == 0)
            ? logRepo.getAllLogs()
            : logRepo.getLogsForKit('kit-${q % 5}'),
      );

      await Future.wait([
        ...writeFutures,
        ...queryFutures,
      ]);

      // Verify all 100 logs are persisted
      final storedLogs = await logRepo.getAllLogs();
      expect(storedLogs.length, equals(logCount),
          reason: 'Zero log loss: exactly 100 logs must be stored');

      final storedIds = storedLogs.map((l) => l.id).toSet();
      expect(storedIds.length, equals(logCount),
          reason: 'All 100 unique log IDs must be present');

      // Verify raw storage contains all 100 logs
      final rawList = await storage.getJsonList(StorageKeys.craftLogs);
      expect(rawList.length, equals(logCount));

      // Verify newest-first order invariant:
      // Each adjacent pair must be sorted non-increasing by timestamp
      for (int i = 0; i < storedLogs.length - 1; i++) {
        expect(
          storedLogs[i].createdAt.isAfter(storedLogs[i + 1].createdAt) ||
              storedLogs[i].createdAt.isAtSameMomentAs(storedLogs[i + 1].createdAt),
          isTrue,
          reason: 'Craft logs must remain sorted newest first',
        );
      }
    });

    test('2.3: Interleaved concurrent cascade deletions and cross-kit log additions maintain referential integrity', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      // Seed 10 kits, each with 5 logs
      for (int i = 0; i < 10; i++) {
        final kitId = 'cascade-kit-$i';
        await kitRepo.saveKit(KitItem(
          id: kitId,
          title: 'Cascade Kit #$i',
          grade: 'HG',
          totalHp: 500,
          currentHp: 500,
          status: KitStatus.inProgress,
          createdAt: DateTime(2026, 1, 1),
        ));

        for (int l = 0; l < 5; l++) {
          await logRepo.addLog(CraftLog(
            id: 'log-$kitId-$l',
            kitId: kitId,
            phase: CraftPhases.snapFit,
            durationMinutes: 25,
            damageDealt: 100,
            isCompletedSession: true,
            timestamp: DateTime(2026, 1, 1, 12, l),
          ));
        }
      }

      final initialLogs = await logRepo.getAllLogs();
      expect(initialLogs.length, equals(50));

      // Concurrently:
      // 1. Delete kit-0, kit-1, kit-2 (which triggers cascade deletion of their 15 logs)
      // 2. Add new logs to kit-3, kit-4, kit-5 (3 new logs each = 9 logs)
      // 3. Update HP on kit-6, kit-7
      // 4. Concurrently query both repositories
      final futures = <Future<dynamic>>[];

      futures.add(kitRepo.deleteKit('cascade-kit-0'));
      futures.add(kitRepo.deleteKit('cascade-kit-1'));
      futures.add(kitRepo.deleteKit('cascade-kit-2'));

      for (int k = 3; k <= 5; k++) {
        for (int n = 0; n < 3; n++) {
          futures.add(logRepo.addLog(CraftLog(
            id: 'new-log-cascade-kit-$k-$n',
            kitId: 'cascade-kit-$k',
            phase: CraftPhases.airbrush,
            durationMinutes: 25,
            damageDealt: 200,
            isCompletedSession: true,
            timestamp: DateTime(2026, 2, 1, 10, n),
          )));
        }
      }

      futures.add(kitRepo.saveKit(KitItem(
        id: 'cascade-kit-6',
        title: 'Cascade Kit #6 (Updated)',
        grade: 'RG',
        totalHp: 800,
        currentHp: 350,
        status: KitStatus.inProgress,
        createdAt: DateTime(2026, 1, 1),
      )));

      // Concurrent queries during the operation
      futures.add(kitRepo.getAllKits());
      futures.add(logRepo.getAllLogs());

      await Future.wait(futures);

      // Invariants:
      // 1. Kits 0, 1, 2 are completely removed
      final remainingKits = await kitRepo.getAllKits();
      final remainingKitIds = remainingKits.map((k) => k.id).toSet();
      expect(remainingKitIds.contains('cascade-kit-0'), isFalse);
      expect(remainingKitIds.contains('cascade-kit-1'), isFalse);
      expect(remainingKitIds.contains('cascade-kit-2'), isFalse);

      // 2. Cascade deletion removed logs for kits 0, 1, 2
      final remainingLogs = await logRepo.getAllLogs();
      for (final log in remainingLogs) {
        expect(log.kitId != 'cascade-kit-0', isTrue);
        expect(log.kitId != 'cascade-kit-1', isTrue);
        expect(log.kitId != 'cascade-kit-2', isTrue);
      }

      // 3. Kits 3, 4, 5 retained their original 5 logs + 3 new logs = 8 logs each
      for (int k = 3; k <= 5; k++) {
        final kitLogs = await logRepo.getLogsForKit('cascade-kit-$k');
        expect(kitLogs.length, equals(8),
            reason: 'cascade-kit-$k should have exactly 8 logs (5 old + 3 new)');
      }

      // 4. Kits 6, 7, 8, 9 retained their 5 logs
      for (int k = 6; k <= 9; k++) {
        final kitLogs = await logRepo.getLogsForKit('cascade-kit-$k');
        expect(kitLogs.length, equals(5));
      }
    });

    test('2.4: Active kit deletion under concurrent query returns valid deterministic successor', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kit1 = KitItem(id: 'active-del-1', title: 'Target 1', grade: 'HG', totalHp: 500, currentHp: 500, status: KitStatus.inProgress, createdAt: DateTime.now());
      final kit2 = KitItem(id: 'active-del-2', title: 'Target 2', grade: 'MG', totalHp: 1000, currentHp: 1000, status: KitStatus.unstarted, createdAt: DateTime.now());
      final kit3 = KitItem(id: 'active-del-3', title: 'Target 3', grade: 'PG', totalHp: 5000, currentHp: 5000, status: KitStatus.unstarted, createdAt: DateTime.now());

      await kitRepo.saveKit(kit1);
      await kitRepo.saveKit(kit2);
      await kitRepo.saveKit(kit3);
      await kitRepo.setActiveKit(kit1.id);

      // While deleting active kit1, concurrently query active kit
      final results = await Future.wait([
        kitRepo.deleteKit(kit1.id),
        kitRepo.getActiveKit(),
        kitRepo.getAllKits(),
      ]);

      final activeAfter = await kitRepo.getActiveKit();
      expect(activeAfter, isNotNull);
      expect(activeAfter!.id, isNot('active-del-1'));
      // Must be either kit2 or kit3
      expect(['active-del-2', 'active-del-3'].contains(activeAfter.id), isTrue);

      // Verify the concurrent getActiveKit call did not return a corrupted state
      final concurrentActive = results[1] as KitItem?;
      expect(concurrentActive, isNotNull);
    });

    test('2.5: Multi-instance repository cache re-hydration consistency', () async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);

      // Two independent repository instances sharing the same persistent storage
      final repoInstanceA = KitRepository(storage);
      final repoInstanceB = KitRepository(storage);

      // Instance A saves 10 kits
      for (int i = 0; i < 10; i++) {
        await repoInstanceA.saveKit(KitItem(
          id: 'shared-kit-$i',
          title: 'Shared Kit #$i',
          grade: 'HG',
          totalHp: 600,
          currentHp: 600,
          status: KitStatus.unstarted,
          createdAt: DateTime.now(),
        ));
      }

      // Instance B invalidates cache and reads
      repoInstanceB.clearCache();
      final kitsB = await repoInstanceB.getAllKits();
      expect(kitsB.where((k) => k.id.startsWith('shared-kit-')).length, equals(10));

      // Instance B updates kit 0
      final kit0 = kitsB.firstWhere((k) => k.id == 'shared-kit-0');
      await repoInstanceB.saveKit(kit0.copyWith(currentHp: 200, status: KitStatus.inProgress));

      // Instance A invalidates cache and reads
      repoInstanceA.clearCache();
      final kitsA = await repoInstanceA.getAllKits();
      final updatedKit0InA = kitsA.firstWhere((k) => k.id == 'shared-kit-0');
      expect(updatedKit0InA.currentHp, equals(200));
      expect(updatedKit0InA.status, equals(KitStatus.inProgress));
    });
  });
}
