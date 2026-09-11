library;

/// Game constants, craft phase multipliers, Pomodoro presets, and grade defaults.

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

/// 番茄鐘模式列舉
enum PomodoroMode {
  standard(
    label: '標準 25m/5m',
    workSeconds: 25 * 60,
    restSeconds: 5 * 60,
    basePoints: 100,
  ),
  deepFocus(
    label: '深度 50m/10m',
    workSeconds: 50 * 60,
    restSeconds: 10 * 60,
    basePoints: 220,
  ),
  debug(
    label: '除錯 5s/3s',
    workSeconds: 5,
    restSeconds: 3,
    basePoints: 20,
  );

  final String label;
  final int workSeconds;
  final int restSeconds;
  final int basePoints;

  const PomodoroMode({
    required this.label,
    required this.workSeconds,
    required this.restSeconds,
    required this.basePoints,
  });
}

/// 番茄鐘狀態階段
enum PomodoroPhase {
  idle,
  work,
  rest,
}

/// 番茄鐘預設設定物件
class PomodoroPreset {
  final String label;
  final int workSeconds;
  final int restSeconds;
  final int basePoints;

  const PomodoroPreset({
    required this.label,
    required this.workSeconds,
    required this.restSeconds,
    required this.basePoints,
  });

  static const standard = PomodoroPreset(
    label: '25m 標準 (5m 休息)',
    workSeconds: 25 * 60,
    restSeconds: 5 * 60,
    basePoints: 100,
  );

  static const deepFocus = PomodoroPreset(
    label: '50m 深度 (10m 休息)',
    workSeconds: 50 * 60,
    restSeconds: 10 * 60,
    basePoints: 220,
  );

  static const fastDebug = PomodoroPreset(
    label: '5s 快速除錯',
    workSeconds: 5,
    restSeconds: 3,
    basePoints: 20,
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

  // Alias for compatibility
  static const Map<String, double> craftMultipliers = phaseMultipliers;

  // --- 戰鬥與處決門檻 ---
  /// 水貼處決技限定 Boss 殘血 <= 20%
  static const double finishingExecutionThreshold = 0.20;
  static const double finishingHpThreshold = 0.20;

  /// Mercy Rule 中途急停保底倍率 (50%)
  static const double mercyRuleMultiplier = 0.50;
  static const double mercyRuleFactor = 0.50;

  // --- 基礎點數 ---
  static const int standardBasePoints = 100;
  static const int deepFocusBasePoints = 220;
  static const int debugBasePoints = 20;

  // --- 工時設定 (秒) ---
  static const int standardWorkSeconds = 25 * 60;
  static const int standardRestSeconds = 5 * 60;
  static const int deepFocusWorkSeconds = 50 * 60;
  static const int deepFocusRestSeconds = 10 * 60;
  static const int debugWorkSeconds = 5;
  static const int debugRestSeconds = 3;

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

  // --- 模型級別預設 HP (SPEC §3, PROJECT.md) ---
  static const Map<String, int> gradeHpDefaults = {
    'EG': 300,
    'HG': 500,
    'RG': 800,
    'MG': 1500,
    'PG': 5000,
  };

  // --- 預設種子模型常數 (Default Seed Kit Source of Truth) ---
  static const String defaultKitId = 'default-box-mimic-hg-001';
  static const String defaultKitTitle = '綠色普通盒怪';
  static const String defaultKitGrade = 'HG';
  static const int defaultKitHp = 500;
}
