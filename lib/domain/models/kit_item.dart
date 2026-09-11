import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../core/constants/game_constants.dart';

/// Kit status constants and normalizer.
class KitStatus {
  static const String unstarted = 'unstarted';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';

  // Backwards & SPEC aliases
  static const String backlog = 'backlog';

  static const List<String> values = [
    unstarted,
    inProgress,
    completed,
  ];

  /// Attempts to normalize [status] to a canonical value.
  /// Returns null if [status] is null, empty, or not a recognized status or alias.
  static String? tryNormalize(String? status) {
    if (status == null) return null;
    final lower = status.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (lower.isEmpty) return null;
    if (lower == completed) return completed;
    if (lower == inProgress || lower == 'inprogress') return inProgress;
    if (lower == backlog || lower == unstarted) return unstarted;
    return null;
  }

  /// Normalizes [status] to canonical representation ('unstarted', 'in_progress', 'completed').
  /// Returns [fallback] (default 'unstarted') if unrecognized or null.
  /// Used for defensive deserialization in [KitItem.fromMap].
  static String normalize(String? status, {String fallback = unstarted}) {
    return tryNormalize(status) ?? fallback;
  }

  /// Validates whether [status] is a recognized status string or alias.
  /// Strictly rejects null, empty strings, and arbitrary invalid strings.
  static bool isValid(String? status) {
    return tryNormalize(status) != null;
  }
}

/// Pure Dart entity representing a Model Kit Boss Mimic.
class KitItem {
  final String id;
  final String title;
  final String grade;
  final int totalHp;
  final int currentHp;
  final String status;
  final String? photoPath;
  final bool isCustomBoss;
  final DateTime createdAt;
  final DateTime? completedAt;

  const KitItem({
    required this.id,
    required this.title,
    this.grade = 'HG',
    required this.totalHp,
    required this.currentHp,
    this.status = KitStatus.unstarted,
    this.photoPath,
    this.isCustomBoss = false,
    required this.createdAt,
    this.completedAt,
  });

  /// Factory constructor for creating new kits with automated UUID and defaults.
  factory KitItem.create({
    String? id,
    required String title,
    String grade = 'HG',
    int? totalHp,
    int? currentHp,
    String status = KitStatus.unstarted,
    String? photoPath,
    bool isCustomBoss = false,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    final defaultHp = GameConstants.gradeHpDefaults[grade] ?? 500;
    final resolvedTotalHp = totalHp ?? defaultHp;
    final resolvedCurrentHp = currentHp ?? resolvedTotalHp;
    return KitItem(
      id: id ?? const Uuid().v4(),
      title: title.trim(),
      grade: grade,
      totalHp: resolvedTotalHp,
      currentHp: resolvedCurrentHp.clamp(0, resolvedTotalHp),
      status: KitStatus.normalize(status),
      photoPath: photoPath,
      isCustomBoss: isCustomBoss,
      createdAt: createdAt ?? DateTime.now(),
      completedAt: completedAt,
    );
  }

  /// Initial default seed kit for app startup.
  static KitItem initialSeedKit() {
    return KitItem(
      id: GameConstants.defaultKitId,
      title: GameConstants.defaultKitTitle,
      grade: GameConstants.defaultKitGrade,
      totalHp: GameConstants.defaultKitHp,
      currentHp: GameConstants.defaultKitHp,
      status: KitStatus.inProgress,
      photoPath: null,
      isCustomBoss: false,
      createdAt: DateTime(2026, 1, 1),
      completedAt: null,
    );
  }

  // --- Getters & Status Helpers ---
  bool get isUnstarted => KitStatus.normalize(status) == KitStatus.unstarted;
  bool get isBacklog => isUnstarted;
  bool get isInProgress => KitStatus.normalize(status) == KitStatus.inProgress;
  bool get isCompleted =>
      KitStatus.normalize(status) == KitStatus.completed || currentHp <= 0;
  bool get isDefeated => currentHp <= 0;

  double get hpPercentage =>
      totalHp > 0 ? (currentHp / totalHp).clamp(0.0, 1.0) : 0.0;

  int get damageTaken => totalHp - currentHp;

  bool get canExecuteFinishing =>
      hpPercentage <= (GameConstants.finishingExecutionThreshold + 1e-9);

  // --- Immutable State Transitions ---
  KitItem applyDamage(int damage, {DateTime? completedTime}) {
    final newHp = (currentHp - damage).clamp(0, totalHp);
    if (newHp <= 0) {
      return copyWith(
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: completedTime ?? DateTime.now(),
      );
    }
    return copyWith(
      currentHp: newHp,
      status: KitStatus.inProgress,
    );
  }

  KitItem reset() {
    return copyWith(
      currentHp: totalHp,
      status: KitStatus.unstarted,
      clearCompletedAt: true,
    );
  }

  // --- copyWith ---
  KitItem copyWith({
    String? id,
    String? title,
    String? grade,
    int? totalHp,
    int? currentHp,
    String? status,
    String? photoPath,
    bool clearPhotoPath = false,
    bool? isCustomBoss,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return KitItem(
      id: id ?? this.id,
      title: title ?? this.title,
      grade: grade ?? this.grade,
      totalHp: totalHp ?? this.totalHp,
      currentHp: currentHp ?? this.currentHp,
      status: status != null ? KitStatus.normalize(status) : this.status,
      photoPath: clearPhotoPath ? null : (photoPath ?? this.photoPath),
      isCustomBoss: isCustomBoss ?? this.isCustomBoss,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  // --- Serialization ---
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'grade': grade,
      'totalHp': totalHp,
      'currentHp': currentHp,
      'status': status,
      'photoPath': photoPath,
      'isCustomBoss': isCustomBoss ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory KitItem.fromMap(Map<String, dynamic> map) {
    int parseInt(dynamic val, int defaultVal) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? defaultVal;
      return defaultVal;
    }

    final parsedTotal = parseInt(map['totalHp'], 500);
    final parsedCurrent = parseInt(map['currentHp'], parsedTotal);

    DateTime parseDate(dynamic val, DateTime defaultVal) {
      if (val is DateTime) return val;
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return defaultVal;
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String && val.isNotEmpty) return DateTime.tryParse(val);
      return null;
    }

    final dynamic rawCustom = map['isCustomBoss'];
    final bool custom = rawCustom == true || rawCustom == 1 || rawCustom == '1';

    return KitItem(
      id: map['id']?.toString() ?? const Uuid().v4(),
      title: map['title']?.toString() ?? 'Untitled Boss',
      grade: map['grade']?.toString() ?? 'HG',
      totalHp: parsedTotal > 0 ? parsedTotal : 500,
      currentHp: parsedCurrent.clamp(0, parsedTotal > 0 ? parsedTotal : 500),
      status: KitStatus.normalize(map['status']?.toString()),
      photoPath: map['photoPath'] as String?,
      isCustomBoss: custom,
      createdAt: parseDate(map['createdAt'], DateTime.now()),
      completedAt: parseNullableDate(map['completedAt']),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory KitItem.fromJson(String source) =>
      KitItem.fromMap(jsonDecode(source) as Map<String, dynamic>);

  // --- Validation ---
  List<String> validate() {
    final errors = <String>[];
    if (id.trim().isEmpty) errors.add('ID cannot be empty');
    if (title.trim().isEmpty) errors.add('Title cannot be empty');
    if (title.trim().length > 50) errors.add('Title exceeds 50 characters');
    if (totalHp <= 0) errors.add('Total HP must be positive');
    if (currentHp < 0) errors.add('Current HP cannot be negative');
    if (currentHp > totalHp) errors.add('Current HP cannot exceed Total HP');
    if (!KitStatus.isValid(status)) errors.add('Invalid status: $status');
    return errors;
  }

  bool get isValid => validate().isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KitItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          grade == other.grade &&
          totalHp == other.totalHp &&
          currentHp == other.currentHp &&
          status == other.status &&
          photoPath == other.photoPath &&
          isCustomBoss == other.isCustomBoss &&
          createdAt == other.createdAt &&
          completedAt == other.completedAt;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        grade,
        totalHp,
        currentHp,
        status,
        photoPath,
        isCustomBoss,
        createdAt,
        completedAt,
      );

  @override
  String toString() =>
      'KitItem(id: $id, title: "$title", grade: $grade, hp: $currentHp/$totalHp, status: $status, isCustom: $isCustomBoss)';
}
