# HANDOFF — Explorer 2 for Milestone 2: Storage Architecture & Repositories

- **Role**: `teamwork_preview_explorer` (Explorer 2 for Milestone 2)
- **Working Directory**: `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\teamwork_preview_explorer_m2_2`
- **Parent Conversation ID**: `6fa20b7c-dc2d-40cc-9d90-84e64adeddcf`
- **Date**: 2026-09-11
- **Target Audience**: Orchestrator & Milestone 2 Worker

---

## 1. Observation

### 1.1 `pubspec.yaml` 依賴現狀
在 `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\pubspec.yaml` 第 30-39 行直接觀察到：
```yaml
dependencies:
  flutter:
    sdk: flutter

  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  cupertino_icons: ^1.0.8
  google_fonts: ^6.2.1
  uuid: ^4.6.0
```
- **現狀**：尚未引入 `shared_preferences`。`uuid: ^4.6.0` 已就緒可用於產生實體 ID。

### 1.2 `PROJECT.md` 之介面契約定義
在 `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\PROJECT.md` 第 90-104 行直接觀察到：
```dart
abstract class IKitRepository {
  Future<List<KitItem>> getAllKits();
  Future<KitItem?> getActiveKit();
  Future<void> saveKit(KitItem kit);
  Future<void> deleteKit(String kitId);
  Future<void> setActiveKit(String kitId);
}

abstract class ICraftLogRepository {
  Future<List<CraftLog>> getLogsForKit(String kitId);
  Future<List<CraftLog>> getAllLogs();
  Future<void> addLog(CraftLog log);
}
```
- **代碼組織路徑 (Lines 112-114)**：
  - `lib/data/storage/local_storage_service.dart`
  - `lib/data/repositories/kit_repository.dart`
  - `lib/data/repositories/craft_log_repository.dart`

### 1.3 `SPEC.md` §7 之資料表與級聯約束
在 `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\SPEC.md` 第 147-170 行直接觀察到：
```sql
CREATE TABLE KitItem (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    grade TEXT NOT NULL,
    totalHp INTEGER NOT NULL,
    currentHp INTEGER NOT NULL,
    status TEXT NOT NULL,
    photoPath TEXT,
    isCustomBoss INTEGER DEFAULT 0,
    createdAt TEXT NOT NULL,
    completedAt TEXT
);

CREATE TABLE CraftLog (
    id TEXT PRIMARY KEY,
    kitId TEXT NOT NULL,
    phase TEXT NOT NULL,
    durationMinutes INTEGER NOT NULL,
    damageDealt INTEGER NOT NULL,
    isCompletedSession INTEGER NOT NULL,
    createdAt TEXT NOT NULL,
    FOREIGN KEY (kitId) REFERENCES KitItem(id) ON DELETE CASCADE
);
```
- 當刪除模型時，必須級聯清除關聯之 `CraftLog`。

### 1.4 `main.dart` 現行狀態硬編碼
在 `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\lib\main.dart` 第 43-47 行直接觀察到：
```dart
  // --- Boss & Player State ---
  final String bossName = '綠色普通盒怪';
  final String bossGrade = 'HG 1/144';
  final int maxHp = 500;
  int currentHp = 500;
  int userCoins = 150; // 廢流道塑料金幣
```
- 目前模型狀態為完全寫死於 State 的單一盒怪，尚無持久化載入或儲存機制。

### 1.5 測試執行工具鏈現況
執行 `flutter test test/unit/battle_engine_test.dart` 與 `flutter test test/unit/battle_engine_adversarial_test.dart`：
- 全部 47 項單元與對抗測試通過（Exit Code: 0），耗時小於 3 秒。
- 專案已具備高效快速的單元測試運行環境。

---

## 2. Logic Chain

1. **依據 Observation 1.1**，目前專案無任何本地持久化套件。若要實現 R2（重新整理與重啟程式資料不遺失），必須引入跨平台離線儲存機制。
2. **依據 Observation 1.1 與 1.2 及 `environment_analysis.md`**：
   - SQLite WASM（`sqflite_common_ffi_web` / `drift`）在 Web 端依賴 `SharedArrayBuffer` 與特製 CORS Headers，部署於 GitHub Pages 等靜態環境極易失敗。
   - 純檔案讀寫（`dart:io`）在 Web 編譯時拋出 `UnsupportedError`。
   - `shared_preferences` 在 Web 端自動對應 `window.localStorage`，在 Windows 桌面端自動對應本地 AppData JSON 檔，具有零 native compile 依賴、100% 離線、零金錢成本的特性。
3. **依據 Observation 1.2 與 1.3**：
   - 介面契約必須完全實作 `IKitRepository`（5 個方法）與 `ICraftLogRepository`（3 個方法）。
   - 為了達成 `FOREIGN KEY ... ON DELETE CASCADE`，在 `ICraftLogRepository` 擴充 `deleteLogsForKit(String kitId)`，並於刪除模型時協同調用。
4. **依據 Observation 1.4 與 DISPATCH.md**：
   - 初次啟動時，若儲存為空，`KitRepository` 自動植入預設 HG 盒怪（`綠色普通盒怪`, HG, 500 HP, InProgress），並設定其為 `activeKit`，確保應用程式於第一次啟動即具備即時可玩性，不會因找不到盒怪拋出例外。
5. **依據 Observation 1.5**：
   - `SharedPreferences.setMockInitialValues` 支援純記憶體模擬，使 `test/unit/storage_test.dart` 無須 mockito/mocktail 即可進行 100% 覆蓋的快速單元測試。

---

## 3. Caveats

1. **儲存容量邊界**：
   - 瀏覽器 `localStorage` 上限通常為 5MB~10MB。若單一玩家累積數萬筆施工紀錄，長遠可考慮分頁或匯出歸檔。但對於數十盒模型與幾百筆日誌（總大小 < 300KB），`shared_preferences` 完全游刃有餘。
2. **多頁面併發寫入**：
   - 若使用者在 Web 上同時開啟多個瀏覽器分頁操作不同戰鬥，分頁間的 `localStorage` 變更需重整後載入（屬於本機單人遊戲正常行為）。
3. **模型與日誌定義依賴**：
   - 本架構依賴 Explorer 1 產出之 `KitItem` 與 `CraftLog` 模型及其 `toMap()` / `fromMap()` 實作。兩者已依據 `SPEC.md §7` 保持嚴格一致的欄位命名。

---

## 4. Conclusion

1. **技術選型確定**：在 `pubspec.yaml` 中新增 `shared_preferences: ^2.5.2`，並採用純 JSON 序列化儲存引擎（封裝於 `LocalStorageService`）。
2. **目錄與代碼組織**：
   - `lib/data/storage/storage_keys.dart`：集中管理 `tsumi_pura_kits_v1`、`tsumi_pura_craft_logs_v1`、`tsumi_pura_active_kit_id_v1`。
   - `lib/data/storage/local_storage_service.dart`：提供 `ILocalStorageService` 與安全解析 JSON 陣列之實作。
   - `lib/data/repositories/kit_repository.dart`：實作 `IKitRepository`，內建記憶體快取與初次啟動自動種子（'綠色普通盒怪', HG, 500 HP）。
   - `lib/data/repositories/craft_log_repository.dart`：實作 `ICraftLogRepository`，支援追加日誌、依模型過濾與級聯清除。
3. **驗證就緒**：已於 `analysis.md` 提供完整的 `test/unit/storage_test.dart` 測試實作，覆蓋種子植入、CRUD、切換 Active Kit、級聯刪除與惡意損壞 JSON 容錯。

---

## 5. Verification Method

### 5.1 依賴安裝驗證
```powershell
flutter pub get
```
- **預期結果**：無衝突順利取得 `shared_preferences` 與其平台實作，Exit Code: 0。

### 5.2 單元測試驗證
建立並執行儲存層單元測試：
```powershell
flutter test test/unit/storage_test.dart
```
- **預期結果**：
  - `Empty storage auto-seeds default HG kit` 通過。
  - `Loads pre-existing kits from storage without re-seeding` 通過。
  - `Save kit updates existing and appends new` 通過。
  - `Delete kit removes it and re-adjusts active kit` 通過。
  - `Switching active kit persists correctly` 通過。
  - `Add log and query by kitId and all` 通過。
  - `Cascade delete logs for kit` 通過。
  - `Malformed JSON in storage recovers gracefully without crash` 通過。
  - 所有測試用例均通過，Exit Code: 0。

### 5.3 靜態分析驗證
```powershell
flutter analyze
```
- **預期結果**：0 errors, 0 warnings。

### 5.4 失效條件 (Invalidation Conditions)
若發生以下情況，本報告結論應予修正或重新設計：
- 專案強制要求原生關聯性查詢（如 SQL JOIN 語句），而非純 Dart 記憶體篩選。
- Web 端部署環境保證具備完整的 COOP/COEP Headers，且決定採用 WASM SQLite。
