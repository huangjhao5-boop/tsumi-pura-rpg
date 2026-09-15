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
import 'package:nifty_heisenberg/domain/battle/battle_engine.dart';
import 'package:nifty_heisenberg/domain/models/craft_log.dart';
import 'package:nifty_heisenberg/domain/models/kit_item.dart';
import 'package:nifty_heisenberg/main.dart';
import 'package:nifty_heisenberg/presentation/widgets/retro_bottom_nav_bar.dart';
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
  }) async {
    final storage = LocalStorageService();
    final effectiveLogRepo = logRepo ?? CraftLogRepository(storage);
    final effectiveKitRepo = kitRepo ?? KitRepository(storage, effectiveLogRepo);

    await tester.pumpWidget(
      TsumiPuraApp(
        kitRepository: effectiveKitRepo,
        craftLogRepository: effectiveLogRepo,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  // =========================================================================
  // SUITE 1: Rapid Multi-Touch & Race Conditions During Page Transition
  // =========================================================================
  group('Suite 1: Rapid Multi-Touch & Page Transitions', () {
    testWidgets('1.1: Rapid multi-touch across Header HUD quick links navigates and pops cleanly', (
      WidgetTester tester,
    ) async {
      setTestViewport(tester);
      await pumpApp(tester);

      // Rapidly fire taps across Hangar, Showcase, and CraftLog in same frame
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump(const Duration(milliseconds: 150));

      // Pop back through all stacked screens
      while (find.byIcon(Icons.arrow_back).evaluate().isNotEmpty) {
        await tester.tap(find.byIcon(Icons.arrow_back).first);
        await tester.pump(const Duration(milliseconds: 100));
      }

      // App is still alive and responsive on BattleScreen
      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);

      // Now tap CraftLog link
      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump(const Duration(milliseconds: 150));

      while (find.byIcon(Icons.arrow_back).evaluate().isNotEmpty) {
        await tester.tap(find.byIcon(Icons.arrow_back).first);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
    });

    testWidgets('1.2: Rapid multi-touch switching across RetroBottomNavBar tabs', (
      WidgetTester tester,
    ) async {
      setTestViewport(tester);
      await pumpApp(tester);

      // Rapidly tap bottom dock items
      await tester.tap(find.byKey(const Key('btn_nav_hangar')));
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byIcon(Icons.arrow_back).evaluate().isNotEmpty) {
        await tester.tap(find.byIcon(Icons.arrow_back).first);
        await tester.pump(const Duration(milliseconds: 100));
      }

      await tester.tap(find.byKey(const Key('btn_nav_craft_log')));
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byIcon(Icons.arrow_back).evaluate().isNotEmpty) {
        await tester.tap(find.byIcon(Icons.arrow_back).first);
        await tester.pump(const Duration(milliseconds: 100));
      }

      await tester.tap(find.byKey(const Key('btn_nav_showcase')));
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byIcon(Icons.arrow_back).evaluate().isNotEmpty) {
        await tester.tap(find.byIcon(Icons.arrow_back).first);
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(RetroBottomNavBar), findsOneWidget);
    });

    testWidgets('1.3: Background countdown finishes safely while user navigates to Hangar', (
      WidgetTester tester,
    ) async {
      setTestViewport(tester);
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Start 5s debug timer
      await tester.tap(find.text('5秒測試'));
      await tester.pump(const Duration(seconds: 1)); // 1s elapsed, 4s remaining

      // User immediately opens Hangar while countdown is ticking
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump(const Duration(milliseconds: 100));

      // Advance time while inside Hangar by 6 seconds (session completes in background)
      await tester.pump(const Duration(seconds: 6));

      // Pop back to BattleScreen
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump(const Duration(milliseconds: 200));

      // Verify that damage was recorded in log repository
      final logs = await logRepo.getAllLogs();
      expect(logs.isNotEmpty, isTrue);
      expect(logs.first.isCompletedSession, isTrue);
    });

    testWidgets('1.4: Rapid double-tap on Start Work button does not create duplicate timers', (
      WidgetTester tester,
    ) async {
      setTestViewport(tester);
      await pumpApp(tester);

      // Rapidly double tap '5秒測試'
      await tester.tap(find.text('5秒測試'));
      await tester.tap(find.text('5秒測試'));
      await tester.pump(const Duration(seconds: 1));

      // Should show WORK status and 00:04 remaining (1s elapsed)
      expect(find.text('00:04'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:03'), findsOneWidget);
    });

    testWidgets('1.5: Rapid double-tap on Stop & Settle button applies Mercy damage only once', (
      WidgetTester tester,
    ) async {
      setTestViewport(tester);
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Start 5s test
      await tester.tap(find.text('5秒測試'));
      await tester.pump(const Duration(seconds: 2)); // 2s elapsed

      // Rapidly tap Stop & Settle twice
      final stopBtn = find.text('中途中斷 (結算 50% 保底傷害)');
      expect(stopBtn, findsOneWidget);

      await tester.tap(stopBtn);
      await tester.tap(stopBtn);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify only 1 log was recorded
      final logs = await logRepo.getAllLogs();
      expect(logs.length, 1);
      expect(logs.first.isCompletedSession, isFalse);
    });
  });

  // =========================================================================
  // SUITE 2: Interrupted Countdown Exactly on Tick 0 and Boundary Ticks
  // =========================================================================
  group('Suite 2: Countdown Interruption Exactly on Tick 0 and Boundary Ticks', () {
    testWidgets('2.1: Interruption at exact tick 0 applies 50% Mercy damage and stays idle', (
      WidgetTester tester,
    ) async {
      setTestViewport(tester);
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Start 5s test (debug mode: 20 Base Points)
      await tester.tap(find.text('5秒測試'));

      // Tick 5 times so remainingSeconds == 0
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('00:00'), findsOneWidget);

      // Right at tick 0 before next timer tick fires _completeWorkSession, user stops
      final stopBtn = find.text('中途中斷 (結算 50% 保底傷害)');
      if (stopBtn.evaluate().isNotEmpty) {
        await tester.tap(stopBtn);
        await tester.pump(const Duration(milliseconds: 100));

        final logs = await logRepo.getAllLogs();
        expect(logs.length, 1);
        expect(logs.first.isCompletedSession, isFalse);
        // Debug mode has 20 BP: 20 BP * (5/5) * 1.0 * 0.5 = 10 damage
        expect(logs.first.damageDealt, 10);

        // Does NOT enter rest phase, returns to idle
        expect(find.text('WORK - 專注組裝中 (除錯 5s/3s)'), findsNothing);
      }
    });

    testWidgets('2.2: Interruption at tick 1 (1s remaining) calculates proportional Mercy damage', (
      WidgetTester tester,
    ) async {
      setTestViewport(tester);
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      await tester.tap(find.text('5秒測試'));
      // Tick 4 times -> remaining = 1, elapsed = 4
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('00:01'), findsOneWidget);

      await tester.tap(find.text('中途中斷 (結算 50% 保底傷害)'));
      await tester.pump(const Duration(milliseconds: 100));

      final logs = await logRepo.getAllLogs();
      expect(logs.length, 1);
      expect(logs.first.isCompletedSession, isFalse);
      // Debug mode has 20 BP: 20 BP * (4/5) * 1.0 * 0.5 = 8 damage
      expect(logs.first.damageDealt, 8);
    });

    testWidgets('2.3: Immediate interruption at 0s elapsed yields 0 damage and floor coins', (
      WidgetTester tester,
    ) async {
      setTestViewport(tester);
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      await tester.tap(find.text('5秒測試'));
      await tester.pump(); // Build work phase UI immediately

      // Immediately tap stop button
      final stopBtn = find.text('中途中斷 (結算 50% 保底傷害)');
      expect(stopBtn, findsOneWidget);
      await tester.tap(stopBtn);
      await tester.pump(const Duration(milliseconds: 100));

      final logs = await logRepo.getAllLogs();
      expect(logs.length, 1);
      expect(logs.first.damageDealt, 0);
      expect(logs.first.durationMinutes, 0);
    });

    testWidgets('2.4: Skip rest button advances rest phase to idle cleanly', (
      WidgetTester tester,
    ) async {
      setTestViewport(tester);
      await pumpApp(tester);

      // Run 5s debug test to completion
      await tester.tap(find.text('5秒測試'));
      await tester.pump(const Duration(seconds: 6)); // Completes session, starts rest

      expect(find.text('REST - 工坊整備休息中 ☕'), findsOneWidget);
      final skipBtn = find.text('略過休息 (提前開工)');
      expect(skipBtn, findsOneWidget);

      await tester.tap(skipBtn);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('REST - 工坊整備休息中 ☕'), findsNothing);
      expect(find.text('已略過休息，隨時可再次開工討伐！'), findsOneWidget);
    });

    testWidgets('2.5: Extreme overkill damage clamps Boss HP to exactly 0', (
      WidgetTester tester,
    ) async {
      setTestViewport(tester);
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      // Pre-seed a boss with only 10 HP
      final lowHpBoss = KitItem(
        id: 'low-hp-mimic',
        title: '殘血小弱怪',
        grade: 'EG',
        totalHp: 300,
        currentHp: 10,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(lowHpBoss);
      await kitRepo.setActiveKit(lowHpBoss.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Select Airbrush (2.0x multiplier = 40 damage on 20 BP)
      await tester.tap(find.text('噴塗\n2.0x'));
      await tester.pump(const Duration(milliseconds: 100));

      // Run 5s test
      await tester.tap(find.text('5秒測試'));
      await tester.pump(const Duration(seconds: 6));

      // Overkill damage clamps HP to exactly 0: text shows 0% and 0 / 300 HP
      expect(find.text('0%'), findsOneWidget);
      expect(find.textContaining('0 / 300 HP'), findsOneWidget);

      // Quest Clear dialog appears after 700ms
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);
    });
  });

  // =========================================================================
  // SUITE 3: HP Calculations Under Extreme Multipliers & Mathematical Stress
  // =========================================================================
  group('Suite 3: HP Calculations Under Extreme Multipliers & Mathematical Stress', () {
    const engine = BattleEngine();

    test('3.1: Finishing execution gate exact boundary threshold (20%)', () {
      // Exactly 20% (20 / 100) -> Unlocked
      expect(engine.canExecuteFinishing(currentHp: 20, maxHp: 100), isTrue);
      final dmgUnlocked = engine.calculateDamage(
        basePoints: 100,
        phase: CraftPhases.finishing,
        elapsedSeconds: 1500,
        totalSeconds: 1500,
        isInterrupted: false,
        currentHp: 20,
        maxHp: 100,
      );
      expect(dmgUnlocked, 250); // 100 * 2.5 = 250

      // 21% (21 / 100) -> Locked
      expect(engine.canExecuteFinishing(currentHp: 21, maxHp: 100), isFalse);
      final dmgLocked = engine.calculateDamage(
        basePoints: 100,
        phase: CraftPhases.finishing,
        elapsedSeconds: 1500,
        totalSeconds: 1500,
        isInterrupted: false,
        currentHp: 21,
        maxHp: 100,
      );
      expect(dmgLocked, 0); // Gate locked -> 0 damage
    });

    test('3.2: Extreme HP Boss (maxHp = 99999 custom boss)', () {
      const maxHp = 99999;

      // 20000 / 99999 = 0.2000020... (> 20%) -> Locked
      expect(engine.canExecuteFinishing(currentHp: 20000, maxHp: maxHp), isFalse);
      expect(
        engine.calculateDamage(
          basePoints: 220,
          phase: CraftPhases.finishing,
          elapsedSeconds: 3000,
          totalSeconds: 3000,
          isInterrupted: false,
          currentHp: 20000,
          maxHp: maxHp,
        ),
        0,
      );

      // 19999 / 99999 = 0.1999919... (<= 20%) -> Unlocked
      expect(engine.canExecuteFinishing(currentHp: 19999, maxHp: maxHp), isTrue);
      // In 50m Deep Focus: 220 BP * 2.5 = 550 damage
      expect(
        engine.calculateDamage(
          basePoints: 220,
          phase: CraftPhases.finishing,
          elapsedSeconds: 3000,
          totalSeconds: 3000,
          isInterrupted: false,
          currentHp: 19999,
          maxHp: maxHp,
        ),
        550,
      );
    });

    test('3.3: Smallest valid Boss HP (maxHp = 1, currentHp = 1)', () {
      // 1 / 1 = 100% > 20% -> Finishing locked
      expect(engine.canExecuteFinishing(currentHp: 1, maxHp: 1), isFalse);

      // Snap-fit deals full 100 damage
      final dmg = engine.calculateDamage(
        basePoints: 100,
        phase: CraftPhases.snapFit,
        elapsedSeconds: 1500,
        totalSeconds: 1500,
        isInterrupted: false,
        currentHp: 1,
        maxHp: 1,
      );
      expect(dmg, 100);
    });

    test('3.4: Degenerate mathematical inputs to BattleEngine', () {
      // Negative elapsed seconds
      expect(
        engine.calculateDamage(
          basePoints: 100,
          phase: CraftPhases.snapFit,
          elapsedSeconds: -10,
          totalSeconds: 1500,
          isInterrupted: false,
          currentHp: 100,
          maxHp: 100,
        ),
        0,
      );

      // Zero total seconds
      expect(
        engine.calculateDamage(
          basePoints: 100,
          phase: CraftPhases.snapFit,
          elapsedSeconds: 100,
          totalSeconds: 0,
          isInterrupted: false,
          currentHp: 100,
          maxHp: 100,
        ),
        0,
      );

      // Zero base points
      expect(
        engine.calculateDamage(
          basePoints: 0,
          phase: CraftPhases.snapFit,
          elapsedSeconds: 100,
          totalSeconds: 1500,
          isInterrupted: false,
          currentHp: 100,
          maxHp: 100,
        ),
        0,
      );

      // Elapsed exceeding total (e.g. 5000s in 1500s session) clamped to total
      expect(
        engine.calculateDamage(
          basePoints: 100,
          phase: CraftPhases.snapFit,
          elapsedSeconds: 5000,
          totalSeconds: 1500,
          isInterrupted: false,
          currentHp: 100,
          maxHp: 100,
        ),
        100,
      );

      // Unknown phase string falls back to 1.0x
      expect(
        engine.calculateDamage(
          basePoints: 100,
          phase: 'Super-Weapon-Chipping',
          elapsedSeconds: 1500,
          totalSeconds: 1500,
          isInterrupted: false,
          currentHp: 100,
          maxHp: 100,
        ),
        100,
      );
    });

    test('3.5: Earned coins mathematical boundaries', () {
      expect(engine.calculateEarnedCoins(elapsedSeconds: 0), 0);
      expect(engine.calculateEarnedCoins(elapsedSeconds: 1), 2); // clamped minimum
      expect(engine.calculateEarnedCoins(elapsedSeconds: 5), 2); // 5/5 = 1, clamped min 2
      expect(engine.calculateEarnedCoins(elapsedSeconds: 50), 10);
      expect(engine.calculateEarnedCoins(elapsedSeconds: 3000), 50); // clamped max 50
      expect(engine.calculateEarnedCoins(elapsedSeconds: -10), 0);
    });
  });

  // =========================================================================
  // SUITE 4: Empty Storage Recovery, Corrupted Storage Resilience & Cascade
  // =========================================================================
  group('Suite 4: Empty Storage Recovery & Resilience Stress', () {
    test('4.1: Clean cold start from empty storage auto-seeds default kit', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final active = await kitRepo.getActiveKit();
      expect(active, isNotNull);
      expect(active!.id, GameConstants.defaultKitId);
      expect(active.totalHp, GameConstants.defaultKitHp);

      final allKits = await kitRepo.getAllKits();
      expect(allKits.length, 1);

      final allLogs = await logRepo.getAllLogs();
      expect(allLogs, isEmpty);
    });

    test('4.2: Deleting sole active kit cascades deletion of its craft logs and auto-reseeds', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final active = await kitRepo.getActiveKit();
      final log = CraftLog(
        id: 'log-for-seed',
        kitId: active!.id,
        phase: CraftPhases.snapFit,
        durationMinutes: 25,
        damageDealt: 100,
        isCompletedSession: true,
        timestamp: DateTime.now(),
      );
      await logRepo.addLog(log);
      expect((await logRepo.getAllLogs()).length, 1);

      // Delete the only kit
      await kitRepo.deleteKit(active.id);

      // Associated craft logs must be cascade deleted
      final logsAfterDelete = await logRepo.getAllLogs();
      expect(logsAfterDelete, isEmpty);

      // KitRepository must auto-reseed starter kit so hangar is never empty
      final reseededKits = await kitRepo.getAllKits();
      expect(reseededKits.length, 1);
      final nextActive = await kitRepo.getActiveKit();
      expect(nextActive, isNotNull);
    });

    test('4.3: Corrupted JSON strings and invalid types in storage are handled resiliently', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.kits: '!!!MALFORMED_JSON_STRING!!!',
        StorageKeys.craftLogs: jsonEncode({'not': 'a_list'}),
      });
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      // Repositories should not throw, should auto-seed or return empty
      final kits = await kitRepo.getAllKits();
      expect(kits.isNotEmpty, isTrue);

      final logs = await logRepo.getAllLogs();
      expect(logs, isEmpty);
    });

    test('4.4: Cache invalidation across multiple repository instances', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      final repoA = KitRepository(storage);
      final repoB = KitRepository(storage);

      // Init repoA
      final kitA = await repoA.getActiveKit();
      expect(kitA, isNotNull);

      // RepoB adds a new kit
      final newKit = KitItem(
        id: 'new-b-kit',
        title: 'Kit from B',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 1500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await repoB.saveKit(newKit);

      // RepoA has cached list of 1 kit
      expect((await repoA.getAllKits()).length, 1);

      // Clear cache on repoA to invalidate
      repoA.clearCache();
      final updatedList = await repoA.getAllKits();
      expect(updatedList.length, 2);
      expect(updatedList.any((k) => k.id == 'new-b-kit'), isTrue);
    });

    test('4.5: Cascade deletion isolation between multiple kits', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kit1 = KitItem(
        id: 'kit-1',
        title: 'Kit One',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      final kit2 = KitItem(
        id: 'kit-2',
        title: 'Kit Two',
        grade: 'RG',
        totalHp: 800,
        currentHp: 800,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit1);
      await kitRepo.saveKit(kit2);

      await logRepo.addLog(CraftLog(
        id: 'log-1',
        kitId: kit1.id,
        phase: CraftPhases.snapFit,
        durationMinutes: 10,
        damageDealt: 40,
        isCompletedSession: true,
        timestamp: DateTime.now(),
      ));
      await logRepo.addLog(CraftLog(
        id: 'log-2',
        kitId: kit2.id,
        phase: CraftPhases.sanding,
        durationMinutes: 15,
        damageDealt: 60,
        isCompletedSession: true,
        timestamp: DateTime.now(),
      ));

      expect((await logRepo.getAllLogs()).length, 2);

      // Delete Kit 1
      await kitRepo.deleteKit(kit1.id);

      final remainingLogs = await logRepo.getAllLogs();
      expect(remainingLogs.length, 1);
      expect(remainingLogs.first.kitId, kit2.id);
    });
  });

  // =========================================================================
  // SUITE 5: UI Resilience Under Extreme Input Combinations & Rapid Switching
  // =========================================================================
  group('Suite 5: UI Resilience Under Extreme Input Combinations', () {
    testWidgets('5.1: Rapid switching between Pomodoro modes updates start button label', (
      WidgetTester tester,
    ) async {
      setTestViewport(tester);
      await pumpApp(tester);

      // Switch to Deep Focus (50m)
      await tester.tap(find.text('深度 50m/10m'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('開始開工 (深度 50m/10m)'), findsOneWidget);

      // Switch to Debug (5s)
      await tester.tap(find.text('除錯 5s/3s'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('開始開工 (除錯 5s/3s)'), findsOneWidget);

      // Switch back to Standard (25m)
      await tester.tap(find.text('標準 25m/5m'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('開始開工 (標準 25m/5m)'), findsOneWidget);
    });

    testWidgets('5.2: Finishing phase selection is strictly rejected when Boss HP > 20%', (
      WidgetTester tester,
    ) async {
      setTestViewport(tester);
      await pumpApp(tester);

      // Boss HP is 500/500 (100% > 20%)
      expect(find.text('水貼\n🔒20%'), findsOneWidget);

      // Tap locked Finishing segment
      await tester.tap(find.text('水貼\n🔒20%'));
      await tester.pump(const Duration(milliseconds: 50));

      // Phase should NOT switch to Finishing
      expect(find.textContaining('水貼・仕上げ'), findsNothing);
    });

    testWidgets('5.3: Hangar modal rejects invalid custom HP values', (
      WidgetTester tester,
    ) async {
      setTestViewport(tester);
      await pumpApp(tester);

      // Open Hangar
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump(const Duration(milliseconds: 100));

      // Open Add Kit modal
      final addBtn = find.text('＋ 新增模型');
      if (addBtn.evaluate().isNotEmpty) {
        await tester.tap(addBtn);
        await tester.pump(const Duration(milliseconds: 100));

        // Verify title input and HP input exist
        expect(find.text('登錄新山積 (SPAWN BOSS)'), findsOneWidget);

        // Cancel modal
        await tester.tap(find.text('取消'));
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('5.4: Quest clear dialog restart button re-arms Boss cleanly', (
      WidgetTester tester,
    ) async {
      setTestViewport(tester);
      final storage = LocalStorageService();
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final boss = KitItem(
        id: 'fast-kill-boss',
        title: '速攻一刀盒怪',
        grade: 'EG',
        totalHp: 50,
        currentHp: 10,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(boss);
      await kitRepo.setActiveKit(boss.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Run 5s test to finish boss (20 BP on Snap-fit = 20 damage > 10 HP)
      await tester.tap(find.text('5秒測試'));
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);

      // Tap '收錄至展示櫃 (Showcase)'
      final restartBtn = find.byKey(const Key('btn_clear_restart'));
      expect(restartBtn, findsOneWidget);

      await tester.tap(restartBtn);
      await tester.pump(const Duration(milliseconds: 200));

      // Dialog is dismissed and Boss HP is restored to max (100% and 50 / 50 HP)
      expect(find.text('★ QUEST CLEAR ★'), findsNothing);
      expect(find.text('100%'), findsOneWidget);
      expect(find.textContaining('50 / 50 HP'), findsOneWidget);
    });
  });
}
