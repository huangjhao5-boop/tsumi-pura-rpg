# Milestone 4 Deep Investigation: Features 26 & 27 (8-Bit Pixel UI Consistency & Retro Typography)

## 1. Executive Summary

This investigation covers the design, engineering, and backward-compatible integration of **Feature 26 (8-Bit Pixel UI Consistency)** and **Feature 27 (Retro Typography)** into the 《罪普拉 RPG》 Flutter codebase.
The project currently passes all 171 automated tests across unit, widget, and challenge suites, with 0 warnings/errors under `flutter analyze`. 

The core objectives accomplished in this analysis are:
1. **Retro Typography & Offline Safety**: In-depth source code analysis of `google_fonts: ^6.2.1` in the pub cache. We identified why unhandled `rethrow` exceptions occur during widget tests and offline runs, and formulated an environment-aware fallback architecture combining `Press Start 2P`, `VT323`, and platform monospace fonts (`Courier New`, `Consolas`, `monospace`).
2. **8-Bit Pixel UI Widgets & Workbench Palette**: Formalized the retro dark workbench color system (`#12141F` dark slate, retro amber `#FFD54F`, cyber cyan `#8BE9FD`, neon green `#50FA7B`, crimson red `#FF5252`, retro purple `#BD93F9`) and engineered specifications for 5 reusable pixel widgets (`PixelFrame`, `PixelButton` with pressed states, `PixelHpBar` with 3-phase thresholds, `PixelBadge`, and `PixelDialogContainer`).
3. **Screen Compatibility Audit**: Mapped all widget keys, finding patterns, and verbatim strings across `BattleScreen`, `HangarScreen`, `ShowcaseScreen`, and `CraftLogScreen` to guarantee zero test breakage.
4. **Implementation Blueprint**: Produced concrete class interfaces, file layout, and code structures for the upcoming implementation worker.

---

## 2. Feature 27: Retro Typography & Offline Resilience

### 2.1 Technical Analysis of `google_fonts` (v6.3.3)
Investigation of `google_fonts_base.dart` in the local cache revealed the following critical mechanics:
```dart
// Location: google_fonts_base.dart lines 170-207
if (GoogleFonts.config.allowRuntimeFetching) {
  byteData = _httpFetchFontAndSaveToDevice(familyWithVariantString, descriptor.file);
  if (await byteData != null) {
    return loadFontByteData(familyWithVariantString, byteData);
  }
} else {
  throw Exception('GoogleFonts.config.allowRuntimeFetching is false but font $fontName was not found in the application assets.');
}
// Catch block:
} catch (e) {
  _loadedFonts.remove(familyWithVariantString);
  print('Error: google_fonts was unable to load font $fontName...');
  if (file_io.isTest) { ... }
  rethrow; // <-- CRITICAL: Causes unhandled zone exceptions in tests and offline runs!
}
```

#### Key Findings:
1. **Test Environment Crash**: When running `flutter test`, `file_io.isTest` is `true`. Flutter test bindings reject HTTP requests (`httpClient.get`), throwing an unhandled exception that causes test runners to fail.
2. **Setting `allowRuntimeFetching = false` Still Throws**: If `allowRuntimeFetching` is set to `false` and the `.ttf` files are not bundled in `assets/`, it explicitly throws an `Exception` and rethrows.
3. **Asset Manifest Bypass**: If fonts are bundled in `assets/` and registered in `pubspec.yaml`, `google_fonts` loads them directly via `rootBundle.load` without making network calls.
4. **Native Flutter Monospace Fallback**: If a `TextStyle` specifies `fontFamily: 'Press Start 2P'` with `fontFamilyFallback: ['VT323', 'Courier New', 'Consolas', 'monospace']`, Flutter's internal typography engine seamlessly falls back to system monospace fonts without throwing any exception, even if the font is absent.

### 2.2 Architectural Solution: `RetroTypography`
To guarantee that the app looks authentically 8-bit when connected, while remaining 100% resilient when offline or under `flutter test`, we design `RetroTypography` in `lib/presentation/theme/retro_theme.dart`:

```dart
class RetroTypography {
  static const String primaryFont = 'Press Start 2P';
  static const String secondaryFont = 'VT323';
  static const List<String> monospaceFallback = [
    'VT323',
    'Courier New',
    'Consolas',
    'monospace',
  ];

  /// Safe runtime check to determine whether we should bypass network font fetching.
  static bool get isTestOrOffline {
    // 1. Check flutter test binding
    final binding = WidgetsBinding.instance;
    if (binding.runtimeType.toString().contains('Test')) {
      return true;
    }
    // 2. Check if runtime fetching was explicitly disabled
    if (!GoogleFonts.config.allowRuntimeFetching) {
      return true;
    }
    return false;
  }

  /// Primary 8-bit pixel header style (Press Start 2P with monospace fallback)
  static TextStyle pixelHeader({
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.bold,
    Color color = Colors.white,
    double letterSpacing = 1.2,
    double? height,
  }) {
    if (isTestOrOffline) {
      return TextStyle(
        fontFamily: primaryFont,
        fontFamilyFallback: monospaceFallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
    try {
      return GoogleFonts.pressStart2p(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      ).copyWith(fontFamilyFallback: monospaceFallback);
    } catch (_) {
      return TextStyle(
        fontFamily: primaryFont,
        fontFamilyFallback: monospaceFallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
  }

  /// Secondary pixel body/monospace style (VT323 with monospace fallback)
  static TextStyle pixelBody({
    double fontSize = 10,
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.white,
    double letterSpacing = 1.0,
    double? height,
  }) {
    if (isTestOrOffline) {
      return TextStyle(
        fontFamily: secondaryFont,
        fontFamilyFallback: monospaceFallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
    try {
      return GoogleFonts.vt323(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      ).copyWith(fontFamilyFallback: monospaceFallback);
    } catch (_) {
      return TextStyle(
        fontFamily: secondaryFont,
        fontFamilyFallback: monospaceFallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
  }
}
```

---

## 3. Feature 26: 8-Bit Pixel UI Consistency & Workbench Palette

### 3.1 Retro Dark Workbench Color System (`RetroColors`)
We consolidate all disparate hex codes into a unified, high-contrast arcade workbench palette:

| Color Token | Hex Code | Purpose / Usage |
| :--- | :--- | :--- |
| `darkSlate` | `#12141F` | Main workbench scaffold background |
| `darkSlateDeep` | `#0D0E15` | Battle stage background, dialogue inner box |
| `surfaceDark` | `#1B1B26` | Card backgrounds, drawer panels |
| `surfaceElevated` | `#212234` | App bar headers, filter tab bars |
| `retroAmber` | `#FFD54F` | Primary arcade gold, quest clear title, gold coins, active stars |
| `retroOrange` | `#FFB86C` | MG grade badge, showcase action button |
| `cyberCyan` | `#8BE9FD` | Tech subtitles, Detailing skill, HG grade, CRT grid |
| `neonGreen` | `#50FA7B` | Start button, Rest phase HUD, EG grade, HP > 50% |
| `crimsonRed` | `#FF5252` | Interruption button, Boss hurt flash, HP <= 20%, delete buttons |
| `retroPurple` | `#BD93F9` | Dialogue border, Finishing phase skill, PG grade |
| `borderDark` | `#383A59` | Primary retro panel borders (2px / 3px) |
| `borderMuted` | `#44475A` | Inactive kit card borders, inactive tab borders |
| `borderLight` | `#6272A4` | Active filter chips, hover highlights |

### 3.2 Pixel Widgets Design (`lib/presentation/widgets/pixel_widgets.dart`)

#### 1. `PixelFrame` (2px Stepped / Retro Borders)
- **Concept**: In classic 8-bit games, containers feature stepped notches on corners rather than rounded corners or flat lines.
- **Implementation**:
  Can be implemented either as a `CustomPainter` (`PixelBorderPainter`) or a layered container with stepped corner notches:
  - Top & bottom borders offset by 2px from edges.
  - Left & right borders offset by 2px from edges.
  - 2px corner steps at each vertex.
  - Optional 3D arcade bevel: top/left outer highlight, bottom/right outer shadow.

#### 2. `PixelButton` (3D Beveled Retro Button with Pressed States)
- **Visual States**:
  - **Resting**: Raised 3D bevel (top & left: lighter border `#FFFFFF` / `alpha: 0.35`; bottom & right: darker shadow `#000000` / `alpha: 0.5`). 2px drop-shadow underneath.
  - **Hover**: Accent border glow (cyan or amber).
  - **Pressed**: Content translates by `Offset(0, 2)` via `Transform.translate`. Top/left borders become shadows; bottom/right borders become highlights. Drop-shadow collapses to 0.
- **Compatibility**:
  - Exposes standard `VoidCallback? onPressed`, `Widget child`, `Color color`, `Key? key`.
  - Can drop-in replace or wrap `ElevatedButton`.

#### 3. `PixelHpBar` (Retro 8-Bit Health Bar)
- **Visual Design**:
  - Outer frame: 2px solid border with inner 1px black margin.
  - Inner fill: Pixel block segmented gradient or discrete stepped pips.
  - Color tiering:
    - `> 50%`: Neon Green (`RetroColors.neonGreen` / `#50FA7B`)
    - `20% - 50%`: Retro Amber (`RetroColors.retroAmber` / `#FFD54F`)
    - `<= 20%`: Flashing Crimson (`RetroColors.crimsonRed` / `#FF5252`) — indicates that Finishing execution is UNLOCKED!
  - Displays: Leading `HP` label, fraction bar, and percentage indicator.

#### 4. `PixelBadge` (Grade & Status Badges)
- Blocky 1px/1.5px pixel border with tinted transparent background.
- Preserves exact text: `EG`, `HG`, `RG`, `MG`, `PG`, `GK`, `自訂`, `山積`, `施工中`, `完工`.

#### 5. `PixelDialogContainer` (Retro RPG Dialogue Modal)
- Ornate stepped border with golden or purple arcade corners.
- Dark slate backdrop with scanline grid accents.
- Seamlessly wraps existing dialog children (`KitFormDialog`, `DeleteConfirmDialog`, `ShowcaseDetailDialog`).

---

## 4. Screen-by-Screen Review & Compatibility Matrix

| Screen | Target File | Key Elements to Style | Required Key & Text Preservations |
| :--- | :--- | :--- | :--- |
| **BattleScreen** | `lib/main.dart` (and `lib/presentation/screens/battle_screen.dart`) | Header HUD, Boss Card, PixelHpBar, Battle Stage (Scanlines), Dialogue Box, Process Selector, Timer HUD, Controls | `btn_hangar`, `btn_showcase`, `btn_craft_log`, `btn_clear_to_showcase`, `btn_clear_to_hangar`, `btn_clear_restart`, `TSUMI-PURA RPG`, `素組\n1.0x`, `水貼\n🔒20%`, `開始開工`, `5秒測試`, `中途中斷` |
| **HangarScreen** | `lib/presentation/screens/hangar_screen.dart` | Header bar, Filter tabs, Kit cards (PixelFrame + PixelHpBar), Add/Edit modal, Delete modal | `btn_hangar_back`, `btn_add_kit`, `btn_add_kit_empty`, `filter_all`, `filter_unstarted`, `filter_in_progress`, `filter_completed`, `kit_card_<id>`, `btn_set_active_<id>`, `btn_edit_kit_<id>`, `btn_delete_kit_<id>`, `input_kit_title`, `checkbox_custom_hp`, `input_kit_hp`, `btn_dialog_save`, `btn_confirm_delete` |
| **ShowcaseScreen** | `lib/presentation/screens/showcase_screen.dart` | Header bar, Showcase grid, Pedestal cards with gold PixelFrame, Detail dialog | `btn_showcase_back`, `showcase_empty_state`, `showcase_card_<id>`, `showcase_detail_dialog`, `btn_detail_close`, `btn_view_logs_<id>`, `★ SHOWCASE ★`, `尚無完工模型，快去討伐堆積吧！` |
| **CraftLogScreen** | `lib/presentation/screens/craft_log_screen.dart` | Header bar, Filter selector, KPI metrics overview card, 5-phase breakdown bars, Log cards | `btn_craft_log_back`, `filter_active_kit`, `filter_all_logs`, `log_card_<id>`, `★ CRAFT LOG ★`, `【討伐與施工統計總覽】`, `【5 大工序傷害與工時分佈】`, `【詳細施工歷史清單】` |
| **BottomNavBar** | `lib/presentation/widgets/retro_bottom_nav_bar.dart` | Stepped top border, Pixel tab items with active glow | `btn_nav_battle`, `btn_nav_hangar`, `btn_nav_showcase`, `btn_nav_craft_log` |

---

## 5. Exact Implementation Blueprint

### File Structure to Create / Update:
1. `lib/presentation/theme/retro_theme.dart` (NEW)
   - `RetroColors` constants
   - `RetroTypography` safe font getter class
   - `RetroTheme.darkTheme` factory method returning `ThemeData`
2. `lib/presentation/widgets/pixel_widgets.dart` (NEW)
   - `PixelFrame` (stepped retro container)
   - `PixelBorderPainter` (custom painter for 2px stepped corners)
   - `PixelButton` (beveled 8-bit button with active pressed offset)
   - `PixelHpBar` (retro HP bar with color transitions)
   - `PixelBadge` (grade and status badge)
   - `PixelDialogContainer` (retro RPG modal container)
3. `lib/presentation/widgets/retro_bottom_nav_bar.dart` (UPDATE)
   - Apply `RetroColors` and stepped pixel borders to dock items
4. `lib/main.dart` & `lib/presentation/screens/battle_screen.dart` (UPDATE)
   - Point `ThemeData` to `RetroTheme.darkTheme`
   - Upgrade HP bar, dialogue box, and action buttons to pixel widgets
   - Export `BattleAtelierScreen` and `TsumiPuraApp` to keep 100% test compatibility
5. `lib/presentation/screens/hangar_screen.dart` (UPDATE)
   - Upgrade `KitCard` to use `PixelFrame` and `PixelHpBar`
   - Upgrade dialogs to `PixelDialogContainer`
6. `lib/presentation/screens/showcase_screen.dart` (UPDATE)
   - Upgrade cards to `PixelFrame` with gold trophy accents
   - Upgrade detail dialog to `PixelDialogContainer`
7. `lib/presentation/screens/craft_log_screen.dart` (UPDATE)
   - Upgrade KPI overview, phase distribution bars, and log cards to `PixelFrame`
8. `test/widget/pixel_ui_theme_test.dart` (NEW)
   - Verification tests for `RetroTypography`, `PixelButton` pressed state, `PixelHpBar` color transitions, and `PixelFrame` rendering

---

## 6. Verification Plan for Worker & Challenger

1. **Static Analysis**: `flutter analyze` must pass with 0 errors and 0 warnings.
2. **Regression Suite**: Run `flutter test` across all 171 existing tests to verify that zero tests are broken.
3. **Milestone 4 Targeted Tests**: Run `flutter test test/widget/pixel_ui_theme_test.dart` to verify:
   - Retro typography does not attempt network calls during widget tests.
   - Fallback to monospace functions reliably.
   - `PixelButton` renders with proper bevels and responds to tap events.
   - `PixelHpBar` renders with 100%, 50%, and 20% thresholds properly.
