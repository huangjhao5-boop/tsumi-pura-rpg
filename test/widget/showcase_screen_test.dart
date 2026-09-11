import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nifty_heisenberg/core/constants/game_constants.dart';
import 'package:nifty_heisenberg/data/repositories/craft_log_repository.dart';
import 'package:nifty_heisenberg/data/repositories/kit_repository.dart';
import 'package:nifty_heisenberg/data/storage/local_storage_service.dart';
import 'package:nifty_heisenberg/domain/models/craft_log.dart';
import 'package:nifty_heisenberg/domain/models/kit_item.dart';
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

  Widget createShowcaseScreen({
    required IKitRepository kitRepo,
    required ICraftLogRepository logRepo,
  }) {
    return MaterialApp(
      home: ShowcaseScreen(
        kitRepository: kitRepo,
        craftLogRepository: logRepo,
      ),
    );
  }

  group('ShowcaseScreen Widget Tests', () {
    testWidgets('Displays empty state when no kits are completed', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);
      final logRepo = CraftLogRepository(storage);

      // Seed only an unstarted kit
      final unstartedKit = KitItem(
        id: 'unstarted-1',
        title: '山積盒怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(unstartedKit);

      await tester.pumpWidget(
        createShowcaseScreen(kitRepo: kitRepo, logRepo: logRepo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('showcase_empty_state')), findsOneWidget);
      expect(find.text('尚無完工模型，快去討伐堆積吧！'), findsOneWidget);
      expect(find.text('山積盒怪'), findsNothing);
    });

    testWidgets('Displays completed kit cards with date, duration, and session count', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);
      final logRepo = CraftLogRepository(storage);

      final completedKit = KitItem(
        id: 'completed-1',
        title: 'RG 牛高達 RX-93',
        grade: 'RG',
        totalHp: 800,
        currentHp: 0,
        status: KitStatus.completed,
        createdAt: DateTime(2026, 9, 1),
        completedAt: DateTime(2026, 9, 11),
      );
      await kitRepo.saveKit(completedKit);

      // Add two craft logs: 35m + 25m = 60m (1h 0m)
      final log1 = CraftLog(
        id: 'log-1',
        kitId: 'completed-1',
        phase: CraftPhases.snapFit,
        durationMinutes: 35,
        damageDealt: 350,
        isCompletedSession: true,
        timestamp: DateTime(2026, 9, 5),
      );
      final log2 = CraftLog(
        id: 'log-2',
        kitId: 'completed-1',
        phase: CraftPhases.finishing,
        durationMinutes: 25,
        damageDealt: 450,
        isCompletedSession: true,
        timestamp: DateTime(2026, 9, 11),
      );
      await logRepo.addLog(log1);
      await logRepo.addLog(log2);

      await tester.pumpWidget(
        createShowcaseScreen(kitRepo: kitRepo, logRepo: logRepo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Assert card rendering
      expect(find.byKey(const Key('showcase_card_completed-1')), findsOneWidget);
      expect(find.text('RG 牛高達 RX-93'), findsOneWidget);
      expect(find.text('RG'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
      expect(find.textContaining('2026-09-11'), findsOneWidget);
      expect(find.textContaining('1h 0m'), findsOneWidget);
      expect(find.textContaining('2 次'), findsOneWidget);
    });

    testWidgets('Tapping completed kit card opens detail dialog with 5-phase breakdown', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);
      final logRepo = CraftLogRepository(storage);

      final completedKit = KitItem(
        id: 'trophy-kit',
        title: 'PG 攻擊自由高達',
        grade: 'PG',
        totalHp: 5000,
        currentHp: 0,
        status: KitStatus.completed,
        createdAt: DateTime(2026, 8, 1),
        completedAt: DateTime(2026, 9, 10),
      );
      await kitRepo.saveKit(completedKit);

      // Add craft logs across phases
      await logRepo.addLog(
        CraftLog(
          id: 'l1',
          kitId: 'trophy-kit',
          phase: CraftPhases.snapFit,
          durationMinutes: 60,
          damageDealt: 1000,
          isCompletedSession: true,
          timestamp: DateTime(2026, 8, 10),
        ),
      );
      await logRepo.addLog(
        CraftLog(
          id: 'l2',
          kitId: 'trophy-kit',
          phase: CraftPhases.sanding,
          durationMinutes: 40,
          damageDealt: 800,
          isCompletedSession: true,
          timestamp: DateTime(2026, 8, 15),
        ),
      );
      await logRepo.addLog(
        CraftLog(
          id: 'l3',
          kitId: 'trophy-kit',
          phase: CraftPhases.airbrush,
          durationMinutes: 50,
          damageDealt: 2000,
          isCompletedSession: true,
          timestamp: DateTime(2026, 8, 25),
        ),
      );
      await logRepo.addLog(
        CraftLog(
          id: 'l4',
          kitId: 'trophy-kit',
          phase: CraftPhases.finishing,
          durationMinutes: 30,
          damageDealt: 1200,
          isCompletedSession: true,
          timestamp: DateTime(2026, 9, 10),
        ),
      );

      await tester.pumpWidget(
        createShowcaseScreen(kitRepo: kitRepo, logRepo: logRepo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap card to open modal
      await tester.tap(find.byKey(const Key('showcase_card_trophy-kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('showcase_detail_dialog')), findsOneWidget);
      expect(find.text('★ 完工模型銘牌 ★'), findsOneWidget);
      expect(find.text('【PG】PG 攻擊自由高達'), findsOneWidget);
      expect(find.text('【5 大工序工時佔比】'), findsOneWidget);

      // Verify phase names
      expect(find.textContaining('Snap-fit'), findsOneWidget);
      expect(find.textContaining('Sanding'), findsOneWidget);
      expect(find.textContaining('Airbrush'), findsOneWidget);
      expect(find.textContaining('Finishing'), findsOneWidget);

      // Verify total minutes: 60+40+50+30 = 180m (3h 0m)
      expect(find.textContaining('3h 0m'), findsWidgets);

      // Close dialog
      await tester.tap(find.byKey(const Key('btn_showcase_close_detail')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('showcase_detail_dialog')), findsNothing);
    });

    testWidgets('Detail dialog navigation button opens CraftLogScreen', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);
      final logRepo = CraftLogRepository(storage);

      final kit = KitItem(
        id: 'nav-kit',
        title: 'EG 獵魔高達',
        grade: 'EG',
        totalHp: 300,
        currentHp: 0,
        status: KitStatus.completed,
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit);

      await tester.pumpWidget(
        createShowcaseScreen(kitRepo: kitRepo, logRepo: logRepo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Open detail dialog
      await tester.tap(find.byKey(const Key('showcase_card_nav-kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap '查看本模型專屬施工日誌'
      final viewLogsBtn = find.byKey(const Key('btn_showcase_view_logs_nav-kit'));
      expect(viewLogsBtn, findsOneWidget);
      await tester.tap(viewLogsBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify CraftLogScreen is pushed
      expect(find.text('★ CRAFT LOG ★'), findsOneWidget);
      expect(find.textContaining('EG 獵魔高達'), findsWidgets);
    });

    testWidgets('Refresh button reloads showcase data cleanly', (
      WidgetTester tester,
    ) async {
      setScreenSize(tester);
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final kitRepo = KitRepository(storage);
      final logRepo = CraftLogRepository(storage);

      await tester.pumpWidget(
        createShowcaseScreen(kitRepo: kitRepo, logRepo: logRepo),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('btn_refresh_showcase')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_refresh_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('★ SHOWCASE GALLERY ★'), findsOneWidget);
    });
  });
}
