# Milestone 1: Battle Engine Decoupling & Lint Fixes — Analysis Report

- **Author**: Explorer 1 (`teamwork_preview_explorer_m1_1`)
- **Target Audience**: Milestone 1 Worker & Orchestrator
- **Scope**: Features 1–12 of PROJECT.md
- **Date**: 2026-09-11

---

## 1. 執行摘要 (Executive Summary)

本報告針對專案《罪普拉 RPG（Tsumi-Pura RPG）》第一里程碑（Milestone 1: Pomodoro & Battle Engine）進行完整架構解耦調查與代碼診斷。
目前代碼庫僅存在單一檔案 `lib/main.dart`（1,018 行），所有戰鬥計算、計時循環、工序倍率與 UI 視圖緊密耦合，且存在 6 處待修復的靜態分析警告。

本次調查已完成：
1. **靜態分析診斷**：確認 `flutter analyze` 回報的 6 個 `unnecessary_underscores` 確切行號（298, 676, 719）與成因，並提供精確修復範例。
2. **單元測試現況診斷**：確認 `test/widget_test.dart` 因範本計數器找不到而失敗，並規劃專屬單元測試 `test/unit/battle_engine_test.dart` 與煙霧測試修復。
3. **戰鬥引擎與常數解耦架構**：
   - 抽出 `lib/core/constants/game_constants.dart`：集中管理 5 大工序倍率、Mercy Rule 50% 保底係數、20% 殘血處決門檻、三種番茄鐘設定（25m/5m, 50m/10m, 5s 除錯）與戰鬥字串常數。
   - 實作 `lib/domain/battle/battle_engine.dart`：嚴格遵守 `PROJECT.md` 之 `IBattleEngine` 合約，落實純 Dart 純數學運算、整數四捨五入、極端邊界保護（0 秒、負值、HP 為 0 等）。
4. **UI 與狀態流程對接方案**：規劃 `lib/main.dart` 如何接入解耦後的常數與領域類別，並補足 50m/10m 深度專注模式與工作/休息循環切換。

---

## 2. 基線診斷報告 (Baseline Diagnostics)

### 2.1 `flutter analyze` 執行結果
```
Analyzing nifty-heisenberg...

   info - Unnecessary use of multiple underscores - lib\main.dart:298:37 - unnecessary_underscores
   info - Unnecessary use of multiple underscores - lib\main.dart:298:41 - unnecessary_underscores
   info - Unnecessary use of multiple underscores - lib\main.dart:676:39 - unnecessary_underscores
   info - Unnecessary use of multiple underscores - lib\main.dart:676:43 - unnecessary_underscores
   info - Unnecessary use of multiple underscores - lib\main.dart:719:39 - unnecessary_underscores
   info - Unnecessary use of multiple underscores - lib\main.dart:719:43 - unnecessary_underscores

6 issues found. (ran in 35.3s)
```

#### 成因剖析
專案配置 `pubspec.yaml` 指定 `sdk: ^3.10.4` 與 `flutter_lints: ^6.0.0`。
在 Dart 3.7+ / 3.10+ 中，萬用字元（wildcard variables）`_` 已原生支援在同一參數列表中多次使用，且規則 `unnecessary_underscores` 嚴格禁止使用多個底線（如 `__` 或 `___`）來區分未使用的參數。
原程式碼在 3 處圖片載入錯誤回呼中寫了 `errorBuilder: (_, __, ___) => const Icon(...)`：
- 第 1 個參數 `_`（BuildContext）
- 第 2 個參數 `__`（Object error）→ 觸發 unnecessary_underscores
- 第 3 個參數 `___`（StackTrace? stackTrace）→ 觸發 unnecessary_underscores

每個回呼產生 2 處警告，3 個回呼合計產生恰好 6 個靜態分析警告。

### 2.2 `flutter test` 執行結果
```
00:00 +0: Counter increments smoke test
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "0": []>
   Which: means none were found but one was expected
════════════════════════════════════════════════════════════════════════════════════════════════════
00:03 +0 -1: Counter increments smoke test [E]
00:03 +0 -1: Some tests failed.
```
#### 成因剖析
`test/widget_test.dart` 仍是 Flutter 專案初始範本的計數器點擊測試，但 `TsumiPuraApp` 已是完整遊戲原型，介面上無任何 `'0'` 或 `Icons.add`。 Worker 需將其更新為對 `TsumiPuraApp` 的正常渲染煙霧測試。

---

## 3. Lint 6 處問題精準修復手冊 (Feature 12)

### 3.1 修復點 1：`lib/main.dart:298` (Quest Clear Dialog 盒怪縮圖)
- **原始代碼** (Lines 297–302):
```dart
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.military_tech,
                    size: 70,
                    color: Color(0xFFFFD54F),
                  ),
```
- **建議修復**：
```dart
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.military_tech,
                    size: 70,
                    color: Color(0xFFFFD54F),
                  ),
```
*(或使用具名參數 `(context, error, stackTrace) =>`，均可完全消弭警告)*

### 3.2 修復點 2：`lib/main.dart:676` (戰鬥舞台 Boss 盒怪 Sprite)
- **原始代碼** (Lines 675–680):
```dart
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.smart_toy,
                      size: 100,
                      color: Colors.greenAccent,
                    ),
```
- **建議修復**：
```dart
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.smart_toy,
                      size: 100,
                      color: Colors.greenAccent,
                    ),
```

### 3.3 修復點 3：`lib/main.dart:719` (戰鬥舞台 勇者小人 Sprite)
- **原始代碼** (Lines 718–723):
```dart
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person,
                      size: 80,
                      color: Colors.blueAccent,
                    ),
```
- **建議修復**：
```dart
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.person,
                      size: 80,
                      color: Colors.blueAccent,
                    ),
```

---

## 4. 領域解耦與架構設計

### 4.1 目標目錄結構
依據 `PROJECT.md` 規範，需建立下列結構：
```
lib/
├── core/
│   └── constants/
│       └── game_constants.dart    # [M1 新建] 工序常數、倍率、番茄鐘預設、色彩定義
├── domain/
│   └── battle/
│       └── battle_engine.dart     # [M1 新建] IBattleEngine 介面與純 Dart 戰鬥數值引擎
├── main.dart                      # [M1 重構] 移除硬編碼常數，改用 GameConstants 與 BattleEngine
```

---

### 4.2 常數模組：`lib/core/constants/game_constants.dart`
**職責**：集中所有遊戲數值常數、番茄鐘循環設定、工序字串、日語標記與預設色彩。

#### 完整建議實作代碼：
```dart
/// 工序技能字串定義
class CraftPhases {
  static const String snapFit = 'Snap-fit';
  static const String sanding = 'Sanding';
  static const String detailing = 'Detailing';
  static const String airbrush = 'Airbrush';
  static const String finishing = 'Finishing';

  static const List<String> all = [
    snapFit,
    sanding,
    detailing,
    airbrush,
    finishing,
  ];
}

/// 番茄鐘預設類型
enum PomodoroPresetType {
  standard,
  deepFocus,
  fastDebug,
}

/// 番茄鐘設定實體
class PomodoroPreset {
  final PomodoroPresetType type;
  final String label;
  final int workSeconds;
  final int restSeconds;
  final int basePoints;

  const PomodoroPreset({
    required this.type,
    required this.label,
    required this.workSeconds,
    required this.restSeconds,
    required this.basePoints,
  });

  /// 25m 工作 / 5m 休息，基礎點數 100
  static const standard = PomodoroPreset(
    type: PomodoroPresetType.standard,
    label: '25m 標準 (5m 休息)',
    workSeconds: 25 * 60,
    restSeconds: 5 * 60,
    basePoints: 100,
  );

  /// 50m 工作 / 10m 休息，基礎點數 220 (含 10% 專注加成)
  static const deepFocus = PomodoroPreset(
    type: PomodoroPresetType.deepFocus,
    label: '50m 深度 (10m 休息)',
    workSeconds: 50 * 60,
    restSeconds: 10 * 60,
    basePoints: 220,
  );

  /// 5s 快速除錯模式，基礎點數 100
  static const fastDebug = PomodoroPreset(
    type: PomodoroPresetType.fastDebug,
    label: '5s 快速除錯',
    workSeconds: 5,
    restSeconds: 2,
    basePoints: 100,
  );

  static const List<PomodoroPreset> presets = [
    standard,
    deepFocus,
    fastDebug,
  ];
}

/// 遊戲全域核心數值常數
class GameConstants {
  // --- 傷害倍率矩陣 (Phase Multipliers) ---
  static const double snapFitMultiplier = 1.0;   // 素組 (仮組み)
  static const double sandingMultiplier = 1.2;   // 打磨 (ヤスリ掛け)
  static const double detailingMultiplier = 1.5; // 刻線 (スジ彫り)
  static const double airbrushMultiplier = 2.0;  // 噴塗 (エアブラシ)
  static const double finishingMultiplier = 2.5; // 水貼處決 (デカール・仕上げ)

  static const Map<String, double> phaseMultipliers = {
    CraftPhases.snapFit: snapFitMultiplier,
    CraftPhases.sanding: sandingMultiplier,
    CraftPhases.detailing: detailingMultiplier,
    CraftPhases.airbrush: airbrushMultiplier,
    CraftPhases.finishing: finishingMultiplier,
  };

  // --- 戰鬥與處決門檻 ---
  /// 水貼處決技限定 Boss 殘血 <= 20%
  static const double finishingExecutionThreshold = 0.20;

  /// Mercy Rule 中途急停保底倍率 (50%)
  static const double mercyRuleMultiplier = 0.50;

  // --- 工序名稱與日誌訊息 ---
  static const Map<String, String> phaseSkillNames = {
    CraftPhases.snapFit: '剪鉗連擊',
    CraftPhases.sanding: '破甲打磨',
    CraftPhases.detailing: '弱點刻線',
    CraftPhases.airbrush: '噴筆重砲',
    CraftPhases.finishing: '處決水貼',
  };

  static const Map<String, String> phaseActionLogs = {
    CraftPhases.snapFit: '揮舞神之手單刃剪鉗！俐落剪落湯口零件造成傷害！',
    CraftPhases.sanding: '推動 600 號海綿砂紙！精準破除盒怪裝甲防禦！',
    CraftPhases.detailing: '運轉 0.15mm 鎢鋼推刀！瞄準弱點深刻出爆發切口！',
    CraftPhases.airbrush: '防毒面具著裝！雙動噴筆噴射全覆蓋漆霧轟炸！',
    CraftPhases.finishing: '鑷子夾起標誌水貼並覆蓋消光漆！發動終極處決淨化！',
  };

  // --- 模型級別預設 HP (SPEC §3) ---
  static const Map<String, int> gradeHpDefaults = {
    'EG': 300,
    'HG': 500,
    'RG': 800,
    'MG': 1500,
    'PG': 5000,
  };
}
```

---

### 4.3 領域戰鬥引擎：`lib/domain/battle/battle_engine.dart`
**職責**：
1. 嚴格實作 `PROJECT.md` 規範的 `IBattleEngine` 介面契約。
2. 封裝純粹數值計算（無 Flutter UI 依賴，保證 100% 可單元測試）。
3. 嚴謹處理各類邊界與例外情境：
   - `totalSeconds <= 0`、`elapsedSeconds <= 0`、`basePoints <= 0` 結算均為 0 傷害。
   - `elapsedSeconds` 鉗制在 `[0, totalSeconds]` 區間，防禦超時溢出。
   - 處決技能判定 `canExecuteFinishing`：防禦 `maxHp <= 0` 之除以零錯誤，並加入微小容差處理浮點數精度。
   - 若在未滿足處決門檻時嘗試對 `Finishing` 結算傷害，引擎將判定傷害為 0。
   - 完整支援 Mercy Rule 50% 結算與 Dart 核心 `.round()` 四捨五入取整。

#### 完整建議實作代碼：
```dart
import '../../core/constants/game_constants.dart';

/// 戰鬥引擎介面契約 (PROJECT.md §Interface Contracts)
abstract class IBattleEngine {
  /// 計算本次專注工作結算或中斷時所產生的傷害數值
  int calculateDamage({
    required int basePoints,
    required String phase,
    required int elapsedSeconds,
    required int totalSeconds,
    required bool isInterrupted,
    required int currentHp,
    required int maxHp,
  });

  /// 檢查水貼處決技是否解鎖 (Boss 殘血 <= 20%)
  bool canExecuteFinishing({
    required int currentHp,
    required int maxHp,
  });
}

/// 純 Dart 戰鬥數值引擎實作
class BattleEngine implements IBattleEngine {
  const BattleEngine();

  @override
  bool canExecuteFinishing({
    required int currentHp,
    required int maxHp,
  }) {
    if (maxHp <= 0) return false;
    if (currentHp <= 0) return true;

    // 門檻：HP <= 20% (加上 1e-9 浮點容差防禦 100/500 = 0.20000000000000004)
    return (currentHp / maxHp) <= (GameConstants.finishingExecutionThreshold + 1e-9);
  }

  @override
  int calculateDamage({
    required int basePoints,
    required String phase,
    required int elapsedSeconds,
    required int totalSeconds,
    required bool isInterrupted,
    required int currentHp,
    required int maxHp,
  }) {
    // 邊界防禦：時間或基礎點數不合法時不造成傷害
    if (totalSeconds <= 0 || elapsedSeconds <= 0 || basePoints <= 0) {
      return 0;
    }

    // 處決技安全門鎖：若為 Finishing 且未滿足處決條件，輸出為 0
    if (phase == CraftPhases.finishing &&
        !canExecuteFinishing(currentHp: currentHp, maxHp: maxHp)) {
      return 0;
    }

    // 工序倍率 (未知工序回退至 1.0x)
    final double multiplier = GameConstants.phaseMultipliers[phase] ?? 1.0;

    // 時間進度比例 (鉗制在 0.0 ~ 1.0)
    final int clampedElapsed = elapsedSeconds.clamp(0, totalSeconds);
    final double elapsedRatio = clampedElapsed / totalSeconds;

    // 基礎乘算
    double damage = basePoints * elapsedRatio * multiplier;

    // 中斷保底 (Mercy Rule: 50% 傷害)
    if (isInterrupted) {
      damage *= GameConstants.mercyRuleMultiplier;
    }

    // 四捨五入整數化
    final int finalDamage = damage.round();
    return finalDamage > 0 ? finalDamage : 0;
  }

  /// 結算獲取之廢流道塑料金幣 (SPEC §4.3: 依專注時長結算)
  int calculateEarnedCoins({required int elapsedSeconds}) {
    if (elapsedSeconds <= 0) return 0;
    // 每 5 秒約折算 1 金幣，區間限制在 2 ~ 50
    return (elapsedSeconds / 5).round().clamp(2, 50);
  }

  /// 計算當前血量比例 [0.0, 1.0]
  double calculateHpPercentage({
    required int currentHp,
    required int maxHp,
  }) {
    if (maxHp <= 0) return 0.0;
    return (currentHp / maxHp).clamp(0.0, 1.0);
  }
}
```

---

## 5. UI 與流程整合方案 (`lib/main.dart`)

### 5.1 引入解耦模組
在 `lib/main.dart` 頂部引入：
```dart
import 'core/constants/game_constants.dart';
import 'domain/battle/battle_engine.dart';
```

### 5.2 狀態層精簡與對接
1. **移除硬編碼 Map**：
   - 刪除 `_phaseMultipliers`，改用 `GameConstants.phaseMultipliers`。
   - 刪除 `_phaseSkillNames`，改用 `GameConstants.phaseSkillNames`。
   - 刪除 `_phaseActionLogs`，改用 `GameConstants.phaseActionLogs`。
2. **持有引擎實例**：
   ```dart
   final IBattleEngine _battleEngine = const BattleEngine();
   ```
3. **支援三種番茄鐘預設**：
   - 新增狀態變數：
     ```dart
     PomodoroPreset _currentPreset = PomodoroPreset.standard;
     bool _isResting = false; // 支援工作/休息循環 (Features 1, 2)
     ```
4. **重構傷害結算方法**：
   ```dart
   void _calculateAndApplyDamage({
     required bool isInterrupted,
     required int actualElapsedSeconds,
   }) {
     _totalSessionDurationSeconds += actualElapsedSeconds;

     final int finalDamage = _battleEngine.calculateDamage(
       basePoints: _currentPreset.basePoints,
       phase: _selectedPhase,
       elapsedSeconds: actualElapsedSeconds,
       totalSeconds: _totalSeconds,
       isInterrupted: isInterrupted,
       currentHp: currentHp,
       maxHp: maxHp,
     );

     final int earnedCoins = _battleEngine.calculateEarnedCoins(
       elapsedSeconds: actualElapsedSeconds,
     );
     userCoins += earnedCoins;

     _triggerHitJuice(finalDamage, isInterrupted);

     setState(() {
       currentHp = (currentHp - finalDamage).clamp(0, maxHp);
       if (isInterrupted) {
         _battleDialogText =
             '⚠️ 中途急停！觸發 Mercy 保底防護，結算 50% 造成 $finalDamage 點傷害（掉落 $earnedCoins 塑料金幣）。';
       } else {
         _battleDialogText =
             '💥 ${GameConstants.phaseActionLogs[_selectedPhase]} 造成 $finalDamage 點爆發傷害！（獲得 $earnedCoins 塑料金幣）';
       }

       if (currentHp <= 0) {
         Future.delayed(const Duration(milliseconds: 700), () {
           if (mounted) _showQuestClearDialog();
         });
       }
     });
   }
   ```
5. **工序處決門鎖切換檢查**：
   將所有原 `(currentHp / maxHp) > 0.2` 或 `hpPercentage <= 0.2` 替換為：
   ```dart
   bool isExecuteReady = _battleEngine.canExecuteFinishing(
     currentHp: currentHp,
     maxHp: maxHp,
   );
   ```

6. **控制器按鈕升級 (Features 1, 2, 3)**：
   在 `_buildControls()` 中，提供：
   - `開始開工 (25m)` → 啟動 `PomodoroPreset.standard`
   - `深度專注 (50m)` → 啟動 `PomodoroPreset.deepFocus`
   - `5秒測試` → 啟動 `PomodoroPreset.fastDebug`
   - 當專注結束後，若進入休息階段，提供倒數及「跳過休息 / 繼續開工」按鈕。

---

## 6. 自動化測試驗證方案

### 6.1 新建 `test/unit/battle_engine_test.dart`
涵蓋規格書所有倍率、中斷保底、處決門檻與極端數值：
1. **5 大工序全額完成測試**：
   - 素組 (1.0x, 100 pt) = 100 傷害
   - 打磨 (1.2x, 100 pt) = 120 傷害
   - 刻線 (1.5x, 100 pt) = 150 傷害
   - 噴塗 (2.0x, 100 pt) = 200 傷害
   - 水貼 (2.5x, 100 pt, HP <= 20%) = 250 傷害
2. **深度專注 50m (220 pt) 測試**：
   - 素組 = 220 傷害
   - 噴塗 = 440 傷害
   - 水貼 = 550 傷害
3. **Mercy Rule 中斷保底測試**：
   - 25m 模式進行 50% (750s/1500s) 中斷：$100 \times 0.5 \times 1.0 \times 0.5 = 25$
   - 噴塗進行 50% 中斷：$100 \times 0.5 \times 2.0 \times 0.5 = 50$
   - 5s 除錯模式進行 2s 中斷：$100 \times (2/5) \times 1.0 \times 0.5 = 20$
4. **水貼處決門鎖測試**：
   - HP 101 / 500 (20.2%)：`canExecuteFinishing` 為 `false`，`calculateDamage` 為 0
   - HP 100 / 500 (20.0%)：`canExecuteFinishing` 為 `true`，`calculateDamage` 為 250
   - HP 50 / 500 (10.0%)：`canExecuteFinishing` 為 `true`
5. **邊界防禦測試**：
   - `elapsedSeconds == 0` → 0 傷害
   - `totalSeconds == 0` → 0 傷害
   - `maxHp == 0` → `canExecuteFinishing` 為 `false`

### 6.2 修復 `test/widget_test.dart`
將原計數器測試替換為 `TsumiPuraApp` 基礎渲染煙霧測試：
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nifty_heisenberg/main.dart';

void main() {
  testWidgets('TsumiPuraApp basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TsumiPuraApp());
    expect(find.text('TSUMI-PURA RPG'), findsOneWidget);
  });
}
```

---

## 7. 給予 Worker 的實施建議與步驟 (Action Plan for Worker)

1. **第一步：建立常數模組**
   建立 `lib/core/constants/game_constants.dart`，置入上述常數與 `PomodoroPreset` 定義。
2. **第二步：建立領域戰鬥引擎**
   建立 `lib/domain/battle/battle_engine.dart`，實作 `IBattleEngine` 與 `BattleEngine`。
3. **第三步：撰寫單元測試**
   建立 `test/unit/battle_engine_test.dart`，並修復 `test/widget_test.dart`。執行 `flutter test` 確保 100% 通過。
4. **第四步：修復 `lib/main.dart` 靜態分析警告**
   修復 Lines 298, 676, 719 的 `errorBuilder: (_, _, _)`。
5. **第五步：重構 `lib/main.dart` 接入領域層**
   接入 `GameConstants`、`BattleEngine`，支援 50m 模式與番茄鐘按鈕。
6. **第六步：驗收檢查**
   執行 `flutter analyze` 驗證 0 errors / 0 warnings，執行 `flutter test` 驗證全數通過。
