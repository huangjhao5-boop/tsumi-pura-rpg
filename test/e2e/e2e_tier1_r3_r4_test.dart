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
import 'package:nifty_heisenberg/presentation/screens/hangar_screen.dart';
import 'package:nifty_heisenberg/presentation/theme/retro_colors.dart';
import 'package:nifty_heisenberg/presentation/theme/retro_typography.dart';
import 'package:nifty_heisenberg/presentation/widgets/boss_hurt_flash.dart';
import 'package:nifty_heisenberg/presentation/widgets/floating_damage_text.dart';
import 'package:nifty_heisenberg/presentation/widgets/pixel_button.dart';
import 'package:nifty_heisenberg/presentation/widgets/pixel_frame.dart';
import 'package:nifty_heisenberg/presentation/widgets/pixel_hp_bar.dart';
import 'package:nifty_heisenberg/presentation/widgets/retro_bottom_nav_bar.dart';
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
  // Feature 18: Model Hangar Screen (List View, Status, Active Target)
  // =========================================================================
  group('Feature 18: Model Hangar Screen', () {
    testWidgets('T1-F18-01: Hangar Navigation & Initial Kit Render', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('★ MODEL HANGAR ★'), findsOneWidget);
      expect(find.byKey(const Key('btn_hangar_back')), findsOneWidget);
      expect(find.byKey(Key('kit_card_${GameConstants.defaultKitId}')), findsOneWidget);
      expect(find.text(GameConstants.defaultKitTitle), findsOneWidget);
      expect(find.text('HG'), findsWidgets);
      expect(find.text('★ 當前出擊目標 (ACTIVE BOSS)'), findsOneWidget);
    });

    testWidgets('T1-F18-02: Kit Status Indicators (山積, 施工中, 完工)', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final now = DateTime.now();
      final kitA = KitItem(
        id: 'kit-a',
        title: 'Kit A Unstarted',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: now,
      );
      final kitB = KitItem(
        id: 'kit-b',
        title: 'Kit B InProgress',
        grade: 'RG',
        totalHp: 800,
        currentHp: 400,
        status: KitStatus.inProgress,
        createdAt: now,
      );
      final kitC = KitItem(
        id: 'kit-c',
        title: 'Kit C Completed',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: now,
        createdAt: now,
      );

      await kitRepo.saveKit(kitA);
      await kitRepo.saveKit(kitB);
      await kitRepo.saveKit(kitC);
      await kitRepo.setActiveKit(kitA.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('山積'), findsWidgets);
      expect(find.text('施工中'), findsWidgets);
      expect(find.text('完工'), findsWidgets);
    });

    testWidgets('T1-F18-03: Filter Tabs Dynamic Switching', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final now = DateTime.now();
      final kitA = KitItem(
        id: 'filter-kit-a',
        title: 'Filter A Unstarted',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: now,
      );
      final kitB = KitItem(
        id: 'filter-kit-b',
        title: 'Filter B InProgress',
        grade: 'RG',
        totalHp: 800,
        currentHp: 300,
        status: KitStatus.inProgress,
        createdAt: now,
      );
      final kitC = KitItem(
        id: 'filter-kit-c',
        title: 'Filter C Completed',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: now,
        createdAt: now,
      );

      await kitRepo.saveKit(kitA);
      await kitRepo.saveKit(kitB);
      await kitRepo.saveKit(kitC);
      await kitRepo.setActiveKit(kitA.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Filter: unstarted
      await tester.tap(find.byKey(const Key('filter_unstarted')));
      await tester.pump();
      expect(find.byKey(const Key('kit_card_filter-kit-a')), findsOneWidget);
      expect(find.byKey(const Key('kit_card_filter-kit-b')), findsNothing);
      expect(find.byKey(const Key('kit_card_filter-kit-c')), findsNothing);

      // Filter: in_progress
      await tester.tap(find.byKey(const Key('filter_in_progress')));
      await tester.pump();
      expect(find.byKey(const Key('kit_card_filter-kit-a')), findsNothing);
      expect(find.byKey(const Key('kit_card_filter-kit-b')), findsOneWidget);
      expect(find.byKey(const Key('kit_card_filter-kit-c')), findsNothing);

      // Filter: completed
      await tester.tap(find.byKey(const Key('filter_completed')));
      await tester.pump();
      expect(find.byKey(const Key('kit_card_filter-kit-a')), findsNothing);
      expect(find.byKey(const Key('kit_card_filter-kit-b')), findsNothing);
      expect(find.byKey(const Key('kit_card_filter-kit-c')), findsOneWidget);

      // Filter: all
      await tester.tap(find.byKey(const Key('filter_all')));
      await tester.pump();
      expect(find.byKey(const Key('kit_card_filter-kit-a')), findsOneWidget);
      expect(find.byKey(const Key('kit_card_filter-kit-b')), findsOneWidget);
      expect(find.byKey(const Key('kit_card_filter-kit-c')), findsOneWidget);
    });

    testWidgets('T1-F18-04: Active Kit Switching via Card Button', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final kit1 = KitItem(
        id: 'switch-kit-1',
        title: 'Kit One',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      final kit2 = KitItem(
        id: 'switch-kit-2',
        title: 'Kit Two',
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

      // Tap set active on Kit 2
      await tester.tap(find.byKey(const Key('btn_set_active_switch-kit-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('設為當前討伐目標'), findsOneWidget);
      expect(find.descendant(
        of: find.byKey(const Key('kit_card_switch-kit-2')),
        matching: find.text('★ 當前出擊目標 (ACTIVE BOSS)'),
      ), findsOneWidget);
    });

    testWidgets('T1-F18-05: Hangar Back Navigation to Battle Screen', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('★ MODEL HANGAR ★'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
      expect(find.text('★ MODEL HANGAR ★'), findsNothing);
    });
  });

  // =========================================================================
  // Feature 19: Model CRUD Management (Add, Edit, Delete)
  // =========================================================================
  group('Feature 19: Model CRUD Management', () {
    testWidgets('T1-F19-01: Add New Kit via Dialog', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('input_kit_title')), 'RG 沙薩比');
      await tester.tap(find.byKey(const Key('chip_grade_RG')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('RG 沙薩比'), findsOneWidget);
      expect(find.textContaining('800/800'), findsOneWidget);
    });

    testWidgets('T1-F19-02: Edit Existing Kit Title and Grade', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final editKit = KitItem(
        id: 'kit-edit-1',
        title: 'Original Kit',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(editKit);
      await kitRepo.setActiveKit(editKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_edit_kit_kit-edit-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('input_kit_title')), 'MG 自由鋼彈 2.0');
      await tester.tap(find.byKey(const Key('chip_grade_MG')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('MG 自由鋼彈 2.0'), findsOneWidget);
      expect(find.textContaining('500/1500'), findsOneWidget);
    });

    testWidgets('T1-F19-03: Delete Kit with Confirmation Dialog', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final activeKit = KitItem.initialSeedKit();
      final delKit = KitItem(
        id: 'kit-del-1',
        title: 'To Be Deleted',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(activeKit);
      await kitRepo.saveKit(delKit);
      await kitRepo.setActiveKit(activeKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('To Be Deleted'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_delete_kit_kit-del-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('解體除籍確認'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_confirm_delete')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('To Be Deleted'), findsNothing);
    });

    testWidgets('T1-F19-04: Cancel Add Kit Dialog Preserves Inventory', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('input_kit_title')), 'Temporary Kit');
      await tester.tap(find.byKey(const Key('btn_dialog_cancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.widgetWithText(KitCard, 'Temporary Kit'), findsNothing);
    });

    testWidgets('T1-F19-05: Cancel Delete Kit Dialog Keeps Kit Intact', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final keepKit = KitItem(
        id: 'kit-keep-1',
        title: 'Keep Me Alive',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(keepKit);
      await kitRepo.setActiveKit(keepKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_delete_kit_kit-keep-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_cancel_delete')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Keep Me Alive'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 20: Grade & HP Defaults Presets
  // =========================================================================
  group('Feature 20: Grade & HP Defaults Presets', () {
    testWidgets('T1-F20-01: EG Preset Defaults to 300 HP', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('chip_grade_EG')));
      await tester.pump();

      final hpField = tester.widget<TextFormField>(find.byKey(const Key('input_kit_hp')));
      expect(hpField.controller?.text, '300');
    });

    testWidgets('T1-F20-02: HG Preset Defaults to 500 HP', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('chip_grade_HG')));
      await tester.pump();

      final hpField = tester.widget<TextFormField>(find.byKey(const Key('input_kit_hp')));
      expect(hpField.controller?.text, '500');
    });

    testWidgets('T1-F20-03: RG Preset Defaults to 800 HP', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('chip_grade_RG')));
      await tester.pump();

      final hpField = tester.widget<TextFormField>(find.byKey(const Key('input_kit_hp')));
      expect(hpField.controller?.text, '800');
    });

    testWidgets('T1-F20-04: MG Preset Defaults to 1500 HP', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('chip_grade_MG')));
      await tester.pump();

      final hpField = tester.widget<TextFormField>(find.byKey(const Key('input_kit_hp')));
      expect(hpField.controller?.text, '1500');
    });

    testWidgets('T1-F20-05: PG Preset Defaults to 5000 HP', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('chip_grade_PG')));
      await tester.pump();

      final hpField = tester.widget<TextFormField>(find.byKey(const Key('input_kit_hp')));
      expect(hpField.controller?.text, '5000');
    });
  });

  // =========================================================================
  // Feature 21: Custom HP Input & Override
  // =========================================================================
  group('Feature 21: Custom HP Input & Override', () {
    testWidgets('T1-F21-01: Enable Custom HP Checkbox Enables Input Field', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('預設 HP (依級別自動填寫)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('checkbox_custom_hp')));
      await tester.pump();

      expect(find.text('自訂 HP (> 0)'), findsOneWidget);
    });

    testWidgets('T1-F21-02: Save Kit with Valid Custom HP Value', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('input_kit_title')), '自訂巨神兵');
      await tester.tap(find.byKey(const Key('checkbox_custom_hp')));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('input_kit_hp')), '3200');
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('自訂巨神兵'), findsOneWidget);
      expect(find.text('自訂'), findsOneWidget);
      expect(find.textContaining('3200/3200'), findsOneWidget);
    });

    testWidgets('T1-F21-03: Validation Error on Empty Custom HP Field', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('input_kit_title')), '無效HP怪');
      await tester.tap(find.byKey(const Key('checkbox_custom_hp')));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('input_kit_hp')), '');
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();

      expect(find.text('請輸入 HP'), findsOneWidget);
    });

    testWidgets('T1-F21-04: Validation Error on Zero Custom HP', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('input_kit_title')), '零血怪');
      await tester.tap(find.byKey(const Key('checkbox_custom_hp')));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('input_kit_hp')), '0');
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();

      expect(find.text('HP 必須為大於 0 之整數'), findsOneWidget);
    });

    testWidgets('T1-F21-05: Validation Error on Excessive Custom HP (>99,999)', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('input_kit_title')), '超限巨怪');
      await tester.tap(find.byKey(const Key('checkbox_custom_hp')));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('input_kit_hp')), '100000');
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();

      expect(find.text('HP 不可超過 99,999'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 22: Active Kit Battle Link
  // =========================================================================
  group('Feature 22: Active Kit Battle Link', () {
    testWidgets('T1-F22-01: Hangar Selection Reflects on Battle Screen Boss Card', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final zaku = KitItem(
        id: 'kit-zaku',
        title: 'MS-06S 薩克II',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 1500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(zaku);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_set_active_kit-zaku')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('MS-06S 薩克II'), findsOneWidget);
      expect(find.textContaining('1500 / 1500 HP'), findsOneWidget);
    });

    testWidgets('T1-F22-02: Active Target Change Updates Battle Dialogue', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final k1 = KitItem.initialSeedKit();
      final gouf = KitItem(
        id: 'kit-gouf',
        title: 'MS-07B 古夫',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(k1);
      await kitRepo.saveKit(gouf);
      await kitRepo.setActiveKit(k1.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_set_active_kit-gouf')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('已鎖定新討伐目標！請選擇工序開工。'), findsOneWidget);
    });

    testWidgets('T1-F22-03: Finishing Skill Gate Automatically Locks on High-HP Target Switch', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final lowHpKit = KitItem(
        id: 'low-hp-kit',
        title: '瀕死怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 50, // 10% <= 20%
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      final fullHpKit = KitItem(
        id: 'full-hp-kit',
        title: '滿血怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: KitStatus.unstarted,
        createdAt: DateTime.now(),
      );

      await kitRepo.saveKit(lowHpKit);
      await kitRepo.saveKit(fullHpKit);
      await kitRepo.setActiveKit(lowHpKit.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);

      // Finishing is unlocked for lowHpKit
      expect(find.text('水貼\n2.5x'), findsOneWidget);
      await tester.tap(find.text('水貼\n2.5x'));
      await tester.pump();

      // Switch to fullHpKit in Hangar
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_set_active_full-hp-kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Finishing is locked now on 500/500 HP
      expect(find.text('水貼\n🔒20%'), findsOneWidget);
    });

    testWidgets('T1-F22-04: Add Kit with Set Active Checked Immediately Links to Battle', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_add_kit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('input_kit_title')), '全新出擊怪');
      await tester.tap(find.byKey(const Key('btn_dialog_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('全新出擊怪'), findsOneWidget);
    });

    testWidgets('T1-F22-05: Bottom Navigation Hangar to Battle Transition', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_nav_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('★ MODEL HANGAR ★'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_hangar_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 23: Boss Defeat Transition & Quest Clear Flow
  // =========================================================================
  group('Feature 23: Boss Defeat Transition & Quest Clear Flow', () {
    testWidgets('T1-F23-01: Boss HP <= 0 Triggers Quest Clear Modal Dialog', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final nearDead = KitItem(
        id: 'near-dead-1',
        title: '殘命怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 10,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(nearDead);
      await kitRepo.setActiveKit(nearDead.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      expect(find.text('★ QUEST CLEAR ★'), findsOneWidget);
      expect(find.byKey(const Key('btn_clear_to_showcase')), findsOneWidget);
      expect(find.byKey(const Key('btn_clear_to_hangar')), findsOneWidget);
      expect(find.byKey(const Key('btn_clear_restart')), findsOneWidget);
    });

    testWidgets('T1-F23-02: Defeated Boss Status Marked as Completed', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final nearDead = KitItem(
        id: 'near-dead-2',
        title: '必死怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 10,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(nearDead);
      await kitRepo.setActiveKit(nearDead.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      final kits = await kitRepo.getAllKits();
      final updated = kits.firstWhere((k) => k.id == 'near-dead-2');
      expect(updated.isCompleted, isTrue);
      expect(updated.completedAt, isNotNull);
    });

    testWidgets('T1-F23-03: Quest Clear 前往展示櫃觀看 Navigates to Showcase', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final nearDead = KitItem(
        id: 'near-dead-3',
        title: '展櫃導向怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 10,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(nearDead);
      await kitRepo.setActiveKit(nearDead.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      await tester.tap(find.byKey(const Key('btn_clear_to_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('★ SHOWCASE GALLERY ★'), findsOneWidget);
    });

    testWidgets('T1-F23-04: Quest Clear 返回機庫挑選新目標 Navigates to Hangar', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final nearDead = KitItem(
        id: 'near-dead-4',
        title: '機庫導向怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 10,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(nearDead);
      await kitRepo.setActiveKit(nearDead.id);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      await tester.tap(find.byKey(const Key('btn_clear_to_hangar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('★ MODEL HANGAR ★'), findsOneWidget);
    });

    testWidgets('T1-F23-05: Quest Clear 收錄至展示櫃 Resets Battle Stage', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final nearDead = KitItem(
        id: 'near-dead-5',
        title: '重置怪',
        grade: 'HG',
        totalHp: 500,
        currentHp: 10,
        status: KitStatus.inProgress,
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(nearDead);
      await kitRepo.setActiveKit(nearDead.id);

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

      expect(find.text('★ QUEST CLEAR ★'), findsNothing);
      expect(find.textContaining('500 / 500 HP'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 24: Showcase Gallery Screen
  // =========================================================================
  group('Feature 24: Showcase Gallery Screen', () {
    testWidgets('T1-F24-01: Empty Showcase State Renders When No Kits Completed', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('showcase_empty_state')), findsOneWidget);
      expect(find.text('尚無完工模型，快去討伐堆積吧！'), findsOneWidget);
      expect(find.text('前往討伐'), findsOneWidget);
    });

    testWidgets('T1-F24-02: Showcase Header Displays Accurate Completed Count', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final now = DateTime.now();
      final c1 = KitItem(
        id: 'comp-1',
        title: 'Completed One',
        grade: 'HG',
        totalHp: 500,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: now,
        createdAt: now,
      );
      final c2 = KitItem(
        id: 'comp-2',
        title: 'Completed Two',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: now,
        createdAt: now,
      );
      await kitRepo.saveKit(c1);
      await kitRepo.saveKit(c2);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('完工: 2 盒'), findsOneWidget);
      expect(find.byKey(const Key('btn_refresh_showcase')), findsOneWidget);
    });

    testWidgets('T1-F24-03: Completed Kit Card Displays Grade Badge, Title, Trophy Icon', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final now = DateTime.now();
      final trophyKit = KitItem(
        id: 'trophy-1',
        title: 'RG 自由鋼彈',
        grade: 'RG',
        totalHp: 800,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: now,
        createdAt: now,
      );
      await kitRepo.saveKit(trophyKit);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('showcase_card_trophy-1')), findsOneWidget);
      expect(find.text('RG 自由鋼彈'), findsOneWidget);
      expect(find.text('RG'), findsWidgets);
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    });

    testWidgets('T1-F24-04: Showcase Card Displays Completion Date, Duration, Session Count', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final finishDate = DateTime(2026, 9, 14, 15, 30);
      final trophyKit = KitItem(
        id: 'trophy-2',
        title: 'RG 脈衝鋼彈',
        grade: 'RG',
        totalHp: 800,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: finishDate,
        createdAt: finishDate,
      );
      await kitRepo.saveKit(trophyKit);

      final log1 = CraftLog(
        id: 'log-1',
        kitId: trophyKit.id,
        phase: CraftPhases.snapFit,
        durationMinutes: 25,
        damageDealt: 100,
        isCompletedSession: true,
        timestamp: finishDate,
      );
      final log2 = CraftLog(
        id: 'log-2',
        kitId: trophyKit.id,
        phase: CraftPhases.finishing,
        durationMinutes: 25,
        damageDealt: 700,
        isCompletedSession: true,
        timestamp: finishDate,
      );
      await logRepo.addLog(log1);
      await logRepo.addLog(log2);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('完工: 2026-09-14'), findsOneWidget);
      expect(find.textContaining('累計工時: 50m'), findsOneWidget);
      expect(find.textContaining('討伐次數: 2 次'), findsOneWidget);
    });

    testWidgets('T1-F24-05: Showcase Back Button Returns to Previous Screen', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('★ SHOWCASE GALLERY ★'), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_showcase_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
      expect(find.text('★ SHOWCASE GALLERY ★'), findsNothing);
    });
  });

  // =========================================================================
  // Feature 25: Showcase Details & Metrics Plaque Modal
  // =========================================================================
  group('Feature 25: Showcase Details & Metrics Plaque Modal', () {
    testWidgets('T1-F25-01: Tapping Showcase Card Opens Detail Plaque Dialog', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final trophyKit = KitItem(
        id: 'plaque-1',
        title: 'RG 自由鋼彈',
        grade: 'RG',
        totalHp: 800,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(trophyKit);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('showcase_card_plaque-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('showcase_detail_dialog')), findsOneWidget);
      expect(find.text('★ 完工模型銘牌 ★'), findsOneWidget);
    });

    testWidgets('T1-F25-02: Plaque Modal Displays Model Specs & Date', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final date = DateTime(2026, 9, 14);
      final trophyKit = KitItem(
        id: 'plaque-2',
        title: 'RG 自由鋼彈',
        grade: 'RG',
        totalHp: 800,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: date,
        createdAt: date,
      );
      await kitRepo.saveKit(trophyKit);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('showcase_card_plaque-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('【RG】RG 自由鋼彈'), findsOneWidget);
      expect(find.textContaining('規格: RG 1/144 · 血量: 800 HP'), findsOneWidget);
      expect(find.textContaining('完工日期: 2026-09-14'), findsOneWidget);
    });

    testWidgets('T1-F25-03: Plaque KPI Summary Tiles (工時, 傷害, 討伐次數)', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final trophyKit = KitItem(
        id: 'plaque-3',
        title: 'MG 獵魔鋼彈',
        grade: 'MG',
        totalHp: 1500,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(trophyKit);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('showcase_card_plaque-3')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('累計工時'), findsOneWidget);
      expect(find.text('總輸出傷害'), findsOneWidget);
      expect(find.text('討伐次數'), findsOneWidget);
    });

    testWidgets('T1-F25-04: 5-Phase Breakdown Progress Bars', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final trophyKit = KitItem(
        id: 'plaque-4',
        title: 'HG 風靈鋼彈',
        grade: 'HG',
        totalHp: 500,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(trophyKit);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('showcase_card_plaque-4')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('【5 大工序工時佔比】'), findsOneWidget);
      expect(find.textContaining('Snap-fit (剪鉗連擊)'), findsOneWidget);
      expect(find.textContaining('Sanding (破甲打磨)'), findsOneWidget);
      expect(find.textContaining('Detailing (弱點刻線)'), findsOneWidget);
      expect(find.textContaining('Airbrush (噴筆重砲)'), findsOneWidget);
      expect(find.textContaining('Finishing (處決水貼)'), findsOneWidget);
    });

    testWidgets('T1-F25-05: Close Plaque Modal Button', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalStorageService(prefs);
      final logRepo = CraftLogRepository(storage);
      final kitRepo = KitRepository(storage, logRepo);

      final trophyKit = KitItem(
        id: 'plaque-5',
        title: 'HG 吉姆',
        grade: 'HG',
        totalHp: 500,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(trophyKit);

      await pumpApp(tester, kitRepo: kitRepo, logRepo: logRepo);
      await tester.tap(find.byKey(const Key('btn_showcase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('showcase_card_plaque-5')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('showcase_detail_dialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('btn_showcase_close_detail')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byKey(const Key('showcase_detail_dialog')), findsNothing);
      expect(find.text('★ SHOWCASE GALLERY ★'), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 26: 8-Bit Pixel UI Consistency
  // =========================================================================
  group('Feature 26: 8-Bit Pixel UI Consistency', () {
    testWidgets('T1-F26-01: Retro Workbench Dark Slate Theme Palette', (tester) async {
      expect(RetroColors.darkSlate, const Color(0xFF12141F));
      expect(RetroColors.surfaceDark, const Color(0xFF1B1B26));
      expect(RetroColors.borderDark, const Color(0xFF383A59));

      await pumpApp(tester);
      final theme = Theme.of(tester.element(find.byType(Scaffold)));
      expect(theme.scaffoldBackgroundColor, RetroColors.darkSlate);
    });

    testWidgets('T1-F26-02: PixelFrame Renders Hard Angular 8-Bit Borders', (tester) async {
      await pumpApp(tester);
      final frames = tester.widgetList<PixelFrame>(find.byType(PixelFrame));
      expect(frames.isNotEmpty, isTrue);

      final bossFrame = frames.first;
      expect(bossFrame.borderColor, const Color(0xFF44475A));
      expect(bossFrame.backgroundColor, const Color(0xFF1D1E2C));
    });

    testWidgets('T1-F26-03: PixelButton Renders Tactile 3D Bevel', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PixelButton(
              key: const Key('test_pixel_btn'),
              onPressed: () => pressed = true,
              child: const Text('PIXEL'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('test_pixel_btn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('test_pixel_btn')));
      await tester.pump();
      expect(pressed, isTrue);
    });

    testWidgets('T1-F26-04: PixelHpBar 3-Phase Color Transitions', (tester) async {
      expect(PixelHpBar.getHpColor(0.8), RetroColors.neonGreen);
      expect(PixelHpBar.getHpColor(0.4), RetroColors.retroAmber);
      expect(PixelHpBar.getHpColor(0.1), RetroColors.crimsonRed);
    });

    testWidgets('T1-F26-05: Retro Bottom Navigation Dock Bar Styling', (tester) async {
      await pumpApp(tester);
      expect(find.byType(RetroBottomNavBar), findsOneWidget);
      expect(find.byKey(const Key('btn_nav_battle')), findsOneWidget);
      expect(find.byKey(const Key('btn_nav_hangar')), findsOneWidget);
      expect(find.byKey(const Key('btn_nav_showcase')), findsOneWidget);
      expect(find.byKey(const Key('btn_nav_craft_log')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('btn_nav_battle')), matching: find.text('討伐')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('btn_nav_hangar')), matching: find.text('機庫')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('btn_nav_showcase')), matching: find.text('展櫃')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('btn_nav_craft_log')), matching: find.text('日誌')), findsOneWidget);
    });
  });

  // =========================================================================
  // Feature 27: Retro Typography
  // =========================================================================
  group('Feature 27: Retro Typography', () {
    testWidgets('T1-F27-01: Pixel Header Font Configuration', (tester) async {
      final style = RetroTypography.pixelHeader();
      expect(style.fontFamily, 'Press Start 2P');
    });

    testWidgets('T1-F27-02: Pixel Body Font Configuration', (tester) async {
      final style = RetroTypography.pixelBody();
      expect(style.fontFamily, 'VT323');
    });

    testWidgets('T1-F27-03: Safe Offline Fallback Font Stack', (tester) async {
      final style = RetroTypography.pixelHeader();
      expect(style.fontFamilyFallback, contains('Courier New'));
      expect(style.fontFamilyFallback, contains('monospace'));
      expect(style.fontFamilyFallback, contains('Consolas'));
    });

    testWidgets('T1-F27-04: Dialogue Box Retro Monospace Text Styling', (tester) async {
      await pumpApp(tester);
      expect(find.text('▶ '), findsOneWidget);
      expect(find.textContaining('工作桌前一切就緒'), findsOneWidget);
    });

    testWidgets('T1-F27-05: Header Banner Letter Spacing and Bold Weight', (tester) async {
      await pumpApp(tester);
      final titleFinder = find.text('TSUMI-PURA RPG');
      expect(titleFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(titleFinder);
      expect(textWidget.style?.letterSpacing, greaterThanOrEqualTo(1.2));
      expect(textWidget.style?.fontWeight, FontWeight.bold);
    });
  });

  // =========================================================================
  // Feature 28: Battle Juice Screen Shake
  // =========================================================================
  group('Feature 28: Battle Juice Screen Shake', () {
    testWidgets('T1-F28-01: ScreenShake Widget Wraps Combat Stage', (tester) async {
      await pumpApp(tester);
      expect(find.byType(ScreenShake), findsOneWidget);
    });

    testWidgets('T1-F28-02: Normal Attack Deals Crisp Screen Shake', (tester) async {
      final intensity = DamageColorPalette.getShakeIntensity(CraftPhases.snapFit);
      expect(intensity, equals(7.0));
    });

    testWidgets('T1-F28-03: Finishing Execution Triggers Heavy Shake Intensity', (tester) async {
      final intensity = DamageColorPalette.getShakeIntensity(CraftPhases.finishing);
      expect(intensity, equals(22.0));
    });

    testWidgets('T1-F28-04: Airbrush Burst Triggers High Shake Intensity', (tester) async {
      final intensity = DamageColorPalette.getShakeIntensity(CraftPhases.airbrush);
      expect(intensity, equals(16.0));
    });

    testWidgets('T1-F28-05: Shake Restores to Zero Translation upon Completion', (tester) async {
      final controller = ScreenShakeController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenShake(
              controller: controller,
              child: const Text('SHAKE ME'),
            ),
          ),
        ),
      );
      await tester.pump();

      controller.shake(intensity: 10.0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.isShaking, isTrue);

      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.isShaking, isFalse);
    });
  });

  // =========================================================================
  // Feature 29: Floating Damage Numbers
  // =========================================================================
  group('Feature 29: Floating Damage Numbers', () {
    testWidgets('T1-F29-01: FloatingDamageOverlay Spawns Damage Bubble on Hit', (tester) async {
      await pumpApp(tester);
      expect(find.byType(FloatingDamageOverlay), findsOneWidget);
    });

    testWidgets('T1-F29-02: Snap-fit Normal Damage Text Format', (tester) async {
      final text = DamageColorPalette.formatDamageText(
        damage: 100,
        phase: CraftPhases.snapFit,
        isInterrupted: false,
      );
      final color = DamageColorPalette.getColorForPhase(CraftPhases.snapFit);
      expect(text, equals('-100'));
      expect(color, equals(DamageColorPalette.snapFit));
    });

    testWidgets('T1-F29-03: Airbrush Heavy Burst Text Format', (tester) async {
      final text = DamageColorPalette.formatDamageText(
        damage: 200,
        phase: CraftPhases.airbrush,
        isInterrupted: false,
      );
      final color = DamageColorPalette.getColorForPhase(CraftPhases.airbrush);
      expect(text, equals('BURST! -200'));
      expect(color, equals(DamageColorPalette.airbrush));
    });

    testWidgets('T1-F29-04: Detailing Critical Strike Text Format', (tester) async {
      final text = DamageColorPalette.formatDamageText(
        damage: 150,
        phase: CraftPhases.detailing,
        isInterrupted: false,
      );
      final color = DamageColorPalette.getColorForPhase(CraftPhases.detailing);
      expect(text, equals('CRIT! -150'));
      expect(color, equals(DamageColorPalette.detailing));
    });

    testWidgets('T1-F29-05: Bubble Self-Dismisses after 900ms Lifetime', (tester) async {
      final controller = FloatingDamageController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingDamageOverlay(
              controller: controller,
              child: const Text('STAGE'),
            ),
          ),
        ),
      );
      await tester.pump();

      controller.spawn(damage: 100, phase: CraftPhases.snapFit, isInterrupted: false);
      await tester.pump();
      expect(find.text('-100'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 950));
      expect(find.text('-100'), findsNothing);
    });
  });

  // =========================================================================
  // Feature 30: Boss Hurt Flash
  // =========================================================================
  group('Feature 30: Boss Hurt Flash', () {
    testWidgets('T1-F30-01: BossHurtFlash Wraps Boss Sprite', (tester) async {
      await pumpApp(tester);
      expect(find.byType(BossHurtFlash), findsOneWidget);
    });

    testWidgets('T1-F30-02: Flash Activates Crimson Strobe on Damage', (tester) async {
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
      expect(controller.isFlashing, isTrue);

      await tester.pump(const Duration(milliseconds: 250));
      expect(controller.isFlashing, isFalse);
    });

    testWidgets('T1-F30-03: Flash Duration Runs for ~220ms', (tester) async {
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
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.isFlashing, isTrue);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(controller.isFlashing, isFalse);
    });

    testWidgets('T1-F30-04: Boss Hurt State Restores to Resting State', (tester) async {
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
      await tester.pump(const Duration(milliseconds: 250));
      expect(controller.isFlashing, isFalse);
    });

    testWidgets('T1-F30-05: Flash Can Be Triggered on Zero-Cost Strobe', (tester) async {
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
      await tester.pump(const Duration(milliseconds: 50));
      controller.flash();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      controller.flash();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(controller.isFlashing, isFalse);
    });
  });

  // =========================================================================
  // Feature 31: Zero-Cost Retro Audio & Mute Toggle
  // =========================================================================
  group('Feature 31: Zero-Cost Retro Audio & Mute Toggle', () {
    testWidgets('T1-F31-01: Header HUD Displays Mute Toggle Button', (tester) async {
      await pumpApp(tester);
      expect(find.byKey(const Key('btn_mute_toggle')), findsOneWidget);
    });

    testWidgets('T1-F31-02: Initial State Shows SFX Active with Volume Up Icon', (tester) async {
      final mockAudio = MockRetroAudioService();
      await pumpApp(tester, mockAudio: mockAudio);

      expect(find.text('SFX'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(mockAudio.isMuted, isFalse);
    });

    testWidgets('T1-F31-03: Tapping Toggle Mutes Audio and Updates HUD', (tester) async {
      final mockAudio = MockRetroAudioService();
      await pumpApp(tester, mockAudio: mockAudio);

      await tester.tap(find.byKey(const Key('btn_mute_toggle')));
      await tester.pump();

      expect(find.text('MUTE'), findsOneWidget);
      expect(find.byIcon(Icons.volume_off), findsOneWidget);
      expect(mockAudio.isMuted, isTrue);
    });

    testWidgets('T1-F31-04: Tapping Toggle Again Unmutes Audio', (tester) async {
      final mockAudio = MockRetroAudioService();
      await pumpApp(tester, mockAudio: mockAudio);

      await tester.tap(find.byKey(const Key('btn_mute_toggle')));
      await tester.pump();
      expect(mockAudio.isMuted, isTrue);

      await tester.tap(find.byKey(const Key('btn_mute_toggle')));
      await tester.pump();

      expect(find.text('SFX'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(mockAudio.isMuted, isFalse);
    });

    testWidgets('T1-F31-05: Timer Tick & Hit Audio Sounded on Countdown', (tester) async {
      final mockAudio = MockRetroAudioService();
      await pumpApp(tester, mockAudio: mockAudio);

      await tester.tap(find.text('5秒測試'));
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockAudio.timerTickCount, greaterThanOrEqualTo(1));
      expect(mockAudio.attackHitCount, greaterThanOrEqualTo(1));
    });
  });
}
