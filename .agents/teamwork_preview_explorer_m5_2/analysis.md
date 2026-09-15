# E2E Testing Analysis & Test Specifications: R3 & R4
**Milestone**: Milestone 5 (E2E Test Coverage)  
**Investigator**: teamwork_preview_explorer (Explorer 2: R3 & R4)  
**Target Test Suites**:
- `test/e2e/e2e_tier1_r3_r4_test.dart` (Tier 1: Feature Coverage, >=5 test cases per feature)
- `test/e2e/e2e_tier2_r3_r4_test.dart` (Tier 2: Boundary & Corner Cases, >=5 test cases per feature)
**Coverage Scope**:
- **Requirement 3 (R3)**: Model Hangar & Showcase Gallery (Features 18–25)
- **Requirement 4 (R4)**: 8-Bit Retro Juice & Audio (Features 26–31)

---

## 1. Executive Summary & Scope Overview

This specification establishes an exhaustive, opaque-box E2E test plan for Requirements 3 and 4 of *Tsumi-Pura RPG*. Every test case treats the system under test (SUT) strictly through UI interactions (tapping buttons, entering text, triggering filters, reading rendered text and visual nodes) while verifying state transitions, persistence integrity, and audio/visual juice contracts.

### Scope Breakdown: 14 Features (70 Tier 1 + 70 Tier 2 = 140 Test Cases)

| Feature # | Feature Title | Milestone | Core Responsibility |
|:---:|:---|:---:|:---|
| **F18** | Model Hangar Screen | M3 | Backlog list view, status indicators, filter tabs, active kit switch |
| **F19** | Model CRUD Management | M3 | Add new kit, edit kit info, delete kit from hangar with confirmation |
| **F20** | Grade & HP Defaults | M3 | EG (300), HG (500), RG (800), MG (1500), PG (5000) HP presets |
| **F21** | Custom HP Input | M3 | Custom HP toggle, numerical validation (>0, <=99999), custom boss flag |
| **F22** | Active Kit Battle Link | M3 | Hangar selection links to Battle Boss HUD; finishing lock auto-resets |
| **F23** | Boss Defeat Transition | M3 | HP <= 0 triggers Quest Clear dialog, rewards, and navigation routing |
| **F24** | Showcase Gallery Screen | M3 | Grid/card view of completed kits, empty state, sorting by completion date |
| **F25** | Showcase Details & Metrics | M3 | Plaque modal, elapsed duration formatting, 5-phase work/damage breakdown |
| **F26** | 8-Bit Pixel UI Consistency | M4 | PixelFrame borders, PixelButton tactile offset, dark retro HUD palette |
| **F27** | Retro Typography | M4 | Press Start 2P / VT323 typography, robust offline monospace fallback |
| **F28** | Battle Juice Screen Shake | M4 | 2D harmonic screen shake, intensity scaling, multi-hit clamping, decay |
| **F29** | Floating Damage Numbers | M4 | Phase-colored popping damage numbers, mercy/crit tags, 900ms self-dismissal |
| **F30** | Boss Hurt Flash | M4 | 220ms dual-pulse crimson strobe, recoil squeeze, color-filter cleanup |
| **F31** | Zero-Cost Retro Audio | M4 | Audio synthesis contract, HUD mute toggle, silence guarantee when muted |

---

## 2. Widget Key & Selector Dictionary

The Test Writer must use these exact keys and finder queries to drive interactions and assertions:

### A. Battle Screen HUD & Controls (`lib/main.dart`)
| Key / Selector | Type | Description |
|:---|:---|:---|
| `Key('btn_hangar')` | `InkWell` | Header quick link to Model Hangar |
| `Key('btn_showcase')` | `InkWell` | Header quick link to Showcase Gallery |
| `Key('btn_craft_log')` | `InkWell` | Header quick link to Craft Log History |
| `Key('btn_mute_toggle')` | `InkWell` | Header audio mute toggle (displays 'SFX' or 'MUTE') |
| `Key('btn_nav_battle')` | `PixelButton` | Bottom navigation bar battle tab |
| `Key('btn_nav_hangar')` | `PixelButton` | Bottom navigation bar hangar tab |
| `Key('btn_nav_showcase')` | `PixelButton` | Bottom navigation bar showcase tab |
| `Key('btn_nav_craft_log')` | `PixelButton` | Bottom navigation bar craft log tab |
| `find.text('5秒測試')` | `PixelButton` | Fast 5-second debug pomodoro test button |
| `find.textContaining('開始開工')` | `ElevatedButton` | Start work timer button |
| `find.textContaining('中途中斷')` | `ElevatedButton` | Interrupt work phase and trigger Mercy Rule (50% damage) |
| `find.textContaining('略過休息')` | `ElevatedButton` | Skip rest phase button |
| `find.textContaining('重置 Boss 血量')`| `ElevatedButton` | Restart defeated Boss to max HP |
| `Key('btn_clear_to_showcase')` | `ElevatedButton` | Quest Clear dialog button navigating to Showcase |
| `Key('btn_clear_to_hangar')` | `ElevatedButton` | Quest Clear dialog button navigating to Hangar |
| `Key('btn_clear_restart')` | `TextButton` | Quest Clear dialog button resetting Boss in-place |
| `byType(ScreenShake)` | `ScreenShake` | 2D harmonic displacement container |
| `byType(BossHurtFlash)` | `BossHurtFlash` | Red strobe overlay on Boss sprite |
| `byType(FloatingDamageOverlay)`| `FloatingDamageOverlay`| Multi-bubble damage popups overlay |
| `byType(PixelHpBar)` | `PixelHpBar` | 3-phase retro health bar |

### B. Hangar Screen (`lib/presentation/screens/hangar_screen.dart`)
| Key / Selector | Type | Description |
|:---|:---|:---|
| `Key('btn_hangar_back')` | `IconButton` | Returns from Hangar to previous screen |
| `Key('btn_add_kit')` | `ElevatedButton`| Opens "登錄山積盒怪" (Add Kit) dialog |
| `Key('btn_refresh_hangar')` | `IconButton` | Reloads kit list from repository |
| `Key('filter_all')` | `ChoiceChip` | Filter tab: 全部 |
| `Key('filter_unstarted')` | `ChoiceChip` | Filter tab: 山積 |
| `Key('filter_in_progress')` | `ChoiceChip` | Filter tab: 施工中 |
| `Key('filter_completed')` | `ChoiceChip` | Filter tab: 完工 |
| `Key('btn_add_kit_empty')` | `ElevatedButton`| Add kit button displayed when list is empty |
| `Key('kit_card_<kitId>')` | `Container` | Card representing a single kit |
| `Key('btn_set_active_<kitId>')`| `ElevatedButton`| Sets kit as current active Boss target |
| `Key('btn_edit_kit_<kitId>')` | `IconButton` | Opens edit dialog for kit |
| `Key('btn_delete_kit_<kitId>')`| `IconButton` | Opens delete confirmation dialog for kit |

### C. Kit Form & Delete Dialogs (`lib/presentation/screens/hangar_screen.dart`)
| Key / Selector | Type | Description |
|:---|:---|:---|
| `Key('input_kit_title')` | `TextFormField` | Kit title input (max 50 characters) |
| `Key('chip_grade_<G>')` | `ChoiceChip` | Grade selector chip (EG, HG, RG, MG, PG) |
| `Key('checkbox_custom_hp')` | `Checkbox` | Custom HP override toggle |
| `Key('input_kit_hp')` | `TextFormField` | Numerical HP input field |
| `Key('checkbox_set_active')` | `Checkbox` | Set as active target immediately (Add mode) |
| `Key('checkbox_reset_hp')` | `Checkbox` | Reset current HP to full (Edit mode) |
| `Key('btn_dialog_cancel')` | `OutlinedButton`| Discards form dialog |
| `Key('btn_dialog_save')` | `ElevatedButton`| Submits form dialog |
| `Key('btn_cancel_delete')` | `OutlinedButton`| Cancels kit deletion |
| `Key('btn_confirm_delete')` | `ElevatedButton`| Confirms permanent kit & log deletion |

### D. Showcase Screen & Detail Plaque (`lib/presentation/screens/showcase_screen.dart`)
| Key / Selector | Type | Description |
|:---|:---|:---|
| `Key('btn_showcase_back')` | `IconButton` | Returns from Showcase to previous screen |
| `Key('btn_refresh_showcase')` | `IconButton` | Reloads completed kits and logs |
| `Key('showcase_empty_state')` | `Container` | Empty gallery notice when 0 kits completed |
| `Key('showcase_card_<kitId>')` | `Container` | Card representing a completed trophy kit |
| `Key('showcase_detail_dialog')`| `Dialog` | Modal dialog showing full plaque & 5-phase breakdown |
| `Key('btn_showcase_close_detail')`| `IconButton` | Closes plaque modal |
| `Key('btn_showcase_view_logs_<kitId>')`| `ElevatedButton`| Navigates to CraftLogScreen for that kit |

---

## 3. Test Harness & Execution Conventions for Test Writer

1. **Virtual Screen Dimensions**: Set test view to 1080x1920 to eliminate desktop/mobile layout constraints:
   ```dart
   tester.view.physicalSize = const Size(1080, 1920);
   tester.view.devicePixelRatio = 1.0;
   addTearDown(() => tester.view.resetPhysicalSize());
   ```
2. **Audio Mocking & Reset**:
   ```dart
   final mockAudio = MockRetroAudioService();
   RetroAudioService.setCustomInstance(mockAudio);
   addTearDown(() => RetroAudioService.resetInstance());
   ```
3. **Storage & Fonts Mocking**:
   ```dart
   SharedPreferences.setMockInitialValues({});
   GoogleFonts.config.allowRuntimeFetching = false;
   final prefs = await SharedPreferences.getInstance();
   final storage = LocalStorageService(prefs);
   final logRepo = CraftLogRepository(storage);
   final kitRepo = KitRepository(storage, logRepo);
   kitRepo.bindCraftLogRepository(logRepo);
   ```
4. **App Bootstrapping**:
   ```dart
   await tester.pumpWidget(
     TsumiPuraApp(kitRepository: kitRepo, craftLogRepository: logRepo),
   );
   await tester.pump();
   await tester.pump(const Duration(milliseconds: 200));
   ```
5. **Animation Flushing**:
   Whenever a timer or screen shake is pumped, advance by discrete durations (e.g. `await tester.pump(const Duration(milliseconds: 350)); await tester.pump();`).

---

## 4. Tier 1: Feature Coverage Test Specifications (`test/e2e/e2e_tier1_r3_r4_test.dart`)

### Feature 18: Model Hangar Screen (List View, Status, Active Target)
- **F18-1: Hangar Navigation & Initial Kit Render**
  - *Interaction*: Launch app, tap `Key('btn_hangar')`.
  - *Verification*: Header displays `★ MODEL HANGAR ★`, back button `Key('btn_hangar_back')` exists, default seed kit card `Key('kit_card_default-kit-rx78')` rendered with title `HG RX-78-2 鋼彈`, grade badge `HG`, and `★ 當前出擊目標 (ACTIVE BOSS)`.
- **F18-2: Kit Status Indicators (山積, 施工中, 完工)**
  - *Precondition*: Seed 3 kits: Kit A (currentHp == totalHp -> status `unstarted`), Kit B (0 < currentHp < totalHp -> status `inProgress`), Kit C (currentHp == 0 -> status `completed`).
  - *Interaction*: Open Hangar screen.
  - *Verification*: Kit A card shows text `山積`, Kit B card shows text `施工中`, Kit C card shows text `完工`.
- **F18-3: Filter Tabs Dynamic Switching**
  - *Precondition*: Seed Kit A (`unstarted`), Kit B (`inProgress`), Kit C (`completed`).
  - *Interaction*: Tap `Key('filter_unstarted')` -> check items; tap `Key('filter_in_progress')` -> check items; tap `Key('filter_completed')` -> check items; tap `Key('filter_all')` -> check items.
  - *Verification*: Under `filter_unstarted`, only Kit A is visible; under `filter_in_progress`, only Kit B is visible; under `filter_completed`, only Kit C is visible; under `filter_all`, all 3 kits are visible.
- **F18-4: Active Kit Switching via Card Button**
  - *Precondition*: Seed Kit 1 (active) and Kit 2 (inactive).
  - *Interaction*: Tap `Key('btn_set_active_kit-2')` on Kit 2 card.
  - *Verification*: Snackbar confirms `已將【...】設為當前討伐目標！`, Kit 2 card gains active badge `★ 當前出擊目標 (ACTIVE BOSS)`, Kit 1 card active badge disappears and shows `設為目標` button.
- **F18-5: Hangar Back Navigation to Battle Screen**
  - *Interaction*: In Hangar screen, tap `Key('btn_hangar_back')`.
  - *Verification*: Hangar closes, returning to Battle Screen displaying `TSUMI-PURA RPG` header and active Boss card.

### Feature 19: Model CRUD Management (Add, Edit, Delete)
- **F19-1: Add New Kit via Dialog**
  - *Interaction*: In Hangar, tap `Key('btn_add_kit')`, enter title `RG 沙薩比` in `Key('input_kit_title')`, tap `Key('chip_grade_RG')`, tap `Key('btn_dialog_save')`.
  - *Verification*: Dialog closes, kit card `RG 沙薩比` appears in Hangar list with grade `RG` and default HP `800`.
- **F19-2: Edit Existing Kit Title and Grade**
  - *Precondition*: Kit `kit-edit-1` exists in Hangar.
  - *Interaction*: Tap `Key('btn_edit_kit_kit-edit-1')`, change title to `MG 自由鋼彈 2.0`, select `Key('chip_grade_MG')`, tap `Key('btn_dialog_save')`.
  - *Verification*: Dialog closes, kit card updates to display `MG 自由鋼彈 2.0`, grade `MG`, total HP `1500`.
- **F19-3: Delete Kit with Confirmation Dialog**
  - *Precondition*: Non-active kit `kit-del-1` exists in Hangar.
  - *Interaction*: Tap `Key('btn_delete_kit_kit-del-1')`.
  - *Verification*: Modal appears displaying `⚠️ 解體除籍確認 ⚠️` and warning text; tap `Key('btn_confirm_delete')`. Kit card is removed from Hangar list.
- **F19-4: Cancel Add Kit Dialog Preserves Inventory**
  - *Interaction*: Tap `Key('btn_add_kit')`, enter title `Temporary Kit`, tap `Key('btn_dialog_cancel')`.
  - *Verification*: Dialog closes without adding new kit; kit count remains unchanged.
- **F19-5: Cancel Delete Kit Dialog Keeps Kit Intact**
  - *Precondition*: Kit `kit-keep-1` exists in Hangar.
  - *Interaction*: Tap `Key('btn_delete_kit_kit-keep-1')`, modal appears, tap `Key('btn_cancel_delete')`.
  - *Verification*: Modal dismisses, kit card `kit-keep-1` remains visible in Hangar list.

### Feature 20: Grade & HP Defaults Presets
- **F20-1: EG Preset Defaults to 300 HP**
  - *Interaction*: Open Add Kit dialog, select `Key('chip_grade_EG')`.
  - *Verification*: `Key('input_kit_hp')` value automatically updates to `300`.
- **F20-2: HG Preset Defaults to 500 HP**
  - *Interaction*: Open Add Kit dialog, select `Key('chip_grade_HG')`.
  - *Verification*: `Key('input_kit_hp')` value automatically updates to `500`.
- **F20-3: RG Preset Defaults to 800 HP**
  - *Interaction*: Open Add Kit dialog, select `Key('chip_grade_RG')`.
  - *Verification*: `Key('input_kit_hp')` value automatically updates to `800`.
- **F20-4: MG Preset Defaults to 1500 HP**
  - *Interaction*: Open Add Kit dialog, select `Key('chip_grade_MG')`.
  - *Verification*: `Key('input_kit_hp')` value automatically updates to `1500`.
- **F20-5: PG Preset Defaults to 5000 HP**
  - *Interaction*: Open Add Kit dialog, select `Key('chip_grade_PG')`.
  - *Verification*: `Key('input_kit_hp')` value automatically updates to `5000`.

### Feature 21: Custom HP Input & Override
- **F21-1: Enable Custom HP Checkbox Enables Input Field**
  - *Interaction*: Open Add Kit dialog. Initially `Key('input_kit_hp')` is disabled. Tap `Key('checkbox_custom_hp')`.
  - *Verification*: Checkbox is checked, `Key('input_kit_hp')` becomes editable and displays label `自訂 HP (> 0)`.
- **F21-2: Save Kit with Valid Custom HP Value**
  - *Interaction*: In Add Kit dialog, title `自訂巨神兵`, enable custom HP, enter `3200` in `Key('input_kit_hp')`, tap `Key('btn_dialog_save')`.
  - *Verification*: Kit is saved and card displays `自訂` tag and `3200/3200 HP`.
- **F21-3: Validation Error on Empty Custom HP Field**
  - *Interaction*: Enable custom HP, clear `Key('input_kit_hp')` text, tap `Key('btn_dialog_save')`.
  - *Verification*: Validation error text `請輸入 HP` appears; dialog does not close.
- **F21-4: Validation Error on Zero Custom HP**
  - *Interaction*: Enable custom HP, enter `0` in `Key('input_kit_hp')`, tap `Key('btn_dialog_save')`.
  - *Verification*: Validation error text `HP 必須為大於 0 之整數` appears.
- **F21-5: Validation Error on Excessive Custom HP (>99,999)**
  - *Interaction*: Enable custom HP, enter `100000` in `Key('input_kit_hp')`, tap `Key('btn_dialog_save')`.
  - *Verification*: Validation error text `HP 不可超過 99,999` appears.

### Feature 22: Active Kit Battle Link
- **F22-1: Hangar Selection Reflects on Battle Screen Boss Card**
  - *Precondition*: Seed Kit `kit-zaku` with title `MS-06S 薩克II`, grade `MG`, HP `1500`.
  - *Interaction*: Go to Hangar, tap `Key('btn_set_active_kit-zaku')`, tap `Key('btn_hangar_back')`.
  - *Verification*: Battle Screen Boss card displays `Lv.15 MS-06S 薩克II`, `規格: MG 1/144`, and HP bar `1500 / 1500`.
- **F22-2: Active Target Change Updates Battle Dialogue**
  - *Interaction*: Switch active kit in Hangar and return to Battle Screen.
  - *Verification*: Dialogue box displays `🎯 已鎖定新討伐目標！請選擇工序開工。`.
- **F22-3: Finishing Skill Gate Automatically Locks on High-HP Target Switch**
  - *Precondition*: Active kit was in finishing phase (<20% HP). User switches to new full-HP kit in Hangar.
  - *Interaction*: Return to Battle Screen.
  - *Verification*: Finishing phase button segment resets to Snap-fit; Finishing segment shows locked label `水貼\n🔒20%`.
- **F22-4: Add Kit with 'Set Active' Checked Immediately Links to Battle**
  - *Interaction*: In Add Kit dialog, enter title `全新出擊怪`, ensure `Key('checkbox_set_active')` is checked, save, return to Battle Screen.
  - *Verification*: Battle Screen Boss card now displays `全新出擊怪`.
- **F22-5: Bottom Navigation Hangar to Battle Transition**
  - *Interaction*: On Hangar screen, navigate back, verify bottom nav tab `btn_nav_hangar` routes to Hangar and returning via back button restores Battle view.

### Feature 23: Boss Defeat Transition & Quest Clear Flow
- **F23-1: Boss HP <= 0 Triggers Quest Clear Modal Dialog**
  - *Precondition*: Active Boss HP = 50.
  - *Interaction*: Execute 5s debug pomodoro session (deals >=100 damage).
  - *Verification*: Boss HP drops to 0, `showQuestClearDialog` opens displaying `★ QUEST CLEAR ★`, cumulative duration, coins won, and action buttons.
- **F23-2: Defeated Boss Status Marked as Completed**
  - *Interaction*: Defeat Boss via pomodoro completion.
  - *Verification*: Kit item status in repository transitions from `inProgress` to `completed`, and `completedAt` timestamp is recorded.
- **F23-3: Quest Clear '前往展示櫃觀看' Navigates to Showcase**
  - *Interaction*: On Quest Clear dialog, tap `Key('btn_clear_to_showcase')`.
  - *Verification*: Quest Clear dialog pops, Showcase screen opens displaying `★ SHOWCASE GALLERY ★` with the newly defeated kit card.
- **F23-4: Quest Clear '返回機庫挑選新目標' Navigates to Hangar**
  - *Interaction*: On Quest Clear dialog, tap `Key('btn_clear_to_hangar')`.
  - *Verification*: Quest Clear dialog pops, Hangar screen opens displaying `★ MODEL HANGAR ★`.
- **F23-5: Quest Clear '收錄至展示櫃 (Showcase)' Resets Battle Stage**
  - *Interaction*: On Quest Clear dialog, tap `Key('btn_clear_restart')`.
  - *Verification*: Dialog pops, Boss HP resets to maxHp, battle dialogue updates to `盒怪已收錄至像素展示櫃！已準備迎戰下一位山積怪。`.

### Feature 24: Showcase Gallery Screen
- **F24-1: Empty Showcase State Renders When No Kits Completed**
  - *Precondition*: Repository has only unstarted or in-progress kits.
  - *Interaction*: Tap `Key('btn_showcase')`.
  - *Verification*: `Key('showcase_empty_state')` is visible with text `尚無完工模型，快去討伐堆積吧！` and `前往討伐` button.
- **F24-2: Showcase Header Displays Accurate Completed Count**
  - *Precondition*: Seed 2 completed kits in repository.
  - *Interaction*: Open Showcase screen.
  - *Verification*: Header shows `完工: 2 盒` and refresh button `Key('btn_refresh_showcase')` is present.
- **F24-3: Completed Kit Card Displays Grade Badge, Title, Trophy Icon**
  - *Precondition*: Kit `trophy-1` (RG, title `RG 自由鋼彈`) completed.
  - *Interaction*: Open Showcase screen.
  - *Verification*: Card `Key('showcase_card_trophy-1')` renders badge `RG`, title `RG 自由鋼彈`, and icon `Icons.emoji_events`.
- **F24-4: Showcase Card Displays Completion Date, Duration, Session Count**
  - *Precondition*: Kit `trophy-1` has 2 logs totaling 50 minutes completed on `2026-09-14`.
  - *Interaction*: View kit card in Showcase.
  - *Verification*: Text contains `完工: 2026-09-14`, `累計工時: 50m`, and `討伐次數: 2 次`.
- **F24-5: Showcase Back Button Returns to Previous Screen**
  - *Interaction*: In Showcase screen, tap `Key('btn_showcase_back')`.
  - *Verification*: Showcase screen pops, returning to Battle Screen.

### Feature 25: Showcase Details & Metrics Plaque Modal
- **F25-1: Tapping Showcase Card Opens Detail Plaque Dialog**
  - *Interaction*: Tap `Key('showcase_card_trophy-1')`.
  - *Verification*: Modal `Key('showcase_detail_dialog')` opens displaying header `★ 完工模型銘牌 ★`.
- **F25-2: Plaque Modal Displays Model Specs & Date**
  - *Verification*: Plaque header displays `【RG】RG 自由鋼彈`, `規格: RG 1/144 · 血量: 800 HP`, and `完工日期: ...`.
- **F25-3: Plaque KPI Summary Tiles (工時, 傷害, 討伐次數)**
  - *Verification*: Plaque contains 3 summary tiles: `累計工時`, `總輸出傷害`, and `討伐次數` (format: `X/Y 次` for completed vs interrupted).
- **F25-4: 5-Phase Breakdown Progress Bars**
  - *Verification*: Dialog displays section `【5 大工序工時佔比】` listing all 5 phases (`Snap-fit`, `Sanding`, `Detailing`, `Airbrush`, `Finishing`) with minute totals, damage points, percentage strings, and colored proportional horizontal bars.
- **F25-5: Close Plaque Modal Button**
  - *Interaction*: Tap `Key('btn_showcase_close_detail')`.
  - *Verification*: Plaque modal dismisses cleanly; Showcase screen remains active.

### Feature 26: 8-Bit Pixel UI Consistency
- **F26-1: Retro Workbench Dark Slate Theme Palette**
  - *Verification*: `ThemeData` provides `scaffoldBackgroundColor` matching `RetroColors.darkSlate` (`#12141F`), deep container `#14151F`, and retro borders `#383A59`.
- **F26-2: PixelFrame Renders Hard Angular 8-Bit Borders**
  - *Verification*: `PixelFrame` wraps Boss card with rectangular border (zero border radius) and `#44475A` border color.
- **F26-3: PixelButton Renders Tactile 3D Bevel**
  - *Verification*: `PixelButton` renders bevel border (top/left lighter highlight, bottom/right darker shadow) and elevated shadow.
- **F26-4: PixelHpBar 3-Phase Color Transitions**
  - *Verification*: `PixelHpBar` color shifts: >50% green (`#50FA7B`), 21-50% amber (`#FFD54F`), <=20% crimson red (`#FF5252`).
- **F26-5: Retro Bottom Navigation Dock Bar Styling**
  - *Verification*: `RetroBottomNavBar` renders 4 tabs (`Battle`, `Hangar`, `Showcase`, `Logs`) with pixel borders, glowing active indicators, and monospace labels.

### Feature 27: Retro Typography
- **F27-1: Pixel Header Font Configuration**
  - *Verification*: `RetroTypography.pixelHeader()` sets primary family `Press Start 2P`.
- **F27-2: Pixel Body Font Configuration**
  - *Verification*: `RetroTypography.pixelBody()` sets primary family `VT323`.
- **F27-3: Safe Offline Fallback Font Stack**
  - *Verification*: When offline or under test harness, font fallback includes `['Courier New', 'monospace', 'Consolas']` preventing network fetch crashes.
- **F27-4: Dialogue Box Retro Monospace Text Styling**
  - *Verification*: Combat dialogue box text uses monospace typography with 1.4 line height and retro prompt character `▶ `.
- **F27-5: Header Banner Letter Spacing and Bold Weight**
  - *Verification*: Header title `TSUMI-PURA RPG` renders letterSpacing >= 1.2 and bold weight.

### Feature 28: Battle Juice Screen Shake
- **F28-1: ScreenShake Widget Wraps Combat Stage**
  - *Verification*: `ScreenShake` widget exists in widget tree wrapping the combat stage container.
- **F28-2: Normal Attack Deals Crisp Screen Shake**
  - *Interaction*: Trigger Snap-fit attack damage.
  - *Verification*: `ScreenShakeController.isShaking` becomes true; `Transform` widget ancestor has non-zero translation offset.
- **F28-3: Finishing Execution Triggers Heavy Shake Intensity**
  - *Verification*: `DamageColorPalette.getShakeIntensity(CraftPhases.finishing)` yields `22.0`, greater than `snapFit` (`7.0`).
- **F28-4: Airbrush Burst Triggers High Shake Intensity**
  - *Verification*: `DamageColorPalette.getShakeIntensity(CraftPhases.airbrush)` yields `16.0`.
- **F28-5: Shake Restores to Zero Translation upon Completion**
  - *Interaction*: Pump 350ms duration after shake trigger.
  - *Verification*: `ScreenShakeController.isShaking` becomes false; translation offset returns to `Offset.zero`.

### Feature 29: Floating Damage Numbers
- **F29-1: FloatingDamageOverlay Spawns Damage Bubble on Hit**
  - *Interaction*: Trigger damage settlement.
  - *Verification*: `FloatingDamageOverlay` mounts child with key `ValueKey('floating_damage_1_<damage>')`.
- **F29-2: Snap-fit Normal Damage Text Format**
  - *Verification*: Text string matches `-$damage` with clean white color (`#FFFFFF`).
- **F29-3: Airbrush Heavy Burst Text Format**
  - *Verification*: Text string matches `BURST! -$damage` with cyber cyan color (`#8BE9FD`).
- **F29-4: Detailing Critical Strike Text Format**
  - *Verification*: Text string matches `CRIT! -$damage` with weakpoint neon yellow (`#F1FA8C`).
- **F29-5: Bubble Self-Dismisses after 900ms Lifetime**
  - *Interaction*: Advance clock by 950ms after damage.
  - *Verification*: Spawned floating damage bubble is removed from widget tree.

### Feature 30: Boss Hurt Flash
- **F30-1: BossHurtFlash Wraps Boss Sprite**
  - *Verification*: `BossHurtFlash` widget exists in widget tree wrapping Boss sprite image.
- **F30-2: Flash Activates Crimson Strobe on Damage**
  - *Interaction*: Trigger damage hit.
  - *Verification*: `BossHurtFlashController.isFlashing` becomes true; `ColorFiltered` child is active with crimson tint (`#FF1744`).
- **F30-3: Flash Duration Runs for ~220ms**
  - *Interaction*: Advance clock by 100ms (still flashing); advance by 250ms total.
  - *Verification*: At 100ms `isFlashing == true`; at 250ms `isFlashing == false`.
- **F30-4: Boss Hurt State Restores to Resting State**
  - *Verification*: Once flash finishes, `ColorFiltered` restores to default mode (transparent / non-tinted).
- **F30-5: Flash Can Be Triggered on Zero-Cost Strobe**
  - *Verification*: Multiple consecutive flashes trigger without crashing or throwing state errors.

### Feature 31: Zero-Cost Retro Audio & Mute Toggle
- **F31-1: Header HUD Displays Mute Toggle Button**
  - *Verification*: `Key('btn_mute_toggle')` is present in Header HUD.
- **F31-2: Initial State Shows SFX Active with Volume Up Icon**
  - *Verification*: Displays text `SFX`, icon `Icons.volume_up`, `mockAudio.isMuted == false`.
- **F31-3: Tapping Toggle Mutes Audio and Updates HUD**
  - *Interaction*: Tap `Key('btn_mute_toggle')`.
  - *Verification*: Displays text `MUTE`, icon `Icons.volume_off`, `mockAudio.isMuted == true`.
- **F31-4: Tapping Toggle Again Unmutes Audio**
  - *Interaction*: Tap `Key('btn_mute_toggle')` twice.
  - *Verification*: Reverts to `SFX`, icon `Icons.volume_up`, `mockAudio.isMuted == false`.
- **F31-5: Timer Tick & Hit Audio Sounded on Countdown**
  - *Precondition*: Audio is unmuted.
  - *Interaction*: Run 5s pomodoro debug session.
  - *Verification*: `mockAudio.timerTickCount >= 1` and `mockAudio.attackHitCount >= 1`.

---

## 5. Tier 2: Boundary & Corner Case Test Specifications (`test/e2e/e2e_tier2_r3_r4_test.dart`)

### Feature 18 Boundary & Corner Cases
- **B18-1: Empty Hangar State When All Kits Filtered Out**
  - *Setup*: Seed only unstarted kits. Tap `filter_completed`.
  - *Verification*: List view is replaced by empty hangar container showing `▶ 機庫空空如也` and `btn_add_kit_empty` button.
- **B18-2: Rapid Filter Toggling under Load**
  - *Interaction*: Tap `filter_unstarted` -> `filter_in_progress` -> `filter_completed` -> `filter_all` within rapid succession.
  - *Verification*: List updates asynchronously without state exception or duplicate entries.
- **B18-3: Long Scrollable Inventory Performance (20+ kits)**
  - *Setup*: Seed 25 kits in repository.
  - *Verification*: Hangar ListView scrolls smoothly without render overflow errors.
- **B18-4: Active Kit Badge Consistency After Refresh**
  - *Interaction*: Set Kit X as active. Tap `btn_refresh_hangar`.
  - *Verification*: Kit X retains `★ 當前出擊目標 (ACTIVE BOSS)` badge across refresh.
- **B18-5: Deleting Active Kit Updates Hangar Active Badge**
  - *Setup*: Two kits exist: Kit 1 (active) and Kit 2.
  - *Interaction*: Delete Kit 1 in Hangar.
  - *Verification*: Kit 2 automatically inherits active status in Hangar list without manual selection.

### Feature 19 Boundary & Corner Cases
- **B19-1: Exact 50-Character Kit Title Boundary**
  - *Interaction*: Enter title with exactly 50 characters `'A' * 50`.
  - *Verification*: Accepted, kit saves successfully.
- **B19-2: 51-Character Kit Title Rejection**
  - *Interaction*: Enter title with 51 characters `'A' * 51`.
  - *Verification*: Form validator fails with message `名稱不可超過 50 字元`.
- **B19-3: Whitespace-Only Kit Title Rejection**
  - *Interaction*: Enter `'     \t\n  '` in `input_kit_title`, tap save.
  - *Verification*: Form validator fails with message `請輸入模型名稱`.
- **B19-4: Edit Title Without Changing HP Preserves Custom Flag**
  - *Setup*: Kit has custom HP 2400.
  - *Interaction*: Edit title only in edit dialog and save.
  - *Verification*: Kit retains `totalHp == 2400` and `isCustomBoss == true`.
- **B19-5: Cascade Deletion of Craft Logs**
  - *Setup*: Kit A has 3 craft logs. Kit B has 2 craft logs.
  - *Interaction*: Delete Kit A.
  - *Verification*: Kit A's 3 craft logs are purged from `CraftLogRepository`, while Kit B's 2 logs remain intact.

### Feature 20 Boundary & Corner Cases
- **B20-1: Rapid Grade Preset Switching in Form Dialog**
  - *Interaction*: In Add Kit dialog, cycle chips: EG -> HG -> RG -> MG -> PG -> EG.
  - *Verification*: `input_kit_hp` accurately tracks default at each step: `300` -> `500` -> `800` -> `1500` -> `5000` -> `300`.
- **B20-2: Unchecking Custom HP Restores Selected Grade Default**
  - *Interaction*: Select MG (1500), check custom HP, enter 4000, then uncheck custom HP.
  - *Verification*: `input_kit_hp` immediately reverts to `1500`.
- **B20-3: Switching Grade When Custom HP is Checked Retains Custom Value**
  - *Interaction*: Check custom HP, enter 7777, select PG chip.
  - *Verification*: `input_kit_hp` remains `7777`.
- **B20-4: Edit Mode '重設當前血量為滿血' Checkbox**
  - *Setup*: Kit has `currentHp = 100`, `totalHp = 500`.
  - *Interaction*: Open edit dialog, check `checkbox_reset_hp`, save.
  - *Verification*: Updated kit has `currentHp == 500`.
- **B20-5: Custom Boss Flag Set When HP Differs from Grade Default**
  - *Interaction*: Select HG (default 500), enable custom HP, enter 501, save.
  - *Verification*: Saved kit has `isCustomBoss == true`.

### Feature 21 Boundary & Corner Cases
- **B21-1: Custom HP Exact Lower Boundary: 1 HP**
  - *Interaction*: Enter `1` in `input_kit_hp`, save.
  - *Verification*: Successfully saves with `totalHp == 1`, `currentHp == 1`.
- **B21-2: Custom HP Exact Upper Boundary: 99,999 HP**
  - *Interaction*: Enter `99999` in `input_kit_hp`, save.
  - *Verification*: Successfully saves with `totalHp == 99999`, `currentHp == 99999`.
- **B21-3: Custom HP Exceeding Upper Boundary: 100,000 HP**
  - *Interaction*: Enter `100000` in `input_kit_hp`, tap save.
  - *Verification*: Error `HP 不可超過 99,999` appears; form rejects submission.
- **B21-4: Custom HP Negative Value Protection**
  - *Interaction*: Attempt negative input (e.g. `-100`).
  - *Verification*: `FilteringTextInputFormatter.digitsOnly` blocks minus sign; empty or invalid entry fails validation.
- **B21-5: Non-numeric Input Protection**
  - *Interaction*: Attempt entering alphabetic characters `abc` into `input_kit_hp`.
  - *Verification*: Formatter discards letters; field remains empty or numeric.

### Feature 22 Boundary & Corner Cases
- **B22-1: Switch Active Kit While Battle Pomodoro is Idle**
  - *Interaction*: Select new target in Hangar, pop back to Battle.
  - *Verification*: Boss name, grade, and HP bar immediately update without requiring restart.
- **B22-2: Switch Target Auto-resets Finishing Phase if HP > 20%**
  - *Setup*: Boss A has 15% HP (Finishing unlocked and selected). Boss B has 100% HP.
  - *Interaction*: Switch to Boss B, return to Battle.
  - *Verification*: Selected phase switches to Snap-fit; Finishing phase is locked.
- **B22-3: Deleting the Active Kit Reallocates Target Without Crashing Battle Screen**
  - *Setup*: Kit 1 (active) and Kit 2 exist.
  - *Interaction*: Delete Kit 1 in Hangar, return to Battle Screen.
  - *Verification*: Battle Screen does not throw NullReferenceException and displays Kit 2 as new active Boss.
- **B22-4: Deleting the Only Remaining Kit Auto-seeds Default Kit**
  - *Setup*: Only 1 kit exists in database.
  - *Interaction*: Delete that kit in Hangar, return to Battle Screen.
  - *Verification*: KitRepository auto-seeds a new default seed kit (`HG RX-78-2 鋼彈`, 500 HP), and Battle Screen displays it smoothly.
- **B22-5: Rapid Concurrent setActiveKit Calls**
  - *Interaction*: Fire 5 concurrent `setActiveKit` calls across 3 kits.
  - *Verification*: System settles deterministically on the final active target without race conditions.

### Feature 23 Boundary & Corner Cases
- **B23-1: Exact HP = 0 Defeat Trigger**
  - *Setup*: Boss HP = 100.
  - *Interaction*: Deal exactly 100 damage.
  - *Verification*: Boss HP transitions to 0; Quest Clear modal triggers.
- **B23-2: Overkill Damage Clamped to 0 HP**
  - *Setup*: Boss HP = 20.
  - *Interaction*: Deal 150 damage (Finishing skill).
  - *Verification*: Current HP is clamped to `0`, never negative.
- **B23-3: Quest Clear Modal Non-Dismissible via Barrier Tap**
  - *Interaction*: Tap outside Quest Clear modal dialog.
  - *Verification*: Dialog does not dismiss (`barrierDismissible: false`).
- **B23-4: Defeat Fanfare Sound Triggered on Victory**
  - *Interaction*: Defeat Boss.
  - *Verification*: `mockAudio.victoryFanfareCount` increments by 1.
- **B23-5: Reset Defeated Boss via 'RESTART' Button**
  - *Setup*: Boss defeated (HP = 0), user closes Quest Clear modal via Restart.
  - *Verification*: Battle screen controls show `重置 Boss 血量 (RESTART)`; tapping resets HP to maxHp.

### Feature 24 Boundary & Corner Cases
- **B24-1: Showcase Empty State '前往討伐' Button Functionality**
  - *Setup*: 0 completed kits. Open Showcase.
  - *Interaction*: Tap `前往討伐` button.
  - *Verification*: Showcase pops, returning user to Battle Screen.
- **B24-2: Sorting Completed Kits by Completion Date Descending**
  - *Setup*: Seed Kit A completed on `2026-09-01`, Kit B completed on `2026-09-10`.
  - *Verification*: Kit B appears above Kit A in Showcase list.
- **B24-3: Completed Kit with Missing completedAt Fallback**
  - *Setup*: Completed kit has `completedAt == null`.
  - *Verification*: Sorts by `createdAt` and displays valid formatted date without throwing FormatException.
- **B24-4: Rapid Showcase Refresh**
  - *Interaction*: Tap `btn_refresh_showcase` 10 times rapidly.
  - *Verification*: No UI stutter or duplicate cards rendered.
- **B24-5: Multiple Grades in Showcase with Distinct Badge Colors**
  - *Setup*: Seed completed EG, HG, RG, MG, PG kits.
  - *Verification*: Each card renders distinct grade color (`EG` cyan, `HG` green, `RG` amber, `MG` red, `PG` purple).

### Feature 25 Boundary & Corner Cases
- **B25-1: Completed Kit with 0 Craft Logs Handled Gracefully**
  - *Setup*: Completed kit has 0 associated craft logs.
  - *Interaction*: Open detail plaque modal.
  - *Verification*: Displays `累計工時: 0m`, `0 pt`, `0/0 次`, and all 5 phases show `0m · 0 pt (0%)` without division-by-zero crash.
- **B25-2: Sub-Hour Fractional Duration Formatting (e.g. 45m)**
  - *Setup*: Logs total 45 minutes.
  - *Verification*: Plaque and card display `45m`.
- **B25-3: Exact One Hour Duration Formatting (e.g. 60m -> 1h 0m)**
  - *Setup*: Logs total 60 minutes.
  - *Verification*: Plaque and card display `1h 0m`.
- **B25-4: Multi-Hour Duration Formatting (e.g. 125m -> 2h 5m, 1440m -> 24h 0m)**
  - *Setup*: Logs total 125m and 1440m.
  - *Verification*: Displays `2h 5m` and `24h 0m`.
- **B25-5: View Dedicated Craft Logs Button from Plaque Modal**
  - *Interaction*: On detail plaque, tap `Key('btn_showcase_view_logs_<kitId>')`.
  - *Verification*: Plaque closes, and `CraftLogScreen` opens filtered specifically to that kit's logs.

### Feature 26 Boundary & Corner Cases
- **B26-1: PixelButton Disabled State Does Not Fire Callback**
  - *Interaction*: Attempt tap on `PixelButton(enabled: false)`.
  - *Verification*: Callback is not invoked; button renders reduced opacity (`0.45`).
- **B26-2: PixelButton Tap Cancel Restores Resting Offset**
  - *Interaction*: Start tap gesture down on PixelButton, drag far away (cancel gesture).
  - *Verification*: Button pressed state resets and translation offset restores to 0.0.
- **B26-3: PixelHpBar Boundary: Exactly 50% HP Color**
  - *Verification*: At 50.0% HP, `getHpColor` returns retro amber (`#FFD54F`), not green.
- **B26-4: PixelHpBar Boundary: Exactly 20% HP Color**
  - *Verification*: At 20.0% HP, `getHpColor` returns crimson red (`#FF5252`), not amber.
- **B26-5: PixelHpBar Zero and Negative HP Clamping**
  - *Verification*: At 0 HP or negative input, widthFactor clamps cleanly to `0.0` without layout exception.

### Feature 27 Boundary & Corner Cases
- **B27-1: Offline Font Rendering Does Not Trigger Web Request**
  - *Verification*: `GoogleFonts.config.allowRuntimeFetching == false` causes zero network calls or exceptions.
- **B27-2: Long Kit Title Truncation with Ellipsis**
  - *Setup*: Kit title has 50 characters.
  - *Verification*: Showcase card and Boss card constrain width and apply ellipsis without text overflow crash.
- **B27-3: Special Characters and Symbols in Kit Name**
  - *Interaction*: Add kit with title `★[RG] 00-Raiser (G&B) #01★`.
  - *Verification*: Renders without font encoding failure or missing glyph boxes.
- **B27-4: Dialogue Box Multi-line Dynamic Expansion**
  - *Interaction*: Trigger verbose battle settlement message (>100 characters).
  - *Verification*: Dialogue box text wraps cleanly with 1.4 line height without clipping.
- **B27-5: Modal Dialog Typography Contrast**
  - *Verification*: Contrast ratio of dialog header `#FFD54F` on `#1B1B26` dark background exceeds WCAG AA standards.

### Feature 28 Boundary & Corner Cases
- **B28-1: Multi-Hit Screen Shake Mathematical Bound Clamping**
  - *Interaction*: Fire 100 consecutive `shake()` calls within a single frame.
  - *Verification*: Offset `dx` does not exceed single-hit max `intensity` (25.0) and `dy` does not exceed `0.45 * intensity` (11.25).
- **B28-2: Rapid Consecutive Shake Barrage Decay to Zero**
  - *Interaction*: Spam shake across 20 frames, then wait 400ms.
  - *Verification*: Shake displacement completely decays to `Offset.zero`.
- **B28-3: ScreenShake `stop()` Immediately Restores Resting State**
  - *Interaction*: Trigger shake, call `controller.stop()`.
  - *Verification*: `isShaking` becomes false immediately, translation offset becomes `Offset.zero`.
- **B28-4: ScreenShake Global Accessibility Toggle**
  - *Interaction*: Set `ScreenShake.globalEnabled = false`, trigger shake.
  - *Verification*: No transform translation is applied (`Offset.zero`).
- **B28-5: Hit-testing Active During Shake**
  - *Interaction*: Tap button while screen is actively vibrating.
  - *Verification*: Tap gesture is successfully registered.

### Feature 29 Boundary & Corner Cases
- **B29-1: Zero Damage 'BLOCKED! 0' Popup**
  - *Interaction*: Spawn floating damage with `damage = 0`.
  - *Verification*: Bubble text is `BLOCKED! 0` with steel gray color (`#90A4AE`).
- **B29-2: Mercy Rule Interrupted Damage Popup Format**
  - *Interaction*: Trigger interrupted damage settlement.
  - *Verification*: Bubble text displays `-$damage (MERCY 50%)` with warning amber (`#FFA726`).
- **B29-3: Finishing Execution Damage Popup Format**
  - *Interaction*: Trigger finishing kill damage settlement.
  - *Verification*: Bubble text displays `FINISH! -$damage` with radiant gold (`#FFD700`).
- **B29-4: Multi-Bubble Horizontal Jitter Distribution**
  - *Interaction*: Spawn 3 rapid damage bubbles in sequence.
  - *Verification*: Jitter offsets vary (`-12.0`, `0.0`, `+12.0`), preventing visual overlap stacking.
- **B29-5: Overlay Clear Method Purges All Active Bubbles**
  - *Interaction*: Spawn multiple bubbles, call `controller.clear()`.
  - *Verification*: All bubbles are immediately removed from tree.

### Feature 30 Boundary & Corner Cases
- **B30-1: Rapid Hit Retriggering of Hurt Flash**
  - *Interaction*: Trigger flash 10 times in rapid succession.
  - *Verification*: Strobe restarts smoothly from 0.0 without controller state collision.
- **B30-2: Dual-Pulse Strobe Alpha Curve Verification**
  - *Verification*: Animation curve produces two distinct opacity peaks during the 220ms cycle.
- **B30-3: Recoil Squeeze Scale Factor During First 70ms**
  - *Verification*: Scale squeezes down to ~0.95 during initial phase and restores to 1.0.
- **B30-4: Flash Dismissal Leaves Sprite Undamaged When CurrentHp > 0**
  - *Verification*: At end of flash, sprite returns to original full-color rendering.
- **B30-5: Flash on Defeat Retains Grayscale Filter on Boss Sprite**
  - *Verification*: If damage drops HP to 0, once hurt flash ends, Boss sprite remains grayscale (`BlendMode.saturation`).

### Feature 31 Boundary & Corner Cases
- **B31-1: 50+ Rapid Mute Toggles Parity Test**
  - *Interaction*: Tap `btn_mute_toggle` 50 times rapidly.
  - *Verification*: Final state is unmuted (`SFX`), audio sounds normally. Tap 51st time -> muted (`MUTE`).
- **B31-2: 100% Silence Guarantee When Muted During Combat Spam**
  - *Setup*: Mute audio via HUD toggle.
  - *Interaction*: Complete full pomodoro combat dealing damage and finishing Boss.
  - *Verification*: All audio mock counts (`attackHitCount`, `criticalStrikeCount`, `finishingKillCount`, `timerTickCount`, `victoryFanfareCount`) remain strictly `0`.
- **B31-3: Critical Strike Audio Trigger on High Damage (>=150 pt)**
  - *Precondition*: Unmuted.
  - *Interaction*: Deal >=150 damage or use Airbrush/Detailing.
  - *Verification*: `mockAudio.criticalStrikeCount` increments.
- **B31-4: Finishing Kill Audio Trigger on Defeat**
  - *Precondition*: Unmuted.
  - *Interaction*: Deal final blow reducing Boss HP to 0.
  - *Verification*: `mockAudio.finishingKillCount` increments.
- **B31-5: Mute State Persistence Across App Rehydration**
  - *Interaction*: Mute audio in app, reload / create new audio service instance.
  - *Verification*: Saved preference `pref_retro_audio_muted` in SharedPreferences is `true`.

---

## 6. Guidance for Test Writer

When generating `test/e2e/e2e_tier1_r3_r4_test.dart` and `test/e2e/e2e_tier2_r3_r4_test.dart`:
1. Use distinct, self-documenting test group names matching features (`group('Feature 18: Model Hangar Screen', ...)`, etc.).
2. Always wrap asynchronous actions with `await tester.pump()` and appropriate durations to allow microtasks, timers, and animations to settle cleanly.
3. Ensure every test registers a teardown resetting screen size, audio instances, and global shake flags.
