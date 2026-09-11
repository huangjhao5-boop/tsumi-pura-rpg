import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nifty_heisenberg/core/constants/game_constants.dart';
import 'package:nifty_heisenberg/data/repositories/craft_log_repository.dart';
import 'package:nifty_heisenberg/data/repositories/kit_repository.dart';
import 'package:nifty_heisenberg/data/storage/local_storage_service.dart';
import 'package:nifty_heisenberg/domain/models/kit_item.dart';
import 'package:nifty_heisenberg/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Work session completion saves updated HP and writes CraftLog', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final kitRepo = KitRepository(storage);
    final logRepo = CraftLogRepository(storage);

    // Initial kit in storage: 500 HP
    final initialKit = KitItem(
      id: 'test-kit-001',
      title: '測試盒怪',
      grade: 'HG',
      totalHp: 500,
      currentHp: 500,
      status: KitStatus.inProgress,
      createdAt: DateTime.now(),
    );
    await kitRepo.saveKit(initialKit);
    await kitRepo.setActiveKit(initialKit.id);

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

    // Advance 5 seconds + 1s completion tick
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Kit in repository was updated
    final updatedKit = await kitRepo.getActiveKit();
    expect(updatedKit, isNotNull);
    // Snap-fit 1.0x on 20 base points = 20 dmg -> 500 - 20 = 480 HP
    expect(updatedKit!.currentHp, equals(480));

    // Verify CraftLog was recorded
    final logs = await logRepo.getAllLogs();
    expect(logs.length, equals(1));
    expect(logs.first.isCompletedSession, isTrue);
    expect(logs.first.damageDealt, equals(20));
    expect(logs.first.phase, equals(CraftPhases.snapFit));
  });

  testWidgets('Interruption saves Mercy Rule 50% damage and uncompleted CraftLog', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorageService(prefs);
    final logRepo = CraftLogRepository(storage);
    final kitRepo = KitRepository(storage);

    final initialKit = KitItem(
      id: 'test-kit-002',
      title: '測試急停盒怪',
      grade: 'HG',
      totalHp: 500,
      currentHp: 500,
      status: KitStatus.inProgress,
      createdAt: DateTime.now(),
    );
    await kitRepo.saveKit(initialKit);
    await kitRepo.setActiveKit(initialKit.id);

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

    // Run for 2 seconds
    await tester.pump(const Duration(seconds: 2));

    // Click interrupt
    await tester.tap(find.textContaining('中途中斷'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify CraftLog recorded with isCompletedSession == false
    final logs = await logRepo.getAllLogs();
    expect(logs.length, equals(1));
    expect(logs.first.isCompletedSession, isFalse);
    expect(logs.first.isInterrupted, isTrue);

    // Verify Kit HP was reduced
    final savedKit = await kitRepo.getActiveKit();
    expect(savedKit!.currentHp, lessThan(500));
  });
}
