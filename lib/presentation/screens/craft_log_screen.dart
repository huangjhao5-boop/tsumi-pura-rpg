import 'package:flutter/material.dart';
import '../../core/constants/game_constants.dart';
import '../../data/repositories/craft_log_repository.dart';
import '../../data/repositories/kit_repository.dart';
import '../../domain/models/craft_log.dart';

/// 施工日誌與討伐統計回顧畫面 (Feature 17)
class CraftLogScreen extends StatefulWidget {
  final ICraftLogRepository craftLogRepository;
  final IKitRepository? kitRepository;
  final String? activeKitId;
  final String? activeKitTitle;

  const CraftLogScreen({
    super.key,
    required this.craftLogRepository,
    this.kitRepository,
    this.activeKitId,
    this.activeKitTitle,
  });

  @override
  State<CraftLogScreen> createState() => _CraftLogScreenState();
}

class _CraftLogScreenState extends State<CraftLogScreen> {
  bool _isLoading = true;
  List<CraftLog> _allLogs = [];
  bool _filterActiveKitOnly = true;

  @override
  void initState() {
    super.initState();
    _filterActiveKitOnly = widget.activeKitId != null;
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await widget.craftLogRepository.getAllLogs();
      if (mounted) {
        setState(() {
          _allLogs = List.from(logs)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allLogs = [];
          _isLoading = false;
        });
      }
    }
  }

  List<CraftLog> get _filteredLogs {
    if (_filterActiveKitOnly && widget.activeKitId != null) {
      return _allLogs.where((l) => l.kitId == widget.activeKitId).toList();
    }
    return _allLogs;
  }

  int get _totalMinutes =>
      _filteredLogs.fold(0, (sum, l) => sum + l.durationMinutes);

  int get _totalDamage =>
      _filteredLogs.fold(0, (sum, l) => sum + l.damageDealt);

  int get _completedSessions =>
      _filteredLogs.where((l) => l.isCompletedSession).length;

  int get _interruptedSessions =>
      _filteredLogs.where((l) => !l.isCompletedSession).length;

  Color _getPhaseColor(String phase) {
    switch (phase) {
      case CraftPhases.snapFit:
        return const Color(0xFF4CAF50);
      case CraftPhases.sanding:
        return const Color(0xFFFFB300);
      case CraftPhases.detailing:
        return const Color(0xFF8BE9FD);
      case CraftPhases.airbrush:
        return const Color(0xFFBD93F9);
      case CraftPhases.finishing:
        return const Color(0xFFFF5252);
      default:
        return Colors.white70;
    }
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final String filterTitle = (widget.activeKitTitle != null &&
            widget.activeKitTitle!.isNotEmpty)
        ? widget.activeKitTitle!
        : '當前盒怪';

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
                  // --- Header Bar ---
                  _buildHeader(),

                  if (_isLoading)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFFD54F),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadLogs,
                        color: const Color(0xFFFFD54F),
                        backgroundColor: const Color(0xFF1D1E2C),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Filter Selector (if kit is selected)
                              if (widget.activeKitId != null) ...[
                                _buildFilterSelector(filterTitle),
                                const SizedBox(height: 14),
                              ],

                              // Aggregate KPI Summary Cards
                              _buildKpiSummaryCards(),
                              const SizedBox(height: 16),

                              // Phase Damage & Time Breakdown
                              _buildPhaseBreakdown(),
                              const SizedBox(height: 16),

                              // Session History Log List
                              _buildLogHistorySection(),
                            ],
                          ),
                        ),
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
                key: const Key('btn_craft_log_back'),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF8BE9FD), size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 10),
              const Text(
                '★ CRAFT LOG ★',
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFFD54F), size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: '重新整理',
            onPressed: _loadLogs,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSelector(String activeTitle) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<bool>(
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
        segments: [
          ButtonSegment(
            value: true,
            label: Text(
              '當前: $activeTitle',
              style: const TextStyle(fontSize: 8),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const ButtonSegment(
            value: false,
            label: Text('全部歷史紀錄', style: TextStyle(fontSize: 8)),
          ),
        ],
        selected: {_filterActiveKitOnly},
        onSelectionChanged: (Set<bool> newSelection) {
          setState(() {
            _filterActiveKitOnly = newSelection.first;
          });
        },
      ),
    );
  }

  Widget _buildKpiSummaryCards() {
    final hours = _totalMinutes ~/ 60;
    final mins = _totalMinutes % 60;
    final String timeDisplay = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E2C),
        border: Border.all(color: const Color(0xFF44475A), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '【討伐與施工統計總覽】',
            style: TextStyle(
              color: Color(0xFF8BE9FD),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: '累計工時',
                  value: timeDisplay,
                  valueColor: const Color(0xFF8BE9FD),
                  icon: Icons.timer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: '總輸出傷害',
                  value: '$_totalDamage pt',
                  valueColor: const Color(0xFFFF5252),
                  icon: Icons.flash_on,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: '完整完工',
                  value: '$_completedSessions 次',
                  valueColor: const Color(0xFF50FA7B),
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: '中途保底',
                  value: '$_interruptedSessions 次',
                  valueColor: const Color(0xFFFFB300),
                  icon: Icons.shield_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color valueColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10111A),
        border: Border.all(color: const Color(0xFF282A36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 10, color: Colors.white54),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 8),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseBreakdown() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E2C),
        border: Border.all(color: const Color(0xFF44475A), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '【5 大工序傷害與工時分佈】',
            style: TextStyle(
              color: Color(0xFF8BE9FD),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...CraftPhases.all.map((phase) {
            final phaseLogs = _filteredLogs.where((l) => l.phase == phase);
            final dmg = phaseLogs.fold(0, (s, l) => s + l.damageDealt);
            final mins = phaseLogs.fold(0, (s, l) => s + l.durationMinutes);
            final double pct =
                _totalDamage > 0 ? (dmg / _totalDamage).clamp(0.0, 1.0) : 0.0;
            final color = _getPhaseColor(phase);
            final skillName = GameConstants.phaseSkillNames[phase] ?? phase;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
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
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${mins}m · $dmg pt (${(pct * 100).toStringAsFixed(0)}%)',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 8,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 8,
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
        ],
      ),
    );
  }

  Widget _buildLogHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '【詳細施工歷史清單】',
          style: TextStyle(
            color: Color(0xFF8BE9FD),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (_filteredLogs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B26),
              border: Border.all(color: const Color(0xFF383A59), width: 2),
            ),
            child: const Text(
              '▶ 尚未有施工紀錄。\n請坐回工作桌，啟動番茄鐘展開專注討伐！',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredLogs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final log = _filteredLogs[index];
              return _buildLogTile(log);
            },
          ),
      ],
    );
  }

  Widget _buildLogTile(CraftLog log) {
    final color = _getPhaseColor(log.phase);
    final skillName = GameConstants.phaseSkillNames[log.phase] ?? log.phase;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E2C),
        border: Border.all(color: const Color(0xFF383A59)),
      ),
      child: Row(
        children: [
          // Phase Badge
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              border: Border.all(color: color),
            ),
            child: Text(
              log.phase,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 7,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Detail info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      skillName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatDateTime(log.createdAt),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 8,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '⏱ ${log.durationMinutes}m',
                      style: const TextStyle(
                        color: Color(0xFF8BE9FD),
                        fontSize: 8,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '💥 -${log.damageDealt} HP',
                      style: const TextStyle(
                        color: Color(0xFFFF5252),
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: log.isCompletedSession
                            ? const Color(0x334CAF50)
                            : const Color(0x33FFB300),
                        border: Border.all(
                          color: log.isCompletedSession
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFFB300),
                        ),
                      ),
                      child: Text(
                        log.isCompletedSession ? '完工' : '中斷 50%',
                        style: TextStyle(
                          color: log.isCompletedSession
                              ? const Color(0xFF50FA7B)
                              : const Color(0xFFFFB300),
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
