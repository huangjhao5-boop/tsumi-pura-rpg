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

/// 純 Dart 戰鬥數值引擎實作 (無 Flutter UI 依賴)
class BattleEngine implements IBattleEngine {
  const BattleEngine();

  @override
  bool canExecuteFinishing({
    required int currentHp,
    required int maxHp,
  }) {
    if (maxHp <= 0) return false;
    if (currentHp <= 0) return true;

    // 門檻：HP <= 20% (加上 1e-9 浮點容差)
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

    // 處決技安全門鎖：若為 Finishing 且未滿足處決條件，傷害輸出為 0
    if (phase == CraftPhases.finishing &&
        !canExecuteFinishing(currentHp: currentHp, maxHp: maxHp)) {
      return 0;
    }

    // 工序倍率 (未知工序回退至 1.0x)
    final double multiplier = GameConstants.phaseMultipliers[phase] ?? 1.0;

    // 時間進度比例 (鉗制在 0 ~ totalSeconds)
    final int clampedElapsed = elapsedSeconds.clamp(0, totalSeconds);
    final double elapsedRatio = clampedElapsed / totalSeconds;

    // 基礎乘算及中斷保底 (Mercy Rule: 50% 傷害)
    final double rawFactor = isInterrupted ? GameConstants.mercyRuleMultiplier : 1.0;
    final double rawDamage = basePoints * elapsedRatio * multiplier * rawFactor;

    int damage = rawDamage.round();

    // 保底最低傷害：只要實際進行秒數 > 0 且通過門鎖，若計算四捨五入為 0 則保底輸出 1
    if (damage <= 0 && elapsedSeconds > 0) {
      damage = 1;
    }

    return damage;
  }

  /// 結算獲取之廢流道塑料金幣 (SPEC §4.3)
  int calculateEarnedCoins({required int elapsedSeconds}) {
    if (elapsedSeconds <= 0) return 0;
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
