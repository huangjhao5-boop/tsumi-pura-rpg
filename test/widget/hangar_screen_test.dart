import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nifty_heisenberg/data/repositories/craft_log_repository.dart';
import 'package:nifty_heisenberg/data/repositories/kit_repository.dart';
import 'package:nifty_heisenberg/data/storage/local_storage_service.dart';
import 'package:nifty_heisenberg/domain/models/kit_item.dart';
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

  group('HangarScreen Widget Tests', () {
    testWidgets('Renders empty state when filtered list has no kits', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);

      await tester.pumpWidget(createHangarScreen(kitRepo: kitRepo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Filter by completed kits (none exist yet)
      await tester.tap(find.byKey(const Key('filter_completed')));
      await tester.pump();

      expect(find.text('▶ 機庫空空如也'), findsOneWidget);
      expect(find.byKey(const Key('btn_add_kit_empty')), findsOneWidget);
    });

    testWidgets('Renders kit cards with grade, title, status, and active badge', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);

      final kit1 = KitItem(
        id: 'kit-1',
        title: 'HG 初鋼 RX-78-2',
        grade: 'HG',
        totalHp: 500,
        currentHp: 250,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      final kit2 = KitItem(
        id: 'kit-2',
        title: 'RG 沙薩比',
        grade: 'RG',
        totalHp: 800,
        currentHp: 800,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit1);
      await kitRepo.saveKit(kit2);
      await kitRepo.setActiveKit(kit1.id);

      await tester.pumpWidget(createHangarScreen(kitRepo: kitRepo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('kit_card_kit-1')), findsOneWidget);
      expect(find.byKey(const Key('kit_card_kit-2')), findsOneWidget);
      expect(find.text('HG 初鋼 RX-78-2'), findsOneWidget);
      expect(find.text('RG 沙薩比'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const Key('kit_card_kit-1')), matching: find.text('施工中')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const Key('kit_card_kit-2')), matching: find.text('山積')),
        findsOneWidget,
      );
      expect(find.text('★ 當前出擊目標 (ACTIVE BOSS)'), findsOneWidget);
      expect(find.text('250/500 (50%)'), findsOneWidget);
    });

    testWidgets('Filter bar filters by status (山積, 施工中, 完工, 全部)', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);

      final kit1 = KitItem(
        id: 'kit-backlog',
        title: '山積模型',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      final kit2 = KitItem(
        id: 'kit-progress',
        title: '施工中模型',
        grade: 'RG',
        totalHp: 800,
        currentHp: 400,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      final kit3 = KitItem(
        id: 'kit-done',
        title: '完工模型',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 0,
        status: KitStatus.completed,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit1);
      await kitRepo.saveKit(kit2);
      await kitRepo.saveKit(kit3);

      await tester.pumpWidget(createHangarScreen(kitRepo: kitRepo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Filter by 山積
      await tester.tap(find.byKey(const Key('filter_unstarted')));
      await tester.pump();
      expect(find.text('山積模型'), findsOneWidget);
      expect(find.text('施工中模型'), findsNothing);
      expect(find.text('完工模型'), findsNothing);

      // Filter by 施工中
      await tester.tap(find.byKey(const Key('filter_in_progress')));
      await tester.pump();
      expect(find.text('山積模型'), findsNothing);
      expect(find.text('施工中模型'), findsOneWidget);
      expect(find.text('完工模型'), findsNothing);

      // Filter by 完工
      await tester.tap(find.byKey(const Key('filter_completed')));
      await tester.pump();
      expect(find.text('山積模型'), findsNothing);
      expect(find.text('施工中模型'), findsNothing);
      expect(find.text('完工模型'), findsOneWidget);

      // Reset to 全部
      await tester.tap(find.byKey(const Key('filter_all')));
      await tester.pump();
      expect(find.text('山積模型'), findsOneWidget);
      expect(find.text('施工中模型'), findsOneWidget);
      expect(find.text('完工模型'), findsOneWidget);
    });

    testWidgets('Tapping 設為目標 updates active kit and triggers callback', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);

      final kit1 = KitItem(
        id: 'kit-1',
        title: '模型一號',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      final kit2 = KitItem(
        id: 'kit-2',
        title: '模型二號',
        grade: 'RG',
        totalHp: 800,
        currentHp: 800,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit1);
      await kitRepo.saveKit(kit2);
      await kitRepo.setActiveKit(kit1.id);

      KitItem? selectedKit;
      await tester.pumpWidget(
        createHangarScreen(
          kitRepo: kitRepo,
          onKitSelected: (kit) => selectedKit = kit,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('btn_set_active_kit-2')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_set_active_kit-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final activeKit = await kitRepo.getActiveKit();
      expect(activeKit!.id, equals('kit-2'));
      expect(selectedKit?.id, equals('kit-2'));
      expect(find.textContaining('已將【模型二號】設為當前討伐目標！'), findsOneWidget);
    });

    testWidgets('Add Kit dialog: Grade preset auto-fills HP, custom HP override, and validation', (
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

      expect(find.text('★ 登錄山積盒怪 ★'), findsOneWidget);

      // Verify default grade is HG and default HP is 500
      expect(find.text('500'), findsOneWidget);

      // Select Grade RG -> HP automatically updates to 800
      await tester.tap(find.byKey(const Key('chip_grade_RG')));
      await tester.pump();
      expect(find.text('800'), findsOneWidget);

      // Select Grade MG -> HP automatically updates to 1500
      await tester.tap(find.byKey(const Key('chip_grade_MG')));
      await tester.pump();
      expect(find.text('1500'), findsOneWidget);

      // Select Grade PG -> HP automatically updates to 5000
      await tester.tap(find.byKey(const Key('chip_grade_PG')));
      await tester.pump();
      expect(find.text('5000'), findsOneWidget);

      // Select Grade EG -> HP automatically updates to 300
      await tester.tap(find.byKey(const Key('chip_grade_EG')));
      await tester.pump();
      expect(find.text('300'), findsOneWidget);

      // Test validation: submit without title
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      expect(find.text('請輸入模型名稱'), findsOneWidget);

      // Enter Title
      await tester.enterText(find.byKey(const Key('input_kit_title')), 'MG 自由高達 2.0');
      await tester.pump();

      // Enable Custom HP override
      await tester.tap(find.byKey(const Key('checkbox_custom_hp')));
      await tester.pump();

      // Enter invalid HP (0)
      await tester.enterText(find.byKey(const Key('input_kit_hp')), '0');
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      expect(find.text('HP 必須為大於 0 之整數'), findsOneWidget);

      // Enter valid Custom HP (2400)
      await tester.enterText(find.byKey(const Key('input_kit_hp')), '2400');
      await tester.pump();

      // Save
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify dialog closed and kit rendered
      expect(find.text('★ 登錄山積盒怪 ★'), findsNothing);
      expect(find.text('MG 自由高達 2.0'), findsOneWidget);
      expect(find.textContaining('2400/2400'), findsOneWidget);
      expect(find.text('自訂'), findsOneWidget);

      // Verify saved in repository
      final kits = await kitRepo.getAllKits();
      final created = kits.firstWhere((k) => k.title == 'MG 自由高達 2.0');
      expect(created.totalHp, equals(2400));
      expect(created.isCustomBoss, isTrue);
    });

    testWidgets('Edit Kit dialog updates title, grade, and HP', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);

      final kit = KitItem(
        id: 'edit-target',
        title: '舊版模型',
        grade: 'HG',
        totalHp: 500,
        currentHp: 200,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit);

      await tester.pumpWidget(createHangarScreen(kitRepo: kitRepo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Edit
      await tester.tap(find.byKey(const Key('btn_edit_kit_edit-target')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('★ 編輯模型資料 ★'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '舊版模型'), findsOneWidget);

      // Change title
      await tester.enterText(find.byKey(const Key('input_kit_title')), '新版豪華模型');
      await tester.pump();

      // Change grade to MG
      await tester.tap(find.byKey(const Key('chip_grade_MG')));
      await tester.pump();

      // Save
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('★ 編輯模型資料 ★'), findsNothing);
      expect(find.text('新版豪華模型'), findsOneWidget);

      final updated = (await kitRepo.getAllKits()).firstWhere((k) => k.id == 'edit-target');
      expect(updated.title, equals('新版豪華模型'));
      expect(updated.grade, equals('MG'));
      expect(updated.totalHp, equals(1500));
    });

    testWidgets('Delete Kit opens confirmation dialog with warning and deletes kit', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);

      final kit = KitItem(
        id: 'delete-target',
        title: '欲解體模型',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit);

      await tester.pumpWidget(createHangarScreen(kitRepo: kitRepo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('欲解體模型'), findsOneWidget);

      // Tap Delete
      await tester.tap(find.byKey(const Key('btn_delete_kit_delete-target')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('⚠️ 解體除籍確認 ⚠️'), findsOneWidget);
      expect(find.textContaining('此操作將一併永久清除該模型的全部施工紀錄'), findsOneWidget);

      // Confirm Delete
      await tester.tap(find.byKey(const Key('btn_confirm_delete')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('⚠️ 解體除籍確認 ⚠️'), findsNothing);
      expect(find.text('欲解體模型'), findsNothing);

      final all = await kitRepo.getAllKits();
      expect(all.any((k) => k.id == 'delete-target'), isFalse);
    });
  });
}
