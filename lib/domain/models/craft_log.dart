import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../core/constants/game_constants.dart';

/// Pure Dart entity representing a Crafting / Pomodoro session log record.
class CraftLog {
  final String id;
  final String kitId;
  final String phase;
  final int durationMinutes;
  final int damageDealt;
  final bool isCompletedSession;
  final DateTime timestamp;

  const CraftLog({
    required this.id,
    required this.kitId,
    required this.phase,
    required this.durationMinutes,
    required this.damageDealt,
    required this.isCompletedSession,
    required this.timestamp,
  });

  /// Factory constructor for generating new craft logs with automated UUID.
  factory CraftLog.create({
    String? id,
    required String kitId,
    required String phase,
    required int durationMinutes,
    required int damageDealt,
    required bool isCompletedSession,
    DateTime? timestamp,
  }) {
    return CraftLog(
      id: id ?? const Uuid().v4(),
      kitId: kitId,
      phase: phase,
      durationMinutes: durationMinutes < 0 ? 0 : durationMinutes,
      damageDealt: damageDealt < 0 ? 0 : damageDealt,
      isCompletedSession: isCompletedSession,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// Factory constructor helper from Pomodoro seconds.
  factory CraftLog.fromSession({
    String? id,
    required String kitId,
    required String phase,
    required int elapsedSeconds,
    required int damageDealt,
    required bool isCompletedSession,
    DateTime? timestamp,
  }) {
    final minutes = (elapsedSeconds / 60).round();
    final durationMinutes = (elapsedSeconds > 0 && minutes == 0) ? 1 : minutes;
    return CraftLog.create(
      id: id,
      kitId: kitId,
      phase: phase,
      durationMinutes: durationMinutes,
      damageDealt: damageDealt,
      isCompletedSession: isCompletedSession,
      timestamp: timestamp,
    );
  }

  // --- Getters & Aliases ---
  /// Alias for compatibility with SPEC §7 SQLite schema
  DateTime get createdAt => timestamp;

  /// Whether the session was aborted prematurely
  bool get isInterrupted => !isCompletedSession;

  /// Retro display skill name
  String get phaseSkillName => GameConstants.phaseSkillNames[phase] ?? phase;

  // --- copyWith ---
  CraftLog copyWith({
    String? id,
    String? kitId,
    String? phase,
    int? durationMinutes,
    int? damageDealt,
    bool? isCompletedSession,
    DateTime? timestamp,
  }) {
    return CraftLog(
      id: id ?? this.id,
      kitId: kitId ?? this.kitId,
      phase: phase ?? this.phase,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      damageDealt: damageDealt ?? this.damageDealt,
      isCompletedSession: isCompletedSession ?? this.isCompletedSession,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  // --- Serialization ---
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kitId': kitId,
      'phase': phase,
      'durationMinutes': durationMinutes,
      'damageDealt': damageDealt,
      'isCompletedSession': isCompletedSession ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
      'createdAt': timestamp.toIso8601String(),
    };
  }

  factory CraftLog.fromMap(Map<String, dynamic> map) {
    int parseInt(dynamic val, int defaultVal) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? defaultVal;
      return defaultVal;
    }

    final dynamic rawCompleted = map['isCompletedSession'];
    final bool isCompleted = rawCompleted == true ||
        rawCompleted == 1 ||
        rawCompleted == '1' ||
        rawCompleted == 'true';

    final rawDate = map['timestamp'] ?? map['createdAt'];
    DateTime parseDate(dynamic val) {
      if (val is DateTime) return val;
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return CraftLog(
      id: map['id']?.toString() ?? const Uuid().v4(),
      kitId: map['kitId']?.toString() ?? '',
      phase: map['phase']?.toString() ?? CraftPhases.snapFit,
      durationMinutes: parseInt(map['durationMinutes'], 0),
      damageDealt: parseInt(map['damageDealt'], 0),
      isCompletedSession: isCompleted,
      timestamp: parseDate(rawDate),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory CraftLog.fromJson(String source) =>
      CraftLog.fromMap(jsonDecode(source) as Map<String, dynamic>);

  // --- Validation ---
  List<String> validate() {
    final errors = <String>[];
    if (id.trim().isEmpty) errors.add('ID cannot be empty');
    if (kitId.trim().isEmpty) errors.add('Kit ID cannot be empty');
    if (phase.trim().isEmpty) errors.add('Phase cannot be empty');
    if (durationMinutes < 0) errors.add('Duration cannot be negative');
    if (damageDealt < 0) errors.add('Damage dealt cannot be negative');
    return errors;
  }

  bool get isValid => validate().isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CraftLog &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          kitId == other.kitId &&
          phase == other.phase &&
          durationMinutes == other.durationMinutes &&
          damageDealt == other.damageDealt &&
          isCompletedSession == other.isCompletedSession &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
        id,
        kitId,
        phase,
        durationMinutes,
        damageDealt,
        isCompletedSession,
        timestamp,
      );

  @override
  String toString() =>
      'CraftLog(id: $id, kitId: $kitId, phase: $phase, dur: ${durationMinutes}m, dmg: $damageDealt, completed: $isCompletedSession, time: ${timestamp.toIso8601String()})';
}
