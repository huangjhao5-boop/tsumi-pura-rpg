# Handoff Report: Milestone 2 Domain Models & Serialization

**Target Role**: Worker / Parent Agent  
**Author**: Explorer 1 (`teamwork_preview_explorer_m2_1`)  
**Parent Conversation ID**: `6fa20b7c-dc2d-40cc-9d90-84e64adeddcf`  
**Milestone**: Milestone 2: Local Persistence & CraftLog (Features 13 & 14)  
**Status**: Hard Handoff (Investigation & Architecture Design Complete)  

---

## 1. Observation

1. **Schema Specifications in SPEC.md §7 (Lines 147-170)**:
   ```sql
   CREATE TABLE KitItem (
       id TEXT PRIMARY KEY,
       title TEXT NOT NULL,
       grade TEXT NOT NULL, -- EG, HG, RG, MG, PG, GK
       totalHp INTEGER NOT NULL,
       currentHp INTEGER NOT NULL,
       status TEXT NOT NULL, -- Backlog (山積), InProgress (施工中), Completed (已完工)
       photoPath TEXT,
       isCustomBoss INTEGER DEFAULT 0, -- 0: 預設, 1: AI生成
       createdAt TEXT NOT NULL,
       completedAt TEXT
   );

   CREATE TABLE CraftLog (
       id TEXT PRIMARY KEY,
       kitId TEXT NOT NULL,
       phase TEXT NOT NULL, -- Snap-fit, Sanding, Detailing, Airbrush, Finishing
       durationMinutes INTEGER NOT NULL,
       damageDealt INTEGER NOT NULL,
       isCompletedSession INTEGER NOT NULL, -- 1: 完整完成, 0: 中途中斷
       createdAt TEXT NOT NULL,
       FOREIGN KEY (kitId) REFERENCES KitItem(id) ON DELETE CASCADE
   );
   ```
2. **Schema & Field Naming Variations**:
   - `DISPATCH.md` lines 12 & 15 specify:
     - `KitItem`: `status (String: unstarted, in_progress, completed)`
     - `CraftLog`: `timestamp (DateTime)`
   - `SPEC.md §7` lines 153 & 168 specify:
     - `KitItem`: `status TEXT NOT NULL, -- Backlog (山積), InProgress (施工中), Completed (已完工)`
     - `CraftLog`: `createdAt TEXT NOT NULL`
   - `PROJECT.md` lines 38-39 specify:
     - `KitItem Data Model`: UUID, title, grade, totalHp, currentHp, status, timestamps
     - `CraftLog Data Model`: UUID, kitId, phase, durationMinutes, damageDealt, isCompleted
3. **Available Packages in `pubspec.yaml` (Line 38)**:
   - `uuid: ^4.6.0` is already installed and available in `pubspec.yaml`.
   - `uuid.v4()` provides RFC4122 v4 UUID strings.
4. **Current Codebase State**:
   - `find_by_name` reveals no model files currently exist under `lib/domain/models/`.
   - `lib/core/constants/game_constants.dart` defines `CraftPhases.all`, `CraftPhases.snapFit`, etc. (lines 6-20) and `gradeHpDefaults` (lines 165-171).
   - `test/unit/battle_engine_test.dart` passes cleanly and uses pure Dart tests with `flutter_test`.
5. **Detailed Architecture Plan**:
   - Complete Dart entity designs for `lib/domain/models/kit_item.dart` and `lib/domain/models/craft_log.dart` have been authored in `analysis.md` in the current working directory.

---

## 2. Logic Chain

1. **Deriving Entity Architecture from Observations 1, 2, and 4**:
   - Because `lib/domain/models/` is currently empty, Worker must create two new files:
     - `lib/domain/models/kit_item.dart`
     - `lib/domain/models/craft_log.dart`
   - Because these entities reside in the Domain layer (`PROJECT.md §Architecture`), they must remain pure Dart classes with zero dependencies on Flutter UI (`package:flutter/material.dart`).
2. **Reconciling Status Vocabulary Discrepancies from Observation 2**:
   - `DISPATCH.md` uses snake_case (`unstarted`, `in_progress`, `completed`), while `SPEC.md` uses PascalCase (`Backlog`, `InProgress`, `Completed`).
   - By creating `KitStatus.normalize(String? status)` and mapping aliases (`'backlog'` $\to$ `'unstarted'`), both naming systems are supported seamlessly without breaking JSON deserialization or persistence.
   - Adding helper getters (`isUnstarted`, `isBacklog`, `isInProgress`, `isCompleted`) allows UI components to check status cleanly regardless of conventions.
3. **Reconciling CraftLog Timestamp Discrepancies from Observation 2**:
   - `DISPATCH.md` requests `timestamp (DateTime)`, while `SPEC.md §7` requires `createdAt TEXT NOT NULL`.
   - By defining the primary field as `final DateTime timestamp;` with a getter `DateTime get createdAt => timestamp;`, and outputting both keys in `toMap()`, any consumer expecting either `timestamp` or `createdAt` will function without errors.
4. **Resilient Serialization across SQLite and JSON from Observation 1**:
   - SQLite represents booleans as `INTEGER` (`1` or `0`), while JSON uses booleans (`true` or `false`).
   - In `fromMap()`, evaluating `raw == true || raw == 1 || raw == '1' || raw == 'true'` guarantees that whether the data originates from an SQLite query, a `SharedPreferences` JSON string, or a REST API, deserialization succeeds.
5. **Ergonomic Null Reset in `copyWith`**:
   - `photoPath` and `completedAt` in `KitItem` are nullable. Standard Dart `copyWith` cannot differentiate between passing `null` to clear a field versus omitting the argument to keep the current value.
   - Introducing explicit flags `clearPhotoPath: true` and `clearCompletedAt: true` enables unambiguous clearing of nullable fields while preserving standard argument ergonomics for all other fields.
6. **Domain State Mutation via Pure Functions**:
   - Adding `applyDamage(int damage, {DateTime? completedTime})` to `KitItem` encapsulates core business rules: clamping HP $\ge 0$, setting status to `'in_progress'` or auto-completing to `'completed'` when `currentHp == 0`, and stamping `completedAt`.

---

## 3. Caveats

1. **Storage Implementation Separation**:
   - This investigation focuses strictly on Features 13 & 14 (Domain Models & Serialization). Explorer 2 (`teamwork_preview_explorer_m2_2`) is handling Feature 15 (`SharedPreferences` repository storage layer).
2. **Enum vs String**:
   - `grade`, `phase`, and `status` are retained as `String` properties rather than Dart enums to strictly match the schemas in `SPEC.md §7` and `DISPATCH.md`, and to avoid serialization fragility when new grades or phases are added. Strongly typed helpers (`KitStatus`, `CraftPhases`, `GameConstants.gradeHpDefaults`) provide validation and type safety.
3. **Photo Storage Resolution**:
   - `photoPath` stores a string path. Actual camera/gallery image picker integrations and physical file I/O belong to Milestone 3 (Hangar & Showcase CRUD).

---

## 4. Conclusion

1. The data contracts for `KitItem` and `CraftLog` are fully resolved and documented in `analysis.md`.
2. Both entities must be implemented as immutable pure Dart classes in `lib/domain/models/` with:
   - Automated v4 UUID generation (`uuid: ^4.6.0`).
   - Bi-directional serialization (`toMap`, `fromMap`, `toJson`, `fromJson`) with defensive parsing of numeric strings, booleans, and ISO-8601 dates.
   - Dual timestamp compatibility (`timestamp` and `createdAt` alias) on `CraftLog`.
   - Normalized status management (`KitStatus`) supporting both `unstarted`/`in_progress`/`completed` and `Backlog`/`InProgress`/`Completed`.
   - Full `copyWith` with nullable field reset flags (`clearPhotoPath`, `clearCompletedAt`).
   - Domain transition helpers (`applyDamage`, `reset`, `fromSession`).
   - Value equality (`operator ==`, `hashCode`) and validation (`validate()`, `isValid`).
3. Complete source code and a 33-case test suite are specified in `analysis.md` and ready for immediate implementation by Worker.

---

## 5. Verification Method

To verify the implementation once Worker builds the models and test files:

1. **Run Flutter Static Analysis**:
   ```powershell
   flutter analyze
   ```
   **Expected Result**: 0 errors, 0 warnings, 0 lints.

2. **Run Unit Tests for Models**:
   ```powershell
   flutter test test/unit/models_test.dart
   ```
   **Expected Result**: All 33 test cases pass with 100% success.

3. **Verify Existing Tests Continue to Pass**:
   ```powershell
   flutter test test/unit/battle_engine_test.dart
   flutter test test/unit/battle_engine_adversarial_test.dart
   ```
   **Expected Result**: Existing battle engine tests pass without regression.

4. **Inspect Generated Files**:
   - Verify `lib/domain/models/kit_item.dart` exists and does not import `package:flutter/material.dart`.
   - Verify `lib/domain/models/craft_log.dart` exists and does not import `package:flutter/material.dart`.
   - Verify `test/unit/models_test.dart` contains test groups for Creation, Damage/Transitions, CopyWith, Serialization, and Validation.

5. **Invalidation Conditions**:
   - If `KitItem.fromMap` fails when receiving `status: 'Backlog'` or `isCustomBoss: 1`.
   - If `CraftLog.fromMap` fails when receiving `createdAt` instead of `timestamp`.
   - If `flutter analyze` reports any deprecations, warnings, or lint failures.
