# Original User Request

## Initial Request — 2026-09-11T02:57:46Z

# Teamwork Project Prompt — Draft

> 狀態：已啟動 (Launched)
> 目標：打造《罪普拉 RPG》完整版獨立遊戲
> 開發原則：零額外花費 (Zero monetary cost)、完全使用免費開源資源
> 團隊規模：完整多智能體團隊 (Full team)

## 專案簡介 (Project Description)
將《罪普拉 RPG（Tsumi-Pura RPG）》從目前的 MVP 雛形，完整開發為一款兼具實用性與趣味性的「模型製作番茄鐘 × 像素 RPG 討伐」獨立遊戲。玩家將模型堆積視為 Boss 怪物，透過實際組裝打磨的時間對 Boss 造成傷害，達成清空堆積並收錄機庫展櫃。全案堅持不使用任何付費 API 或雲端服務，純依賴本地開源方案。

Working directory: c:\Users\k-kaw\Documents\antigravity\nifty-heisenberg
Integrity mode: development

---

## 核心需求 (Requirements)

### R1. 完整番茄鐘與戰鬥循環 (Complete Pomodoro & Battle Loop)
- 支援標準 25 分鐘工作 / 5 分鐘休息之番茄鐘循環，並提供快速測試除錯模式。
- 完整實作 5 大工序乘數（素組 1.0x、打磨 1.2x、刻線 1.5x、噴塗 2.0x、水貼 2.5x 限殘血 20% 以下處決）。
- 實作中斷保底機制（Mercy Rule）：中途放棄時依比例結算並給予保底 50% 傷害。

### R2. 本地資料庫持久化與歷史日誌 (Local Persistence & CraftLog)
- 依照 SPEC.md 建立本地資料庫儲存模型清單 (KitItem) 與施工紀錄 (CraftLog)。
- 支援離線本機儲存（確保 Web 與桌面端重整/重啟後進度均不丟失，零雲端花費）。
- 提供工時與日誌檢視介面：玩家可回顧每盒模型的製作歷程與累積工時。

### R3. 堆積模型機庫與展示櫃 (Model Hangar & Showcase Gallery)
- 完整的模型 CRUD 管理：新增、編輯、刪除模型，包含自訂名稱、級別（EG/HG/RG/MG/PG）、自訂或預設血量。
- 討伐成功的模型移入「完工像素展櫃」，記錄完工日期與總討伐耗時。

### R4. 8-Bit 像素遊戲體驗與打擊反饋 (Retro Game Juice)
- 像素風格視覺一致性（字體、按鈕、血條、怪物與勇者）。
- 加入打擊特效、震動、跳字反饋，以及無版權免費 8-bit 復古音效/視覺提示。

---

## 驗證機制與驗收標準 (Acceptance Criteria)

### 客觀驗證 (Objective Verification)
- [ ] 靜態分析：執行 lutter analyze 為 0 錯誤、0 警告。
- [ ] 自動化測試：撰寫單元測試覆蓋資料庫儲存、傷害公式換算與保底機制。
- [ ] 跨平台構建：專案能無報錯成功編譯並於本機流暢運行（Windows/Web）。
- [ ] 零花費驗證：不依賴任何外部付費訂閱、雲端資料庫或付費 Token。

## Follow-up — 2026-09-11T07:49:42Z

The quota reset period has ended. The user requested: GO. Please resume execution of M2 hardening and continue through M3, M4, and M5.
