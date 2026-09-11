import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/game_constants.dart';
import '../../data/repositories/craft_log_repository.dart';
import '../../data/repositories/kit_repository.dart';
import '../../domain/models/kit_item.dart';

/// 模型機庫與山積清單管理畫面 (Features 18-21)
class HangarScreen extends StatefulWidget {
  final IKitRepository kitRepository;
  final ICraftLogRepository? craftLogRepository;
  final void Function(KitItem kit)? onKitSelected;

  const HangarScreen({
    super.key,
    required this.kitRepository,
    this.craftLogRepository,
    this.onKitSelected,
  });

  @override
  State<HangarScreen> createState() => _HangarScreenState();
}

class _HangarScreenState extends State<HangarScreen> {
  bool _isLoading = true;
  List<KitItem> _kits = [];
  String? _activeKitId;
  String _selectedFilter = 'all'; // 'all', 'unstarted', 'in_progress', 'completed'

  @override
  void initState() {
    super.initState();
    _loadKits();
  }

  Future<void> _loadKits() async {
    setState(() => _isLoading = true);
    try {
      final kits = await widget.kitRepository.getAllKits();
      final activeKit = await widget.kitRepository.getActiveKit();
      if (mounted) {
        setState(() {
          _kits = kits;
          _activeKitId = activeKit?.id;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _kits = [];
          _isLoading = false;
        });
      }
    }
  }

  List<KitItem> get _filteredKits {
    switch (_selectedFilter) {
      case 'unstarted':
        return _kits.where((k) => k.isUnstarted).toList();
      case 'in_progress':
        return _kits.where((k) => k.isInProgress).toList();
      case 'completed':
        return _kits.where((k) => k.isCompleted).toList();
      default:
        return _kits;
    }
  }

  Future<void> _setActiveKit(KitItem kit) async {
    try {
      await widget.kitRepository.setActiveKit(kit.id);
      if (mounted) {
        setState(() {
          _activeKitId = kit.id;
        });
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '已將【${kit.title}】設為當前討伐目標！',
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      widget.onKitSelected?.call(kit);
    } catch (e) {
      debugPrint('Error setting active kit: $e');
    }
  }

  void _openAddKitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => KitFormDialog(
        kitRepository: widget.kitRepository,
        onSaved: () => _loadKits(),
      ),
    );
  }

  void _openEditKitDialog(KitItem kit) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => KitFormDialog(
        kitRepository: widget.kitRepository,
        editingKit: kit,
        onSaved: () => _loadKits(),
      ),
    );
  }

  void _confirmDeleteKit(KitItem kit) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DeleteConfirmDialog(
        kit: kit,
        isActive: kit.id == _activeKitId,
        onConfirmDelete: () async {
          await widget.kitRepository.deleteKit(kit.id);
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('【${kit.title}】已自機庫除籍。', style: const TextStyle(fontFamily: 'monospace')),
                backgroundColor: const Color(0xFFC62828),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          await _loadKits();
        },
      ),
    );
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
                  _buildFilterBar(),
                  if (_isLoading)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFFFFD54F)),
                      ),
                    )
                  else
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadKits,
                        color: const Color(0xFFFFD54F),
                        backgroundColor: const Color(0xFF1D1E2C),
                        child: _filteredKits.isEmpty
                            ? _buildEmptyState()
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _filteredKits.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (ctx, index) {
                                  final kit = _filteredKits[index];
                                  return KitCard(
                                    key: Key('kit_card_${kit.id}'),
                                    kit: kit,
                                    isActive: kit.id == _activeKitId,
                                    onSetActive: () => _setActiveKit(kit),
                                    onEdit: () => _openEditKitDialog(kit),
                                    onDelete: () => _confirmDeleteKit(kit),
                                  );
                                },
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                key: const Key('btn_hangar_back'),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF8BE9FD), size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              const SizedBox(width: 8),
              const Text(
                '★ MODEL HANGAR ★',
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              ElevatedButton.icon(
                key: const Key('btn_add_kit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  side: const BorderSide(color: Colors.white70, width: 1.5),
                ),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('+ 新增', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                onPressed: _openAddKitDialog,
              ),
              const SizedBox(width: 6),
              IconButton(
                key: const Key('btn_refresh_hangar'),
                icon: const Icon(Icons.refresh, color: Color(0xFFFFD54F), size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: '重新整理',
                onPressed: _loadKits,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final unstartedCount = _kits.where((k) => k.isUnstarted).length;
    final inProgressCount = _kits.where((k) => k.isInProgress).length;
    final completedCount = _kits.where((k) => k.isCompleted).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: const Color(0xFF191A28),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('all', '全部 (${_kits.length})', const Key('filter_all')),
            const SizedBox(width: 6),
            _buildFilterChip('unstarted', '山積 ($unstartedCount)', const Key('filter_unstarted')),
            const SizedBox(width: 6),
            _buildFilterChip('in_progress', '施工中 ($inProgressCount)', const Key('filter_in_progress')),
            const SizedBox(width: 6),
            _buildFilterChip('completed', '完工 ($completedCount)', const Key('filter_completed')),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, Key key) {
    final isSelected = _selectedFilter == filterKey;
    return InkWell(
      key: key,
      onTap: () => setState(() => _selectedFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6272A4) : const Color(0xFF212234),
          border: Border.all(
            color: isSelected ? const Color(0xFF8BE9FD) : const Color(0xFF44475A),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 8,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B26),
          border: Border.all(color: const Color(0xFF383A59), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox, color: Colors.white38, size: 40),
            const SizedBox(height: 12),
            const Text(
              '▶ 機庫空空如也',
              style: TextStyle(color: Color(0xFFFFD54F), fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '尚未有符合條件的模型盒怪。\n點擊上方【+ 新增】登錄你的第一隻山積怪！',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 9, height: 1.5),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              key: const Key('btn_add_kit_empty'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('立刻登錄模型', style: TextStyle(fontSize: 9)),
              onPressed: _openAddKitDialog,
            ),
          ],
        ),
      ),
    );
  }
}

class KitCard extends StatelessWidget {
  final KitItem kit;
  final bool isActive;
  final VoidCallback onSetActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const KitCard({
    super.key,
    required this.kit,
    required this.isActive,
    required this.onSetActive,
    required this.onEdit,
    required this.onDelete,
  });

  Color _getGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'EG':
        return const Color(0xFF50FA7B);
      case 'HG':
        return const Color(0xFF8BE9FD);
      case 'RG':
        return const Color(0xFFBD93F9);
      case 'MG':
        return const Color(0xFFFFB86C);
      case 'PG':
        return const Color(0xFFFF79C6);
      default:
        return const Color(0xFF8BE9FD);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradeColor = _getGradeColor(kit.grade);
    final hpPercentage = kit.hpPercentage;

    Color hpColor = hpPercentage > 0.5
        ? const Color(0xFF4CAF50)
        : (hpPercentage > 0.2 ? const Color(0xFFFFB300) : const Color(0xFFFF5252));

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E2C),
        border: Border.all(
          color: isActive ? const Color(0xFFFFD54F) : const Color(0xFF44475A),
          width: isActive ? 2.5 : 1.5,
        ),
        boxShadow: isActive
            ? [
                const BoxShadow(
                  color: Color(0x55FFD54F),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Badges & Title
          Row(
            children: [
              // Grade badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: gradeColor.withValues(alpha: 0.2),
                  border: Border.all(color: gradeColor, width: 1),
                ),
                child: Text(
                  kit.grade,
                  style: TextStyle(color: gradeColor, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              // Custom Boss badge
              if (kit.isCustomBoss) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5555).withValues(alpha: 0.2),
                    border: Border.all(color: const Color(0xFFFF5555), width: 1),
                  ),
                  child: const Text(
                    '自訂',
                    style: TextStyle(color: Color(0xFFFF5555), fontSize: 7, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              // Title
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
              const SizedBox(width: 6),
              // Status Badge
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 8),

          // Active Banner (if active)
          if (isActive) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
              margin: const EdgeInsets.only(bottom: 6),
              color: const Color(0x33FFD54F),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Color(0xFFFFD54F), size: 10),
                  SizedBox(width: 4),
                  Text(
                    '★ 當前出擊目標 (ACTIVE BOSS)',
                    style: TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // HP Bar
          Row(
            children: [
              const Text('HP ', style: TextStyle(color: Color(0xFFFF5252), fontSize: 8, fontWeight: FontWeight.bold)),
              Expanded(
                child: Container(
                  height: 12,
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.white54, width: 1),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: hpPercentage.clamp(0.0, 1.0),
                    child: Container(color: hpColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${kit.currentHp}/${kit.totalHp} (${(hpPercentage * 100).toStringAsFixed(0)}%)',
                style: TextStyle(color: hpColor, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row: Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isActive)
                Container(
                  key: Key('btn_set_active_${kit.id}'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x334CAF50),
                    border: Border.all(color: const Color(0xFF4CAF50)),
                  ),
                  child: const Text('討伐中', style: TextStyle(color: Color(0xFF50FA7B), fontSize: 8)),
                )
              else
                ElevatedButton(
                  key: Key('btn_set_active_${kit.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6272A4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  onPressed: onSetActive,
                  child: const Text('設為目標', style: TextStyle(fontSize: 8)),
                ),
              const SizedBox(width: 6),
              OutlinedButton(
                key: Key('btn_edit_kit_${kit.id}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8BE9FD),
                  side: const BorderSide(color: Color(0xFF8BE9FD)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                onPressed: onEdit,
                child: const Text('編輯', style: TextStyle(fontSize: 8)),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                key: Key('btn_delete_kit_${kit.id}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF5252),
                  side: const BorderSide(color: Color(0xFFFF5252)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                onPressed: onDelete,
                child: const Text('刪除', style: TextStyle(fontSize: 8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    String label = '山積';
    Color color = const Color(0xFF6272A4);

    if (kit.isCompleted) {
      label = '完工';
      color = const Color(0xFF50FA7B);
    } else if (kit.isInProgress) {
      label = '施工中';
      color = const Color(0xFFFFB300);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class KitFormDialog extends StatefulWidget {
  final IKitRepository kitRepository;
  final KitItem? editingKit;
  final VoidCallback onSaved;

  const KitFormDialog({
    super.key,
    required this.kitRepository,
    this.editingKit,
    required this.onSaved,
  });

  bool get isEditing => editingKit != null;

  @override
  State<KitFormDialog> createState() => _KitFormDialogState();
}

class _KitFormDialogState extends State<KitFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _hpController;

  String _selectedGrade = 'HG';
  bool _isCustomHp = false;
  bool _setAsActive = true;
  bool _resetHpToFull = false;

  final List<String> _grades = ['EG', 'HG', 'RG', 'MG', 'PG'];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final kit = widget.editingKit!;
      _titleController = TextEditingController(text: kit.title);
      _selectedGrade = _grades.contains(kit.grade.toUpperCase()) ? kit.grade.toUpperCase() : 'HG';
      final defaultHp = GameConstants.gradeHpDefaults[_selectedGrade] ?? 500;
      _isCustomHp = kit.isCustomBoss || kit.totalHp != defaultHp;
      _hpController = TextEditingController(text: kit.totalHp.toString());
      _setAsActive = false;
    } else {
      _titleController = TextEditingController();
      _selectedGrade = 'HG';
      _isCustomHp = false;
      _hpController = TextEditingController(
        text: (GameConstants.gradeHpDefaults['HG'] ?? 500).toString(),
      );
      _setAsActive = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _hpController.dispose();
    super.dispose();
  }

  void _onGradeSelected(String newGrade) {
    setState(() {
      _selectedGrade = newGrade;
      if (!_isCustomHp) {
        final defaultHp = GameConstants.gradeHpDefaults[newGrade] ?? 500;
        _hpController.text = defaultHp.toString();
      }
    });
  }

  void _onCustomHpToggled(bool? value) {
    setState(() {
      _isCustomHp = value ?? false;
      if (!_isCustomHp) {
        final defaultHp = GameConstants.gradeHpDefaults[_selectedGrade] ?? 500;
        _hpController.text = defaultHp.toString();
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final parsedHp = int.parse(_hpController.text.trim());
    final title = _titleController.text.trim();
    final defaultHp = GameConstants.gradeHpDefaults[_selectedGrade] ?? 500;
    final isCustom = _isCustomHp || parsedHp != defaultHp;

    try {
      if (widget.isEditing) {
        final oldKit = widget.editingKit!;
        final newCurrentHp = _resetHpToFull
            ? parsedHp
            : (oldKit.currentHp > parsedHp ? parsedHp : oldKit.currentHp);

        final updatedKit = oldKit.copyWith(
          title: title,
          grade: _selectedGrade,
          totalHp: parsedHp,
          currentHp: newCurrentHp,
          isCustomBoss: isCustom,
        );
        await widget.kitRepository.saveKit(updatedKit);
      } else {
        final newKit = KitItem.create(
          title: title,
          grade: _selectedGrade,
          totalHp: parsedHp,
          currentHp: parsedHp,
          isCustomBoss: isCustom,
        );
        await widget.kitRepository.saveKit(newKit);
        if (_setAsActive) {
          await widget.kitRepository.setActiveKit(newKit.id);
        }
      }

      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B26),
          border: Border.all(color: const Color(0xFFFFD54F), width: 3),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.isEditing ? '★ 編輯模型資料 ★' : '★ 登錄山積盒怪 ★',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 14),

                // Title Input
                const Text('模型名稱 (Title)', style: TextStyle(color: Colors.white70, fontSize: 8)),
                const SizedBox(height: 4),
                TextFormField(
                  key: const Key('input_kit_title'),
                  controller: _titleController,
                  maxLength: 50,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Color(0xFF10121A),
                    hintText: '例：RG 1/144 沙薩比',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                    counterStyle: TextStyle(color: Colors.white38, fontSize: 7),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return '請輸入模型名稱';
                    if (val.trim().length > 50) return '名稱不可超過 50 字元';
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // Grade Selector
                const Text('模型級別 (Grade Preset)', style: TextStyle(color: Colors.white70, fontSize: 8)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: _grades.map((g) {
                    final isSel = _selectedGrade == g;
                    final hp = GameConstants.gradeHpDefaults[g] ?? 500;
                    return ChoiceChip(
                      key: Key('chip_grade_$g'),
                      label: Text('$g ($hp)', style: TextStyle(fontSize: 8, color: isSel ? Colors.black : Colors.white)),
                      selected: isSel,
                      selectedColor: const Color(0xFFFFD54F),
                      backgroundColor: const Color(0xFF212234),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      onSelected: (selected) {
                        if (selected) _onGradeSelected(g);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),

                // Custom HP Toggle
                Row(
                  children: [
                    Checkbox(
                      key: const Key('checkbox_custom_hp'),
                      value: _isCustomHp,
                      activeColor: const Color(0xFFFFD54F),
                      checkColor: Colors.black,
                      onChanged: _onCustomHpToggled,
                    ),
                    const Text('自訂 HP 數值 (Custom HP Override)', style: TextStyle(color: Colors.white, fontSize: 8)),
                  ],
                ),
                const SizedBox(height: 4),

                // HP Input Field
                TextFormField(
                  key: const Key('input_kit_hp'),
                  controller: _hpController,
                  enabled: _isCustomHp,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    color: _isCustomHp ? Colors.white : Colors.white54,
                    fontSize: 10,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _isCustomHp ? const Color(0xFF10121A) : const Color(0xFF181924),
                    labelText: _isCustomHp ? '自訂 HP (> 0)' : '預設 HP (依級別自動填寫)',
                    labelStyle: const TextStyle(color: Colors.white70, fontSize: 8),
                    border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return '請輸入 HP';
                    final parsed = int.tryParse(val.trim());
                    if (parsed == null || parsed <= 0) return 'HP 必須為大於 0 之整數';
                    if (parsed > 99999) return 'HP 不可超過 99,999';
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // Options (Edit or Create)
                if (!widget.isEditing) ...[
                  Row(
                    children: [
                      Checkbox(
                        key: const Key('checkbox_set_active'),
                        value: _setAsActive,
                        activeColor: const Color(0xFF4CAF50),
                        checkColor: Colors.white,
                        onChanged: (v) => setState(() => _setAsActive = v ?? true),
                      ),
                      const Text('登錄後立刻設為當前討伐目標', style: TextStyle(color: Colors.white, fontSize: 8)),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Checkbox(
                        key: const Key('checkbox_reset_hp'),
                        value: _resetHpToFull,
                        activeColor: const Color(0xFFFFB300),
                        checkColor: Colors.black,
                        onChanged: (v) => setState(() => _resetHpToFull = v ?? false),
                      ),
                      const Text('重設當前血量為滿血', style: TextStyle(color: Colors.white, fontSize: 8)),
                    ],
                  ),
                ],
                const SizedBox(height: 14),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      key: const Key('btn_dialog_cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white38),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消', style: TextStyle(fontSize: 8)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      key: const Key('btn_dialog_save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      ),
                      onPressed: _submit,
                      child: Text(widget.isEditing ? '儲存變更' : '登錄怪獸', style: const TextStyle(fontSize: 8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DeleteConfirmDialog extends StatelessWidget {
  final KitItem kit;
  final bool isActive;
  final VoidCallback onConfirmDelete;

  const DeleteConfirmDialog({
    super.key,
    required this.kit,
    required this.isActive,
    required this.onConfirmDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B26),
          border: Border.all(color: const Color(0xFFFF5252), width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '⚠️ 解體除籍確認 ⚠️',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFFF5252),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '確定要將【${kit.title}】從機庫中解體除籍嗎？',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              color: const Color(0x33FF5252),
              child: const Text(
                '※ 此操作將一併永久清除該模型的全部施工紀錄 (Craft Logs)，且無法復原！',
                style: TextStyle(color: Color(0xFFFF8A80), fontSize: 8, height: 1.4),
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 6),
              const Text(
                '※ 此模型為當前出擊目標，刪除後將自動切換為下一盒模型。',
                style: TextStyle(color: Color(0xFFFFD54F), fontSize: 8),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  key: const Key('btn_cancel_delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white38),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('保留', style: TextStyle(fontSize: 8)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  key: const Key('btn_confirm_delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onConfirmDelete();
                  },
                  child: const Text('確認除籍', style: TextStyle(fontSize: 8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
