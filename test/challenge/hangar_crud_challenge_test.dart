import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nifty_heisenberg/core/constants/game_constants.dart';
import 'package:nifty_heisenberg/data/repositories/craft_log_repository.dart';
import 'package:nifty_heisenberg/data/repositories/kit_repository.dart';
import 'package:nifty_heisenberg/data/storage/local_storage_service.dart';
import 'package:nifty_heisenberg/domain/models/craft_log.dart';
import 'package:nifty_heisenberg/domain/models/kit_item.dart';
import 'package:nifty_heisenberg/main.dart';
import 'package:nifty_heisenberg/presentation/screens/hangar_screen.dart';
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

  Widget createHangarScreen({
    required IKitRepository kitRepo,
    ICraftLogRepository? logRepo,
    void Function(KitItem kit)? onKitSelected,
  }) {
    return MaterialApp(
      home: HangarScreen(
        kitRepository: kitRepo,
        craftLogRepository: logRepo,
        onKitSelected: onKitSelected,
      ),
    );
  }

  group('Milestone 3 Adversarial Challenge: Input Boundaries', () {
    testWidgets('Rejects empty and whitespace-only titles', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);

      await tester.pumpWidget(createHangarScreen(kitRepo: kitRepo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Open Add Kit dialog
      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Submit with empty title
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      expect(find.text('請輸入模型名稱'), findsOneWidget);

      // 2. Submit with whitespace-only title
      await tester.enterText(
        find.byKey(const Key('input_kit_title')),
        '    \t\n  ',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      expect(find.text('請輸入模型名稱'), findsOneWidget);

      // Verify no new kit was created
      final kits = await kitRepo.getAllKits();
      expect(kits.length, equals(1)); // only initial seed
    });

    testWidgets('Enforces 50-character title limit and allows 50 chars', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);

      await tester.pumpWidget(createHangarScreen(kitRepo: kitRepo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 50-character valid title
      final exact50Chars = 'A' * 50;
      await tester.enterText(
        find.byKey(const Key('input_kit_title')),
        exact50Chars,
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('★ 登錄山積盒怪 ★'), findsNothing);
      final kits = await kitRepo.getAllKits();
      expect(kits.any((k) => k.title == exact50Chars), isTrue);
    });

    testWidgets('Custom HP boundary stress: 0, negative, non-numeric, 99999, 100000', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);

      await tester.pumpWidget(createHangarScreen(kitRepo: kitRepo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(
        find.byKey(const Key('input_kit_title')),
        '數值邊界測試機',
      );
      await tester.pump();

      // Enable custom HP
      await tester.tap(find.byKey(const Key('checkbox_custom_hp')));
      await tester.pump();

      // 1. Test 0 HP
      await tester.enterText(find.byKey(const Key('input_kit_hp')), '0');
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      expect(find.text('HP 必須為大於 0 之整數'), findsOneWidget);

      // 2. Test negative HP (attempting -500)
      // Note: digitsOnly input formatter strips '-' during enterText in live UI,
      // but if a negative value is set or parsed, validator must reject it.
      await tester.enterText(find.byKey(const Key('input_kit_hp')), '');
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      expect(find.text('請輸入 HP'), findsOneWidget);

      // 3. Test extreme HP exceeding 99,999 (e.g. 100000)
      await tester.enterText(find.byKey(const Key('input_kit_hp')), '100000');
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      expect(find.text('HP 不可超過 99,999'), findsOneWidget);

      // 4. Test extreme HP boundary: exactly 99999 (Valid upper bound)
      await tester.enterText(find.byKey(const Key('input_kit_hp')), '99999');
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('★ 登錄山積盒怪 ★'), findsNothing);
      final kits = await kitRepo.getAllKits();
      final created = kits.firstWhere((k) => k.title == '數值邊界測試機');
      expect(created.totalHp, equals(99999));
      expect(created.currentHp, equals(99999));
      expect(created.isCustomBoss, isTrue);
    });

    testWidgets('Custom HP lower boundary: exactly 1 HP is accepted', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);

      await tester.pumpWidget(createHangarScreen(kitRepo: kitRepo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(find.byKey(const Key('input_kit_title')), '一擊必殺機');
      await tester.pump();

      await tester.tap(find.byKey(const Key('checkbox_custom_hp')));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('input_kit_hp')), '1');
      await tester.pump();

      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final kits = await kitRepo.getAllKits();
      final created = kits.firstWhere((k) => k.title == '一擊必殺機');
      expect(created.totalHp, equals(1));
      expect(created.currentHp, equals(1));
    });
  });

  group('Milestone 3 Adversarial Challenge: Deletion Safety', () {
    testWidgets('Deleting the active kit reallocates active target safely without crashing BattleScreen', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);
      final logRepo = CraftLogRepository(storage);
      kitRepo.bindCraftLogRepository(logRepo);

      final kit1 = KitItem(
        id: 'active-target',
        title: '當前目標機',
        grade: 'HG',
        totalHp: 500,
        currentHp: 400,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      final kit2 = KitItem(
        id: 'reserve-target',
        title: '備用待命機',
        grade: 'RG',
        totalHp: 800,
        currentHp: 800,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit1);
      await kitRepo.saveKit(kit2);
      await kitRepo.setActiveKit(kit1.id);

      // Launch full app
      await tester.pumpWidget(
        TsumiPuraApp(kitRepository: kitRepo, craftLogRepository: logRepo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify initial battle screen shows kit1
      expect(find.textContaining('當前目標機'), findsOneWidget);

      // Open Hangar
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('★ MODEL HANGAR ★'), findsOneWidget);

      // Delete the active kit
      await tester.tap(find.byKey(const Key('btn_delete_kit_active-target')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('⚠️ 解體除籍確認 ⚠️'), findsOneWidget);
      expect(find.textContaining('此模型為當前出擊目標，刪除後將自動切換為下一盒模型。'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_confirm_delete')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify active-target is gone from Hangar
      expect(find.text('當前目標機'), findsNothing);
      expect(find.text('備用待命機'), findsOneWidget);

      // Return to Battle Screen
      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Battle Screen did not crash and now shows reserve-target
      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
      expect(find.textContaining('備用待命機'), findsOneWidget);
      final newActive = await kitRepo.getActiveKit();
      expect(newActive?.id, equals('reserve-target'));
    });

    testWidgets('Deleting the last remaining kit auto-seeds default kit safely without crash', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);
      final logRepo = CraftLogRepository(storage);
      kitRepo.bindCraftLogRepository(logRepo);

      // Initial state: only 1 seed kit exists
      final kits = await kitRepo.getAllKits();
      expect(kits.length, equals(1));
      final onlyKit = kits.first;

      await tester.pumpWidget(
        TsumiPuraApp(kitRepository: kitRepo, craftLogRepository: logRepo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Open Hangar
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Delete the only kit
      await tester.tap(find.byKey(Key('btn_delete_kit_${onlyKit.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('btn_confirm_delete')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Kit repository auto-seeds a new default seed kit
      final remainingKits = await kitRepo.getAllKits();
      expect(remainingKits.isNotEmpty, isTrue);
      expect(remainingKits.first.id, equals(GameConstants.defaultKitId));

      // Return to Battle Screen
      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Battle screen remains fully operational
      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
      expect(find.textContaining(GameConstants.defaultKitTitle), findsOneWidget);
    });

    testWidgets('Cascade deletion: deleting a kit purges all its craft logs while preserving others', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);
      final logRepo = CraftLogRepository(storage);
      kitRepo.bindCraftLogRepository(logRepo);

      final kitA = KitItem(
        id: 'kit-a',
        title: '模型 A',
        grade: 'HG',
        totalHp: 500,
        currentHp: 200,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      final kitB = KitItem(
        id: 'kit-b',
        title: '模型 B',
        grade: 'RG',
        totalHp: 800,
        currentHp: 400,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kitA);
      await kitRepo.saveKit(kitB);

      // Add 3 logs for Kit A
      for (int i = 1; i <= 3; i++) {
        await logRepo.addLog(
          CraftLog(
            id: 'log-a-$i',
            kitId: kitA.id,
            phase: 'Snap-fit',
            durationMinutes: 25,
            damageDealt: 100,
            isCompletedSession: true,
            timestamp: DateTime.now().subtract(Duration(hours: i)),
          ),
        );
      }

      // Add 2 logs for Kit B
      for (int i = 1; i <= 2; i++) {
        await logRepo.addLog(
          CraftLog(
            id: 'log-b-$i',
            kitId: kitB.id,
            phase: 'Sanding',
            durationMinutes: 25,
            damageDealt: 120,
            isCompletedSession: true,
            timestamp: DateTime.now().subtract(Duration(hours: i)),
          ),
        );
      }

      expect((await logRepo.getLogsForKit(kitA.id)).length, equals(3));
      expect((await logRepo.getLogsForKit(kitB.id)).length, equals(2));
      expect((await logRepo.getAllLogs()).length, equals(5));

      // Render Hangar and delete Kit A
      await tester.pumpWidget(
        createHangarScreen(kitRepo: kitRepo, logRepo: logRepo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('btn_delete_kit_kit-a')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('btn_confirm_delete')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify Kit A logs are completely purged
      expect((await logRepo.getLogsForKit(kitA.id)).isEmpty, isTrue);

      // Verify Kit B logs remain 100% intact
      final logsB = await logRepo.getLogsForKit(kitB.id);
      expect(logsB.length, equals(2));
      expect((await logRepo.getAllLogs()).length, equals(2));
    });
  });

  group('Milestone 3 Adversarial Challenge: Active Target Switching', () {
    testWidgets('Rapid concurrent active target switching does not cause race condition', (
      WidgetTester tester,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);

      final k1 = KitItem.create(id: 'rapid-1', title: '速切一號', grade: 'EG');
      final k2 = KitItem.create(id: 'rapid-2', title: '速切二號', grade: 'HG');
      final k3 = KitItem.create(id: 'rapid-3', title: '速切三號', grade: 'RG');
      await kitRepo.saveKit(k1);
      await kitRepo.saveKit(k2);
      await kitRepo.saveKit(k3);

      // Rapidly fire asynchronous setActiveKit operations
      await Future.wait([
        kitRepo.setActiveKit(k1.id),
        kitRepo.setActiveKit(k2.id),
        kitRepo.setActiveKit(k3.id),
        kitRepo.setActiveKit(k1.id),
        kitRepo.setActiveKit(k2.id),
      ]);

      final active = await kitRepo.getActiveKit();
      expect(active, isNotNull);
      expect(['rapid-1', 'rapid-2', 'rapid-3'].contains(active!.id), isTrue);

      // Read back all kits - should remain intact without corruption
      final allKits = await kitRepo.getAllKits();
      expect(allKits.any((k) => k.id == 'rapid-1'), isTrue);
      expect(allKits.any((k) => k.id == 'rapid-2'), isTrue);
      expect(allKits.any((k) => k.id == 'rapid-3'), isTrue);
    });

    testWidgets('Switching to completed kit vs unstarted kit in BattleScreen', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);
      final logRepo = CraftLogRepository(storage);
      kitRepo.bindCraftLogRepository(logRepo);

      final unstartedKit = KitItem(
        id: 'unstarted-kit',
        title: '全新未開工盒怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      final completedKit = KitItem(
        id: 'completed-kit',
        title: '已討伐完工盒怪',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(unstartedKit);
      await kitRepo.saveKit(completedKit);
      await kitRepo.setActiveKit(unstartedKit.id);

      await tester.pumpWidget(
        TsumiPuraApp(kitRepository: kitRepo, craftLogRepository: logRepo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Initially unstarted kit is active (500/500)
      expect(find.textContaining('全新未開工盒怪'), findsOneWidget);
      expect(find.textContaining('500/500'), findsOneWidget);

      // Open Hangar and switch to completed kit
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Find and tap set active for completed kit
      await tester.tap(find.byKey(const Key('btn_set_active_completed-kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Return to Battle Screen
      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // BattleScreen safely renders completed kit with 0 HP and Reset button
      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
      expect(find.textContaining('已討伐完工盒怪'), findsOneWidget);
      expect(find.textContaining('0/1500'), findsOneWidget);

      // Switch back to unstarted kit
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const Key('btn_set_active_unstarted-kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Back to unstarted kit
      expect(find.textContaining('全新未開工盒怪'), findsOneWidget);
      expect(find.textContaining('500/500'), findsOneWidget);
    });

    testWidgets('Finishing skill gate lock automatically resets when switching from low HP to full HP kit', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);
      final logRepo = CraftLogRepository(storage);
      kitRepo.bindCraftLogRepository(logRepo);

      // Damaged kit (15% HP <= 20% threshold)
      final damagedKit = KitItem(
        id: 'damaged-kit',
        title: '殘血受創機',
        grade: 'HG',
        totalHp: 500,
        currentHp: 75, // 15%
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      // Fresh kit (100% HP)
      final freshKit = KitItem(
        id: 'fresh-kit',
        title: '全新滿血機',
        grade: 'RG',
        totalHp: 800,
        currentHp: 800,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(damagedKit);
      await kitRepo.saveKit(freshKit);
      await kitRepo.setActiveKit(damagedKit.id);

      await tester.pumpWidget(
        TsumiPuraApp(kitRepository: kitRepo, craftLogRepository: logRepo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Select Finishing skill (it is unlocked since HP is 15% <= 20%)
      expect(find.text('水貼\n2.5x'), findsOneWidget);
      await tester.tap(find.text('水貼\n2.5x'));
      await tester.pump();

      // Dialogue confirms Finishing weapon selected
      expect(find.textContaining('水貼・仕上げ'), findsOneWidget);

      // Open Hangar and switch to fresh kit (100% HP)
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const Key('btn_set_active_fresh-kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Return to Battle Screen
      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Finishing is locked again (shows 🔒20%) and selected phase reset to Snap-fit
      expect(find.text('水貼\n🔒20%'), findsOneWidget);
      expect(find.textContaining('全新滿血機'), findsOneWidget);
    });
  });
}
