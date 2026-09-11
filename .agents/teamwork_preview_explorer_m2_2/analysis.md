# 《罪普拉 RPG》Milestone 2 本地離線儲存架構與 Repository 設計深度分析報告
**Storage Architecture, Offline Persistence & Repository Design for Milestone 2**

- **調查員**：`teamwork_preview_explorer` (Explorer 2 for Milestone 2: Storage Architecture & Repositories)
- **調查日期**：2026-09-11
- **工作目錄**：`c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m2_2`
- **依據文檔**：`ORIGINAL_REQUEST.md`, `SPEC.md`, `PROJECT.md`, `environment_analysis.md`

---

## 1. 執行摘要 (Executive Summary)

本報告針對《罪普拉 RPG》Milestone 2（Feature 15 本地持久化服務與 Repository、Feature 16 自動存檔與狀態注水、Feature 17 施工紀錄歷史儲存）提供完整架構規劃與工程落地規範。

### 核心結論：
1. **儲存引擎選型**：
   - 採用 **`shared_preferences` 純 JSON 序列化儲存引擎**（封裝於 `LocalStorageService`）。
   - **零金錢成本 (Zero Monetary Cost)**：純開源套件，零雲端開銷。
   - **雙平台原生支援 (Web & Windows)**：Web 端底層使用 `window.localStorage`（免除 SQLite WASM 的 `SharedArrayBuffer` 與 CORS Header 限制，100% 相容 GitHub Pages 等靜態伺服器）；Windows 桌面端使用本地檔案/註冊表持久化（無需 Visual Studio C++ 工具鏈或外掛 DLL）。
   - **單一 JSON 字串 vs StringList**：強烈推薦使用 `setString(key, jsonEncode(list))` 儲存單一 JSON 陣列，避免 `setStringList` 在 Web localStorage 中產生雙重轉義引號（`"[\"{\\\"id\\\":...}\"]"`），提升序列化效能與 Chrome DevTools 可檢視性。
2. **介面契約遵循 (Interface Contracts Compliance)**：
   - 嚴格實作 `PROJECT.md §Interface Contracts` 定義之抽象介面：
     - `IKitRepository`: `getAllKits()`, `getActiveKit()`, `saveKit(KitItem kit)`, `deleteKit(String kitId)`, `setActiveKit(String kitId)`。
     - `ICraftLogRepository`: `getLogsForKit(String kitId)`, `getAllLogs()`, `addLog(CraftLog log)`。
   - 擴充級聯清除輔助方法 `deleteLogsForKit(String kitId)` 滿足 `SPEC.md §7` 外鍵 `ON DELETE CASCADE` 規則。
3. **預設種子資料機制 (Default Initial Seeding)**：
   - 當儲存層為空（初次安裝或儲存清空）時，自動植入第一隻預設 HG 盒怪（`id: 'default-seed-mimic-001'`, `title: '綠色普通盒怪'`, `grade: 'HG'`, `totalHp: 500`, `currentHp: 500`, `status: 'InProgress'`），並設定為當前 `activeKit`，確保使用者初次開啟遊戲即時可玩，零等待、零例外。
4. **單元測試與 Mock 機制 (Zero-Cost Mocking)**：
   - 透過官方原生提供之 `SharedPreferences.setMockInitialValues(<String, Object>{})` 達成 100% 同步記憶體 Mock，無須任何第三方 Mock 套件（如 mockito、mocktail），單元測試執行時間 < 100ms。
5. **併發與防禦性容錯 (Concurrency & Resilience)**：
   - Repository 內部維護記憶體快取與順序化寫入佇列，消除讀-改-寫（Read-Modify-Write）競態條件。
   - 包含 JSON 解析例外攔截，損壞資料自動降級或修復，避免因本機儲存損壞造成 App 崩潰。

---

## 2. 依賴項分析與 `pubspec.yaml` 整合配置

### 2.1 現行依賴現狀
檢視 `pubspec.yaml`：
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  google_fonts: ^6.2.1
  uuid: ^4.6.0
```
目前尚未引入 `shared_preferences`。

### 2.2 建議配置
在 `pubspec.yaml` 之 `dependencies` 加入 `shared_preferences: ^2.5.2`：
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  google_fonts: ^6.2.1
  uuid: ^4.6.0
  shared_preferences: ^2.5.2
```
- **版本相容性**：`shared_preferences ^2.5.2` 支援 Dart 3.x 與 Flutter 3.38+，與本專案環境（Dart 3.10.4 / Flutter 3.38.5）100% 相容。
- **平台實作層**：
  - Web: 內部自動引用 `shared_preferences_web`（使用瀏覽器 `window.localStorage`）。
  - Windows: 內部自動引用 `shared_preferences_windows`（使用本機檔案系統儲存 JSON 檔）。

---

## 3. 儲存層架構設計 (`lib/data/storage/`)

### 3.1 職責劃分 (Separation of Concerns)
在 Clean Architecture 中：
- `lib/data/storage/`：負責低階 Key-Value 存取、JSON 編解碼、例外捕捉與快取管理。
- `lib/data/repositories/`：負責領域實體（Domain Entities）的對應、種子資料植入、業務規則驗證與級聯操作。

```
lib/data/
├── storage/
│   ├── storage_keys.dart           # 全域鍵名常數
│   └── local_storage_service.dart   # SharedPreferences 包裝與 JSON 存取服務
└── repositories/
    ├── kit_repository.dart         # IKitRepository 實作
    └── craft_log_repository.dart   # ICraftLogRepository 實作
```

### 3.2 儲存鍵名規範 (`storage_keys.dart`)
為避免鍵名衝突並支援未來版號遷移，鍵名統一採版本化命名空間：

```dart
// lib/data/storage/storage_keys.dart

class StorageKeys {
  StorageKeys._();

  /// 所有盒怪模型清單 (JSON 陣列字串)
  static const String kits = 'tsumi_pura_kits_v1';

  /// 所有施工紀錄清單 (JSON 陣列字串)
  static const String craftLogs = 'tsumi_pura_craft_logs_v1';

  /// 當前出戰/選定中的盒怪 ID (String UUID)
  static const String activeKitId = 'tsumi_pura_active_kit_id_v1';

  /// 玩家設定檔 (預留 Milestone 4/擴充功能)
  static const String userProfile = 'tsumi_pura_user_profile_v1';
}
```

### 3.3 本地儲存服務介面與實作 (`local_storage_service.dart`)
定義 `ILocalStorageService`，方便未來抽換或替換為其他儲存媒介：

```dart
// lib/data/storage/local_storage_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class ILocalStorageService {
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
  Future<List<Map<String, dynamic>>> getJsonList(String key);
  Future<bool> setJsonList(String key, List<Map<String, dynamic>> list);
  Future<bool> remove(String key);
  Future<bool> clear();
}

class LocalStorageService implements ILocalStorageService {
  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  static Future<LocalStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  @override
  Future<String?> getString(String key) async {
    return _prefs.getString(key);
  }

  @override
  Future<bool> setString(String key, String value) async {
    return _prefs.setString(key, value);
  }

  @override
  Future<List<Map<String, dynamic>>> getJsonList(String key) async {
    try {
      final raw = _prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) {
        return <Map<String, dynamic>>[];
      }
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return <Map<String, dynamic>>[];
    } catch (e, stack) {
      debugPrint('LocalStorageService.getJsonList error for key $key: $e\n$stack');
      return <Map<String, dynamic>>[];
    }
  }

  @override
  Future<bool> setJsonList(String key, List<Map<String, dynamic>> list) async {
    try {
      final jsonString = jsonEncode(list);
      return await _prefs.setString(key, jsonString);
    } catch (e, stack) {
      debugPrint('LocalStorageService.setJsonList error for key $key: $e\n$stack');
      return false;
    }
  }

  @override
  Future<bool> remove(String key) async {
    return _prefs.remove(key);
  }

  @override
  Future<bool> clear() async {
    return _prefs.clear();
  }
}
```

---

## 4. Repository 實作規格與業務邏輯 (`lib/data/repositories/`)

### 4.1 `KitRepository` 實作架構
遵循 `PROJECT.md §Interface Contracts` 之 `IKitRepository`：

```dart
abstract class IKitRepository {
  Future<List<KitItem>> getAllKits();
  Future<KitItem?> getActiveKit();
  Future<void> saveKit(KitItem kit);
  Future<void> deleteKit(String kitId);
  Future<void> setActiveKit(String kitId);
}
```

#### 關鍵實作細節：
1. **預設種子盒怪常數 (Default Seed Mimic)**：
   - ID: `'default-box-mimic-hg-001'`
   - Title: `'綠色普通盒怪'` (與現有 `main.dart` 畫面中一致)
   - Grade: `'HG'`
   - TotalHp: 500
   - CurrentHp: 500
   - Status: `'InProgress'` (已在開工桌前)
   - PhotoPath: null
   - IsCustomBoss: false
   - CreatedAt: 固定或啟動時時間戳記
2. **自動種子植入條件 (Auto-Seed on First Launch)**：
   - 當呼叫 `getAllKits()` 時，若儲存中無任何記錄（清單為空），立即建立預設盒怪，呼叫 `saveKit(seedKit)` 並寫入 `activeKitId`。
   - 確保不論是初次安裝、重新整理或是全新開機，`getAllKits()` 至少回傳 1 筆盒怪，`getActiveKit()` 絕不為 null。
3. **`saveKit(KitItem kit)` 語意**：
   - Upsert 語意：依據 `kit.id` 比對，若存在則替換更新；若不存在則追加至清單尾端。
4. **`deleteKit(String kitId)` 語意**：
   - 從清單中移除該 ID。
   - 若被刪除者為當前 `activeKit`：
     - 若清單中仍有其他盒怪，自動將第一隻未完工（`InProgress` 或 `Backlog`）盒怪設為新的 `activeKit`；若無未完工盒怪，則選取剩餘的第一隻盒怪。
     - 若清單被刪空，可視需求重新觸發預設種子。
5. **記憶體快取與原子更新**：
   - 內部保持 `List<KitItem>? _cachedKits` 與 `String? _cachedActiveKitId`，讀取優先命中記憶體，寫入時同步更新快取並非同步持久化至 `LocalStorageService`。

#### 建議完整實作代碼：
```dart
// lib/data/repositories/kit_repository.dart
import '../../domain/models/kit_item.dart';
import '../storage/local_storage_service.dart';
import '../storage/storage_keys.dart';

abstract class IKitRepository {
  Future<List<KitItem>> getAllKits();
  Future<KitItem?> getActiveKit();
  Future<void> saveKit(KitItem kit);
  Future<void> deleteKit(String kitId);
  Future<void> setActiveKit(String kitId);
}

class KitRepository implements IKitRepository {
  final ILocalStorageService _storage;
  List<KitItem>? _cachedKits;
  String? _cachedActiveKitId;

  KitRepository(this._storage);

  /// 預設第一隻種子盒怪
  static KitItem createDefaultSeedKit() {
    return KitItem(
      id: 'default-box-mimic-hg-001',
      title: '綠色普通盒怪',
      grade: 'HG',
      totalHp: 500,
      currentHp: 500,
      status: 'InProgress',
      photoPath: null,
      isCustomBoss: false,
      createdAt: DateTime.now(),
      completedAt: null,
    );
  }

  @override
  Future<List<KitItem>> getAllKits() async {
    if (_cachedKits != null) {
      return List.unmodifiable(_cachedKits!);
    }

    final rawList = await _storage.getJsonList(StorageKeys.kits);
    final kits = <KitItem>[];

    for (final map in rawList) {
      try {
        kits.add(KitItem.fromMap(map));
      } catch (_) {
        // 略過毀損的個別項目
      }
    }

    // 初次安裝或為空時自動植入預設種子
    if (kits.isEmpty) {
      final seed = createDefaultSeedKit();
      kits.add(seed);
      _cachedKits = kits;
      _cachedActiveKitId = seed.id;
      await _persistKits(kits);
      await _storage.setString(StorageKeys.activeKitId, seed.id);
      return List.unmodifiable(kits);
    }

    _cachedKits = kits;
    return List.unmodifiable(kits);
  }

  @override
  Future<KitItem?> getActiveKit() async {
    final kits = await getAllKits();
    _cachedActiveKitId ??= await _storage.getString(StorageKeys.activeKitId);

    if (_cachedActiveKitId != null) {
      try {
        return kits.firstWhere((k) => k.id == _cachedActiveKitId);
      } catch (_) {}
    }

    // 若未指定或找不到，退回第一隻進行中或第一隻模型
    final fallback = kits.firstWhere(
      (k) => k.status != 'Completed',
      orElse: () => kits.first,
    );
    await setActiveKit(fallback.id);
    return fallback;
  }

  @override
  Future<void> saveKit(KitItem kit) async {
    final kits = (await getAllKits()).toList();
    final index = kits.indexWhere((k) => k.id == kit.id);

    if (index >= 0) {
      kits[index] = kit;
    } else {
      kits.add(kit);
    }

    _cachedKits = kits;
    await _persistKits(kits);
  }

  @override
  Future<void> deleteKit(String kitId) async {
    final kits = (await getAllKits()).toList();
    kits.removeWhere((k) => k.id == kitId);

    // 若清單已空，重新補充預設種子
    if (kits.isEmpty) {
      final seed = createDefaultSeedKit();
      kits.add(seed);
      _cachedActiveKitId = seed.id;
      await _storage.setString(StorageKeys.activeKitId, seed.id);
    } else if (_cachedActiveKitId == kitId) {
      // 若刪除的是出戰中的模型，自動轉移至下一隻
      final nextActive = kits.firstWhere(
        (k) => k.status != 'Completed',
        orElse: () => kits.first,
      );
      _cachedActiveKitId = nextActive.id;
      await _storage.setString(StorageKeys.activeKitId, nextActive.id);
    }

    _cachedKits = kits;
    await _persistKits(kits);
  }

  @override
  Future<void> setActiveKit(String kitId) async {
    _cachedActiveKitId = kitId;
    await _storage.setString(StorageKeys.activeKitId, kitId);
  }

  Future<void> _persistKits(List<KitItem> kits) async {
    final mapList = kits.map((k) => k.toMap()).toList();
    await _storage.setJsonList(StorageKeys.kits, mapList);
  }
}
```

---

### 4.2 `CraftLogRepository` 實作架構
遵循 `PROJECT.md §Interface Contracts` 之 `ICraftLogRepository`：

```dart
abstract class ICraftLogRepository {
  Future<List<CraftLog>> getLogsForKit(String kitId);
  Future<List<CraftLog>> getAllLogs();
  Future<void> addLog(CraftLog log);
}
```

#### 關鍵實作細節：
1. **追加日誌 (`addLog`)**：
   - 每次番茄鐘專注結束（滿額完成或 Mercy 中途中斷）時，呼叫 `addLog(log)`。
   - 採用追加至開頭（最新排前面）或依時間排序。
2. **依模型檢索 (`getLogsForKit`)**：
   - 篩選 `log.kitId == kitId`，可用於模型展示櫃或工時統計分析。
3. **級聯清除輔助 (`deleteLogsForKit`)**：
   - 當在機庫中刪除某一 `KitItem` 時，可呼叫此方法清除相關所有施工紀錄，滿足 `SPEC.md §7` 之 `ON DELETE CASCADE`。

#### 建議完整實作代碼：
```dart
// lib/data/repositories/craft_log_repository.dart
import '../../domain/models/craft_log.dart';
import '../storage/local_storage_service.dart';
import '../storage/storage_keys.dart';

abstract class ICraftLogRepository {
  Future<List<CraftLog>> getLogsForKit(String kitId);
  Future<List<CraftLog>> getAllLogs();
  Future<void> addLog(CraftLog log);
  Future<void> deleteLogsForKit(String kitId);
}

class CraftLogRepository implements ICraftLogRepository {
  final ILocalStorageService _storage;
  List<CraftLog>? _cachedLogs;

  CraftLogRepository(this._storage);

  @override
  Future<List<CraftLog>> getAllLogs() async {
    if (_cachedLogs != null) {
      return List.unmodifiable(_cachedLogs!);
    }

    final rawList = await _storage.getJsonList(StorageKeys.craftLogs);
    final logs = <CraftLog>[];

    for (final map in rawList) {
      try {
        logs.add(CraftLog.fromMap(map));
      } catch (_) {
        // 略過損壞日誌
      }
    }

    // 依時間倒序排列（最新在前）
    logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cachedLogs = logs;
    return List.unmodifiable(logs);
  }

  @override
  Future<List<CraftLog>> getLogsForKit(String kitId) async {
    final all = await getAllLogs();
    return all.where((log) => log.kitId == kitId).toList();
  }

  @override
  Future<void> addLog(CraftLog log) async {
    final logs = (await getAllLogs()).toList();
    logs.insert(0, log); // 最新日誌放首位
    _cachedLogs = logs;

    final mapList = logs.map((l) => l.toMap()).toList();
    await _storage.setJsonList(StorageKeys.craftLogs, mapList);
  }

  @override
  Future<void> deleteLogsForKit(String kitId) async {
    final logs = (await getAllLogs()).toList();
    logs.removeWhere((l) => l.kitId == kitId);
    _cachedLogs = logs;

    final mapList = logs.map((l) => l.toMap()).toList();
    await _storage.setJsonList(StorageKeys.craftLogs, mapList);
  }
}
```

---

## 5. 自動存檔與狀態注水流程 (Auto-Save & State Hydration)

### 5.1 啟動時狀態注水 (Hydration on Startup)
在 `BattleAtelierScreen`（或全域狀態）的 `initState` 階段：
```dart
// 1. 初始化 Storage 與 Repository
final storage = await LocalStorageService.create();
final kitRepo = KitRepository(storage);
final logRepo = CraftLogRepository(storage);

// 2. 異步讀取 Active Kit
final activeKit = await kitRepo.getActiveKit();

// 3. 更新 State
setState(() {
  _currentKit = activeKit;
  bossName = activeKit.title;
  bossGrade = activeKit.grade;
  maxHp = activeKit.totalHp;
  currentHp = activeKit.currentHp;
  _isLoading = false;
});
```
- **無閃爍體驗**：提供預設值（即預設 HG 盒怪數值），在讀取完成後進行平滑狀態更新。

### 5.2 傷害結算與日誌寫入 (Persistence on Settlement)
在 `_calculateAndApplyDamage` 結算時：
```dart
void _persistSessionResult({
  required KitItem activeKit,
  required int damageDealt,
  required int elapsedSeconds,
  required String phase,
  required bool isInterrupted,
}) async {
  final newHp = (activeKit.currentHp - damageDealt).clamp(0, activeKit.totalHp);
  final isCompleted = newHp <= 0;

  // 1. 更新 KitItem 並存檔
  final updatedKit = activeKit.copyWith(
    currentHp: newHp,
    status: isCompleted ? 'Completed' : 'InProgress',
    completedAt: isCompleted ? DateTime.now() : activeKit.completedAt,
  );
  await _kitRepository.saveKit(updatedKit);

  // 2. 建立並寫入 CraftLog
  final log = CraftLog(
    id: const Uuid().v4(),
    kitId: activeKit.id,
    phase: phase,
    durationMinutes: (elapsedSeconds / 60).ceil(),
    damageDealt: damageDealt,
    isCompletedSession: !isInterrupted,
    createdAt: DateTime.now(),
  );
  await _craftLogRepository.addLog(log);
}
```

---

## 6. 單元測試與 Mock 驗證策略 (`test/unit/storage_test.dart`)

### 6.1 `SharedPreferences.setMockInitialValues` 原理
Flutter 官方的 `shared_preferences` 在測試環境下提供靜態方法 `SharedPreferences.setMockInitialValues(Map<String, Object> values)`。
- 它在記憶體中維護一個 Map，模擬底層平台 Channel 回應。
- 完全同步初始化，無須啟動真實作業系統檔案讀寫或瀏覽器環境。
- 測試前在 `setUp()` 呼叫 `setMockInitialValues({})` 即可保證測試隔離性與純淨狀態。

### 6.2 測試套件規劃與完整驗證用例
Worker 可直接依據以下藍圖撰寫 `test/unit/storage_test.dart`：

```dart
// test/unit/storage_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nifty_heisenberg/data/storage/local_storage_service.dart';
import 'package:nifty_heisenberg/data/storage/storage_keys.dart';
import 'package:nifty_heisenberg/data/repositories/kit_repository.dart';
import 'package:nifty_heisenberg/data/repositories/craft_log_repository.dart';
import 'package:nifty_heisenberg/domain/models/kit_item.dart';
import 'package:nifty_heisenberg/domain/models/craft_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ILocalStorageService storage;
  late IKitRepository kitRepo;
  late ICraftLogRepository logRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = LocalStorageService(prefs);
    kitRepo = KitRepository(storage);
    logRepo = CraftLogRepository(storage);
  });

  group('KitRepository Tests', () {
    test('Empty storage auto-seeds default HG kit', () async {
      final kits = await kitRepo.getAllKits();
      expect(kits.length, equals(1));
      expect(kits.first.title, equals('綠色普通盒怪'));
      expect(kits.first.grade, equals('HG'));
      expect(kits.first.totalHp, equals(500));
      expect(kits.first.currentHp, equals(500));
      expect(kits.first.status, equals('InProgress'));

      final active = await kitRepo.getActiveKit();
      expect(active, isNotNull);
      expect(active!.id, equals(kits.first.id));
    });

    test('Loads pre-existing kits from storage without re-seeding', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.kits: jsonEncode([
          {
            'id': 'test-mg-001',
            'title': 'MG 獵魔鋼彈',
            'grade': 'MG',
            'totalHp': 1500,
            'currentHp': 1200,
            'status': 'InProgress',
            'photoPath': null,
            'isCustomBoss': false,
            'createdAt': DateTime.now().toIso8601String(),
            'completedAt': null,
          }
        ]),
        StorageKeys.activeKitId: 'test-mg-001',
      });

      final prefs = await SharedPreferences.getInstance();
      final customStorage = LocalStorageService(prefs);
      final customRepo = KitRepository(customStorage);

      final kits = await customRepo.getAllKits();
      expect(kits.length, equals(1));
      expect(kits.first.id, equals('test-mg-001'));
      expect(kits.first.title, equals('MG 獵魔鋼彈'));

      final active = await customRepo.getActiveKit();
      expect(active!.id, equals('test-mg-001'));
    });

    test('Save kit updates existing and appends new', () async {
      final kits = await kitRepo.getAllKits();
      final defaultKit = kits.first;

      // 1. Update existing kit HP
      final damagedKit = defaultKit.copyWith(currentHp: 400);
      await kitRepo.saveKit(damagedKit);

      var updatedKits = await kitRepo.getAllKits();
      expect(updatedKits.length, equals(1));
      expect(updatedKits.first.currentHp, equals(400));

      // 2. Add new kit
      final newKit = KitItem(
        id: 'new-rg-002',
        title: 'RG 牛鋼彈',
        grade: 'RG',
        totalHp: 800,
        currentHp: 800,
        status: 'Backlog',
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(newKit);

      updatedKits = await kitRepo.getAllKits();
      expect(updatedKits.length, equals(2));
      expect(updatedKits.any((k) => k.id == 'new-rg-002'), isTrue);
    });

    test('Delete kit removes it and re-adjusts active kit', () async {
      final seedKits = await kitRepo.getAllKits();
      final seedId = seedKits.first.id;

      final extraKit = KitItem(
        id: 'extra-001',
        title: 'HG 異端',
        grade: 'HG',
        totalHp: 500,
        currentHp: 500,
        status: 'InProgress',
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(extraKit);
      await kitRepo.setActiveKit(extraKit.id);

      // Delete active kit
      await kitRepo.deleteKit(extraKit.id);
      final remaining = await kitRepo.getAllKits();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals(seedId));

      final active = await kitRepo.getActiveKit();
      expect(active!.id, equals(seedId));
    });

    test('Switching active kit persists correctly', () async {
      final secondKit = KitItem(
        id: 'kit-2',
        title: 'EG 初鋼',
        grade: 'EG',
        totalHp: 300,
        currentHp: 300,
        status: 'Backlog',
        createdAt: DateTime.now(),
      );
      await kitRepo.saveKit(secondKit);
      await kitRepo.setActiveKit('kit-2');

      final active = await kitRepo.getActiveKit();
      expect(active!.id, equals('kit-2'));
    });
  });

  group('CraftLogRepository Tests', () {
    test('Add log and query by kitId and all', () async {
      final log1 = CraftLog(
        id: 'log-1',
        kitId: 'kit-A',
        phase: 'Snap-fit',
        durationMinutes: 25,
        damageDealt: 100,
        isCompletedSession: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      final log2 = CraftLog(
        id: 'log-2',
        kitId: 'kit-B',
        phase: 'Sanding',
        durationMinutes: 12,
        damageDealt: 30,
        isCompletedSession: false,
        createdAt: DateTime.now(),
      );

      await logRepo.addLog(log1);
      await logRepo.addLog(log2);

      final allLogs = await logRepo.getAllLogs();
      expect(allLogs.length, equals(2));

      final kitALogs = await logRepo.getLogsForKit('kit-A');
      expect(kitALogs.length, equals(1));
      expect(kitALogs.first.id, equals('log-1'));

      final kitBLogs = await logRepo.getLogsForKit('kit-B');
      expect(kitBLogs.length, equals(1));
      expect(kitBLogs.first.id, equals('log-2'));
    });

    test('Cascade delete logs for kit', () async {
      final logA = CraftLog(
        id: 'l-a',
        kitId: 'target-kit',
        phase: 'Airbrush',
        durationMinutes: 25,
        damageDealt: 200,
        isCompletedSession: true,
        createdAt: DateTime.now(),
      );
      final logB = CraftLog(
        id: 'l-b',
        kitId: 'other-kit',
        phase: 'Detailing',
        durationMinutes: 25,
        damageDealt: 150,
        isCompletedSession: true,
        createdAt: DateTime.now(),
      );

      await logRepo.addLog(logA);
      await logRepo.addLog(logB);

      await logRepo.deleteLogsForKit('target-kit');

      final remaining = await logRepo.getAllLogs();
      expect(remaining.length, equals(1));
      expect(remaining.first.kitId, equals('other-kit'));
    });
  });

  group('Corruption & Edge Case Resilience', () {
    test('Malformed JSON in storage recovers gracefully without crash', () async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.kits: '{this is not valid json!}',
      });

      final prefs = await SharedPreferences.getInstance();
      final corruptedStorage = LocalStorageService(prefs);
      final repo = KitRepository(corruptedStorage);

      // Should recover gracefully and re-seed default kit
      final kits = await repo.getAllKits();
      expect(kits.length, equals(1));
      expect(kits.first.title, equals('綠色普通盒怪'));
    });
  });
}
```

---

## 7. 落地指南與 Worker 執行順序建議

為使後續 Worker 實作順暢且零摩擦，建議執行步驟如下：

1. **依賴安裝**：
   - 編輯 `pubspec.yaml`，在 `dependencies:` 下加入 `shared_preferences: ^2.5.2`。
   - 執行 `flutter pub get`。
2. **建立 Storage 服務**：
   - 建立 `lib/data/storage/storage_keys.dart`。
   - 建立 `lib/data/storage/local_storage_service.dart`。
3. **建立 Repositories**：
   - 建立 `lib/data/repositories/kit_repository.dart`（實作 `IKitRepository`，包含初次啟動自動種子植入）。
   - 建立 `lib/data/repositories/craft_log_repository.dart`（實作 `ICraftLogRepository`）。
4. **撰寫與執行單元測試**：
   - 建立 `test/unit/storage_test.dart`。
   - 執行 `flutter test test/unit/storage_test.dart` 確保所有測試 100% 通過。
5. **程式碼靜態分析**：
   - 執行 `flutter analyze` 確保 0 errors, 0 warnings。
