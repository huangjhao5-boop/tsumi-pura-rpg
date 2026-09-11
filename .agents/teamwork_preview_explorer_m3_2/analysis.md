# Analysis — Milestone 3: Showcase Gallery Screen & Metrics Breakdown

## 1. Executive Summary & Problem Boundary

In 《罪普拉 RPG（Tsumi-Pura RPG）》, the core fantasy revolves around transforming neglected model backlog ("山積 / Box Mimics") into completed masterworks ("完工完成品") through disciplined Pomodoro craft sessions. 

When a model kit Boss's HP reaches 0, it is vanquished and purified, transitioning from the backlog / hangar into the **Showcase Gallery Cabinet (完工像素展櫃)**.
This analysis defines the complete architectural design, data aggregation strategies, retro 8-bit UI specifications, and test harness for:
- **Feature 24: Showcase Gallery Screen (`lib/presentation/screens/showcase_screen.dart`)**
- **Feature 25: Showcase Details & Metrics (Trophy cards, completion timestamps, aggregated craft duration, session counts, and 5-phase breakdown modal)**

---

## 2. Evidence Chain & Codebase Investigation

### 2.1 Domain Entities

#### `KitItem` (`lib/domain/models/kit_item.dart`)
- **Completion criteria**:
  ```dart
  bool get isCompleted => KitStatus.normalize(status) == KitStatus.completed || currentHp <= 0;
  ```
- **Attributes**:
  - `id` (`String`): UUID.
  - `title` (`String`): Kit name.
  - `grade` (`String`): EG, HG, RG, MG, PG (default 'HG').
  - `totalHp` (`int`): Maximum HP.
  - `currentHp` (`int`): Current HP (0 when completed).
  - `status` (`String`): 'unstarted', 'in_progress', 'completed'.
  - `photoPath` (`String?`): Optional image path or camera upload.
  - `isCustomBoss` (`bool`): Whether custom Boss mimic.
  - `createdAt` (`DateTime`): Registration timestamp.
  - `completedAt` (`DateTime?`): Nullable timestamp recorded when vanquished.

#### `CraftLog` (`lib/domain/models/craft_log.dart`)
- **Session details**:
  - `id` (`String`): UUID.
  - `kitId` (`String`): Foreign key referencing `KitItem.id`.
  - `phase` (`String`): One of `CraftPhases.snapFit`, `sanding`, `detailing`, `airbrush`, `finishing`.
  - `durationMinutes` (`int`): Minutes spent in that craft session.
  - `damageDealt` (`int`): HP deducted from the boss.
  - `isCompletedSession` (`bool`): `true` if full session, `false` if mercy rule interrupted.
  - `timestamp` / `createdAt` (`DateTime`): Session completion time.

#### `GameConstants` (`lib/core/constants/game_constants.dart`)
- **5 Craft Phases**:
  - `CraftPhases.snapFit`: 'Snap-fit' (仮組み, 剪鉗連擊) — Multiplier 1.0x
  - `CraftPhases.sanding`: 'Sanding' (ヤスリ掛け, 破甲打磨) — Multiplier 1.2x
  - `CraftPhases.detailing`: 'Detailing' (スジ彫り, 弱點刻線) — Multiplier 1.5x
  - `CraftPhases.airbrush`: 'Airbrush' (エアブラシ, 噴筆重砲) — Multiplier 2.0x
  - `CraftPhases.finishing`: 'Finishing' (デカール・仕上げ, 處決水貼) — Multiplier 2.5x

---

## 3. Query & Metrics Aggregation Engine

### 3.1 Fetching Completed Kits
`IKitRepository.getAllKits()` retrieves the full collection of kits.
In `ShowcaseScreen`:
```dart
final allKits = await kitRepository.getAllKits();
final completedKits = allKits.where((k) => k.isCompleted).toList();
```
**Ordering**:
Showcase represents a physical trophy shelf. Newest completions should occupy the top-left spotlight position:
```dart
completedKits.sort((a, b) {
  final aTime = a.completedAt ?? a.createdAt;
  final bTime = b.completedAt ?? b.createdAt;
  return bTime.compareTo(aTime);
});
```

### 3.2 High-Performance Metrics Aggregation (Avoiding N+1 Queries)
Rather than executing `getLogsForKit(kit.id)` asynchronously per item in a loop or builder, `ShowcaseScreen` loads all logs once via `ICraftLogRepository.getAllLogs()`, and buckets them into an in-memory index:
```dart
final allLogs = await craftLogRepository.getAllLogs();
final Map<String, List<CraftLog>> logsByKit = {};
for (final log in allLogs) {
  logsByKit.putIfAbsent(log.kitId, () => []).add(log);
}
```

### 3.3 Aggregated Metrics Formulation
For each kit:
1. **Total Craft Time**:
   $$\text{totalMinutes} = \sum \text{log.durationMinutes}$$
   - Formatted string:
     - If $\text{totalMinutes} \ge 60$: `"${totalMinutes ~/ 60}h ${totalMinutes % 60}m"`
     - If $\text{totalMinutes} < 60$: `"${totalMinutes}m"`
2. **Session Count**:
   - Total sessions: `kitLogs.length`
   - Completed vs Interrupted:
     - `completedSessions = kitLogs.where((l) => l.isCompletedSession).length`
     - `interruptedSessions = kitLogs.where((l) => !l.isCompletedSession).length`
3. **Total Damage Dealt**:
   $$\text{totalDamage} = \sum \text{log.damageDealt}$$
4. **Completion Date Formatting**:
   $$\text{Date} = \text{YYYY-MM-DD}$$
   Example: `2026-09-11`. If `kit.completedAt` is null, defensive fallback to `kit.createdAt` formatted as `YYYY-MM-DD`.

### 3.4 5-Phase Craft Time & Damage Breakdown
For the detail dialog, calculate the exact breakdown across the 5 canonical phases:
```dart
Map<String, PhaseStats> calculatePhaseStats(List<CraftLog> logs, int totalMinutes, int totalDamage) {
  final result = <String, PhaseStats>{};
  for (final phase in CraftPhases.all) {
    final phaseLogs = logs.where((l) => l.phase == phase);
    final minutes = phaseLogs.fold<int>(0, (sum, l) => sum + l.durationMinutes);
    final damage = phaseLogs.fold<int>(0, (sum, l) => sum + l.damageDealt);
    final timePercent = totalMinutes > 0 ? (minutes / totalMinutes).clamp(0.0, 1.0) : 0.0;
    final damagePercent = totalDamage > 0 ? (damage / totalDamage).clamp(0.0, 1.0) : 0.0;
    result[phase] = PhaseStats(
      phase: phase,
      minutes: minutes,
      damage: damage,
      timePercent: timePercent,
      damagePercent: damagePercent,
    );
  }
  return result;
}
```

---

## 4. UI/UX & Retro 8-Bit Design System

### 4.1 Theme & Color Palette
- **Scaffold Background**: `const Color(0xFF10121A)` (workbench dark tone)
- **Container / Card Background**: `const Color(0xFF14151F)` and `const Color(0xFF1D1E2C)`
- **Cabinet / Card Border**: `const Color(0xFF383A59)` (2px) with gold highlight `const Color(0xFFFFD54F)`
- **Trophy / Gold Accent**: `const Color(0xFFFFD54F)` (champion gold)
- **Grade Badge Colors**:
  - `EG`: `Color(0xFF8BE9FD)` (cyan)
  - `HG`: `Color(0xFF50FA7B)` (neon green)
  - `RG`: `Color(0xFFFFB300)` (amber gold)
  - `MG`: `Color(0xFFFF5252)` (crimson red)
  - `PG`: `Color(0xFFBD93F9)` (royal purple)
- **Phase Bar Colors**:
  - `Snap-fit` (素組): `Color(0xFF4CAF50)`
  - `Sanding` (打磨): `Color(0xFFFFB300)`
  - `Detailing` (刻線): `Color(0xFF8BE9FD)`
  - `Airbrush` (噴塗): `Color(0xFFBD93F9)`
  - `Finishing` (水貼): `Color(0xFFFF5252)`
- **Typography**: 'Press Start 2P', fallback 'VT323', 'Courier New', 'monospace'
- **Pixel Aesthetic**: Zero border radius (`BorderRadius.zero`) throughout all cards, buttons, badges, and modals.

### 4.2 Empty State Specification
When `completedKits.isEmpty`:
- Key: `const Key('showcase_empty_state')`
- Mandatory text string:
  ```
  尚無完工模型，快去討伐堆積吧！
  ```
- Subtext:
  ```
  在工作桌啟動番茄鐘討伐盒怪，將血量歸零即可收錄至此展櫃。
  ```
- Visual icon: `Icons.inventory_2_outlined` or `Icons.emoji_events_outlined` in `Color(0xFFFFD54F)`.
- Action button: "返回工作桌討伐" (Pops or triggers callback).

### 4.3 Completed Kit Trophy Card Specification
- Key: `Key('showcase_card_${kit.id}')`
- Card layout:
  - **Header Row**:
    - Grade badge (`EG`, `HG`, etc.) with distinctive color border and background.
    - Title (`kit.title`), bold, truncated cleanly if long.
    - Trophy icon: `Icon(Icons.emoji_events, color: Color(0xFFFFD54F), size: 16)`
  - **Thumbnail Display**:
    - Image container framed with `Border.all(color: Colors.white24, width: 2)`.
    - Asset `assets/images/boss_green_box.jpg` or kit photo, with fallback `Icon(Icons.military_tech, color: Color(0xFFFFD54F), size: 48)`.
  - **Completion Timestamp**:
    - Row displaying: `🏆 完工: YYYY-MM-DD` (e.g. `2026-09-11`).
  - **Aggregated KPI Chips**:
    - `⏱ 累計工時: Xh Ym`
    - `⚔️ 討伐次數: N 次`
  - **Interaction**:
    - Entire card is an `InkWell` / `GestureDetector`.
    - Tapping opens the **Showcase Detail Dialog**.

### 4.4 Showcase Detail Dialog / BottomSheet Specification
- Key: `const Key('showcase_detail_dialog')`
- Components:
  1. **Modal Header**:
     - `★ 完工模型銘牌 (SHOWCASE DETAILS) ★` in `Color(0xFFFFD54F)`.
     - Close button: `Key('btn_showcase_close_detail')`.
  2. **Model Plaque & Badge (SPEC §5.1)**:
     - Title: `【${kit.grade} ${kit.title}】`
     - Grade & Specs: `${kit.grade} 1/144`
     - Completed Date: formatted date and time.
     - Craftsman Title: `【銳利剪鉗手 · 討伐完工】`
  3. **Aggregated Metrics Summary**:
     - Total Craft Duration: `Xh Ym`
     - Total Damage Dealt: `N pt`
     - Sessions Count: `N 次 (完工: A / 中斷: B)`
  4. **5-Phase Craft Time & Damage Breakdown**:
     - Each phase listed with:
       - Phase name & skill title (`Snap-fit (剪鉗連擊)`)
       - Duration & percentage (`Xm · N pt (XX%)`)
       - Distribution progress bar with phase color.
  5. **Action Buttons**:
     - "查看完整施工日誌" (View Full CraftLog): Key `Key('btn_showcase_view_logs_${kit.id}')`. Pushes `CraftLogScreen` filtered to `kit.id`.
     - "關閉銘牌" (Close): Dismisses dialog.

---

## 5. Architectural Blueprint: `showcase_screen.dart`

The implementation blueprint is completely self-contained, adheres to `package:flutter_lints`, and directly interfaces with `IKitRepository` and `ICraftLogRepository`.

```dart
// lib/presentation/screens/showcase_screen.dart
import 'package:flutter/material.dart';
import '../../core/constants/game_constants.dart';
import '../../data/repositories/craft_log_repository.dart';
import '../../data/repositories/kit_repository.dart';
import '../../domain/models/craft_log.dart';
import '../../domain/models/kit_item.dart';
import 'craft_log_screen.dart';

class ShowcaseScreen extends StatefulWidget {
  final IKitRepository kitRepository;
  final ICraftLogRepository craftLogRepository;

  const ShowcaseScreen({
    super.key,
    required this.kitRepository,
    required this.craftLogRepository,
  });

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  bool _isLoading = true;
  List<KitItem> _completedKits = [];
  Map<String, List<CraftLog>> _logsByKitId = {};

  @override
  void initState() {
    super.initState();
    _loadShowcaseData();
  }

  Future<void> _loadShowcaseData() async {
    setState(() => _isLoading = true);
    try {
      final allKits = await widget.kitRepository.getAllKits();
      final allLogs = await widget.craftLogRepository.getAllLogs();

      final completed = allKits.where((k) => k.isCompleted).toList();
      completed.sort((a, b) {
        final aTime = a.completedAt ?? a.createdAt;
        final bTime = b.completedAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });

      final Map<String, List<CraftLog>> grouped = {};
      for (final log in allLogs) {
        grouped.putIfAbsent(log.kitId, () => []).add(log);
      }

      if (mounted) {
        setState(() {
          _completedKits = completed;
          _logsByKitId = grouped;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _completedKits = [];
          _logsByKitId = {};
          _isLoading = false;
        });
      }
    }
  }

  // Formatting helpers
  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDuration(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  Color _getGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'EG': return const Color(0xFF8BE9FD);
      case 'HG': return const Color(0xFF50FA7B);
      case 'RG': return const Color(0xFFFFB300);
      case 'MG': return const Color(0xFFFF5252);
      case 'PG': return const Color(0xFFBD93F9);
      default: return const Color(0xFFFFD54F);
    }
  }

  Color _getPhaseColor(String phase) {
    switch (phase) {
      case CraftPhases.snapFit: return const Color(0xFF4CAF50);
      case CraftPhases.sanding: return const Color(0xFFFFB300);
      case CraftPhases.detailing: return const Color(0xFF8BE9FD);
      case CraftPhases.airbrush: return const Color(0xFFBD93F9);
      case CraftPhases.finishing: return const Color(0xFFFF5252);
      default: return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10121A),
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
                  _buildHeader(),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: Color(0xFFFFD54F)),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadShowcaseData,
                            color: const Color(0xFFFFD54F),
                            backgroundColor: const Color(0xFF1D1E2C),
                            child: _completedKits.isEmpty
                                ? _buildEmptyState()
                                : _buildShowcaseGrid(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF212234),
        border: Border(bottom: BorderSide(color: Color(0xFF383A59), width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('btn_showcase_back'),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF8BE9FD), size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 10),
              const Text(
                '★ SHOWCASE GALLERY ★',
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          Text(
            '完工: ${_completedKits.length} 盒',
            style: const TextStyle(color: Color(0xFF50FA7B), fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Container(
            key: const Key('showcase_empty_state'),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1E2C),
              border: Border.all(color: const Color(0xFF383A59), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFFFFD54F),
                  size: 54,
                ),
                const SizedBox(height: 16),
                const Text(
                  '尚無完工模型，快去討伐堆積吧！',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '前往工作桌啟動番茄鐘開工，將盒怪 HP 歸零即可收錄至此展櫃！',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 8,
                    height: 1.5,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  icon: const Icon(Icons.fitness_center, size: 12),
                  label: const Text('前往討伐', style: TextStyle(fontSize: 8)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShowcaseGrid() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: _completedKits.length,
      itemBuilder: (context, index) {
        final kit = _completedKits[index];
        final logs = _logsByKitId[kit.id] ?? [];
        return _buildKitCard(kit, logs);
      },
    );
  }

  Widget _buildKitCard(KitItem kit, List<CraftLog> logs) {
    final gradeColor = _getGradeColor(kit.grade);
    final totalMins = logs.fold<int>(0, (sum, l) => sum + l.durationMinutes);
    final formattedTime = _formatDuration(totalMins);
    final completionDate = _formatDate(kit.completedAt ?? kit.createdAt);

    return Container(
      key: Key('showcase_card_${kit.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E2C),
        border: Border.all(color: const Color(0xFF44475A), width: 2),
      ),
      child: InkWell(
        onTap: () => _showDetailModal(kit, logs),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Grade badge, Title, Trophy icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: gradeColor.withValues(alpha: 0.2),
                      border: Border.all(color: gradeColor),
                    ),
                    child: Text(
                      kit.grade,
                      style: TextStyle(
                        color: gradeColor,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kit.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.emoji_events,
                    color: Color(0xFFFFD54F),
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Image & Info row
              Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Image.asset(
                      'assets/images/boss_green_box.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.military_tech,
                        size: 36,
                        color: Color(0xFFFFD54F),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_available, color: Color(0xFFFFD54F), size: 10),
                            const SizedBox(width: 4),
                            Text(
                              '完工: $completionDate',
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.timer, color: Color(0xFF8BE9FD), size: 10),
                            const SizedBox(width: 4),
                            Text(
                              '累計工時: $formattedTime',
                              style: const TextStyle(color: Color(0xFF8BE9FD), fontSize: 8),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.sports_martial_arts, color: Color(0xFF50FA7B), size: 10),
                            const SizedBox(width: 4),
                            Text(
                              '討伐次數: ${logs.length} 次',
                              style: const TextStyle(color: Color(0xFF50FA7B), fontSize: 8),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFF10121A),
                  border: Border(top: BorderSide(color: Color(0xFF282A36))),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '▶ 點擊檢視工藝身分證與 5 大工序工時佔比',
                      style: TextStyle(color: Colors.white54, fontSize: 7),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailModal(KitItem kit, List<CraftLog> logs) {
    final gradeColor = _getGradeColor(kit.grade);
    final totalMins = logs.fold<int>(0, (sum, l) => sum + l.durationMinutes);
    final totalDamage = logs.fold<int>(0, (sum, l) => sum + l.damageDealt);
    final completedSessions = logs.where((l) => l.isCompletedSession).length;
    final interruptedSessions = logs.where((l) => !l.isCompletedSession).length;
    final completionDate = _formatDate(kit.completedAt ?? kit.createdAt);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        key: const Key('showcase_detail_dialog'),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B26),
            border: Border.all(color: const Color(0xFFFFD54F), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 16,
                spreadRadius: 4,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '★ 完工模型銘牌 ★',
                      style: TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    IconButton(
                      key: const Key('btn_showcase_close_detail'),
                      icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Plaque details
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10121A),
                    border: Border.all(color: gradeColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Image.asset(
                          'assets/images/boss_green_box.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.military_tech,
                            size: 32,
                            color: Color(0xFFFFD54F),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '【${kit.grade}】${kit.title}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '規格: ${kit.grade} 1/144 · 血量: ${kit.totalHp} HP',
                              style: const TextStyle(color: Color(0xFF8BE9FD), fontSize: 7),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '完工日期: $completionDate',
                              style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 7),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // KPI summary
                Row(
                  children: [
                    Expanded(
                      child: _buildPlaqueTile('累計工時', _formatDuration(totalMins), const Color(0xFF8BE9FD)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildPlaqueTile('總輸出傷害', '$totalDamage pt', const Color(0xFFFF5252)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildPlaqueTile('討伐次數', '$completedSessions/$interruptedSessions 次', const Color(0xFF50FA7B)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 5-Phase Breakdown
                const Text(
                  '【5 大工序工時佔比】',
                  style: TextStyle(
                    color: Color(0xFF8BE9FD),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                ...CraftPhases.all.map((phase) {
                  final phaseLogs = logs.where((l) => l.phase == phase);
                  final mins = phaseLogs.fold<int>(0, (s, l) => s + l.durationMinutes);
                  final dmg = phaseLogs.fold<int>(0, (s, l) => s + l.damageDealt);
                  final double pct = totalMins > 0 ? (mins / totalMins).clamp(0.0, 1.0) : 0.0;
                  final color = _getPhaseColor(phase);
                  final skillName = GameConstants.phaseSkillNames[phase] ?? phase;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$phase ($skillName)',
                              style: TextStyle(
                                color: color,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${mins}m · $dmg pt (${(pct * 100).toStringAsFixed(0)}%)',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 7,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: pct,
                            child: Container(color: color),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),

                // Footer action button
                ElevatedButton.icon(
                  key: Key('btn_showcase_view_logs_${kit.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF212234),
                    foregroundColor: const Color(0xFF8BE9FD),
                    side: const BorderSide(color: Color(0xFF8BE9FD), width: 1.5),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.menu_book, size: 12),
                  label: const Text('查看本模型專屬施工日誌', style: TextStyle(fontSize: 8)),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CraftLogScreen(
                          craftLogRepository: widget.craftLogRepository,
                          kitRepository: widget.kitRepository,
                          activeKitId: kit.id,
                          activeKitTitle: kit.title,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaqueTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF10121A),
        border: Border.all(color: const Color(0xFF282A36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 6)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 6. Verification & Test Harness Specification

To guarantee 100% test passing under `flutter test`, we design `test/widget/showcase_screen_test.dart` covering 7 distinct requirements:

### Test Cases Matrix
1. **Empty State Display**:
   - Given empty repository or zero completed kits.
   - Assert `find.byKey(const Key('showcase_empty_state'))` finds 1 widget.
   - Assert `find.text('尚無完工模型，快去討伐堆積吧！')` finds 1 widget.
2. **Filtering Integrity**:
   - Seed `unstarted` and `in_progress` kits.
   - Assert they are NOT rendered in Showcase.
3. **Showcase Trophy Card Rendering**:
   - Seed completed kit with `KitStatus.completed` and `completedAt = DateTime(2026, 9, 11)`.
   - Assert Title, Grade badge, Trophy icon (`Icons.emoji_events`), and completion date `2026-09-11` render properly.
4. **Aggregated Duration & Sessions Metrics**:
   - Seed 2 logs: 35 min + 25 min = 60 min (1h 0m).
   - Assert `1h 0m` and `2 次` are shown on the trophy card.
5. **Detail Modal & 5-Phase Breakdown**:
   - Tap `showcase_card_<id>`.
   - Assert `find.byKey(const Key('showcase_detail_dialog'))` appears.
   - Assert 5 phases (Snap-fit, Sanding, Detailing, Airbrush, Finishing) render with accurate percentages.
6. **Cross-Screen Navigation to CraftLog**:
   - Tap `btn_showcase_view_logs_<id>` in the modal.
   - Assert `CraftLogScreen` is pushed and filtered to the specific kit.
7. **Refresh Indicator**:
   - Trigger `onRefresh` via pull or method.
   - Assert data refreshes without errors.
