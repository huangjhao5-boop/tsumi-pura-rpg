import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nifty_heisenberg/core/constants/game_constants.dart';
import 'package:nifty_heisenberg/data/repositories/craft_log_repository.dart';
import 'package:nifty_heisenberg/data/storage/local_storage_service.dart';
import 'package:nifty_heisenberg/domain/models/craft_log.dart';
import 'package:nifty_heisenberg/presentation/screens/craft_log_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('CraftLogScreen renders empty state when no logs exist', (
    WidgetTester tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final logRepo = CraftLogRepository(storage);

    await tester.pumpWidget(
      MaterialApp(
        home: CraftLogScreen(
          craftLogRepository: logRepo,
          activeKitId: 'kit-001',
          activeKitTitle: 'HG 綠色普通盒怪',
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('★ CRAFT LOG ★'), findsOneWidget);
    expect(find.text('【討伐與施工統計總覽】'), findsOneWidget);
    expect(find.textContaining('尚未有施工紀錄'), findsOneWidget);
    expect(find.text('0 pt'), findsOneWidget);
  });

  testWidgets('CraftLogScreen displays aggregate KPIs and phase breakdown', (
    WidgetTester tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final logRepo = CraftLogRepository(storage);

    // Seed 2 logs
    await logRepo.addLog(
      CraftLog(
        id: 'l1',
        kitId: 'kit-001',
        phase: CraftPhases.snapFit,
        durationMinutes: 25,
        damageDealt: 100,
        isCompletedSession: true,
        timestamp: DateTime(2026, 9, 11, 10, 0),
      ),
    );

    await logRepo.addLog(
      CraftLog(
        id: 'l2',
        kitId: 'kit-001',
        phase: CraftPhases.sanding,
        durationMinutes: 15,
        damageDealt: 36,
        isCompletedSession: false,
        timestamp: DateTime(2026, 9, 11, 11, 0),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CraftLogScreen(
          craftLogRepository: logRepo,
          activeKitId: 'kit-001',
          activeKitTitle: 'HG 綠色普通盒怪',
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify KPI calculations: 25 + 15 = 40m, 100 + 36 = 136 pt
    expect(find.text('40m'), findsOneWidget);
    expect(find.text('136 pt'), findsOneWidget);
    expect(find.text('1 次'), findsNWidgets(2)); // 1 completed, 1 interrupted

    // Verify session tiles in list
    expect(find.text('完工'), findsOneWidget);
    expect(find.text('中斷 50%'), findsOneWidget);
    expect(find.text('⏱ 25m'), findsOneWidget);
    expect(find.text('💥 -100 HP'), findsOneWidget);
    expect(find.text('⏱ 15m'), findsOneWidget);
    expect(find.text('💥 -36 HP'), findsOneWidget);
  });

  testWidgets('CraftLogScreen filter toggles between active kit and all history', (
    WidgetTester tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final logRepo = CraftLogRepository(storage);

    // Log for active kit
    await logRepo.addLog(
      CraftLog(
        id: 'l-active',
        kitId: 'kit-active',
        phase: CraftPhases.snapFit,
        durationMinutes: 25,
        damageDealt: 100,
        isCompletedSession: true,
        timestamp: DateTime(2026, 9, 11, 10, 0),
      ),
    );

    // Log for other kit
    await logRepo.addLog(
      CraftLog(
        id: 'l-other',
        kitId: 'kit-other',
        phase: CraftPhases.airbrush,
        durationMinutes: 50,
        damageDealt: 440,
        isCompletedSession: true,
        timestamp: DateTime(2026, 9, 11, 12, 0),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CraftLogScreen(
          craftLogRepository: logRepo,
          activeKitId: 'kit-active',
          activeKitTitle: '當前主角',
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Initially filtered to active kit only
    expect(find.text('100 pt'), findsOneWidget);
    expect(find.text('540 pt'), findsNothing);

    // Tap "全部歷史紀錄"
    await tester.tap(find.text('全部歷史紀錄'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Now shows total 100 + 440 = 540 pt
    expect(find.text('540 pt'), findsOneWidget);
  });
}
