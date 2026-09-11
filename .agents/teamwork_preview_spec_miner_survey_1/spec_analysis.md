# 《罪普拉 RPG（Tsumi-Pura RPG）》規格挖掘與需求分析報告
**檔案路徑**: `spec_analysis.md`  
**探查人員**: Specification Miner (`teamwork_preview_spec_miner_survey_1`)  
**基準規格來源**:
1. `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\SPEC.md` (技術規格真理來源)
2. `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\.agents\ORIGINAL_REQUEST.md` (專案目標與驗收標準)
3. `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\lib\main.dart` (現行 Flutter MVP 原型程式碼)
4. `c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg\pubspec.yaml` (依賴套件與資產清單)

---

## 1. 專案背景與規格定位

《罪普拉 RPG》是一款將模型玩家「山積模型（積みプラ）」心理負擔轉化為「像素 RPG 盒怪討伐」的模型製作輔助遊戲。玩家以專注工時（番茄鐘）作為攻擊能量，使用剪鉗、砂紙、推刀、噴筆與水貼等工序技能，對具象化的盒怪造成傷害，淨化山積並收納至展示櫃。

### 核心原則 (Guiding Principles)
- **零額外金錢開銷 (Zero Monetary Cost)**：不依賴任何外部付費訂閱、雲端資料庫或付費 LLM API Token，純本機開源運作。
- **雙平台離線可用 (Offline Windows & Web)**：本機持久化儲存，重新整理或重啟程式進度絕不遺失。
- **像素復古美學 (Retro 8-Bit Game Juice)**：嚴格維持像素字體、血條、介面與打擊回饋的一致性。

---

## 2. 規格特性全清單 (Features Discovered)

依照系統規範，以下為從 `SPEC.md`、`ORIGINAL_REQUEST.md` 與現有程式碼中探查並挖掘出的完整特性清單：

| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | R1: 戰鬥引擎 | 標準 25m 番茄鐘循環 | 25 分鐘工作專注階段，換算 100 基礎攻擊點數 (BP)，倒數計時並持續更新剩餘時間 | 點擊「開始開工 (25m)」按鈕 | 計時器啟動，每秒倒數，HUD 更新時間文字 | 若當前已在計時中或 Boss HP <= 0，點擊無效且被阻擋 | `SPEC.md` §2.1, `ORIGINAL_REQUEST.md` §R1, `main.dart`:114-141 |
| 2 | R1: 戰鬥引擎 | 5 秒快速測試/除錯模式 | 5 秒專注測試階段，換算 100 基礎點數，供開發、自動化測試與演示驗證 | 點擊「5秒測試」按鈕 | 5 秒高速倒數完結，結算 100 BP 滿額傷害 | 計時中或 HP <= 0 被阻擋 | `SPEC.md` §2.1, `main.dart`:124, 978-991 |
| 3 | R1: 戰鬥引擎 | 50m 深度專注工時模式 | 50 分鐘連續深度工作階段，換算 220 基礎點數（含 10% 專注獎勵） | 選擇「深度開工 (50m)」 | 計時器設置 3,000 秒，結算給予防禦突破加成傷害 | 重複啟動無效 | `SPEC.md` §2.1 |
| 4 | R1: 戰鬥引擎 | 5m 休息間歇模式 | 專注完成後進入 5 分鐘休息倒數，恢復玩家活力並提供休憩提示 | 工作階段結束自動觸發或點擊「休息」 | 300 秒休息倒數，切換至休息 HUD 介面 | 休息中不得發動攻擊 | `ORIGINAL_REQUEST.md` §R1 |
| 5 | R1: 工序矩陣 | 素組 (Snap-fit) 技能 | 仮組み，1.0x 基礎普攻，穩定累積連擊條 (Combo Bar)，不消耗額外精神力 | 選擇 SegmentedButton「素組」 | 造成 $\text{BP} \times 1.0$ 傷害，對話框提示剪鉗連擊 | 計時中切換工序無效（鎖定工序） | `SPEC.md` §2.2, `main.dart`:68, 76, 84, 831 |
| 6 | R1: 工序矩陣 | 打磨 (Sanding) 技能 | ヤスリ掛け，1.2x 破甲穿刺，削弱 Boss 防禦，每次命中提升後續傷害 2%（上限 +20%） | 選擇 SegmentedButton「打磨」 | 造成 $\text{BP} \times 1.2 \times (1 + \text{疊層})$ 傷害，疊加破甲狀態 | 對電鍍怪傷害減半 (0.6x) | `SPEC.md` §2.2, §3, `main.dart`:69, 77, 85, 839 |
| 7 | R1: 工序矩陣 | 刻線 (Detailing) 技能 | スジ彫り，1.5x 弱點打擊，高暴擊率，擊中判定點觸發額外 1.5x 暴擊 (總倍率 2.25x) | 選擇 SegmentedButton「刻線」 | 造成 $\text{BP} \times 1.5$ 傷害，機率觸發暴擊對話與大數字 | 命中判定失誤維持原 1.5x | `SPEC.md` §2.2, `main.dart`:70, 78, 86, 847 |
| 8 | R1: 工序矩陣 | 噴塗 (Airbrush) 技能 | エアブラシ，2.0x 元素蓄力轟炸，雙倍範圍重擊，小人配戴防毒面具並觸發排風特效 | 選擇 SegmentedButton「噴塗」 | 造成 $\text{BP} \times 2.0$ 傷害，對話框提示漆霧轟炸 | 冷卻或蓄力條件未達時不可連續發動 | `SPEC.md` §2.2, §4.2, `main.dart`:71, 79, 87, 855 |
| 9 | R1: 工序矩陣 | 水貼處決 (Finishing) | デカール・仕上げ，2.5x 終結處決技，**嚴格限定 Boss 殘血 20% 以下**方可解鎖發動 | Boss HP/MaxHP <= 0.20 時選擇「水貼」 | 造成 $\text{BP} \times 2.5$ 毀滅性傷害，處決淨化盒怪 | 若殘血 > 20%，按鈕顯示鎖定圖示，點擊彈出 SnackBar 警告並阻擋 | `SPEC.md` §2.2, `main.dart`:72, 80, 88, 118, 863-871 |
| 10 | R1: 戰鬥引擎 | 中斷保底 (Mercy Rule) | 因現實突發狀況中途急停時，按進度比例計算並給予保底 50% 傷害，絕不歸零 | 專注中點擊「中途中斷」按鈕 | 計算 $\text{BP} \times \frac{T_{\text{elapsed}}}{T_{\text{total}}} \times \text{Mult} \times 0.5$，扣血並掉落金幣 | 若已耗時 0 秒則不扣血且不給幣 | `SPEC.md` §2.3, `ORIGINAL_REQUEST.md` §R1, `main.dart`:143-162, 188-190 |
| 11 | R1: 戰鬥引擎 | 匠人天賦樹 (Talents) | 被動提升中斷保底趴數：Lv.1 50%、Lv.5 70%、Lv.10 90% | 累積工時升級匠人等級 | 提高 Mercy Rule 保底係數 (0.50 -> 0.70 -> 0.90) | 等級不足無法享受高保底 | `SPEC.md` §2.3 |
| 12 | R2: 資料架構 | 模型項目實體 (KitItem) | 儲存盒怪/模型的核心實體：包含 id, title, grade, totalHp, currentHp, status, photoPath, isCustomBoss, createdAt, completedAt | 模型建立或載入 | 提供資料模型物件與 JSON / Map 序列化 | 缺少必填欄位或型態不符時拋出驗證異常 | `SPEC.md` §7, `ORIGINAL_REQUEST.md` §R2 |
| 13 | R2: 資料架構 | 施工紀錄實體 (CraftLog) | 儲存每次番茄鐘開工日誌：包含 id, kitId, phase, durationMinutes, damageDealt, isCompletedSession, createdAt | 開工完成或中途中斷結算 | 新增一筆記錄並與對應 KitItem 關聯 | kitId 不存在時違反外鍵約束 (CASCADE) | `SPEC.md` §7, `ORIGINAL_REQUEST.md` §R2 |
| 14 | R2: 持久化 | 跨平台本地離線持久化 | 離線本機儲存機制，確保在 Windows (桌面) 與 Web (瀏覽器) 重整/重啟後資料皆完整保留 | KitItem / CraftLog 狀態變更 | 自動序列化寫入本機資料庫/儲存層，啟動時反序列化載入 | 本機儲存失敗時捕獲例外並降級快取 | `SPEC.md` §7, `ORIGINAL_REQUEST.md` §R2 |
| 15 | R2: 資料架構 | 工作室家具 (FurnitureItem) | 儲存家具解鎖與擺放狀態：包含 id, name, type, isUnlocked, isPlaced, gridX, gridY, unlockRequirement | 金幣購買或成就里程碑解鎖 | 提供家具清單與 2.5D 網格座標 | 未解鎖家具不可擺放 | `SPEC.md` §7, §4 |
| 16 | R2: 資料架構 | 玩家設定檔 (UserProfile) | 儲存玩家個人檔案：包含 id, nickname, avatarPixelPath, rankTitle, coins, focusStreakDays | 遊戲啟動與獲得金幣/連續天數 | 讀取目前暱稱、稱號、塑料金幣餘額與連擊天數 | 負數金幣非法 | `SPEC.md` §7, §1.2 |
| 17 | R3: 機庫管理 | 模型新增 (Create Kit) | 玩家自定義登錄新山積模型，輸入標題、選擇級別、指定預設或自訂 HP | 表單輸入名稱、級別 (EG/HG/RG/MG/PG/GK)、血量數值 | 建立狀態為 Backlog 的 KitItem 並加入清單 | 標題為空或血量 <= 0 報錯提示 | `SPEC.md` §3, §7, `ORIGINAL_REQUEST.md` §R3 |
| 18 | R3: 機庫管理 | 級別與預設 HP 對應矩陣 | 各模型規格具備標準預設血量：EG: 300, HG: 500, RG: 800, MG: 1500, PG/GK: 5000 | 選擇模型等級下拉選單 | 自動帶入對應推薦血量，亦允許手動自訂修改 | 未知等級使用預設 500 HP | `SPEC.md` §3, `ORIGINAL_REQUEST.md` §R3 |
| 19 | R3: 機庫管理 | 模型編輯 (Update Kit) | 允許修改尚未完工模型的標題、級別或更換代表照片 | 編輯對話框提交新資料 | 即時更新模型項目屬性並持久化存檔 | 完工模型不可竄改血量 | `ORIGINAL_REQUEST.md` §R3 |
| 20 | R3: 機庫管理 | 模型刪除 (Delete Kit) | 刪除不再追蹤的山積模型，支援級聯刪除 (Cascade) 其施工紀錄 | 點擊刪除確認按鈕 | 自機庫與資料庫移除該項目與關聯 CraftLog | 刪除正在討伐中模型時自動清空當前戰鬥 | `SPEC.md` §7, `ORIGINAL_REQUEST.md` §R3 |
| 21 | R3: 討伐狀態機 | 模型狀態變更 (Status Transition) | 模型狀態生命週期：Backlog (山積待建) -> InProgress (施工討伐中) -> Completed (討伐成功已完工) | 選擇模型出戰 / 戰鬥扣血 / 血量歸零 | 更新 status 欄位並記錄 completedAt 時間戳記 | 非法狀態轉換被拒絕 | `SPEC.md` §7 |
| 22 | R3: 完工展櫃 | 像素玻璃展示櫃 (Showcase) | 討伐成功的模型陳列於展櫃，展示模型名稱、級別、完工日期、總累積工時與工序圓餅圖 | 點擊導航進入展櫃視圖 | 呈現陳列貨架清單，支援點擊檢視詳細身分證銘牌與 CraftLog 歷程 | 展櫃為空時顯示空置引導 | `SPEC.md` §4.2, §5.1, `ORIGINAL_REQUEST.md` §R3 |
| 23 | R4: 視覺反饋 | 像素血條與漸層色彩 | 像素外框血條，隨剩餘血量動態變換顏色（>50% 綠色、20%~50% 橙黃色、<20% 警示鮮紅色） | currentHp 與 maxHp 比值 | 渲染 FractionallySizedBox 像素漸層色條與百分比文字 | 溢出時 clamp 在 0%~100% | `main.dart`:515-604 |
| 24 | R4: 視覺反饋 | 打擊震屏與受創紅光 | 造成傷害時觸發戰鬥舞台水平震顫動畫 (Sine Wave)，盒怪 Sprite 疊加紅色受創濾鏡 | 結算傷害時調用 `_triggerHitJuice` | 舞台晃動 400ms，盒怪閃爍紅色受創視覺 | 避免連續重複調用導致動畫控制器崩潰 | `main.dart`:59, 196-236, 608-683 |
| 25 | R4: 視覺反饋 | 漂浮彈跳傷害數字 | 命中時於盒怪上方彈出像素方塊字型數字，區分一般暴擊 (-XX) 與 Mercy 保底 (-XX MERCY 50%) | 結算傷害數值與中斷標記 | 渲染帶有外框的黃/紅/琥珀色浮動標籤 | 傷害為 0 時不顯示或顯示 MISS | `main.dart`:61, 220-227, 730-753 |
| 26 | R4: 視覺反饋 | 角色呼吸與動作動畫 | 勇者與盒怪具備循環待機呼吸 (Scale/Translate)，開工倒數時動作頻率與姿勢響應 | `_idleController` (1400ms repeat) | 像素小人與盒怪上下微動，營造復古街機動態感 | 關閉頁面時 dispose 控制器避免記憶體洩漏 | `main.dart`:58, 94-98, 649-727 |
| 27 | R4: 視覺反饋 | 8-Bit 復古對話框 | 底部黑底紫框像素對話框，以打字機或行動日誌顯示工序招式動作與傷害提示 | 狀態變更與攻擊觸發字串 | 渲染「▶」符號引導的 monospace 多行對話框 | 長文字自動換行不破版 | `main.dart`:759-787 |
| 28 | R4: 音效系統 | 零花費 8-Bit 復古音效 | 不花費付費授權，使用開源無版權音效（或 WebAudio/合成器音調），提供按鈕點擊、開工鈴、打擊暴擊、完工喇叭聲 | 使用者互動與戰鬥事件觸發 | 播放短促 8-bit 方波/三角波 Retro Sound 效果音 | 靜音或離線無音訊設備時優雅降級不報錯 | `ORIGINAL_REQUEST.md` §R4, §驗收標準 |
| 29 | 擴充: 經濟系統 | 廢流道塑料金幣回收 | 專注時間依比例掉落塑料金幣（每專注 1 分鐘 = 1 金幣，中途急停給予保底獎勵），用於解鎖家具 | actualElapsedSeconds | 更新玩家 UserProfile.coins 餘額並於 Header HUD 顯示 | 金幣增加需原子化更新 | `SPEC.md` §1.2, §4.3, `main.dart`:45, 193-195 |
| 30 | 擴充: 工坊系統 | 2.5D 動森風工作室光影 | 45 度俯視角像素工作室，隨本機真實系統時間切換白天、黃昏、深夜環境氛圍光 | DateTime.now().hour | 調整畫面環境遮罩透明度與色調（柔白、橘紅、暗夜黃燈） | 時間解析異常使用預設白天 | `SPEC.md` §4.1 |
| 31 | 擴充: 盒怪特異 | 特殊盒怪屬性機制 | PB限定幽靈（時間飄移）、電鍍黃金石像（打磨傷害減半0.6x/暴擊2.0x）、彩透怪（水口白化反噬扣活力）、深淵巨神兵（雙階段骨架/外甲血條） | 遭遇特定怪物種類 | 戰鬥引擎動態套用防禦倍率與特殊反饋 | 未定義屬性退回普通怪規格 | `SPEC.md` §3 |
| 32 | 擴充: 社群圖卡 | 完工戰報圖卡生成 | 討伐完成時產生包含破盒盒怪、完工資訊、總工時與 QR Code 的戰報圖卡，提供存檔與分享 | 點擊「生成戰報圖卡」 | 繪製 9:16 或 1:1 像素卡片畫面 | 離線環境不呼叫外部雲端轉發 | `SPEC.md` §5.2 |

---

## 3. 核心需求 R1 ~ R4 深度剖析與數值架構

### 3.1 R1: 完整番茄鐘與戰鬥循環 (Pomodoro & Battle Engine)

#### (1) 計時循環架構
- **專注工作階段 (Work Session)**：
  - 標準模式：25 分鐘 ($1,500$ 秒)，基礎點數 $\text{Base Points} = 100$。
  - 深度模式：50 分鐘 ($3,000$ 秒)，基礎點數 $\text{Base Points} = 220$（計算：$200 \times 1.10 = 220$）。
  - 快速除錯測試模式 (Fast Debug Mode)：5 秒，基礎點數 $\text{Base Points} = 100$。
- **休息間歇階段 (Break Session)**：
  - 標準休息：5 分鐘 ($300$ 秒)。
  - 狀態流轉：`Idle` $\rightarrow$ `WorkSession` $\rightarrow$ `SessionSettlement` $\rightarrow$ `BreakSession` $\rightarrow$ `Idle`。

#### (2) 5 大工序傷害矩陣 (Craft Multipliers Matrix)
| 工序識別碼 (Phase Enum) | 工序名稱 | 倍率 ($M_{\text{phase}}$) | 特殊解鎖 / 戰鬥觸發條件 | 技能機制與視覺連動 |
|:---|:---|:---:|:---|:---|
| `Snap-fit` | 剪件/素組 | **1.0x** | 無條件解鎖（預設） | 普攻連擊，剪斷水口，小人揮舞單刃剪鉗 |
| `Sanding` | 修件打磨 | **1.2x** | 無條件解鎖 | 破甲打磨，每次命中給予 Boss 2% 易傷，上限 +20% |
| `Detailing` | 刻線/改件 | **1.5x** | 無條件解鎖 | 弱點刻線，擊中判定點有額外 1.5x 暴擊判定 |
| `Airbrush` | 遮蓋/噴塗 | **2.0x** | 無條件解鎖（可附加冷卻） | 漆霧重砲，角色自動切換為戴防毒面具造型 |
| `Finishing` | 水貼/消光 | **2.5x** | **限定 $\frac{\text{CurrentHP}}{\text{TotalHP}} \le 20\%$** | 終結處決技；未達標時按鈕禁用並鎖定，強行點擊彈出紅色警告 |

#### (3) 中斷保底機制 (Mercy Rule) 數學公式
當玩家在專注中途手動點擊「中途中斷」時，系統依照已執行時間比例計算傷害，並乘上 50% 保底折減係數：

$$\text{Damage}_{\text{interrupted}} = \text{round}\left( \text{BasePoints} \times \frac{t_{\text{elapsed}}}{t_{\text{total}}} \times M_{\text{phase}} \times 0.50 \right)$$

- **範例 1**：25 分鐘標準素組 ($M=1.0$)，進行至 12 分 30 秒 ($t_{\text{elapsed}}=750$s) 中斷：
  $$\text{Damage} = \text{round}\left( 100 \times \frac{750}{1500} \times 1.0 \times 0.5 \right) = \text{round}(25.0) = 25$$
- **範例 2**：25 分鐘噴塗 ($M=2.0$)，進行至 20 分鐘 ($t_{\text{elapsed}}=1200$s) 中斷：
  $$\text{Damage} = \text{round}\left( 100 \times \frac{1200}{1500} \times 2.0 \times 0.5 \right) = \text{round}(80.0) = 80$$
- **範例 3 (快速除錯)**：5 秒測試打磨 ($M=1.2$)，進行至 3 秒中斷：
  $$\text{Damage} = \text{round}\left( 100 \times \frac{3}{5} \times 1.2 \times 0.5 \right) = \text{round}(36.0) = 36$$
- **滿額完成公式 (Complete Session)**：
  $$\text{Damage}_{\text{complete}} = \text{round}\left( \text{BasePoints} \times 1.0 \times M_{\text{phase}} \right)$$
  - 25m 素組滿額：$100$
  - 25m 打磨滿額：$120$
  - 25m 刻線滿額：$150$
  - 25m 噴塗滿額：$200$
  - 25m 水貼滿額：$250$
- **保底掉落塑料金幣**：
  $$\text{Coins} = \text{clamp}\left( \text{round}\left(\frac{t_{\text{elapsed}}}{5}\right), 2, 50 \right)$$

---

### 3.2 R2: 本地資料庫持久化與歷史日誌 (Persistence & CraftLog)

#### (1) 資料庫 Schema 設計
本專案為零花費純本機架構，採用關聯式結構，支援 Windows (SQLite/FFI 或本機檔案) 與 Web (localStorage / IndexedDB / Web SQLite)：

```sql
-- 模型項目資料表 (KitItem)
CREATE TABLE KitItem (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    grade TEXT NOT NULL, -- 'EG', 'HG', 'RG', 'MG', 'PG', 'GK'
    totalHp INTEGER NOT NULL,
    currentHp INTEGER NOT NULL,
    status TEXT NOT NULL, -- 'Backlog', 'InProgress', 'Completed'
    photoPath TEXT,
    isCustomBoss INTEGER DEFAULT 0,
    createdAt TEXT NOT NULL, -- ISO-8601
    completedAt TEXT         -- ISO-8601, null if not completed
);

-- 施工紀錄日誌資料表 (CraftLog)
CREATE TABLE CraftLog (
    id TEXT PRIMARY KEY,
    kitId TEXT NOT NULL,
    phase TEXT NOT NULL, -- 'Snap-fit', 'Sanding', 'Detailing', 'Airbrush', 'Finishing'
    durationMinutes INTEGER NOT NULL,
    damageDealt INTEGER NOT NULL,
    isCompletedSession INTEGER NOT NULL, -- 1: 完整完成, 0: 中途中斷
    createdAt TEXT NOT NULL, -- ISO-8601
    FOREIGN KEY (kitId) REFERENCES KitItem(id) ON DELETE CASCADE
);

-- 工作室家具資料表 (FurnitureItem)
CREATE TABLE FurnitureItem (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL, -- 'Workbench', 'Booth', 'Showcase', 'Decoration'
    isUnlocked INTEGER DEFAULT 0,
    isPlaced INTEGER DEFAULT 0,
    gridX INTEGER DEFAULT 0,
    gridY INTEGER DEFAULT 0,
    unlockRequirement TEXT
);

-- 玩家個人設定 (UserProfile)
CREATE TABLE UserProfile (
    id TEXT PRIMARY KEY,
    nickname TEXT NOT NULL DEFAULT '模型工匠',
    avatarPixelPath TEXT,
    rankTitle TEXT NOT NULL DEFAULT '剪鉗學徒',
    coins INTEGER DEFAULT 0,
    focusStreakDays INTEGER DEFAULT 0
);
```

#### (2) 跨平台離線儲存相容策略
- **Windows Desktop**：使用本機檔案系統讀寫或 SQLite，零網路依賴。
- **Web Browser**：使用 `shared_preferences`、IndexedDB 或 Web Storage API。在瀏覽器端，重新整理頁面 (F5) 或關閉重開時，資料需完整存在。
- **資料庫訪問抽象層 (Repository Pattern)**：
  - 定義介面 `IKitRepository`、`ICraftLogRepository`、`IUserProfileRepository`。
  - 提供本地實作，屏蔽 Windows 與 Web 底層存儲媒介差異。

---

### 3.3 R3: 堆積模型機庫與展示櫃 (Model Hangar & Showcase Gallery)

#### (1) 模型階級與血量規則 (Grade Matrix & HP Mapping)
機庫支援 6 大模型規格，提供標準推薦血量與完全自訂血量：
| 規格代號 | 規格全稱 | 模型比例與特性 | 預設推薦血量 (HP) | 討伐估計番茄數 (以素組換算) |
|:---:|:---|:---|:---:|:---:|
| **EG** | Entry Grade | 1/144 入門免工具免膠水 | **300 HP** | 3 顆番茄 (75 分鐘) |
| **HG** | High Grade | 1/144 標準分色普遍款 | **500 HP** | 5 顆番茄 (125 分鐘) |
| **RG** | Real Grade | 1/144 骨架外甲高精細度 | **800 HP** | 8 顆番茄 (200 分鐘) |
| **MG** | Master Grade | 1/100 完整骨架連動機構 | **1,500 HP** | 15 顆番茄 (375 分鐘) |
| **PG** | Perfect Grade | 1/60 頂級旗艦雙層裝甲 | **5,000 HP** | 50 顆番茄 (1,250 分鐘) |
| **GK** | Garage Kit | 樹脂白模/高難度打磨修件 | **3,000 HP** | 30 顆番茄 (750 分鐘) |
- **自訂血量 (Custom HP)**：建立時可自行填寫正整數（下限 100 HP，上限 99,999 HP）。

#### (2) 機庫 CRUD 規格
- **Create (登錄山積)**：彈出像素對話框，輸入模型名稱（必填，上限 50 字元）、選擇階級下拉選單、自訂/預設血量切換開關、可選相片路徑。
- **Read (檢視機庫)**：按狀態分類標籤切換：
  - 待討伐山積 (`Backlog`)
  - 施工討伐中 (`InProgress`)
  - 完工展示櫃 (`Completed`)
- **Update (編輯模型)**：允許修改名稱、調整設定；若當前正在討伐該模型，同步更新戰鬥畫面中的 Boss 名稱與規格。
- **Delete (清理山積)**：刪除確認彈窗提示「確定要捨棄此山積模型嗎？相關施工紀錄將一併清除」。執行後 CASCADE 刪除關聯 `CraftLog`。

#### (3) 完工像素展示櫃 (Showcase Gallery)
- 當模型 `currentHp <= 0` 時，狀態轉換為 `Completed`，記錄 `completedAt = DateTime.now().toIso8601String()`。
- 展示櫃陳列架：
  - 像素外框玻璃展示架，展示已淨化模型的完成品圖像或專屬徽章。
  - 點擊開啟「展品身分證銘牌」：
    - 模型名稱、級別規格、完工日期。
    - 總討伐耗時（累計小時/分鐘）。
    - 工序耗時佔比（素組/打磨/刻線/噴塗/水貼各佔多少 %）。
    - 完整 `CraftLog` 歷程清單（每次開工日期、工序、傷害、是否中斷）。

---

### 3.4 R4: 8-Bit 像素遊戲體驗與打擊反饋 (Retro Game Juice)

#### (1) 視覺元素像素一致性 (Pixel Consistency)
- **字體**：全局統一使用像素字體（優先載入 `Press Start 2P`，備用字體為 `VT323`, `monospace`）。
- **色彩系統 (Palette)**：
  - 黑暗工坊背景底色：`#10121A`
  - HUD 與卡片容器色：`#14151F`, `#1D1E2C`
  - 邊框與分隔線：`#383A59`, `#44475A`（直角邊框，禁止圓角）
  - 警示/處決亮紅：`#FF5252`
  - 專注金幣亮黃：`#FFD54F`
  - 破甲/刻線霓虹青：`#8BE9FD`
  - 完工生命值翡翠綠：`#4CAF50`
  - 終極處決紫：`#BD93F9`
- **像素按鈕**：直角矩形，厚度 2~3px 實線邊框，按下具備 1~2px 偏移反饋。

#### (2) 動態打擊反饋 (Combat Juice)
- **打擊震屏 (Screen Shake)**：傷害結算時，戰鬥舞台沿水平軸以正弦衰減波震顫（幅度 8px，持續 400ms）。
- **受創閃爍 (Hurt Flash)**：怪物 Sprite 疊加紅色混色濾鏡 (`Color(0x99FF0000)`)。
- **浮動傷害字體 (Floating Damage Numbers)**：
  - 正常輸出/暴擊：鮮紅文字外框 `CRITICAL! -XXX`。
  - 中途中斷：琥珀色文字外框 `-XX (MERCY 50%)`。
- **討伐獲勝慶典 (Quest Clear)**：
  - 金黃色閃爍邊框 Dialog。
  - 怪物 Sprite 轉為完成品展品。
  - 彈出「★ QUEST CLEAR ★」光芒特效，結算工時、金幣與工匠稱號。

#### (3) 零花費音效機制 (Zero-Cost Audio)
- 零花費原則：不使用付費授權音效庫或雲端語音服務。
- 技術途徑：
  1. 使用 Web Audio API / Dart 生成純合成 8-bit 方波、三角波音效（例如：開工鈴 440Hz->880Hz 短嗶聲、打擊噪音爆破、完工琶音）。
  2. 或隨附 CC0 / 公有領域 8-bit 免費開源短音效檔 (WAV/OGG/MP3) 放於 `assets/audio/`。
  3. 支援音效開關切換 (Mute/Unmute)，並處理 Web 端使用者未與頁面互動前不可自動播放音效之限制。

---

## 4. 邊界條件與極端狀況 (Edge Cases)

以下為本專案在戰鬥數值、計時器、機庫 CRUD 與本機存儲中已辨識並記錄之極端條件矩陣：

| # | Feature | Input / Condition | Observed / Required Behavior |
|---|---------|-------------------|-----------------------------|
| 1 | Pomodoro 計時器 | 專注啟動後立即中斷（耗時 0 秒或 < 1 秒） | `elapsedSeconds = 0`，`elapsedRatio = 0.0`。計算得傷害 0 點、金幣 0 枚，不得出現除以零異常 (`NaN`) 或扣血錯誤；對話框提示「立即急停，未產生工時」。 |
| 2 | 水貼處決技鎖定 | Boss HP 處於臨界點：恰好等於 20.0% (例如 100/500) | 滿足 `hpRatio <= 0.20` 條件，按鈕解鎖可選，允許發動 2.5x 處決。 |
| 3 | 水貼處決技鎖定 | Boss HP 處於臨界點：等於 20.2% (例如 101/500) | `hpRatio > 0.20`，按鈕保持鎖定狀態。若使用者試圖透過熱鍵或點擊選中，強制阻擋並彈出 SnackBar 警告：「水貼處決技限定 Boss 殘血 20% 以下！」。 |
| 4 | 水貼選中後怪回血/重置 | 當前已選中水貼，但 Boss 因重置或切換回到 100% HP | 系統強制將選中工序重置回預設「素組 (Snap-fit)」，防止處決技能在滿血狀態下被觸發。 |
| 5 | 傷害溢出 (Overkill) | Boss 剩餘 HP 為 15，玩家發動噴塗造成 200 點傷害 | Boss HP 結算為 0（`currentHp.clamp(0, maxHp)`），不得出現負數血量。觸發 Quest Clear 結算流程。 |
| 6 | 快速測試模式中途中斷 | 5 秒測試模式中，於第 2 秒中途急停 | $t_{\text{elapsed}} = 2$s, $t_{\text{total}} = 5$s。計算公式 $100 \times \frac{2}{5} \times M_{\text{phase}} \times 0.5$。以素組計算傷害為 20 點，紀錄為中斷日誌。 |
| 7 | 機庫新增驗證 | 模型標題輸入為空字串、全半形空白或過長 (>50字元) | 送出按鈕阻擋或顯示輸入欄位紅字錯誤：「請輸入模型名稱」，防止建立空白名稱盒怪。 |
| 8 | 機庫血量驗證 | 自訂血量輸入非數字字元、0 或負數 (例如 `-100`, `abc`) | 輸入框限制僅能輸入正整數；若非法自動過濾或將血量限制在下限 100 HP，上限 99,999 HP。 |
| 9 | 刪除正在討伐之模型 | 玩家在機庫中刪除當前處於戰鬥舞台的進行中模型 | 彈出高風險警告確認彈窗；確認刪除後，戰鬥畫面清空當前目標，提示「目標已移除，請由機庫選擇新山積」，不可發生 NullReferenceException。 |
| 10 | 機庫山積完全為空 | 玩家完成或刪除了所有模型，機庫內 0 筆資料 | 機庫列表與戰鬥舞台顯示空狀態 (Empty State) 像素引導：「目前沒有山積！點擊【＋】登錄新模型開工」。禁用開工按鈕。 |
| 11 | 本機存檔損毀或初次啟動 | 本機無任何存檔資料，或 JSON/Storage 資料格式損毀 | 自動執行容錯初始化，寫入預設設定檔 (UserProfile: 剪鉗學徒) 與一隻初始教學盒怪 (EG 攻擊鋼彈, 300 HP)，保證遊戲不崩潰。 |
| 12 | 瀏覽器標籤頁切換或休眠 | Web 環境下使用者切換標籤頁導致瀏覽器背景節流 (Throttling) | 計時器應記錄真實啟動時間戳記 (`DateTime.now()`)，重回前台時透過真實時間差重新校正剩餘秒數，防止背景時間凍結。 |
| 13 | 視窗極限縮放 | 桌面版視窗縮小至 320px 寬度或放大至 4K 全螢幕 | 使用 `ConstrainedBox(maxWidth: 540)` 保持街機掌機居中比例；內容區域使用 `SingleChildScrollView` 避免產生底端 RenderFlex overflow 破版紅條。 |
| 14 | 圖片資產載入失敗 | 離線環境下模型照片不存在或圖片路徑損毀 | 使用 `errorBuilder` 提供像素風備用 Icon (`Icons.smart_toy` / `Icons.military_tech`)，保證介面穩定。 |

---

## 5. 現有 MVP 程式碼與完整規格差異 (Gap Analysis)

透過審查現有 `lib/main.dart`（共 1,018 行）與 `SPEC.md`，目前系統之實作成熟度與缺口如下：

| 規格要項 | 現有 MVP 狀態 (`lib/main.dart`) | 完整規格要求 (`SPEC.md` / `ORIGINAL_REQUEST.md`) | 需補齊工作 |
|---|---|---|---|
| **計時循環 (R1)** | 已實作 25m 與 5s 測試模式，單向倒數 | 需包含 25m 工作 / 5m 休息循環切換，以及 50m 深度專注模式 | 新增休息階段狀態機與 50m 選項 |
| **工序技能 (R1)** | 5 大倍率已存在，水貼 20% 限制已存在 | 需實作打磨 2% 易傷疊加、刻線判定暴擊、噴塗條件限制 | 擴充戰鬥數值計算引擎 |
| **中斷保底 (R1)** | 已實作 50% 比例結算 | 需記錄至 `CraftLog` (isCompletedSession=0)，並與匠人天賦關聯 | 連接日誌持久化儲存 |
| **資料持久化 (R2)** | 全為記憶體變數 (`_BattleAtelierScreenState`)，重整即遺失 | 需遵循 SQLite Schema，本機持久化 `KitItem` 與 `CraftLog`，重啟不丟失 | 建立 Repository 與本機儲存層 (Windows & Web) |
| **機庫管理 (R3)** | 硬編碼單一 Boss (綠色普通盒怪 HG 500HP) | 完整模型清單 CRUD，支援 EG/HG/RG/MG/PG/GK 與自訂血量 | 建立機庫頁面、新增/編輯對話框與選擇切換 |
| **完工展櫃 (R3)** | 僅有一彈出 Dialog，點擊後重置血量 | 獨立完工展示櫃頁面，記錄完工日期、總耗時與工序圓餅圖 | 建立展示櫃視圖與歷史日誌回顧 |
| **遊戲回饋 (R4)** | 已有基本震屏、紅光濾鏡、浮動跳字 | 需補齊零花費 8-bit 音效、無警告靜態代碼 (0 lints)、連擊動畫 | 整合無版權/合成音效，修復代碼 lint |

---

## 6. 驗收標準與驗證途徑 (Acceptance Criteria & Verification)

1. **靜態分析驗證**：
   - 執行 `flutter analyze` 必須達到 **0 錯誤 (0 errors)、0 警告 (0 warnings)、0 提示 (0 lints)**。
   - 現況備註：當前 `lib/main.dart` 存在 6 處 `unnecessary_underscores`，重構實作時必須全面修復。
2. **自動化單元測試覆蓋**：
   - 必須撰寫涵蓋以下核心邏輯之單元測試 (`flutter test`)：
     - 基礎點數與 5 大工序乘數換算正確性。
     - 水貼處決技在 20% 血量上下之解鎖/阻擋判定。
     - 中斷保底 (Mercy Rule) 公式換算（50% 保底折減與時間比例）。
     - 機庫 CRUD 與 `CraftLog` 串接及 Cascade 刪除邏輯。
3. **跨平台本機運行**：
   - Windows 桌面版編譯無錯誤，本機讀寫檔案正常。
   - Web 平台離線重新整理 (F5) 後模型清單與戰鬥日誌持續存在。
4. **零花費確認**：
   - 專案內部無任何第三方雲端連線、無付費 Firebase 依賴、無付費金鑰需求。
