import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nifty_heisenberg/core/audio/retro_audio_service.dart';
import 'package:nifty_heisenberg/data/repositories/craft_log_repository.dart';
import 'package:nifty_heisenberg/data/repositories/kit_repository.dart';
import 'package:nifty_heisenberg/data/storage/local_storage_service.dart';
import 'package:nifty_heisenberg/main.dart';
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
    MockRetroAudioService? mockAudio,
  }) async {
    setTestViewport(tester);
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
  // Scenario 1: The Grand PG 1/60 Strike Freedom Odyssey
  // =========================================================================
  group('Scenario 1: The Grand PG 1/60 Strike Freedom Odyssey', () {
    testWidgets('T4-S1: End-to-end player journey from unbox to showcase & craft log audit', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);
      final mockAudio = MockRetroAudioService();

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo, mockAudio: mockAudio);

      // --- 1. Unboxing & Hangar Setup ---
      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('input_kit_title')), 'PG 1/60 攻擊自由鋼彈');
      await tester.pump();

      await tester.tap(find.byKey(const Key('chip_grade_PG')));
      await tester.pump();

      // Verify input_kit_hp updates to 5000
      expect(find.text('5000'), findsWidgets);

      // Ensure set active is checked
      final setAsActiveFinder = find.byKey(const Key('checkbox_set_active'));
      final checkbox = tester.widget<Checkbox>(setAsActiveFinder);
      if (checkbox.value != true) {
        await tester.tap(setAsActiveFinder);
        await tester.pump();
      }

      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify card rendered with status "山積" and active badge "討伐中"
      expect(find.text('PG 1/60 攻擊自由鋼彈'), findsOneWidget);
      expect(find.text('山積'), findsWidgets);
      expect(find.text('討伐中'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // --- 2. First Session: Snap-fit Foundation (仮組み) ---
      expect(find.textContaining('PG 1/60 攻擊自由鋼彈'), findsOneWidget);
      expect(find.textContaining('5000 / 5000 HP'), findsOneWidget);
      expect(find.text('水貼\n🔒20%'), findsOneWidget);

      await tester.tap(find.text('素組\n1.0x'));
      await tester.pump();

      // Standard session: 25 minutes = 1500s -> 100 * 1.0 = 100 damage
      await tester.tap(find.text('開始開工 (標準 25m/5m)'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1501));
      await tester.pump(const Duration(milliseconds: 800));

      // Damage dealt 100 -> 4900 / 5000 HP
      expect(find.textContaining('4900 / 5000 HP'), findsOneWidget);

      // In rest phase, skip rest
      expect(find.text('略過休息 (提前開工)'), findsOneWidget);
      await tester.tap(find.text('略過休息 (提前開工)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // --- 3. Second Session: Sanding & Surface Prep (ヤスリ掛け) ---
      await tester.tap(find.text('打磨\n1.2x'));
      await tester.pump();

      // Standard session: 100 * 1.2 = 120 damage
      await tester.tap(find.text('開始開工 (標準 25m/5m)'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1501));
      await tester.pump(const Duration(milliseconds: 800));

      // Damage dealt 120 -> 4780 / 5000 HP
      expect(find.textContaining('4780 / 5000 HP'), findsOneWidget);

      await tester.tap(find.text('略過休息 (提前開工)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // --- 4. Third Session: Detailing with Interruption (Mercy Rule) ---
      await tester.tap(find.text('刻線\n1.5x'));
      await tester.pump();

      await tester.tap(find.text('開始開工 (標準 25m/5m)'));
      await tester.pump();
      // Tick 600s out of 1500s (40% progress)
      await tester.pump(const Duration(seconds: 600));

      await tester.tap(find.text('中途中斷 (結算 50% 保底傷害)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Mercy damage: 100 * (600/1500) * 1.5 * 0.5 = 30 damage -> 4750 / 5000 HP
      expect(find.textContaining('4750 / 5000 HP'), findsOneWidget);
      expect(find.textContaining('Mercy 保底防護'), findsOneWidget);

      // --- 5. Phase Transition: Heavy Airbrushing past 20% Threshold (1000 HP) ---
      await tester.tap(find.text('噴塗\n2.0x'));
      await tester.pump();

      // 19 Airbrush sessions: 19 * 200 = 3800 damage -> 4750 - 3800 = 950 HP (19% <= 20%)
      for (int i = 0; i < 19; i++) {
        await tester.tap(find.text('開始開工 (標準 25m/5m)'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1501));
        await tester.pump(const Duration(milliseconds: 200));

        if (find.text('略過休息 (提前開工)').evaluate().isNotEmpty) {
          await tester.tap(find.text('略過休息 (提前開工)'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      expect(find.textContaining('950 / 5000 HP'), findsOneWidget);
      // Finishing technique is now unlocked!
      expect(find.text('水貼\n2.5x'), findsOneWidget);

      // --- 6. Final Blow: Finishing Deathblow (水貼終結) ---
      await tester.tap(find.text('水貼\n2.5x'));
      await tester.pump();

      // 3 Finishing sessions: 3 * 250 = 750 damage -> 200 HP remaining
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('開始開工 (標準 25m/5m)'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1501));
        await tester.pump(const Duration(milliseconds: 200));

        if (find.text('略過休息 (提前開工)').evaluate().isNotEmpty) {
          await tester.tap(find.text('略過休息 (提前開工)'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      expect(find.textContaining('200 / 5000 HP'), findsOneWidget);

      mockAudio.resetCounts();
      // 4th Finishing session: deals 250 damage -> 200 - 250 <= 0 -> Defeat!
      await tester.tap(find.text('開始開工 (標準 25m/5m)'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1501));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      expect(mockAudio.victoryFanfareCount, greaterThan(0));
      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);

      // --- 7. Showcase Induction ---
      await tester.tap(find.byKey(const Key('btn_clear_to_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('★ SHOWCASE GALLERY ★'), findsOneWidget);
      expect(find.textContaining('PG 1/60 攻擊自由鋼彈'), findsOneWidget);

      // Open detail dialog
      await tester.tap(find.textContaining('PG 1/60 攻擊自由鋼彈'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('showcase_detail_dialog')), findsOneWidget);
      // Verify 5-phase breakdown visible
      expect(find.textContaining('Snap-fit'), findsWidgets);
      expect(find.textContaining('Sanding'), findsWidgets);
      expect(find.textContaining('Detailing'), findsWidgets);
      expect(find.textContaining('Airbrush'), findsWidgets);
      expect(find.textContaining('Finishing'), findsWidgets);

      // --- 8. CraftLog Forensic Audit ---
      final viewLogsFinder = find.textContaining('查看本模型專屬施工日誌');
      await tester.ensureVisible(viewLogsFinder);
      await tester.tap(viewLogsFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('★ CRAFT LOG ★'), findsOneWidget);
      // Total sessions: 1 Snap + 1 Sand + 1 Detailing + 19 Airbrush + 4 Finishing = 26 sessions
      expect(find.text('25 次'), findsOneWidget);
      expect(find.text('1 次'), findsOneWidget);
      expect(find.text('中斷 50%'), findsOneWidget);
      expect(find.text('5050 pt'), findsOneWidget);
    });
  });

  // =========================================================================
  // Scenario 2: The Multi-Kit Juggling Craftsman
  // =========================================================================
  group('Scenario 2: The Multi-Kit Juggling Craftsman', () {
    testWidgets('T4-S2: Multi-kit lifecycle, switching targets, isolated logs & partial completion', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // 1. Register Kit A ("HG 獨角獸", 500 HP) and Kit B ("HG 新安洲", 500 HP)
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Add Kit A
      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byKey(const Key('input_kit_title')), 'HG 獨角獸');
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Add Kit B
      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byKey(const Key('input_kit_title')), 'HG 新安洲');
      await tester.pump();
      // Uncheck set active for Kit B so Kit A remains active
      final setAsActiveFinder = find.byKey(const Key('checkbox_set_active'));
      await tester.tap(setAsActiveFinder);
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Kit A is active in Hangar
      final kits = await kitRepo.getAllKits();
      final kitA = kits.firstWhere((k) => k.title == 'HG 獨角獸');
      final kitB = kits.firstWhere((k) => k.title == 'HG 新安洲');

      // Return to battle with Kit A
      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 2. Set Kit A active. Run Snap-fit session (100 dmg -> 400 HP).
      expect(find.textContaining('HG 獨角獸'), findsOneWidget);
      expect(find.textContaining('500 / 500 HP'), findsOneWidget);

      await tester.tap(find.text('素組\n1.0x'));
      await tester.pump();
      await tester.tap(find.text('開始開工 (標準 25m/5m)'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1501));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.textContaining('400 / 500 HP'), findsOneWidget);

      await tester.tap(find.text('略過休息 (提前開工)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 3. Open Hangar. Verify Kit A is "施工中", Kit B is "山積".
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('施工中'), findsWidgets);
      expect(find.text('山積'), findsWidgets);

      // 4. Set Kit B active.
      await tester.tap(find.byKey(Key('btn_set_active_${kitB.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 5. Return to Battle. HUD displays Kit B (500 HP).
      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Lv.15 HG 新安洲'), findsOneWidget);
      expect(find.textContaining('500 / 500 HP'), findsOneWidget);

      // 6. Run Sanding session on Kit B (500 - 120 = 380 HP).
      await tester.tap(find.text('打磨\n1.2x'));
      await tester.pump();
      await tester.tap(find.text('開始開工 (標準 25m/5m)'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1501));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.textContaining('380 / 500 HP'), findsOneWidget);

      await tester.tap(find.text('略過休息 (提前開工)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 7. Open CraftLog: Filter Kit B -> 1 session; Filter All -> 2 sessions.
      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Active kit is Kit B: shows 1 session, 120 pt
      expect(find.text('120 pt'), findsOneWidget);
      expect(find.text('1 次'), findsOneWidget);

      // Filter all logs
      await tester.tap(find.text('全部歷史紀錄'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // All logs: Kit A (100) + Kit B (120) = 220 pt, 2 sessions
      expect(find.text('220 pt'), findsOneWidget);
      expect(find.text('2 次'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_craft_log_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 8. Return to Hangar, switch back to Kit A, complete Kit A.
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(Key('btn_set_active_${kitA.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Lv.15 HG 獨角獸'), findsOneWidget);
      expect(find.textContaining('400 / 500 HP'), findsOneWidget);

      // Run 2 Airbrush sessions to deal 2 * 200 = 400 damage and clear Kit A
      await tester.tap(find.text('噴塗\n2.0x'));
      await tester.pump();

      await tester.tap(find.text('開始開工 (標準 25m/5m)'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1501));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('略過休息 (提前開工)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Session 2: 200 HP -> 0 HP
      await tester.tap(find.text('開始開工 (標準 25m/5m)'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1501));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);

      // 9. Go to Showcase: verify Kit A is present.
      await tester.tap(find.byKey(const Key('btn_clear_to_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('HG 獨角獸'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_showcase_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open Hangar: Kit B remains in Hangar with 380 HP and "施工中" status
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('HG 新安洲'), findsOneWidget);
      expect(find.textContaining('380/500'), findsOneWidget);
    });
  });

  // =========================================================================
  // Scenario 3: Atelier Hardening: Deep Focus & Storage Recovery
  // =========================================================================
  group('Scenario 3: Atelier Hardening: Deep Focus & Storage Recovery', () {
    testWidgets('T4-S3: Deep focus mode, custom boss, cold restart persistence & data integrity', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // 1. Register custom Boss with 2000 HP ("PB 限定幽靈")
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('input_kit_title')), 'PB 限定幽靈');
      await tester.pump();

      await tester.tap(find.byKey(const Key('checkbox_custom_hp')));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('input_kit_hp')), '2000');
      await tester.pump();

      final setAsActiveFinder = find.byKey(const Key('checkbox_set_active'));
      final cb = tester.widget<Checkbox>(setAsActiveFinder);
      if (cb.value != true) {
        await tester.tap(setAsActiveFinder);
        await tester.pump();
      }

      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('PB 限定幽靈'), findsOneWidget);
      expect(find.textContaining('2000 / 2000 HP'), findsOneWidget);

      // 2. Select Deep Focus mode (50m/10m, 220 base points)
      await tester.tap(find.text('深度 50m/10m'));
      await tester.pump();

      expect(find.text('開始開工 (深度 50m/10m)'), findsOneWidget);

      // 3. Start session and verify timer is 50:00
      await tester.tap(find.text('開始開工 (深度 50m/10m)'));
      await tester.pump();

      expect(find.text('50:00'), findsOneWidget);

      // Advance timer by 100 seconds
      await tester.pump(const Duration(seconds: 100));
      expect(find.text('48:20'), findsOneWidget);

      // 4. Interrupt session with Mercy Rule
      await tester.tap(find.text('中途中斷 (結算 50% 保底傷害)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Mercy damage: 220 * (100 / 3000) * 1.0 * 0.5 = 3.66 -> 4 damage
      // HP drops: 2000 - 4 = 1996 HP
      expect(find.textContaining('1996 / 2000 HP'), findsOneWidget);

      // 5. Simulate cold app restart
      await tester.pumpWidget(Container());
      await tester.pump();

      final restartStorage = LocalStorageService(prefs);
      final restartLogRepo = CraftLogRepository(restartStorage);
      final restartKitRepo = KitRepository(restartStorage, restartLogRepo);

      await pumpApp(
        tester,
        kitRepo: restartKitRepo,
        logRepo: restartLogRepo,
      );

      // 6. Verify cold start integrity:
      // Active kit correctly restored
      expect(find.textContaining('PB 限定幽靈'), findsOneWidget);
      expect(find.textContaining('1996 / 2000 HP'), findsOneWidget);

      // Open CraftLog and verify persisted session
      await tester.tap(find.byKey(const Key('btn_craft_log')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('4 pt'), findsOneWidget);
      expect(find.text('中斷 50%'), findsOneWidget);
    });
  });
}
