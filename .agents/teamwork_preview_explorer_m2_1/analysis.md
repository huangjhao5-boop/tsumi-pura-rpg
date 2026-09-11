# Analysis Report: Milestone 2 Domain Models & Serialization

**Target Component**: Domain Entities (`KitItem` & `CraftLog`), JSON Serialization, Validation, and Unit Testing  
**Author**: Explorer 1 (`teamwork_preview_explorer_m2_1`)  
**Parent Conversation ID**: `6fa20b7c-dc2d-40cc-9d90-84e64adeddcf`  
**Milestone**: Milestone 2: Local Persistence & CraftLog (Features 13 & 14)  
**Date**: 2026-09-11  

---

## 1. Executive Summary

Milestone 2 establishes the core persistence domain models for 《罪普拉 RPG（Tsumi-Pura RPG）》. This analysis provides the authoritative technical blueprint for:
1. **`KitItem`** (`lib/domain/models/kit_item.dart`): Pure Dart entity representing a model kit boss in the backlog, in-progress battle, or completed showcase.
2. **`CraftLog`** (`lib/domain/models/craft_log.dart`): Pure Dart entity recording each Pomodoro session's duration, craft phase, damage dealt, and completion status.
3. **Serialization & Interoperability**: Bi-directional conversions (`toMap` / `fromMap` / `toJson` / `fromJson`) resilient across SQLite types (`INTEGER` 1/0 for booleans), JSON strings, ISO-8601 timestamps, and schema naming variants (`timestamp` vs `createdAt`).
4. **Validation & Immutability**: Full `copyWith` support with explicit nullable reset controls, state mutation helpers (`applyDamage`, `reset`), and validation logic (`validate()`, `isValid`).
5. **Unit Test Suite Blueprint** (`test/unit/models_test.dart`): Over 30 targeted test cases covering serialization roundtrips, edge cases, defensive conversions, copyWith, and state transitions.

---

## 2. Requirement Cross-Reference & Source Matrix

| Component | Source Reference | Canonical Requirement | Design Resolution |
| :--- | :--- | :--- | :--- |
| **KitItem Schema** | `SPEC.md §7`, `PROJECT.md §13`, `DISPATCH.md` | `id`, `title`, `grade`, `totalHp`, `currentHp`, `status`, `photoPath`, `isCustomBoss`, `createdAt`, `completedAt` | Immutable pure Dart entity with const constructor and `KitItem.create` factory |
| **Status Vocabulary** | `SPEC.md §7` (`Backlog`, `InProgress`, `Completed`) vs `DISPATCH.md` (`unstarted`, `in_progress`, `completed`) | Interoperability across legacy/spec terms | `KitStatus` class with `normalize(status)` and boolean getters (`isUnstarted`, `isBacklog`, `isInProgress`, `isCompleted`) |
| **CraftLog Schema** | `SPEC.md §7`, `PROJECT.md §14`, `DISPATCH.md` | `id`, `kitId`, `phase`, `durationMinutes`, `damageDealt`, `isCompletedSession`, `timestamp` / `createdAt` | Primary field `timestamp`, alias getter `createdAt`, both keys in `toMap()` / `fromMap()` |
| **Boolean Typing** | `SPEC.md §7` (`INTEGER 1/0`) vs Dart `bool` vs JSON engine | SQLite uses `1`/`0`; JSON engine in SharedPreferences uses `true`/`false` | `fromMap` accepts `bool`, `int` (`1`/`0`), and `String` (`'1'`, `'true'`). `toMap` outputs standard JSON and SQLite compatible types |
| **UUID Generation** | `pubspec.yaml` (`uuid: ^4.6.0`) | Automated v4 UUID if `id` not explicitly provided | `const Uuid().v4()` used in factory constructors |
| **Zero Flutter Cost** | `PROJECT.md §Architecture` | Pure Dart entities in `lib/domain/models/` without Flutter UI dependencies | Only imports `dart:convert`, `package:uuid/uuid.dart`, and `game_constants.dart` |

---

## 3. Detailed Architecture & Design Specifications

### 3.1 KitItem (`lib/domain/models/kit_item.dart`)

#### 3.1.1 Schema & Field Definitions
- `final String id`: Unique identifier (UUID v4 format).
- `final String title`: Display name of the model kit (1..50 chars, non-empty after trim).
- `final String grade`: Model scale/grade preset (`'EG'`, `'HG'`, `'RG'`, `'MG'`, `'PG'`, `'GK'`). Defaults to `'HG'`.
- `final int totalHp`: Maximum hit points of the boss (`> 0`). Default derived from `GameConstants.gradeHpDefaults[grade]` (500 HP for HG).
- `final int currentHp`: Remaining hit points (`0 <= currentHp <= totalHp`). When `0`, boss is defeated.
- `final String status`: Progression state (`'unstarted'`, `'in_progress'`, `'completed'`).
- `final String? photoPath`: Optional local file path or image URI.
- `final bool isCustomBoss`: Flag for custom or AI-generated bosses (default `false`).
- `final DateTime createdAt`: Creation timestamp (ISO-8601 formatted).
- `final DateTime? completedAt`: Timestamp when boss was defeated (`null` if in progress or unstarted).

#### 3.1.2 Status Normalization Strategy (`KitStatus`)
To resolve discrepancies between `SPEC.md` (`Backlog`, `InProgress`, `Completed`) and `DISPATCH.md` (`unstarted`, `in_progress`, `completed`), `KitStatus` provides canonical normalization:
```dart
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

  static String normalize(String? status) {
    if (status == null) return unstarted;
    final lower = status.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (lower == 'completed') return completed;
    if (lower == 'in_progress' || lower == 'inprogress') return inProgress;
    if (lower == 'backlog' || lower == 'unstarted') return unstarted;
    return unstarted;
  }

  static bool isValid(String? status) {
    if (status == null) return false;
    final norm = normalize(status);
    return values.contains(norm);
  }
}
```

#### 3.1.3 Immutable Domain State Helpers
- `KitItem applyDamage(int damage, {DateTime? completedTime})`:
  Calculates new HP via `(currentHp - damage).clamp(0, totalHp)`.
  If `newHp == 0`: auto-transitions status to `KitStatus.completed` and records `completedAt`.
  If `newHp > 0`: transitions status to `KitStatus.inProgress`.
- `KitItem reset()`:
  Resets `currentHp` to `totalHp`, status to `KitStatus.unstarted`, and clears `completedAt`.
- `double get hpPercentage => totalHp > 0 ? (currentHp / totalHp).clamp(0.0, 1.0) : 0.0;`
- `bool get canExecuteFinishing => hpPercentage <= (GameConstants.finishingExecutionThreshold + 1e-9);`
- `int get damageTaken => totalHp - currentHp;`
- `bool get isDefeated => currentHp <= 0;`

#### 3.1.4 `copyWith` with Nullable Field Reset
Dart lacks built-in syntax to distinguish between "keep existing value" and "set to null" for nullable fields. In `KitItem`, `photoPath` and `completedAt` are nullable. The design includes explicit boolean flags (`clearPhotoPath`, `clearCompletedAt`):
```dart
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
    status: status ?? this.status,
    photoPath: clearPhotoPath ? null : (photoPath ?? this.photoPath),
    isCustomBoss: isCustomBoss ?? this.isCustomBoss,
    createdAt: createdAt ?? this.createdAt,
    completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
  );
}
```

#### 3.1.5 Defensive `fromMap` Deserialization
Input maps from local storage or JSON may have mismatched types (e.g. integer serialized as string, boolean as 1/0, null values). The deserializer guards every field:
- Safe `int` parsing: converts `int`, `num`, and numeric `String` (`int.tryParse`).
- Safe date parsing: parses `DateTime` objects or ISO-8601 strings; falls back to `DateTime.now()` for `createdAt` and `null` for `completedAt`.
- Safe boolean parsing: treats `true`, `1`, `'1'`, `'true'` as `true`.
- Sane fallbacks: `title` defaults to `'Untitled Boss'`, `grade` to `'HG'`, `totalHp` to `500`.

---

### 3.2 CraftLog (`lib/domain/models/craft_log.dart`)

#### 3.2.1 Schema & Field Definitions
- `final String id`: Unique session log identifier (UUID v4 format).
- `final String kitId`: Associated `KitItem.id` foreign key.
- `final String phase`: Craft process name (`'Snap-fit'`, `'Sanding'`, `'Detailing'`, `'Airbrush'`, `'Finishing'`).
- `final int durationMinutes`: Total focus time logged in minutes (`>= 0`).
- `final int damageDealt`: Damage points inflicted during session (`>= 0`).
- `final bool isCompletedSession`: `true` if session ran to full completion; `false` if aborted via Mercy Rule.
- `final DateTime timestamp`: Timestamp when session took place (ISO-8601 formatted).

#### 3.2.2 Dual Timestamp Compatibility (`timestamp` vs `createdAt`)
`SPEC.md §7` names the column `createdAt`, whereas `DISPATCH.md` names it `timestamp`. To prevent incompatibility:
- Primary Dart property: `final DateTime timestamp;`
- Getter alias: `DateTime get createdAt => timestamp;`
- `toMap()` produces:
  ```dart
  'timestamp': timestamp.toIso8601String(),
  'createdAt': timestamp.toIso8601String(),
  ```
- `fromMap()` checks:
  ```dart
  final rawDate = map['timestamp'] ?? map['createdAt'];
  ```

#### 3.2.3 Session Duration Factory Helper
For fast testing modes (e.g. 5-second debug mode) or standard pomodoros (1,500 seconds):
```dart
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
```

---

## 4. Concrete Proposed Code Implementations

### 4.1 Proposed `lib/domain/models/kit_item.dart`

```dart
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

  static String normalize(String? status) {
    if (status == null) return unstarted;
    final lower = status.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (lower == 'completed') return completed;
    if (lower == 'in_progress' || lower == 'inprogress') return inProgress;
    if (lower == 'backlog' || lower == 'unstarted') return unstarted;
    return unstarted;
  }

  static bool isValid(String? status) {
    if (status == null) return false;
    final norm = normalize(status);
    return values.contains(norm);
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
      id: 'default-hg-mimic-001',
      title: '綠色普通盒怪',
      grade: 'HG',
      totalHp: 500,
      currentHp: 500,
      status: KitStatus.unstarted,
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
  bool get isCompleted => KitStatus.normalize(status) == KitStatus.completed || currentHp <= 0;
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
      status: status ?? this.status,
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
```

---

### 4.2 Proposed `lib/domain/models/craft_log.dart`

```dart
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
```

---

## 5. Unit Test Plan (`test/unit/models_test.dart`)

To guarantee 100% test coverage and satisfy project acceptance criteria, `test/unit/models_test.dart` will be structured into distinct test suites:

### Suite 1: KitItem Creation & Defaults
1. `KitItem.create` assigns default values (`grade: 'HG'`, `totalHp: 500`, `currentHp: 500`, `status: 'unstarted'`).
2. `KitItem.create` assigns correct default HP when grade is changed (`'EG'` -> 300, `'RG'` -> 800, `'MG'` -> 1500, `'PG'` -> 5000).
3. `KitItem.create` generates valid UUID v4 (length 36, contains 4 hyphens).
4. `KitItem.initialSeedKit` returns authoritative initial seed with expected ID and 500 HP.

### Suite 2: KitItem State Transitions & Damage
5. `applyDamage` decrements `currentHp` and transitions status from `unstarted` to `in_progress`.
6. `applyDamage` on fatal blow (damage >= currentHp) clamps `currentHp` to 0, transitions status to `completed`, and records `completedAt`.
7. `reset` restores `currentHp` to `totalHp`, sets status to `unstarted`, and clears `completedAt`.
8. `hpPercentage` returns accurate ratio clamped in `[0.0, 1.0]`.
9. `canExecuteFinishing` returns true when HP <= 20%, false when HP > 20%.

### Suite 3: KitItem `copyWith`
10. `copyWith` modifies target fields while preserving unmodified fields.
11. `copyWith` clears `photoPath` when `clearPhotoPath: true`.
12. `copyWith` clears `completedAt` when `clearCompletedAt: true`.

### Suite 4: KitItem Serialization & Defensive Deserialization
13. `toMap` and `fromMap` roundtrip preserves all field values.
14. `toJson` and `fromJson` roundtrip produces identical entity.
15. `fromMap` normalizes status strings (`'Backlog'` -> `'unstarted'`, `'InProgress'` -> `'in_progress'`).
16. `fromMap` defensively parses numeric strings (`"totalHp": "800"` -> `800`).
17. `fromMap` defensively parses boolean variants (`"isCustomBoss": 1` -> `true`).
18. `fromMap` handles missing optional values without exception.

### Suite 5: KitItem Validation & Equality
19. `isValid` returns true for well-formed kit.
20. `validate` reports errors for empty title, title > 50 characters, totalHp <= 0, negative currentHp, currentHp > totalHp.
21. Value equality (`==`) and `hashCode` succeed across identical instances.

### Suite 6: CraftLog Creation & Helpers
22. `CraftLog.create` assigns valid UUID v4, defaults timestamp to now.
23. `CraftLog.fromSession` correctly rounds seconds to minutes with 1m minimum for short positive runs.
24. `createdAt` alias returns identical `DateTime` as `timestamp`.
25. `isInterrupted` returns `!isCompletedSession`.
26. `phaseSkillName` maps to correct Chinese skill label from `GameConstants`.

### Suite 7: CraftLog Serialization & Defensive Deserialization
27. `toMap` and `fromMap` roundtrip preserves all fields.
28. `toJson` and `fromJson` roundtrip produces identical entity.
29. `fromMap` resolves timestamp from both `'timestamp'` and `'createdAt'` keys.
30. `fromMap` resolves `isCompletedSession` from `bool`, `int` (1/0), and `String` ('true'/'1').
31. `copyWith` modifies fields and preserves others.
32. `isValid` returns true for valid log, catches negative duration/damage.
33. Value equality and `hashCode` test.

---

## 6. Worker Implementation Roadmap

| Step | Action | Files | Verification |
|---|---|---|---|
| **1** | Create `lib/domain/models/kit_item.dart` | `lib/domain/models/kit_item.dart` | `flutter analyze` |
| **2** | Create `lib/domain/models/craft_log.dart` | `lib/domain/models/craft_log.dart` | `flutter analyze` |
| **3** | Implement comprehensive unit tests | `test/unit/models_test.dart` | `flutter test test/unit/models_test.dart` |
| **4** | Verify zero lints and zero warnings | Whole project | `flutter analyze` |
