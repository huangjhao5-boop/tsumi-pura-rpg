# Proposed Integration for `lib/main.dart`

This document details the exact changes required in `lib/main.dart` to integrate Milestone 2 persistence and CraftLog features while preserving 100% backward compatibility with existing tests.

---

### 1. New Imports at Top of `lib/main.dart`
```dart
import 'package:uuid/uuid.dart';
import 'data/repositories/craft_log_repository.dart';
import 'data/repositories/kit_repository.dart';
import 'domain/models/craft_log.dart';
import 'domain/models/kit_item.dart';
import 'presentation/screens/craft_log_screen.dart';
```

---

### 2. `TsumiPuraApp` Constructor Injection
```dart
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
        scaffoldBackgroundColor: const Color(0xFF10121A),
        fontFamily: 'Press Start 2P',
        fontFamilyFallback: const ['VT323', 'Courier New', 'monospace'],
        useMaterial3: true,
      ),
      home: BattleAtelierScreen(
        kitRepository: kitRepository,
        craftLogRepository: craftLogRepository,
      ),
    );
  }
}
```

---

### 3. `BattleAtelierScreen` Constructor Injection
```dart
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
```

---

### 4. `_BattleAtelierScreenState` State Variables & Zero-Flicker Hydration
```dart
class _BattleAtelierScreenState extends State<BattleAtelierScreen>
    with TickerProviderStateMixin {
  // --- Repositories ---
  late IKitRepository _kitRepo;
  late ICraftLogRepository _craftLogRepo;

  // --- Default Seed Kit (Guarantees Instant 1st-Frame Render) ---
  static final KitItem defaultKit = KitItem(
    id: 'default_hg_green_mimic',
    title: '綠色普通盒怪',
    grade: 'HG 1/144',
    totalHp: 500,
    currentHp: 500,
    status: 'InProgress',
    createdAt: DateTime(2026, 1, 1),
  );

  // --- Boss & Player State ---
  late KitItem _activeKit = defaultKit;
  String get bossName => _activeKit.title;
  String get bossGrade => _activeKit.grade;
  late int maxHp = defaultKit.totalHp;
  late int currentHp = defaultKit.currentHp;
  int userCoins = 150; // 廢流道塑料金幣

  @override
  void initState() {
    super.initState();
    _kitRepo = widget.kitRepository ?? KitRepository();
    _craftLogRepo = widget.craftLogRepository ?? CraftLogRepository();

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

  Future<void> _hydrateActiveKit() async {
    try {
      final storedKit = await _kitRepo.getActiveKit();
      if (storedKit != null && mounted) {
        setState(() {
          _activeKit = storedKit;
          currentHp = storedKit.currentHp;
          maxHp = storedKit.totalHp;
        });
      }
    } catch (e) {
      // Non-fatal fallback for unmocked unit tests
      debugPrint('Hydration fallback: $e');
    }
  }
```

---

### 5. Auto-Save Logic in `_calculateAndApplyDamage`
```dart
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
      createdAt: DateTime.now(),
    );

    final bool isDefeated = newHp <= 0;
    final updatedKit = _activeKit.copyWith(
      currentHp: newHp,
      status: isDefeated ? 'Completed' : 'InProgress',
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
```

---

### 6. Header HUD with CraftLog Button
```dart
  Widget _buildHeaderHUD() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      color: const Color(0xFF212234),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                'TSUMI-PURA RPG',
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                key: const Key('btn_craft_log'),
                onTap: _openCraftLogScreen,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10121A),
                    border: Border.all(color: const Color(0xFF8BE9FD), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book, color: Color(0xFF8BE9FD), size: 11),
                      SizedBox(width: 3),
                      Text(
                        '日誌',
                        style: TextStyle(
                          color: Color(0xFF8BE9FD),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.circle, color: Color(0xFFFFD54F), size: 10),
              const SizedBox(width: 4),
              Text(
                '$userCoins 塑料金幣',
                style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openCraftLogScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CraftLogScreen(
          craftLogRepository: _craftLogRepo,
          kitRepository: _kitRepo,
          activeKitId: _activeKit.id,
          activeKitTitle: _activeKit.title,
        ),
      ),
    );
  }
```

---

### 7. Boss HP Reset Persistence
```dart
  // In _buildControls (RESTART button) & _showQuestClearDialog:
  final resetKit = _activeKit.copyWith(
    currentHp: _activeKit.totalHp,
    status: 'InProgress',
  );
  _activeKit = resetKit;
  _kitRepo.saveKit(resetKit).catchError((e) => debugPrint('$e'));
```
