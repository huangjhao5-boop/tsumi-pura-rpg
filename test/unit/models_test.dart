import 'package:flutter_test/flutter_test.dart';
import 'package:nifty_heisenberg/core/constants/game_constants.dart';
import 'package:nifty_heisenberg/domain/models/craft_log.dart';
import 'package:nifty_heisenberg/domain/models/kit_item.dart';

void main() {
  group('KitItem Domain Model Tests', () {
    test('KitItem.create assigns default values and calculates default HP', () {
      final kit = KitItem.create(title: 'HG 自由鋼彈');
      expect(kit.title, equals('HG 自由鋼彈'));
      expect(kit.grade, equals('HG'));
      expect(kit.totalHp, equals(500));
      expect(kit.currentHp, equals(500));
      expect(kit.status, equals(KitStatus.unstarted));
      expect(kit.isUnstarted, isTrue);
      expect(kit.isBacklog, isTrue);
      expect(kit.photoPath, isNull);
      expect(kit.isCustomBoss, isFalse);
      expect(kit.completedAt, isNull);
      expect(kit.id.length, equals(36));
      expect(kit.id.split('-').length, equals(5));
    });

    test('KitItem.create derives default HP from grade presets', () {
      final egKit = KitItem.create(title: 'EG 初鋼', grade: 'EG');
      expect(egKit.totalHp, equals(300));
      expect(egKit.currentHp, equals(300));

      final rgKit = KitItem.create(title: 'RG 牛鋼', grade: 'RG');
      expect(rgKit.totalHp, equals(800));

      final mgKit = KitItem.create(title: 'MG 獵魔', grade: 'MG');
      expect(mgKit.totalHp, equals(1500));

      final pgKit = KitItem.create(title: 'PG 能天使', grade: 'PG');
      expect(pgKit.totalHp, equals(5000));
    });

    test('KitItem.initialSeedKit returns standard initial seed', () {
      final seed = KitItem.initialSeedKit();
      expect(seed.title, equals('綠色普通盒怪'));
      expect(seed.grade, equals('HG'));
      expect(seed.totalHp, equals(500));
      expect(seed.currentHp, equals(500));
      expect(seed.isCompleted, isFalse);
    });

    test('applyDamage transitions status to in_progress and decrements HP', () {
      final kit = KitItem.create(title: 'HG 盒怪', totalHp: 500);
      final damaged = kit.applyDamage(100);

      expect(damaged.currentHp, equals(400));
      expect(damaged.status, equals(KitStatus.inProgress));
      expect(damaged.isInProgress, isTrue);
      expect(damaged.isCompleted, isFalse);
      expect(damaged.damageTaken, equals(100));
      expect(damaged.hpPercentage, closeTo(0.8, 1e-6));
    });

    test('applyDamage on lethal damage clamps to 0 and marks completed', () {
      final kit = KitItem.create(title: 'HG 盒怪', totalHp: 500, currentHp: 50);
      final completionTime = DateTime(2026, 9, 11, 12, 0);
      final defeated = kit.applyDamage(100, completedTime: completionTime);

      expect(defeated.currentHp, equals(0));
      expect(defeated.status, equals(KitStatus.completed));
      expect(defeated.isCompleted, isTrue);
      expect(defeated.isDefeated, isTrue);
      expect(defeated.completedAt, equals(completionTime));
      expect(defeated.damageTaken, equals(500));
    });

    test('reset restores HP to totalHp and resets status to unstarted', () {
      final kit = KitItem.create(
        title: 'HG 盒怪',
        totalHp: 500,
        currentHp: 0,
        status: KitStatus.completed,
        completedAt: DateTime.now(),
      );

      final resetKit = kit.reset();
      expect(resetKit.currentHp, equals(500));
      expect(resetKit.status, equals(KitStatus.unstarted));
      expect(resetKit.completedAt, isNull);
    });

    test('canExecuteFinishing returns true when HP <= 20%', () {
      final highHp = KitItem.create(title: 'Boss', totalHp: 500, currentHp: 101);
      expect(highHp.canExecuteFinishing, isFalse);

      final thresholdHp = KitItem.create(title: 'Boss', totalHp: 500, currentHp: 100);
      expect(thresholdHp.canExecuteFinishing, isTrue);

      final lowHp = KitItem.create(title: 'Boss', totalHp: 500, currentHp: 50);
      expect(lowHp.canExecuteFinishing, isTrue);
    });

    test('copyWith updates specified fields and clearPhotoPath / clearCompletedAt work', () {
      final now = DateTime.now();
      final kit = KitItem(
        id: 'k1',
        title: 'Title',
        grade: 'HG',
        totalHp: 500,
        currentHp: 200,
        status: KitStatus.inProgress,
        photoPath: '/path/to/photo.jpg',
        isCustomBoss: false,
        createdAt: now,
        completedAt: now,
      );

      final cleared = kit.copyWith(clearPhotoPath: true, clearCompletedAt: true);
      expect(cleared.photoPath, isNull);
      expect(cleared.completedAt, isNull);
      expect(cleared.title, equals('Title'));
      expect(cleared.currentHp, equals(200));

      final updated = kit.copyWith(title: 'New Title', currentHp: 150);
      expect(updated.title, equals('New Title'));
      expect(updated.currentHp, equals(150));
      expect(updated.photoPath, equals('/path/to/photo.jpg'));
    });

    test('toMap and fromMap roundtrip preserves all fields', () {
      final now = DateTime(2026, 9, 11, 10, 30);
      final kit = KitItem(
        id: 'k-roundtrip',
        title: 'RG 沙薩比',
        grade: 'RG',
        totalHp: 800,
        currentHp: 650,
        status: KitStatus.inProgress,
        photoPath: '/images/sazabi.png',
        isCustomBoss: true,
        createdAt: now,
        completedAt: null,
      );

      final map = kit.toMap();
      final fromMap = KitItem.fromMap(map);

      expect(fromMap.id, equals(kit.id));
      expect(fromMap.title, equals(kit.title));
      expect(fromMap.grade, equals(kit.grade));
      expect(fromMap.totalHp, equals(kit.totalHp));
      expect(fromMap.currentHp, equals(kit.currentHp));
      expect(fromMap.status, equals(kit.status));
      expect(fromMap.photoPath, equals(kit.photoPath));
      expect(fromMap.isCustomBoss, isTrue);
      expect(fromMap.createdAt, equals(kit.createdAt));
      expect(fromMap.completedAt, isNull);

      final jsonStr = kit.toJson();
      final fromJson = KitItem.fromJson(jsonStr);
      expect(fromJson, equals(kit));
    });

    test('fromMap normalizes legacy and string status values defensively', () {
      final mapBacklog = {
        'id': '1',
        'title': 'Test',
        'status': 'Backlog',
      };
      expect(KitItem.fromMap(mapBacklog).status, equals(KitStatus.unstarted));

      final mapInProgress = {
        'id': '2',
        'title': 'Test',
        'status': 'InProgress',
      };
      expect(KitItem.fromMap(mapInProgress).status, equals(KitStatus.inProgress));

      final mapCompleted = {
        'id': '3',
        'title': 'Test',
        'status': 'Completed',
      };
      expect(KitItem.fromMap(mapCompleted).status, equals(KitStatus.completed));
    });

    test('fromMap defensively parses numeric strings and boolean variants', () {
      final map = {
        'id': 'def-1',
        'title': 'Defensive Test',
        'totalHp': '1200',
        'currentHp': '950',
        'isCustomBoss': '1',
      };
      final kit = KitItem.fromMap(map);
      expect(kit.totalHp, equals(1200));
      expect(kit.currentHp, equals(950));
      expect(kit.isCustomBoss, isTrue);
    });

    test('validate catches empty title, excessive length, and negative HP', () {
      final emptyTitle = KitItem(
        id: '1',
        title: '   ',
        totalHp: 500,
        currentHp: 500,
        createdAt: DateTime.now(),
      );
      expect(emptyTitle.validate().any((e) => e.contains('Title')), isTrue);
      expect(emptyTitle.isValid, isFalse);

      final badHp = KitItem(
        id: '2',
        title: 'Normal Title',
        totalHp: -10,
        currentHp: -5,
        createdAt: DateTime.now(),
      );
      expect(badHp.validate().length, greaterThanOrEqualTo(2));
      expect(badHp.isValid, isFalse);
    });

    test('KitStatus.isValid strictly validates status strings and aliases', () {
      expect(KitStatus.isValid(KitStatus.unstarted), isTrue);
      expect(KitStatus.isValid(KitStatus.inProgress), isTrue);
      expect(KitStatus.isValid(KitStatus.completed), isTrue);
      expect(KitStatus.isValid('backlog'), isTrue);
      expect(KitStatus.isValid('Backlog'), isTrue);
      expect(KitStatus.isValid('in-progress'), isTrue);
      expect(KitStatus.isValid('inprogress'), isTrue);
      expect(KitStatus.isValid(' Completed '), isTrue);

      // Strict invalid rejections
      expect(KitStatus.isValid(null), isFalse);
      expect(KitStatus.isValid(''), isFalse);
      expect(KitStatus.isValid('   '), isFalse);
      expect(KitStatus.isValid('BOGUS_STATUS'), isFalse);
      expect(KitStatus.isValid('pending'), isFalse);
    });

    test('KitItem.validate rejects unrecognized status strings', () {
      final badStatusKit = KitItem(
        id: 'k-bad-status',
        title: 'Bad Status',
        totalHp: 500,
        currentHp: 500,
        status: 'UNKNOWN_XYZ',
        createdAt: DateTime.now(),
      );
      expect(badStatusKit.isValid, isFalse);
      expect(badStatusKit.validate(), contains('Invalid status: UNKNOWN_XYZ'));
    });

    test('Consolidated seed constants in GameConstants match KitItem.initialSeedKit', () {
      final seed = KitItem.initialSeedKit();
      expect(seed.id, equals(GameConstants.defaultKitId));
      expect(seed.title, equals(GameConstants.defaultKitTitle));
      expect(seed.grade, equals(GameConstants.defaultKitGrade));
      expect(seed.totalHp, equals(GameConstants.defaultKitHp));
      expect(seed.currentHp, equals(GameConstants.defaultKitHp));
    });
  });

  group('CraftLog Domain Model Tests', () {
    test('CraftLog.create generates valid UUID and default timestamp', () {
      final log = CraftLog.create(
        kitId: 'kit-101',
        phase: CraftPhases.snapFit,
        durationMinutes: 25,
        damageDealt: 100,
        isCompletedSession: true,
      );

      expect(log.kitId, equals('kit-101'));
      expect(log.phase, equals(CraftPhases.snapFit));
      expect(log.durationMinutes, equals(25));
      expect(log.damageDealt, equals(100));
      expect(log.isCompletedSession, isTrue);
      expect(log.isInterrupted, isFalse);
      expect(log.id.length, equals(36));
      expect(log.createdAt, equals(log.timestamp));
    });

    test('CraftLog.fromSession rounds seconds to minutes with 1m minimum for short runs', () {
      final shortDebugLog = CraftLog.fromSession(
        kitId: 'kit-101',
        phase: CraftPhases.sanding,
        elapsedSeconds: 5,
        damageDealt: 24,
        isCompletedSession: true,
      );
      expect(shortDebugLog.durationMinutes, equals(1));

      final standardLog = CraftLog.fromSession(
        kitId: 'kit-101',
        phase: CraftPhases.snapFit,
        elapsedSeconds: 1500,
        damageDealt: 100,
        isCompletedSession: true,
      );
      expect(standardLog.durationMinutes, equals(25));
    });

    test('phaseSkillName retrieves correct skill name from GameConstants', () {
      final log = CraftLog.create(
        kitId: 'kit-1',
        phase: CraftPhases.airbrush,
        durationMinutes: 25,
        damageDealt: 200,
        isCompletedSession: true,
      );
      expect(log.phaseSkillName, equals('噴筆重砲'));
    });

    test('toMap and fromMap roundtrip preserves all fields', () {
      final time = DateTime(2026, 9, 11, 14, 0);
      final log = CraftLog(
        id: 'log-uuid-1234',
        kitId: 'kit-999',
        phase: CraftPhases.detailing,
        durationMinutes: 30,
        damageDealt: 150,
        isCompletedSession: false,
        timestamp: time,
      );

      final map = log.toMap();
      expect(map['isCompletedSession'], equals(0));
      expect(map['createdAt'], equals(time.toIso8601String()));
      expect(map['timestamp'], equals(time.toIso8601String()));

      final fromMap = CraftLog.fromMap(map);
      expect(fromMap.id, equals(log.id));
      expect(fromMap.kitId, equals(log.kitId));
      expect(fromMap.phase, equals(log.phase));
      expect(fromMap.durationMinutes, equals(log.durationMinutes));
      expect(fromMap.damageDealt, equals(log.damageDealt));
      expect(fromMap.isCompletedSession, isFalse);
      expect(fromMap.timestamp, equals(log.timestamp));

      final jsonStr = log.toJson();
      final fromJson = CraftLog.fromJson(jsonStr);
      expect(fromJson, equals(log));
    });

    test('fromMap defensively parses boolean and timestamp keys', () {
      final mapWithInt = {
        'id': 'log-int',
        'kitId': 'kit-1',
        'phase': 'Snap-fit',
        'durationMinutes': '15',
        'damageDealt': '50',
        'isCompletedSession': 1,
        'createdAt': '2026-09-11T12:00:00.000',
      };
      final parsed = CraftLog.fromMap(mapWithInt);
      expect(parsed.isCompletedSession, isTrue);
      expect(parsed.durationMinutes, equals(15));
      expect(parsed.damageDealt, equals(50));
      expect(parsed.timestamp.year, equals(2026));
    });

    test('validate catches invalid negative values and empty fields', () {
      final invalidLog = CraftLog(
        id: '',
        kitId: '',
        phase: '',
        durationMinutes: -5,
        damageDealt: -10,
        isCompletedSession: false,
        timestamp: DateTime.now(),
      );

      expect(invalidLog.isValid, isFalse);
      final errors = invalidLog.validate();
      expect(errors.length, equals(5));
    });

    test('copyWith and value equality work correctly', () {
      final log1 = CraftLog.create(
        id: 'fixed-id',
        kitId: 'kit-1',
        phase: CraftPhases.snapFit,
        durationMinutes: 25,
        damageDealt: 100,
        isCompletedSession: true,
        timestamp: DateTime(2026, 1, 1),
      );

      final log2 = log1.copyWith();
      expect(log1, equals(log2));
      expect(log1.hashCode, equals(log2.hashCode));

      final log3 = log1.copyWith(damageDealt: 200);
      expect(log1 == log3, isFalse);
    });
  });
}
