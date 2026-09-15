import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'core/audio/retro_audio_service.dart';
import 'core/constants/game_constants.dart';
import 'data/repositories/craft_log_repository.dart';
import 'data/repositories/kit_repository.dart';
import 'domain/battle/battle_engine.dart';
import 'domain/models/craft_log.dart';
import 'domain/models/kit_item.dart';
import 'presentation/screens/craft_log_screen.dart';
import 'presentation/screens/hangar_screen.dart';
import 'presentation/screens/showcase_screen.dart';
import 'presentation/theme/retro_colors.dart';
import 'presentation/theme/retro_typography.dart';
import 'presentation/widgets/boss_hurt_flash.dart';
import 'presentation/widgets/floating_damage_text.dart';
import 'presentation/widgets/pixel_button.dart';
import 'presentation/widgets/pixel_frame.dart';
import 'presentation/widgets/pixel_hp_bar.dart';
import 'presentation/widgets/retro_bottom_nav_bar.dart';
import 'presentation/widgets/screen_shake.dart';

void main() {
  runApp(const TsumiPuraApp());
}

class TsumiPuraApp extends StatelessWidget {
  final IKitRepository? kitRepository;
  final ICraftLogRepository? craftLogRepository;

  const TsumiPuraApp({
    super.key,
    this.kitRepository,
    this.craftLogRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tsumi-Pura RPG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: RetroColors.darkSlate,
        fontFamily: RetroTypography.primaryFont,
        fontFamilyFallback: RetroTypography.monospaceFallback,
        useMaterial3: true,
      ),
      home: BattleAtelierScreen(
        kitRepository: kitRepository,
        craftLogRepository: craftLogRepository,
      ),
    );
  }
}

class BattleAtelierScreen extends StatefulWidget {
  final IKitRepository? kitRepository;
  final ICraftLogRepository? craftLogRepository;

  const BattleAtelierScreen({
    super.key,
    this.kitRepository,
    this.craftLogRepository,
  });

  @override
  State<BattleAtelierScreen> createState() => _BattleAtelierScreenState();
}

class _BattleAtelierScreenState extends State<BattleAtelierScreen>
    with TickerProviderStateMixin {
  // --- Repositories ---
  late IKitRepository _kitRepo;
  late ICraftLogRepository _craftLogRepo;

  // --- Default Seed Kit (Guarantees Instant 1st-Frame Render) ---
  static final KitItem defaultKit = KitItem.initialSeedKit();

  // --- Boss & Player State ---
  late KitItem _activeKit = defaultKit;
  String get bossName => _activeKit.title;
  String get bossGrade => _activeKit.grade;
  late int maxHp = defaultKit.totalHp;
  late int currentHp = defaultKit.currentHp;
  int userCoins = 150; // 廢流道塑料金幣

  // --- Battle Engine ---
  final IBattleEngine _battleEngine = const BattleEngine();

  // --- Pomodoro State ---
  Timer? _timer;
  PomodoroMode _selectedMode = PomodoroMode.standard;
  PomodoroPhase _pomodoroPhase = PomodoroPhase.idle;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  bool get _isRunning => _pomodoroPhase == PomodoroPhase.work;
  int _totalSessionDurationSeconds = 0;

  // --- Battle Log & Dialogue ---
  String _battleDialogText = '工作桌前一切就緒。請選擇工序技能，開始專注討伐！';

  // --- Animation & Combat Juice Controllers ---
  late AnimationController _idleController;
  late AnimationController _shakeController;
  final ScreenShakeController _screenShakeController = ScreenShakeController();
  final BossHurtFlashController _bossHurtFlashController =
      BossHurtFlashController();
  final FloatingDamageController _floatingDamageController =
      FloatingDamageController();
  final IRetroAudioService _audioService = RetroAudioService.instance;
  bool _isHurt = false;
  String? _floatingDamageText;
  Color _floatingDamageColor = Colors.yellow;

  // --- Process & Skill Selection ---
  String _selectedPhase = CraftPhases.snapFit;

  Map<String, double> get _phaseMultipliers => GameConstants.phaseMultipliers;
  Map<String, String> get _phaseSkillNames => GameConstants.phaseSkillNames;

  @override
  void initState() {
    super.initState();
    _craftLogRepo = widget.craftLogRepository ?? CraftLogRepository();
    _kitRepo = widget.kitRepository ?? KitRepository(null, _craftLogRepo);
    if (_kitRepo is KitRepository) {
      (_kitRepo as KitRepository).bindCraftLogRepository(_craftLogRepo);
    }

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _hydrateActiveKit();
  }

  Future<void> _hydrateActiveKit({bool notifyTargetChange = false}) async {
    try {
      final storedKit = await _kitRepo.getActiveKit();
      if (storedKit != null && mounted) {
        final bool isTargetChanged = storedKit.id != _activeKit.id;
        setState(() {
          _activeKit = storedKit;
          currentHp = storedKit.currentHp;
          maxHp = storedKit.totalHp;

          if (isTargetChanged && notifyTargetChange) {
            _battleDialogText = '🎯 已鎖定新討伐目標！請選擇工序開工。';
            _floatingDamageText = null;
          }

          // Reset Finishing phase if new kit HP > 20%
          if (_selectedPhase == CraftPhases.finishing &&
              !_battleEngine.canExecuteFinishing(
                currentHp: currentHp,
                maxHp: maxHp,
              )) {
            _selectedPhase = CraftPhases.snapFit;
          }
        });
      }
    } catch (e) {
      debugPrint('Hydration fallback: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _idleController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // --- Timer Controls ---
  void _startTimer(PomodoroMode mode) {
    if (_pomodoroPhase != PomodoroPhase.idle || currentHp <= 0) return;

    // Check Finishing condition (<= 20% HP)
    if (_selectedPhase == CraftPhases.finishing &&
        !_battleEngine.canExecuteFinishing(currentHp: currentHp, maxHp: maxHp)) {
      _showSnackAlert('⚠️ 水貼終結技限定 Boss 殘血 20% 以下發動！');
      return;
    }

    _selectedMode = mode;
    _startWorkPhase();
  }

  void _startWorkPhase() {
    _timer?.cancel();
    setState(() {
      _pomodoroPhase = PomodoroPhase.work;
      _totalSeconds = _selectedMode.workSeconds;
      _remainingSeconds = _totalSeconds;
      _floatingDamageText = null;
      _battleDialogText =
          '⚔️ 開工中：${GameConstants.phaseSkillNames[_selectedPhase]}！時間滴答倒數...';
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
        if (_remainingSeconds <= 5 && _remainingSeconds > 0) {
          _audioService.playTimerTick();
        }
      } else {
        _completeWorkSession();
      }
    });
  }

  void _startRestPhase() {
    _timer?.cancel();
    setState(() {
      _pomodoroPhase = PomodoroPhase.rest;
      _totalSeconds = _selectedMode.restSeconds;
      _remainingSeconds = _totalSeconds;
      _battleDialogText =
          '$_battleDialogText\n☕ 進入休息整備時間（${_selectedMode.restSeconds}秒），喝口水放鬆一下！';
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _completeRestSession();
      }
    });
  }

  void _completeRestSession() {
    _timer?.cancel();
    setState(() {
      _pomodoroPhase = PomodoroPhase.idle;
      _remainingSeconds = 0;
      _battleDialogText = '✨ 休息完畢！精力充沛，請選擇工序繼續討伐！';
    });
  }

  void _skipRest() {
    _timer?.cancel();
    setState(() {
      _pomodoroPhase = PomodoroPhase.idle;
      _remainingSeconds = 0;
      _battleDialogText = '已略過休息，隨時可再次開工討伐！';
    });
  }

  void _stopAndSettle() {
    if (_pomodoroPhase != PomodoroPhase.work) return;
    _timer?.cancel();

    int elapsedSeconds = _totalSeconds - _remainingSeconds;

    _calculateAndApplyDamage(
      isInterrupted: true,
      actualElapsedSeconds: elapsedSeconds,
    );

    setState(() {
      _pomodoroPhase = PomodoroPhase.idle;
      _remainingSeconds = 0;
    });
  }

  void _completeWorkSession() {
    _timer?.cancel();
    _calculateAndApplyDamage(
      isInterrupted: false,
      actualElapsedSeconds: _totalSeconds,
    );

    if (currentHp > 0) {
      _startRestPhase();
    } else {
      setState(() {
        _pomodoroPhase = PomodoroPhase.idle;
        _remainingSeconds = 0;
      });
    }
  }

  void _calculateAndApplyDamage({
    required bool isInterrupted,
    required int actualElapsedSeconds,
  }) {
    _totalSessionDurationSeconds += actualElapsedSeconds;

    final int finalDamage = _battleEngine.calculateDamage(
      basePoints: _selectedMode.basePoints,
      phase: _selectedPhase,
      elapsedSeconds: actualElapsedSeconds,
      totalSeconds: _totalSeconds,
      isInterrupted: isInterrupted,
      currentHp: currentHp,
      maxHp: maxHp,
    );

    final int earnedCoins = (actualElapsedSeconds / 5).round().clamp(2, 50);
    userCoins += earnedCoins;

    _triggerHitJuice(finalDamage, isInterrupted);

    final int newHp = (currentHp - finalDamage).clamp(0, maxHp);

    setState(() {
      currentHp = newHp;

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

    _recordSessionAndSave(
      isInterrupted: isInterrupted,
      actualElapsedSeconds: actualElapsedSeconds,
      damageDealt: finalDamage,
      newHp: newHp,
    );
  }

  Future<void> _recordSessionAndSave({
    required bool isInterrupted,
    required int actualElapsedSeconds,
    required int damageDealt,
    required int newHp,
  }) async {
    final int durationMinutes = actualElapsedSeconds <= 0
        ? 0
        : (actualElapsedSeconds < 60 ? 1 : actualElapsedSeconds ~/ 60);

    final log = CraftLog(
      id: const Uuid().v4(),
      kitId: _activeKit.id,
      phase: _selectedPhase,
      durationMinutes: durationMinutes,
      damageDealt: damageDealt,
      isCompletedSession: !isInterrupted,
      timestamp: DateTime.now(),
    );

    final bool isDefeated = newHp <= 0;
    final updatedKit = _activeKit.copyWith(
      currentHp: newHp,
      status: isDefeated ? KitStatus.completed : KitStatus.inProgress,
      completedAt: isDefeated ? DateTime.now() : _activeKit.completedAt,
    );

    _activeKit = updatedKit;

    try {
      await _craftLogRepo.addLog(log);
      await _kitRepo.saveKit(updatedKit);
    } catch (e) {
      debugPrint('Persistence warning (non-fatal): $e');
    }
  }

  void _triggerHitJuice(int damage, bool isInterrupted) {
    // 1. Feature 28: 2D Screen Shake
    final double intensity = DamageColorPalette.getShakeIntensity(
      _selectedPhase,
      isInterrupted: isInterrupted,
      damage: damage,
    );
    _screenShakeController.shake(intensity: intensity);

    // 2. Feature 30: Boss Hurt Flash
    _bossHurtFlashController.flash();

    // 3. Feature 29: Floating Damage Numbers
    _floatingDamageController.spawn(
      damage: damage,
      phase: _selectedPhase,
      isInterrupted: isInterrupted,
    );

    // 4. Feature 31: Zero-Cost Retro Audio Trigger
    if ((currentHp - damage) <= 0) {
      _audioService.playFinishingKill();
    } else if (damage >= 150 ||
        _selectedPhase == CraftPhases.airbrush ||
        _selectedPhase == CraftPhases.detailing) {
      _audioService.playCriticalStrike();
    } else {
      _audioService.playAttackHit();
    }

    // Baseline fallback state
    setState(() {
      _isHurt = true;
      _floatingDamageText = isInterrupted
          ? '-$damage (MERCY 50%)'
          : 'CRITICAL! -$damage';
      _floatingDamageColor = isInterrupted
          ? Colors.amber
          : const Color(0xFFFF5252);
    });

    _shakeController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _isHurt = false;
        });
      }
    });
  }

  void _showSnackAlert(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        backgroundColor: const Color(0xFFC62828),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showQuestClearDialog() {
    _audioService.playVictoryFanfare();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B26),
            border: Border.all(color: const Color(0xFFFFD54F), width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFFFFD54F),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '★ QUEST CLEAR ★',
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: Image.asset(
                  'assets/images/boss_green_box.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.military_tech,
                    size: 70,
                    color: Color(0xFFFFD54F),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '【$bossGrade $bossName】',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '山積淨化完畢！完成品誕生！',
                style: TextStyle(color: Color(0xFF8BE9FD), fontSize: 11),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '累計工時：',
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                        Text(
                          '${_totalSessionDurationSeconds ~/ 60}m ${_totalSessionDurationSeconds % 60}s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '獲得塑料金幣：',
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                        Text(
                          '+50 🪙',
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '解鎖工匠稱號：',
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                        Text(
                          '【銳利剪鉗手】',
                          style: TextStyle(
                            color: Color(0xFF50FA7B),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Action 1: 前往展示櫃觀看 (Feature 23)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('btn_clear_to_showcase'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB86C),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    side: const BorderSide(color: Colors.white, width: 1.5),
                  ),
                  icon: const Icon(Icons.military_tech, size: 14),
                  label: const Text(
                    '前往展示櫃觀看',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openShowcaseScreen();
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Action 2: 返回機庫挑選新目標 (Feature 23)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('btn_clear_to_hangar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF50FA7B),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    side: const BorderSide(color: Colors.white, width: 1.5),
                  ),
                  icon: const Icon(Icons.warehouse, size: 14),
                  label: const Text(
                    '返回機庫挑選新目標',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openHangarScreen();
                  },
                ),
              ),
              const SizedBox(height: 6),

              // Action 3: 收錄至展示櫃 (Showcase) [M2 Backward Compatibility & Fast Replay]
              TextButton(
                key: const Key('btn_clear_restart'),
                onPressed: () {
                  Navigator.of(context).pop();
                  final resetKit = _activeKit.reset();
                  _activeKit = resetKit;
                  _kitRepo.saveKit(resetKit).catchError((e) => debugPrint('$e'));

                  setState(() {
                    currentHp = maxHp;
                    _floatingDamageText = null;
                    _totalSessionDurationSeconds = 0;
                    _battleDialogText = '盒怪已收錄至像素展示櫃！已準備迎戰下一位山積怪。';
                  });
                },
                child: const Text(
                  '收錄至展示櫃 (Showcase)',
                  style: TextStyle(color: Colors.white60, fontSize: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    double hpPercentage = currentHp / maxHp;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF14151F),
                border: Border.all(color: const Color(0xFF383A59), width: 3),
              ),
              child: Column(
                children: [
                  // --- Header HUD ---
                  _buildHeaderHUD(),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          // --- Boss Status Card ---
                          _buildBossCard(hpPercentage),
                          const SizedBox(height: 12),

                          // --- Combat & Workbench Stage ---
                          _buildBattleStage(),
                          const SizedBox(height: 12),

                          // --- 8-Bit Combat Dialogue Box ---
                          _buildDialogueBox(),
                          const SizedBox(height: 14),

                          // --- Process Selection (SegmentedButton) ---
                          _buildSegmentedProcessSelector(hpPercentage),
                          const SizedBox(height: 16),

                          // --- Pomodoro Clock HUD ---
                          _buildTimerHUD(),
                          const SizedBox(height: 14),

                          // --- Controls ---
                          _buildControls(),
                        ],
                      ),
                    ),
                  ),

                  // --- Retro Bottom Arcade Dock ---
                  RetroBottomNavBar(
                    currentTab: RetroNavTab.battle,
                    onTabSelected: _onNavTabSelected,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderHUD() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      color: const Color(0xFF212234),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
          Row(
            children: [
              const Text(
                'TSUMI-PURA RPG',
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              // Hangar Quick Link
              InkWell(
                key: const Key('btn_hangar'),
                onTap: _openHangarScreen,
                child: _buildHeaderNavBadge(
                  icon: Icons.warehouse,
                  label: '機庫',
                  color: const Color(0xFF50FA7B),
                ),
              ),
              const SizedBox(width: 4),
              // Showcase Quick Link
              InkWell(
                key: const Key('btn_showcase'),
                onTap: _openShowcaseScreen,
                child: _buildHeaderNavBadge(
                  icon: Icons.military_tech,
                  label: '展櫃',
                  color: const Color(0xFFFFB86C),
                ),
              ),
              const SizedBox(width: 4),
              // CraftLog Quick Link
              InkWell(
                key: const Key('btn_craft_log'),
                onTap: _openCraftLogScreen,
                child: _buildHeaderNavBadge(
                  icon: Icons.menu_book,
                  label: '日誌',
                  color: const Color(0xFF8BE9FD),
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Mute Toggle Quick Action
              InkWell(
                key: const Key('btn_mute_toggle'),
                onTap: () {
                  setState(() {
                    _audioService.toggleMute();
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10121A),
                    border: Border.all(
                      color: _audioService.isMuted
                          ? Colors.white38
                          : const Color(0xFFBD93F9),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _audioService.isMuted
                            ? Icons.volume_off
                            : Icons.volume_up,
                        color: _audioService.isMuted
                            ? Colors.white38
                            : const Color(0xFFBD93F9),
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _audioService.isMuted ? 'MUTE' : 'SFX',
                        style: TextStyle(
                          color: _audioService.isMuted
                              ? Colors.white38
                              : const Color(0xFFBD93F9),
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.circle, color: Color(0xFFFFD54F), size: 10),
              const SizedBox(width: 4),
              Text(
                '$userCoins 塑料金幣',
                style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildHeaderNavBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF10121A),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 7,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Route<T> _createRetroRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  Future<void> _openHangarScreen() async {
    await Navigator.of(context).push(
      _createRetroRoute(
        HangarScreen(
          kitRepository: _kitRepo,
          craftLogRepository: _craftLogRepo,
        ),
      ),
    );
    await _hydrateActiveKit(notifyTargetChange: true);
  }

  Future<void> _openShowcaseScreen() async {
    await Navigator.of(context).push(
      _createRetroRoute(
        ShowcaseScreen(
          kitRepository: _kitRepo,
          craftLogRepository: _craftLogRepo,
        ),
      ),
    );
    await _hydrateActiveKit(notifyTargetChange: true);
  }

  Future<void> _openCraftLogScreen() async {
    await Navigator.of(context).push(
      _createRetroRoute(
        CraftLogScreen(
          craftLogRepository: _craftLogRepo,
          kitRepository: _kitRepo,
          activeKitId: _activeKit.id,
          activeKitTitle: _activeKit.title,
        ),
      ),
    );
    await _hydrateActiveKit(notifyTargetChange: true);
  }

  void _onNavTabSelected(RetroNavTab tab) {
    switch (tab) {
      case RetroNavTab.battle:
        break;
      case RetroNavTab.hangar:
        _openHangarScreen();
        break;
      case RetroNavTab.showcase:
        _openShowcaseScreen();
        break;
      case RetroNavTab.logs:
        _openCraftLogScreen();
        break;
    }
  }

  Widget _buildBossCard(double hpPercentage) {
    return PixelFrame(
      borderColor: const Color(0xFF44475A),
      backgroundColor: const Color(0xFF1D1E2C),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Lv.15 $bossName',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '規格: ${bossGrade.contains('1/144') ? bossGrade : '$bossGrade 1/144'}',
                style: const TextStyle(color: Color(0xFF8BE9FD), fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Pixel HP Bar
          PixelHpBar(
            currentHp: currentHp,
            maxHp: maxHp,
            height: 16,
            showLabel: true,
            showPercentage: true,
            showFraction: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBattleStage() {
    return ScreenShake(
      controller: _screenShakeController,
      child: AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          double shakeOffset =
              sin(_shakeController.value * pi * 8) *
              8 *
              (1 - _shakeController.value);
          return Transform.translate(
            offset: Offset(shakeOffset, 0),
            child: child,
          );
        },
        child: Container(
          height: 210,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0D0E15),
            border: Border.all(
              color: _isHurt ? const Color(0xFFFF5252) : const Color(0xFF44475A),
              width: 2,
            ),
          ),
          child: FloatingDamageOverlay(
            controller: _floatingDamageController,
            child: Stack(
              children: [
                // Background Isometric Scanline Grid
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.12,
                    child: GridPaper(
                      color: Colors.cyanAccent,
                      divisions: 2,
                      subdivisions: 1,
                    ),
                  ),
                ),

                // Boss Sprite (Top Right)
                Positioned(
                  top: 10,
                  right: 12,
                  child: BossHurtFlash(
                    controller: _bossHurtFlashController,
                    child: AnimatedBuilder(
                      animation: _idleController,
                      builder: (context, child) {
                        double scale = _isRunning
                            ? (1.0 + _idleController.value * 0.04)
                            : 1.0;
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: ColorFiltered(
                        colorFilter: _isHurt
                            ? const ColorFilter.mode(
                                Color(0x99FF0000),
                                BlendMode.srcATop,
                              )
                            : (currentHp <= 0
                                  ? const ColorFilter.mode(
                                      Colors.grey,
                                      BlendMode.saturation,
                                    )
                                  : const ColorFilter.mode(
                                      Colors.transparent,
                                      BlendMode.dst,
                                    )),
                        child: Image.asset(
                          'assets/images/boss_green_box.jpg',
                          height: 125,
                          width: 125,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.smart_toy,
                            size: 100,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Hero Sprite (Bottom Left)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: AnimatedBuilder(
                    animation: _idleController,
                    builder: (context, child) {
                      double offset = _isRunning
                          ? sin(_idleController.value * pi) * 6
                          : 0;
                      return Transform.translate(
                        offset: Offset(offset, -offset),
                        child: child,
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF8BE9FD),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8BE9FD).withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/hero.jpg',
                        height: 95,
                        width: 95,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.person,
                          size: 80,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                  ),
                ),

                // Floating Damage Numbers
                if (_floatingDamageText != null)
                  Positioned(
                    top: 30,
                    right: 70,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        border: Border.all(color: _floatingDamageColor, width: 2),
                      ),
                      child: Text(
                        _floatingDamageText!,
                        style: TextStyle(
                          color: _floatingDamageColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogueBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B26),
        border: Border.all(color: const Color(0xFFBD93F9), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '▶ ',
            style: TextStyle(color: Color(0xFFBD93F9), fontSize: 10),
          ),
          Expanded(
            child: Text(
              _battleDialogText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedProcessSelector(double hpPercentage) {
    bool isExecuteReady = _battleEngine.canExecuteFinishing(
      currentHp: currentHp,
      maxHp: maxHp,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '【工序技能切換 (Phase Skill)】',
          style: TextStyle(
            color: Color(0xFF8BE9FD),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              shape: WidgetStateProperty.all(
                const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              backgroundColor: WidgetStateProperty.resolveWith<Color?>((
                states,
              ) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF4CAF50);
                }
                return const Color(0xFF212234);
              }),
              foregroundColor: WidgetStateProperty.resolveWith<Color?>((
                states,
              ) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.black;
                }
                return Colors.white;
              }),
            ),
            segments: [
              const ButtonSegment(
                value: 'Snap-fit',
                label: Text(
                  '素組\n1.0x',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 8),
                ),
              ),
              const ButtonSegment(
                value: 'Sanding',
                label: Text(
                  '打磨\n1.2x',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 8),
                ),
              ),
              const ButtonSegment(
                value: 'Detailing',
                label: Text(
                  '刻線\n1.5x',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 8),
                ),
              ),
              const ButtonSegment(
                value: 'Airbrush',
                label: Text(
                  '噴塗\n2.0x',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 8),
                ),
              ),
              ButtonSegment(
                value: 'Finishing',
                enabled: isExecuteReady || _selectedPhase == 'Finishing',
                label: Text(
                  isExecuteReady ? '水貼\n2.5x' : '水貼\n🔒20%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 8),
                ),
              ),
            ],
            selected: {_selectedPhase},
            onSelectionChanged: _pomodoroPhase != PomodoroPhase.idle
                ? null
                : (Set<String> newSelection) {
                    _audioService.playButtonClick();
                    String chosen = newSelection.first;
                    if (chosen == 'Finishing' && !isExecuteReady) {
                      _showSnackAlert('⚠️ 水貼處決技限定 Boss 殘血 20% 以下！');
                      return;
                    }
                    setState(() {
                      _selectedPhase = chosen;
                      final skillName =
                          (chosen == CraftPhases.finishing || chosen == 'Finishing')
                              ? '${_phaseSkillNames[chosen]} (水貼・仕上げ)'
                              : _phaseSkillNames[chosen];
                      _battleDialogText =
                          '已切換武器：【$skillName】(${_phaseMultipliers[chosen]}x 倍率)。';
                    });
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildTimerHUD() {
    String statusLabel;
    Color clockColor;
    switch (_pomodoroPhase) {
      case PomodoroPhase.work:
        statusLabel = 'WORK - 專注組裝中 (${_selectedMode.label})';
        clockColor = const Color(0xFFFFD54F);
        break;
      case PomodoroPhase.rest:
        statusLabel = 'REST - 工坊整備休息中 ☕';
        clockColor = const Color(0xFF50FA7B);
        break;
      case PomodoroPhase.idle:
        statusLabel = 'POMODORO WORKBENCH CLOCK';
        clockColor = Colors.white70;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF10111A),
        border: Border.all(
          color: _pomodoroPhase == PomodoroPhase.rest
              ? const Color(0xFF50FA7B)
              : const Color(0xFF282A36),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Text(
            statusLabel,
            style: TextStyle(
              color: _pomodoroPhase == PomodoroPhase.rest
                  ? const Color(0xFF50FA7B)
                  : Colors.white38,
              fontSize: 8,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatTime(_remainingSeconds),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: clockColor,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<PomodoroMode>(
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            shape: WidgetStateProperty.all(
              const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFF6272A4);
              }
              return const Color(0xFF212234);
            }),
            foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              return Colors.white70;
            }),
          ),
          segments: const [
            ButtonSegment(
              value: PomodoroMode.standard,
              label: Text('標準 25m/5m', style: TextStyle(fontSize: 8)),
            ),
            ButtonSegment(
              value: PomodoroMode.deepFocus,
              label: Text('深度 50m/10m', style: TextStyle(fontSize: 8)),
            ),
            ButtonSegment(
              value: PomodoroMode.debug,
              label: Text('除錯 5s/3s', style: TextStyle(fontSize: 8)),
            ),
          ],
          selected: {_selectedMode},
          onSelectionChanged: _pomodoroPhase != PomodoroPhase.idle
              ? null
              : (newSelection) {
                  _audioService.playButtonClick();
                  setState(() {
                    _selectedMode = newSelection.first;
                  });
                },
        ),
      ),
    );
  }

  Widget _buildControls() {
    if (currentHp <= 0) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            side: const BorderSide(color: Colors.white, width: 2),
          ),
          onPressed: () {
            final resetKit = _activeKit.reset();
            _activeKit = resetKit;
            _kitRepo.saveKit(resetKit).catchError((e) => debugPrint('$e'));

            setState(() {
              currentHp = maxHp;
              _pomodoroPhase = PomodoroPhase.idle;
              _remainingSeconds = 0;
              _battleDialogText = 'Boss 已重置血量，隨時可再次開工討伐！';
            });
          },
          child: const Text(
            '重置 Boss 血量 (RESTART)',
            style: TextStyle(fontSize: 10),
          ),
        ),
      );
    }

    if (_pomodoroPhase == PomodoroPhase.rest) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00897B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            side: const BorderSide(color: Color(0xFF80CBC4), width: 2),
          ),
          icon: const Icon(Icons.fast_forward, size: 16),
          label: const Text(
            '略過休息 (提前開工)',
            style: TextStyle(fontSize: 10),
          ),
          onPressed: _skipRest,
        ),
      );
    }

    if (_pomodoroPhase == PomodoroPhase.work) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5252),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            side: const BorderSide(color: Colors.white, width: 2),
          ),
          icon: const Icon(Icons.stop, size: 16),
          label: const Text(
            '中途中斷 (結算 50% 保底傷害)',
            style: TextStyle(fontSize: 10),
          ),
          onPressed: _stopAndSettle,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildModeSelector(),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  side: const BorderSide(color: Colors.white, width: 2),
                ),
                icon: const Icon(Icons.play_arrow, size: 16),
                label: Text(
                  '開始開工 (${_selectedMode.label})',
                  style: const TextStyle(fontSize: 10),
                ),
                onPressed: () => _startTimer(_selectedMode),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: PixelButton(
                color: const Color(0xFF6272A4),
                borderColor: Colors.white38,
                padding: const EdgeInsets.symmetric(vertical: 14),
                onPressed: () => _startTimer(PomodoroMode.debug),
                child: const Text('5秒測試', style: TextStyle(fontSize: 9)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
