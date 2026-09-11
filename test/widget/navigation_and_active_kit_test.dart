import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nifty_heisenberg/data/repositories/craft_log_repository.dart';
import 'package:nifty_heisenberg/data/repositories/kit_repository.dart';
import 'package:nifty_heisenberg/data/storage/local_storage_service.dart';
import 'package:nifty_heisenberg/domain/models/kit_item.dart';
import 'package:nifty_heisenberg/main.dart';
import 'package:nifty_heisenberg/presentation/screens/showcase_screen.dart';
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

  group('Milestone 3 Navigation & Active Kit Battle Link Tests', () {
    testWidgets('Header HUD and Bottom Dock quick links navigate to Hangar, Showcase, and CraftLog', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);
      final logRepo = CraftLogRepository(storage);

      await tester.pumpWidget(
        TsumiPuraApp(kitRepository: kitRepo, craftLogRepository: logRepo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Test Header Hangar Quick Link
      expect(find.byKey(const Key('btn_hangar')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('★ MODEL HANGAR ★'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);

      // 2. Test Header Showcase Quick Link
      expect(find.byKey(const Key('btn_showcase')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('★ SHOWCASE GALLERY ★'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_showcase_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);

      // 3. Test Header CraftLog Quick Link
      expect(find.byKey(const Key('btn_craft_log')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('★ CRAFT LOG ★'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_craft_log_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);

      // 4. Test Bottom Dock Hangar Link
      expect(find.byKey(const Key('btn_nav_hangar')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_nav_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('★ MODEL HANGAR ★'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);

      // 5. Test Bottom Dock Showcase Link
      expect(find.byKey(const Key('btn_nav_showcase')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_nav_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('★ SHOWCASE GALLERY ★'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_showcase_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
    });

    testWidgets('Feature 22: Selecting kit in Hangar updates BattleScreen Boss HUD and resets Finishing phase if HP > 20%', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);
      final logRepo = CraftLogRepository(storage);

      // Seed Kit A (Active, 10% HP) and Kit B (100% HP)
      final kitA = KitItem(
        id: 'kit-a',
        title: '殘血普通盒怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 50, // 10% HP -> can unlock finishing
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      final kitB = KitItem(
        id: 'kit-b',
        title: '紅色沙薩比 RG',
        grade: 'RG',
        totalHp: 800,
        currentHp: 800, // 100% HP
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kitA);
      await kitRepo.saveKit(kitB);
      await kitRepo.setActiveKit(kitA.id);

      await tester.pumpWidget(
        TsumiPuraApp(kitRepository: kitRepo, craftLogRepository: logRepo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Initial active Boss: Kit A
      expect(find.text('Lv.15 殘血普通盒怪'), findsOneWidget);
      expect(find.textContaining('50 / 500 HP'), findsOneWidget);

      // Select Finishing phase (allowed because HP is 10% <= 20%)
      await tester.tap(find.textContaining('水貼'));
      await tester.pump();

      // Navigate to Hangar
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Select Kit B as target
      final setActiveBtn = find.byKey(const Key('btn_set_active_kit-b'));
      expect(setActiveBtn, findsOneWidget);
      await tester.tap(setActiveBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Return to Battle Screen
      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Boss Card immediately reflects Kit B!
      expect(find.text('Lv.15 紅色沙薩比 RG'), findsOneWidget);
      expect(find.textContaining('RG 1/144'), findsOneWidget);
      expect(find.textContaining('800 / 800 HP'), findsOneWidget);

      // Verify Finishing phase was reset because Kit B is at 100% HP (> 20%)
      expect(find.textContaining('水貼\n🔒20%'), findsOneWidget);
    });

    testWidgets('Feature 23: Boss defeat persists completion and offers Showcase and Hangar transitions', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);
      final logRepo = CraftLogRepository(storage);

      // Seed near-death kit: 10 HP
      final dyingKit = KitItem(
        id: 'dying-mimic',
        title: '殘血盒怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 10,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(dyingKit);
      await kitRepo.setActiveKit(dyingKit.id);

      await tester.pumpWidget(
        TsumiPuraApp(kitRepository: kitRepo, craftLogRepository: logRepo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Deal damage via 5s debug test mode
      await tester.tap(find.text('除錯 5s/3s'));
      await tester.pump();
      await tester.tap(find.textContaining('開始開工'));
      await tester.pump();

      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));

      // Wait for Quest Clear dialog (700ms delay in app)
      await tester.pump(const Duration(milliseconds: 800));

      // Verify Quest Clear modal
      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.textContaining('殘血盒怪')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('btn_clear_to_showcase')), findsOneWidget);
      expect(find.byKey(const Key('btn_clear_to_hangar')), findsOneWidget);
      expect(find.byKey(const Key('btn_clear_restart')), findsOneWidget);

      // Verify kit in repo marked completed with timestamp
      final savedKit = (await kitRepo.getAllKits()).firstWhere((k) => k.id == 'dying-mimic');
      expect(savedKit.isCompleted, isTrue);
      expect(savedKit.currentHp, equals(0));
      expect(savedKit.completedAt, isNotNull);

      // Tap "前往展示櫃觀看"
      await tester.tap(find.byKey(const Key('btn_clear_to_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify navigated to ShowcaseScreen and shows the completed kit
      expect(find.text('★ SHOWCASE GALLERY ★'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(ShowcaseScreen), matching: find.textContaining('殘血盒怪')),
        findsWidgets,
      );
    });
  });
}
