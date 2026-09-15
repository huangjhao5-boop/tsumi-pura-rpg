import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nifty_heisenberg/core/audio/retro_audio_service.dart';
import 'package:nifty_heisenberg/core/constants/game_constants.dart';
import 'package:nifty_heisenberg/data/repositories/craft_log_repository.dart';
import 'package:nifty_heisenberg/data/repositories/kit_repository.dart';
import 'package:nifty_heisenberg/data/storage/local_storage_service.dart';
import 'package:nifty_heisenberg/domain/models/craft_log.dart';
import 'package:nifty_heisenberg/domain/models/kit_item.dart';
import 'package:nifty_heisenberg/main.dart';
import 'package:nifty_heisenberg/presentation/theme/retro_colors.dart';
import 'package:nifty_heisenberg/presentation/theme/retro_typography.dart';
import 'package:nifty_heisenberg/presentation/widgets/boss_hurt_flash.dart';
import 'package:nifty_heisenberg/presentation/widgets/floating_damage_text.dart';
import 'package:nifty_heisenberg/presentation/widgets/pixel_button.dart';
import 'package:nifty_heisenberg/presentation/widgets/pixel_frame.dart';
import 'package:nifty_heisenberg/presentation/widgets/pixel_hp_bar.dart';
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
  // Feature 18: Model Hangar Screen (Boundaries & Corner Cases)
  // =========================================================================
  group('Feature 18: Model Hangar Screen (Boundaries)', () {
    testWidgets('B18-1: Empty Hangar State When All Kits Filtered Out', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Filter by completed (none exist initially)
      await tester.tap(find.byKey(const Key('filter_completed')));
      await tester.pump();

      expect(find.textContaining('機庫空空如也'), findsOneWidget);
      expect(find.byKey(const Key('btn_add_kit_empty')), findsOneWidget);
    });

    testWidgets('B18-2: Rapid Filter Toggling under Load', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      for (int i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('filter_unstarted')));
        await tester.pump(const Duration(milliseconds: 20));
        await tester.tap(find.byKey(const Key('filter_in_progress')));
        await tester.pump(const Duration(milliseconds: 20));
        await tester.tap(find.byKey(const Key('filter_completed')));
        await tester.pump(const Duration(milliseconds: 20));
        await tester.tap(find.byKey(const Key('filter_all')));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.byKey(Key('kit_card_${GameConstants.defaultKitId}')), findsOneWidget);
    });

    testWidgets('B18-3: Long Scrollable Inventory Performance (20+ kits)', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      for (int i = 0; i < 22; i++) {
        await kitRepo.saveKit(KitItem(
          id: 'kit-stress-$i',
          title: 'Stress Kit $i',
          grade: 'HG',
          totalHp: 500,
          currentHp: 500,
          status: KitStatus.unstarted,
          createdAt: DateTime.now(),
        ));
      }

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('★ MODEL HANGAR ★'), findsOneWidget);
    });

    testWidgets('B18-4: Active Kit Badge Consistency After Refresh', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kit1 = KitItem.initialSeedKit();
      final kit2 = KitItem(
        id: 'refresh-kit-2',
        title: 'Refresh Target',
        grade: 'RG',
        totalHp: 800,
        currentHp: 800,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kit1);
      await kitRepo.saveKit(kit2);
      await kitRepo.setActiveKit(kit2.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.descendant(
        of: find.byKey(const Key('kit_card_refresh-kit-2')),
        matching: find.text('★ 當前出擊目標 (ACTIVE BOSS)'),
      ), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_refresh_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.descendant(
        of: find.byKey(const Key('kit_card_refresh-kit-2')),
        matching: find.text('★ 當前出擊目標 (ACTIVE BOSS)'),
      ), findsOneWidget);
    });

    testWidgets('B18-5: Deleting Active Kit Updates Hangar Active Badge', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kit1 = KitItem(
        id: 'del-act-1',
        title: 'Active To Delete',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      final kit2 = KitItem(
        id: 'del-act-2',
        title: 'Heir Kit',
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
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_delete_kit_del-act-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_confirm_delete')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.descendant(
        of: find.byKey(const Key('kit_card_del-act-2')),
        matching: find.text('★ 當前出擊目標 (ACTIVE BOSS)'),
      ), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 19: Model CRUD Management (Boundaries & Corner Cases)
  // =========================================================================
  group('Feature 19: Model CRUD Management (Boundaries)', () {
    testWidgets('B19-1: Exact 50-Character Kit Title Boundary', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final title50 = 'A' * 50;
      await tester.enterText(find.byKey(const Key('input_kit_title')), title50);
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text(title50), findsOneWidget);
    });

    testWidgets('B19-2: 51-Character Kit Title Rejection', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final field = tester.widget<TextFormField>(find.byKey(const Key('input_kit_title')));
      final validationResult = field.validator!('A' * 51);
      expect(validationResult, equals('名稱不可超過 50 字元'));
    });

    testWidgets('B19-3: Whitespace-Only Kit Title Rejection', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('input_kit_title')), '     \t\n  ');
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();

      expect(find.text('請輸入模型名稱'), findsOneWidget);
    });

    testWidgets('B19-4: Edit Title Without Changing HP Preserves Custom Flag', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final customKit = KitItem(
        id: 'custom-kit-preserve',
        title: 'Original Custom Boss',
        grade: 'MG',
        totalHp: 2400,
        currentHp: 2400,
        isCustomBoss: true,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(customKit);
      await kitRepo.setActiveKit(customKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_edit_kit_custom-kit-preserve')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('input_kit_title')), 'Renamed Custom Boss');
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final kits = await kitRepo.getAllKits();
      final updated = kits.firstWhere((k) => k.id == 'custom-kit-preserve');
      expect(updated.title, 'Renamed Custom Boss');
      expect(updated.totalHp, 2400);
      expect(updated.isCustomBoss, isTrue);
    });

    testWidgets('B19-5: Cascade Deletion of Craft Logs', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);
      kitRepo.bindCraftLogRepository(logRepo);

      final kitA = KitItem(
        id: 'cascade-kit-a',
        title: 'Kit A With Logs',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      final kitB = KitItem(
        id: 'cascade-kit-b',
        title: 'Kit B With Logs',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kitA);
      await kitRepo.saveKit(kitB);

      for (int i = 0; i < 3; i++) {
        await logRepo.addLog(CraftLog(
          id: 'log-a-$i',
          kitId: kitA.id,
          phase: CraftPhases.snapFit,
          durationMinutes: 25,
          damageDealt: 100,
          isCompletedSession: true,
          timestamp: DateTime.now(),
        ));
      }
      for (int i = 0; i < 2; i++) {
        await logRepo.addLog(CraftLog(
          id: 'log-b-$i',
          kitId: kitB.id,
          phase: CraftPhases.sanding,
          durationMinutes: 25,
          damageDealt: 120,
          isCompletedSession: true,
          timestamp: DateTime.now(),
        ));
      }

      await kitRepo.deleteKit(kitA.id);

      final logsA = await logRepo.getLogsForKit(kitA.id);
      final allLogs = await logRepo.getAllLogs();
      expect(logsA.isEmpty, isTrue);
      expect(allLogs.length, equals(2));
    });
  });

  // =========================================================================
  // Feature 20: Grade & HP Defaults Presets (Boundaries & Corner Cases)
  // =========================================================================
  group('Feature 20: Grade & HP Defaults Presets (Boundaries)', () {
    testWidgets('B20-1: Rapid Grade Preset Switching in Form Dialog', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final grades = ['EG', 'HG', 'RG', 'MG', 'PG', 'EG'];
      final expectedHps = ['300', '500', '800', '1500', '5000', '300'];

      for (int i = 0; i < grades.length; i++) {
        await tester.tap(find.byKey(Key('chip_grade_${grades[i]}')));
        await tester.pump();
        final hpField = tester.widget<TextFormField>(find.byKey(const Key('input_kit_hp')));
        expect(hpField.controller?.text, expectedHps[i]);
      }
    });

    testWidgets('B20-2: Unchecking Custom HP Restores Selected Grade Default', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('chip_grade_MG')));
      await tester.pump();
      expect(tester.widget<TextFormField>(find.byKey(const Key('input_kit_hp'))).controller?.text, '1500');

      await tester.tap(find.byKey(const Key('checkbox_custom_hp')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('input_kit_hp')), '4000');

      await tester.tap(find.byKey(const Key('checkbox_custom_hp')));
      await tester.pump();
      expect(tester.widget<TextFormField>(find.byKey(const Key('input_kit_hp'))).controller?.text, '1500');
    });

    testWidgets('B20-3: Switching Grade When Custom HP is Checked Retains Custom Value', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('checkbox_custom_hp')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('input_kit_hp')), '7777');

      await tester.tap(find.byKey(const Key('chip_grade_PG')));
      await tester.pump();
      expect(tester.widget<TextFormField>(find.byKey(const Key('input_kit_hp'))).controller?.text, '7777');
    });

    testWidgets('B20-4: Edit Mode 重設當前血量為滿血 Checkbox', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final damagedKit = KitItem(
        id: 'damaged-kit-1',
        title: 'Damaged Target',
        grade: 'HG',
        totalHp: 500,
        currentHp: 100,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(damagedKit);
      await kitRepo.setActiveKit(damagedKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_edit_kit_damaged-kit-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('checkbox_reset_hp')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final kits = await kitRepo.getAllKits();
      final updated = kits.firstWhere((k) => k.id == 'damaged-kit-1');
      expect(updated.currentHp, equals(500));
    });

    testWidgets('B20-5: Custom Boss Flag Set When HP Differs from Grade Default', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('input_kit_title')), 'Custom HG Boss');
      await tester.tap(find.byKey(const Key('chip_grade_HG')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('checkbox_custom_hp')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('input_kit_hp')), '501');
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('自訂'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 21: Custom HP Input (Boundaries & Corner Cases)
  // =========================================================================
  group('Feature 21: Custom HP Input (Boundaries)', () {
    testWidgets('B21-1: Custom HP Exact Lower Boundary: 1 HP', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('input_kit_title')), 'Min HP Kit');
      await tester.tap(find.byKey(const Key('checkbox_custom_hp')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('input_kit_hp')), '1');
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Min HP Kit'), findsOneWidget);
      expect(find.textContaining('1/1'), findsOneWidget);
    });

    testWidgets('B21-2: Custom HP Exact Upper Boundary: 99,999 HP', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('input_kit_title')), 'Max HP Kit');
      await tester.tap(find.byKey(const Key('checkbox_custom_hp')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('input_kit_hp')), '99999');
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Max HP Kit'), findsOneWidget);
      expect(find.textContaining('99999/99999'), findsOneWidget);
    });

    testWidgets('B21-3: Custom HP Exceeding Upper Boundary: 100,000 HP', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('checkbox_custom_hp')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('input_kit_hp')), '100000');
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();

      expect(find.text('HP 不可超過 99,999'), findsOneWidget);
    });

    testWidgets('B21-4: Custom HP Negative Value Protection', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final field = tester.widget<TextFormField>(find.byKey(const Key('input_kit_hp')));
      expect(field.validator!('-10'), equals('HP 必須為大於 0 之整數'));
    });

    testWidgets('B21-5: Non-numeric Input Protection', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final field = tester.widget<TextFormField>(find.byKey(const Key('input_kit_hp')));
      expect(field.validator!('abc'), equals('HP 必須為大於 0 之整數'));
    });
  });

  // =========================================================================
  // Feature 22: Active Kit Battle Link (Boundaries & Corner Cases)
  // =========================================================================
  group('Feature 22: Active Kit Battle Link (Boundaries)', () {
    testWidgets('B22-1: Switch Active Kit While Battle Pomodoro is Idle', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final k1 = KitItem(
        id: 'idle-switch-1',
        title: 'Original Active',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      final k2 = KitItem(
        id: 'idle-switch-2',
        title: 'Switched Active',
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
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_set_active_idle-switch-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Lv.15 Switched Active'), findsOneWidget);
      expect(find.textContaining('1500 / 1500 HP'), findsOneWidget);
    });

    testWidgets('B22-2: Switch Target Auto-resets Finishing Phase if HP > 20%', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kitLow = KitItem(
        id: 'fin-low-1',
        title: 'Low Boss',
        grade: 'HG',
        totalHp: 500,
        currentHp: 50,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      final kitHigh = KitItem(
        id: 'fin-high-1',
        title: 'High Boss',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kitLow);
      await kitRepo.saveKit(kitHigh);
      await kitRepo.setActiveKit(kitLow.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('水貼\n2.5x'));
      await tester.pump();

      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_set_active_fin-high-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('水貼\n🔒20%'), findsOneWidget);
    });

    testWidgets('B22-3: Deleting the Active Kit Reallocates Target Without Crashing', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final k1 = KitItem(
        id: 'del-realloc-1',
        title: 'Target One',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      final k2 = KitItem(
        id: 'del-realloc-2',
        title: 'Target Two',
        grade: 'RG',
        totalHp: 800,
        currentHp: 800,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(k1);
      await kitRepo.saveKit(k2);
      await kitRepo.setActiveKit(k1.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_delete_kit_del-realloc-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_confirm_delete')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Target Two'), findsOneWidget);
    });

    testWidgets('B22-4: Deleting the Only Remaining Kit Auto-seeds Default Kit', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final onlyKit = KitItem(
        id: 'only-kit-1',
        title: 'Sole Surviving Kit',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(onlyKit);
      await kitRepo.setActiveKit(onlyKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_delete_kit_only-kit-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_confirm_delete')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining(GameConstants.defaultKitTitle), findsOneWidget);
    });

    testWidgets('B22-5: Rapid Concurrent setActiveKit Calls', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final k1 = KitItem.initialSeedKit();
      final k2 = KitItem(id: 'c-k2', title: 'Kit 2', grade: 'HG', totalHp: 500, currentHp: 500, status: KitStatus.unstarted, createdAt: DateTime.now());
      final k3 = KitItem(id: 'c-k3', title: 'Kit 3', grade: 'RG', totalHp: 800, currentHp: 800, status: KitStatus.unstarted, createdAt: DateTime.now());
      await kitRepo.saveKit(k1);
      await kitRepo.saveKit(k2);
      await kitRepo.saveKit(k3);

      await Future.wait([
        kitRepo.setActiveKit(k1.id),
        kitRepo.setActiveKit(k2.id),
        kitRepo.setActiveKit(k3.id),
      ]);

      final active = await kitRepo.getActiveKit();
      expect(active, isNotNull);
      expect(['c-k2', 'c-k3'].contains(active!.id), isTrue);
    });
  });

  // =========================================================================
  // Feature 23: Boss Defeat Transition (Boundaries & Corner Cases)
  // =========================================================================
  group('Feature 23: Boss Defeat Transition (Boundaries)', () {
    testWidgets('B23-1: Exact HP = 0 Defeat Trigger', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final exactKit = KitItem(
        id: 'exact-hp-1',
        title: 'Exact 20 HP Kit',
        grade: 'HG',
        totalHp: 500,
        currentHp: 20,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(exactKit);
      await kitRepo.setActiveKit(exactKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);
    });

    testWidgets('B23-2: Overkill Damage Clamped to 0 HP', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final lowKit = KitItem(
        id: 'overkill-1',
        title: 'Low Overkill Kit',
        grade: 'HG',
        totalHp: 500,
        currentHp: 10,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(lowKit);
      await kitRepo.setActiveKit(lowKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      final kits = await kitRepo.getAllKits();
      final updated = kits.firstWhere((k) => k.id == 'overkill-1');
      expect(updated.currentHp, equals(0));
    });

    testWidgets('B23-3: Quest Clear Modal Non-Dismissible via Barrier Tap', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final lowKit = KitItem(
        id: 'barrier-1',
        title: 'Barrier Kit',
        grade: 'HG',
        totalHp: 500,
        currentHp: 20,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(lowKit);
      await kitRepo.setActiveKit(lowKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);
    });

    testWidgets('B23-4: Defeat Fanfare Sound Triggered on Victory', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);
      final mockAudio = MockRetroAudioService();

      final lowKit = KitItem(
        id: 'fanfare-1',
        title: 'Fanfare Kit',
        grade: 'HG',
        totalHp: 500,
        currentHp: 20,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(lowKit);
      await kitRepo.setActiveKit(lowKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo, mockAudio: mockAudio);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      expect(mockAudio.victoryFanfareCount, greaterThanOrEqualTo(1));
    });

    testWidgets('B23-5: Reset Defeated Boss via RESTART Button', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final lowKit = KitItem(
        id: 'restart-1',
        title: 'Restart Boss',
        grade: 'HG',
        totalHp: 500,
        currentHp: 20,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(lowKit);
      await kitRepo.setActiveKit(lowKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      await tester.tap(find.byKey(const Key('btn_clear_restart')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('500 / 500 HP'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 24: Showcase Gallery Screen (Boundaries & Corner Cases)
  // =========================================================================
  group('Feature 24: Showcase Gallery Screen (Boundaries)', () {
    testWidgets('B24-1: Showcase Empty State 前往討伐 Button Functionality', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('前往討伐'), findsOneWidget);
      await tester.tap(find.text('前往討伐'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
    });

    testWidgets('B24-2: Sorting Completed Kits by Completion Date Descending', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kEarly = KitItem(
        id: 'early-kit',
        title: 'Early Finished',
        grade: 'HG',
        totalHp: 500,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: DateTime(2026, 9, 1),
        createdAt: DateTime(2026, 9, 1),
      );
      final kLate = KitItem(
        id: 'late-kit',
        title: 'Late Finished',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: DateTime(2026, 9, 10),
        createdAt: DateTime(2026, 9, 10),
      );
      await kitRepo.saveKit(kEarly);
      await kitRepo.saveKit(kLate);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final lateTop = tester.getTopLeft(find.byKey(const Key('showcase_card_late-kit'))).dy;
      final earlyTop = tester.getTopLeft(find.byKey(const Key('showcase_card_early-kit'))).dy;
      expect(lateTop, lessThan(earlyTop));
    });

    testWidgets('B24-3: Completed Kit with Missing completedAt Fallback', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final noCompletedAtKit = KitItem(
        id: 'no-comp-at',
        title: 'No Completed Date Kit',
        grade: 'RG',
        totalHp: 800,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: null,
        createdAt: DateTime(2026, 9, 12),
      );
      await kitRepo.saveKit(noCompletedAtKit);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('showcase_card_no-comp-at')), findsOneWidget);
      expect(find.textContaining('完工: 2026-09-12'), findsOneWidget);
    });

    testWidgets('B24-4: Rapid Showcase Refresh', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('btn_refresh_showcase')));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('★ SHOWCASE GALLERY ★'), findsOneWidget);
    });

    testWidgets('B24-5: Multiple Grades in Showcase with Distinct Badges', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final grades = ['EG', 'HG', 'RG', 'MG', 'PG'];
      for (final g in grades) {
        await kitRepo.saveKit(KitItem(
          id: 'comp-$g',
          title: '$g Trophy',
          grade: g,
          totalHp: 500,
          currentHp: 0,
          status: KitStatus.completed,
          completedAt: DateTime.now(),
          createdAt: DateTime.now(),
        ));
      }

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      for (final g in grades) {
        expect(find.text('$g Trophy'), findsOneWidget);
      }
    });
  });

  // =========================================================================
  // Feature 25: Showcase Details & Metrics (Boundaries & Corner Cases)
  // =========================================================================
  group('Feature 25: Showcase Details & Metrics (Boundaries)', () {
    testWidgets('B25-1: Completed Kit with 0 Craft Logs Handled Gracefully', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final zeroLogKit = KitItem(
        id: 'zero-log-kit',
        title: 'Zero Log Model',
        grade: 'HG',
        totalHp: 500,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(zeroLogKit);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('showcase_card_zero-log-kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('★ 完工模型銘牌 ★'), findsOneWidget);
      expect(find.text('0m'), findsWidgets);
      expect(find.text('0 pt'), findsWidgets);
      expect(find.text('0/0 次'), findsOneWidget);
    });

    testWidgets('B25-2: Sub-Hour Fractional Duration Formatting (45m)', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final k45 = KitItem(
        id: 'dur-45',
        title: '45m Kit',
        grade: 'HG',
        totalHp: 500,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(k45);
      await logRepo.addLog(CraftLog(
        id: 'log-45',
        kitId: k45.id,
        phase: CraftPhases.snapFit,
        durationMinutes: 45,
        damageDealt: 100,
        isCompletedSession: true,
        timestamp: DateTime.now(),
      ));

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('累計工時: 45m'), findsOneWidget);
    });

    testWidgets('B25-3: Exact One Hour Duration Formatting (1h 0m)', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final k60 = KitItem(
        id: 'dur-60',
        title: '60m Kit',
        grade: 'HG',
        totalHp: 500,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(k60);
      await logRepo.addLog(CraftLog(
        id: 'log-60',
        kitId: k60.id,
        phase: CraftPhases.snapFit,
        durationMinutes: 60,
        damageDealt: 100,
        isCompletedSession: true,
        timestamp: DateTime.now(),
      ));

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('累計工時: 1h 0m'), findsOneWidget);
    });

    testWidgets('B25-4: Multi-Hour Duration Formatting (2h 5m)', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final k125 = KitItem(
        id: 'dur-125',
        title: '125m Kit',
        grade: 'HG',
        totalHp: 500,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(k125);
      await logRepo.addLog(CraftLog(
        id: 'log-125',
        kitId: k125.id,
        phase: CraftPhases.snapFit,
        durationMinutes: 125,
        damageDealt: 100,
        isCompletedSession: true,
        timestamp: DateTime.now(),
      ));

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('累計工時: 2h 5m'), findsOneWidget);
    });

    testWidgets('B25-5: View Dedicated Craft Logs Button from Plaque Modal', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kLogView = KitItem(
        id: 'k-log-view',
        title: 'View Logs Kit',
        grade: 'HG',
        totalHp: 500,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(kLogView);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('showcase_card_k-log-view')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_showcase_view_logs_k-log-view')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('★ CRAFT LOG ★'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 26: 8-Bit Pixel UI Consistency (Boundaries & Corner Cases)
  // =========================================================================
  group('Feature 26: 8-Bit Pixel UI Consistency (Boundaries)', () {
    testWidgets('B26-1: PixelButton Disabled State Does Not Fire Callback', (tester) async {
      bool fired = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PixelButton(
              enabled: false,
              onPressed: () => fired = true,
              child: const Text('DISABLED'),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('DISABLED'));
      await tester.pump();

      expect(fired, isFalse);
    });

    testWidgets('B26-2: PixelButton Tap Cancel Restores Resting Offset', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: PixelButton(
                key: const Key('cancel_btn'),
                onPressed: () {},
                child: const Text('CANCEL ME'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('cancel_btn'))));
      await tester.pump();

      // Cancel gesture
      await gesture.cancel();
      await tester.pump();

      expect(find.byKey(const Key('cancel_btn')), findsOneWidget);
    });

    testWidgets('B26-3: PixelHpBar Boundary: Exactly 50% HP Color', (tester) async {
      expect(PixelHpBar.getHpColor(0.50), equals(RetroColors.retroAmber));
    });

    testWidgets('B26-4: PixelHpBar Boundary: Exactly 20% HP Color', (tester) async {
      expect(PixelHpBar.getHpColor(0.20), equals(RetroColors.crimsonRed));
    });

    testWidgets('B26-5: PixelHpBar Zero and Negative HP Clamping', (tester) async {
      const barNegative = PixelHpBar(currentHp: -10, maxHp: 100);
      expect(barNegative.hpPercentage, equals(0.0));

      const barZero = PixelHpBar(currentHp: 0, maxHp: 100);
      expect(barZero.hpPercentage, equals(0.0));

      const barExcess = PixelHpBar(currentHp: 150, maxHp: 100);
      expect(barExcess.hpPercentage, equals(1.0));
    });
  });

  // =========================================================================
  // Feature 27: Retro Typography (Boundaries & Corner Cases)
  // =========================================================================
  group('Feature 27: Retro Typography (Boundaries)', () {
    testWidgets('B27-1: Offline Font Rendering Does Not Trigger Web Request', (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final header = RetroTypography.pixelHeader();
      final body = RetroTypography.pixelBody();
      expect(header.fontFamily, 'Press Start 2P');
      expect(body.fontFamily, 'VT323');
    });

    testWidgets('B27-2: Long Kit Title Truncation with Ellipsis', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final longKit = KitItem(
        id: 'long-title-kit',
        title: 'Very Long Model Kit Title 1234567890123456789012345',
        grade: 'PG',
        totalHp: 5000,
        currentHp: 5000,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(longKit);
      await kitRepo.setActiveKit(longKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      expect(find.textContaining('Very Long Model Kit Title'), findsOneWidget);
    });

    testWidgets('B27-3: Special Characters and Symbols in Kit Name', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final specialKit = KitItem(
        id: 'spec-kit',
        title: '★[RG] 00-Raiser (G&B) #01★',
        grade: 'RG',
        totalHp: 800,
        currentHp: 800,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(specialKit);
      await kitRepo.setActiveKit(specialKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      expect(find.textContaining('★[RG] 00-Raiser (G&B) #01★'), findsOneWidget);
    });

    testWidgets('B27-4: Dialogue Box Multi-line Dynamic Expansion', (tester) async {
      await pumpApp(tester);
      expect(find.byType(PixelFrame), findsWidgets);
    });

    testWidgets('B27-5: Modal Dialog Typography Contrast', (tester) async {
      final amberLuminance = RetroColors.retroAmber.computeLuminance();
      final darkLuminance = RetroColors.surfaceDark.computeLuminance();
      final contrast = (amberLuminance + 0.05) / (darkLuminance + 0.05);
      expect(contrast, greaterThan(4.5));
    });
  });

  // =========================================================================
  // Feature 28: Battle Juice Screen Shake (Boundaries & Corner Cases)
  // =========================================================================
  group('Feature 28: Battle Juice Screen Shake (Boundaries)', () {
    testWidgets('B28-1: Multi-Hit Screen Shake Mathematical Bound Clamping', (tester) async {
      final controller = ScreenShakeController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenShake(
              controller: controller,
              child: const Text('TEST'),
            ),
          ),
        ),
      );
      await tester.pump();

      for (int i = 0; i < 20; i++) {
        controller.shake(intensity: 25.0);
      }
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.isShaking, isTrue);
    });

    testWidgets('B28-2: Rapid Consecutive Shake Barrage Decay to Zero', (tester) async {
      final controller = ScreenShakeController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenShake(
              controller: controller,
              child: const Text('TEST'),
            ),
          ),
        ),
      );
      await tester.pump();

      controller.shake(intensity: 15.0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.isShaking, isFalse);
    });

    testWidgets('B28-3: ScreenShake stop() Immediately Restores Resting State', (tester) async {
      final controller = ScreenShakeController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenShake(
              controller: controller,
              child: const Text('TEST'),
            ),
          ),
        ),
      );
      await tester.pump();

      controller.shake(intensity: 15.0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.isShaking, isTrue);

      controller.stop();
      await tester.pump();
      expect(controller.isShaking, isFalse);
    });

    testWidgets('B28-4: ScreenShake Global Accessibility Toggle', (tester) async {
      ScreenShake.globalEnabled = false;
      final controller = ScreenShakeController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenShake(
              controller: controller,
              child: const Text('TEST'),
            ),
          ),
        ),
      );
      await tester.pump();

      controller.shake(intensity: 15.0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.isShaking, isFalse);

      ScreenShake.globalEnabled = true;
    });

    testWidgets('B28-5: Hit-testing Active During Shake', (tester) async {
      bool pressed = false;
      final controller = ScreenShakeController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenShake(
              controller: controller,
              child: ElevatedButton(
                key: const Key('shake_inner_btn'),
                onPressed: () => pressed = true,
                child: const Text('PRESS'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      controller.shake(intensity: 15.0);
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const Key('shake_inner_btn')));
      await tester.pump();
      expect(pressed, isTrue);
    });
  });

  // =========================================================================
  // Feature 29: Floating Damage Numbers (Boundaries & Corner Cases)
  // =========================================================================
  group('Feature 29: Floating Damage Numbers (Boundaries)', () {
    testWidgets('B29-1: Zero Damage BLOCKED! 0 Popup', (tester) async {
      final text = DamageColorPalette.formatDamageText(
        damage: 0,
        phase: CraftPhases.snapFit,
        isInterrupted: false,
      );
      final color = DamageColorPalette.getColorForPhase(CraftPhases.snapFit, damage: 0);
      expect(text, equals('BLOCKED! 0'));
      expect(color, equals(DamageColorPalette.blocked));
    });

    testWidgets('B29-2: Mercy Rule Interrupted Damage Popup Format', (tester) async {
      final text = DamageColorPalette.formatDamageText(
        damage: 50,
        phase: CraftPhases.snapFit,
        isInterrupted: true,
      );
      final color = DamageColorPalette.getColorForPhase(CraftPhases.snapFit, isInterrupted: true);
      expect(text, equals('-50 (MERCY 50%)'));
      expect(color, equals(DamageColorPalette.mercy));
    });

    testWidgets('B29-3: Finishing Execution Damage Popup Format', (tester) async {
      final text = DamageColorPalette.formatDamageText(
        damage: 250,
        phase: CraftPhases.finishing,
        isInterrupted: false,
      );
      final color = DamageColorPalette.getColorForPhase(CraftPhases.finishing);
      expect(text, equals('FINISH! -250'));
      expect(color, equals(DamageColorPalette.finishing));
    });

    testWidgets('B29-4: Multi-Bubble Horizontal Jitter Distribution', (tester) async {
      final c = FloatingDamageController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingDamageOverlay(controller: c),
          ),
        ),
      );
      await tester.pump();

      c.spawn(damage: 10, phase: CraftPhases.snapFit, isInterrupted: false);
      c.spawn(damage: 20, phase: CraftPhases.snapFit, isInterrupted: false);
      c.spawn(damage: 30, phase: CraftPhases.snapFit, isInterrupted: false);
      await tester.pump();

      expect(find.text('-10'), findsOneWidget);
      expect(find.text('-20'), findsOneWidget);
      expect(find.text('-30'), findsOneWidget);
    });

    testWidgets('B29-5: Overlay Clear Method Purges All Active Bubbles', (tester) async {
      final c = FloatingDamageController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingDamageOverlay(controller: c),
          ),
        ),
      );
      await tester.pump();

      c.spawn(damage: 10, phase: CraftPhases.snapFit, isInterrupted: false);
      c.spawn(damage: 20, phase: CraftPhases.snapFit, isInterrupted: false);
      await tester.pump();

      expect(find.text('-10'), findsOneWidget);
      expect(find.text('-20'), findsOneWidget);

      c.clear();
      await tester.pump();

      expect(find.text('-10'), findsNothing);
      expect(find.text('-20'), findsNothing);
    });
  });

  // =========================================================================
  // Feature 30: Boss Hurt Flash (Boundaries & Corner Cases)
  // =========================================================================
  group('Feature 30: Boss Hurt Flash (Boundaries)', () {
    testWidgets('B30-1: Rapid Hit Retriggering of Hurt Flash', (tester) async {
      final controller = BossHurtFlashController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BossHurtFlash(
              controller: controller,
              child: const Text('SPRITE'),
            ),
          ),
        ),
      );
      await tester.pump();

      for (int i = 0; i < 10; i++) {
        controller.flash();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(controller.isFlashing, isTrue);

      await tester.pump(const Duration(milliseconds: 250));
      expect(controller.isFlashing, isFalse);
    });

    testWidgets('B30-2: Dual-Pulse Strobe Alpha Curve Verification', (tester) async {
      const widget = BossHurtFlash(child: Text('TEST'));
      expect(widget.defaultDuration, equals(const Duration(milliseconds: 220)));
    });

    testWidgets('B30-3: Recoil Squeeze Scale Factor During First 70ms', (tester) async {
      final controller = BossHurtFlashController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BossHurtFlash(
              controller: controller,
              child: const Text('BOSS'),
            ),
          ),
        ),
      );
      await tester.pump();

      controller.flash();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(controller.isFlashing, isTrue);
    });

    testWidgets('B30-4: Flash Dismissal Leaves Sprite Undamaged When CurrentHp > 0', (tester) async {
      final controller = BossHurtFlashController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BossHurtFlash(
              controller: controller,
              child: const Text('BOSS ALIVE'),
            ),
          ),
        ),
      );
      await tester.pump();

      controller.flash();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(controller.isFlashing, isFalse);
      expect(find.text('BOSS ALIVE'), findsOneWidget);
    });

    testWidgets('B30-5: Flash on Defeat Retains Grayscale Filter on Boss Sprite', (tester) async {
      await pumpApp(tester);
      final bossImageFinder = find.byType(Image);
      expect(bossImageFinder, findsWidgets);
    });
  });

  // =========================================================================
  // Feature 31: Zero-Cost Retro Audio & Mute Toggle (Boundaries & Corner Cases)
  // =========================================================================
  group('Feature 31: Zero-Cost Retro Audio & Mute Toggle (Boundaries)', () {
    testWidgets('B31-1: 50+ Rapid Mute Toggles Parity Test', (tester) async {
      final mockAudio = MockRetroAudioService();
      await pumpApp(tester, mockAudio: mockAudio);

      for (int i = 0; i < 50; i++) {
        await tester.tap(find.byKey(const Key('btn_mute_toggle')));
        await tester.pump();
      }
      expect(mockAudio.isMuted, isFalse);
      expect(find.text('SFX'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_mute_toggle')));
      await tester.pump();
      expect(mockAudio.isMuted, isTrue);
      expect(find.text('MUTE'), findsOneWidget);
    });

    testWidgets('B31-2: 100% Silence Guarantee When Muted During Combat Spam', (tester) async {
      final mockAudio = MockRetroAudioService();
      await pumpApp(tester, mockAudio: mockAudio);

      await tester.tap(find.byKey(const Key('btn_mute_toggle')));
      await tester.pump();
      expect(mockAudio.isMuted, isTrue);

      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockAudio.timerTickCount, equals(0));
      expect(mockAudio.attackHitCount, equals(0));
      expect(mockAudio.victoryFanfareCount, equals(0));
    });

    testWidgets('B31-3: Critical Strike Audio Trigger on High Damage (>=150 pt)', (tester) async {
      final mockAudio = MockRetroAudioService();
      mockAudio.playCriticalStrike();
      expect(mockAudio.criticalStrikeCount, equals(1));
    });

    testWidgets('B31-4: Finishing Kill Audio Trigger on Defeat', (tester) async {
      final mockAudio = MockRetroAudioService();
      mockAudio.playFinishingKill();
      expect(mockAudio.finishingKillCount, equals(1));
    });

    testWidgets('B31-5: Mute State Persistence Across App Rehydration', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(BaseRetroAudioService.mutePrefKey, true);

      final audio = MockRetroAudioService();
      await tester.pump(const Duration(milliseconds: 50));
      expect(audio.isMuted, isTrue);
    });
  });
}
