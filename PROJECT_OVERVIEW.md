# Training La — 專案總覽 / Project Overview

> 跨 repo 的共用總覽：方向、架構、部署、以及各 repo 之間的關係。
> **刻意保持精簡**——欄位級細節、API 端點、實作決策都在各自的 repo 裡，寫在這裡只會漂移。
>
> ⚠️ **本檔為同步複本**：正本在 `Training-la/PROJECT_OVERVIEW.md`（parent 目錄）。異動請先改正本，再複製到各 repo 底下這份，保持三份一致。

---

## 1. 大方向 Vision

一款**本地優先（local-first）**的重量訓練 app：安排要練什麼、訓練時逐組記錄、事後回顧單一動作的進展。無帳號、無網路也能完整使用，資料存在裝置上。

> A local-first strength-training app. Works fully offline with no account.

**使用者資料不進後端**（2026-08 定案）——訓練紀錄、課表、能力值這些個人資料只存在裝置上，跨裝置與備份走 **iCloud**，不上傳到自家伺服器。後端在這個前提下還剩什麼角色**尚未拍板**，見 §8。

**原則 Principles**

- **本地優先** — 單機即為完整產品，網路只是加值
- **個人資料留在裝置上** — 備份／跨裝置用 iCloud，不經過自家後端
- **前後端徹底切開** — 以 OpenAPI 為契約，後端產生 Swift client 給 app 用
- **開源** — app 為 Apache-2.0，公開於 GitHub

---

## 2. Repo 關係 Repos

| 角色 | Repo | 可見性 | 內容 |
|---|---|---|---|
| App | `wly-p/training-la` | public | SwiftUI app（iOS，watchOS 規劃中）；local-first，v0 不串後端 |
| API 契約 / Client | `wly-p/training-la-client-swift` | public | 由 OpenAPI **生成**的 SPM SDK；**API 契約的真實來源**，請勿手改 |
| Backend | `wly-p/training-la-api` | private | Go 後端；**擁有 OpenAPI spec** 與自己的部署 |
| 對外靜態頁 | `wly-p/training-la-web` | private | 隱私政策等公開頁面；內容公開，pipeline 不公開 |

**依賴是單向的**，app 不被反向依賴：

```
training-la-api ──(OpenAPI)──► training-la-client-swift ──(SPM)──► training-la
training-la-web ────────────────(只透過網址)───────────────────────► training-la
```

**為什麼維持多 repo 不合併**：語言不同（Go / Swift）、可見性不同、client 需要獨立版本化，monorepo 不適合。

**為什麼靜態頁要獨立**：隱私政策是 App Store 審查會抓、使用者在 app 壞掉時也要看得到的法律文件，可用性要求比 API 高，不該跟著後端的部署節奏走；它又是純靜態，不需要一個服務來服務它。app 端**刻意不打包副本**——政策可在不發版時更新，副本會直接變成錯的內容，而政策與實際行為不符可以導致下架。

**Apple Watch 是 target，不是 repo**——與 iOS app 同一個 Xcode 專案、共用現有 SPM 模組，Watch 只補自己的 Presentation 層。Clean Architecture 分模組正是為此鋪路。

---

## 3. 產品範圍 Product Scope

**核心閉環**：建立動作 → （可選）排課 → 逐組記錄 → 檢視歷史

- **動作庫** — 官方動作目錄＋自建動作（名稱、肌群、器材、說明）
- **課表** — 月曆式排課、課表範本、循環課表、長期課表（投影出未來的排課）
- **訓練記錄** — 逐組記錄重量與次數，排課或臨時加練皆可，誤按可復原
- **歷史** — 依日期看過往場次，或鑽入單一動作看歷來每一組
- **能力值** — 每個動作的最大重量，用來推算課表的建議重量
- **組間休息提醒** — 本機通知，可設彈窗／聲音
- **設定** — 主題、語言（繁中／英）、重量單位（kg／lb）、重量與休息級距、App 圖示、隱私政策

---

## 4. 架構 Architecture

**App（iOS）** — Clean Architecture，每個 domain 一個本地 SPM package，各含 `Domain / Data / Presentation` 三層：

```
Spec（動作庫）  Plan（課表）  Training（訓練）  History  Ability  Reminders  Settings
                    ＋ SharedKernel（共用型別）  DesignSystem（元件與 token）
```

Domain 層純 Swift、無框架相依，可脫離 SwiftUI / SwiftData / 模擬器單測。**v0 依設計為純本地、刻意不串後端**，串接排在 v1。

**Backend（Go）** — v0 單用戶（伺服器寫死 dev user）、無 auth、純 CRUD，以 OpenAPI 為契約產出 client。**契約先行**：後端與契約提前備妥，讓 app 之後接上時零猜測；這是刻意的解耦，不代表 app 落後。

**靜態頁** — 單一 HTML，語言切換靠瀏覽器端讀 URL fragment，無伺服器邏輯。

---

## 5. 部署 Deployment

| Repo | 部署到哪 | 怎麼觸發 |
|---|---|---|
| `training-la` | App Store〔規劃〕 | — |
| `training-la-client-swift` | SPM tag，版本對齊 API | spec 更新 → 重新生成 → tag |
| `training-la-api` | Cloud Run，`training-la-api-dev.wly.lol` | CI |
| `training-la-web` | Cloudflare Pages，`training-la.wly.lol` | GitHub Actions，**只手動觸發** |

- 三個 repo 各自 **semver**；`client` 的 tag 對齊 API 版本，`app` 用 SPM **pin 住某個 client 版本**，避免被後端變更突襲
- 契約紀律：OpenAPI 非破壞性變更照常，**破壞性變更必 bump 版本**
- 靜態頁的部署刻意手動：法律文件上線該是刻意的動作，不是 push 的副作用；每次成功部署打一個遞增的 `deploy-N` tag
- Watch 採 **companion 模式**（隨 iOS app 一起遞送、App Store 單一 listing、一次審核）〔待確認〕

---

## 6. 資料模型 Data Model（摘要）

以 API 契約為準，欄位級細節見 `training-la-client-swift/docs/`。

兩條平行階層共用同一個動作庫：**計劃**（`Plan → PlanWorkout → TargetSet`）與**實際**（`Workout → WorkoutSet`）。`PlanWorkout` 可獨立存在（純排課）或掛在 `Plan` 底下。另有一層**範本** `Specs*`，是個人資料的鏡像，用來複製套用、日後做公開分享。

**寫入是 aggregate 整包取代**——v0 沒有單一 set 的端點，改任何一組都得送出整包重建。這對日後的同步合併策略有影響（見 §8）。

---

## 7. 路線圖 Roadmap

**功能軸（app）** — v0 純本地驗證核心閉環 ✅ → v1.0 補齊本地基礎管理 → v2.0 週期範本／進度圖表／匯出 → v3.0 智能建議與 AI 生成

**契約軸（api）** — 0.2.0 現行（單用戶、無 auth、CRUD、範本、aggregate 寫入）→ 後續補 auth／多用戶、單一 set 端點、公開分享

**平台軸** — v1 備份與跨裝置（檔案匯出／還原優先，CloudKit 自動同步視前置條件而定）、v1 Apple Watch（排課與計劃留在手機，Watch 專注「開始訓練」的當下體驗；資料流是 Watch → 手機，Watch 不直連後端）

> ⚠️ 原本這一軸寫的是「v1 API 整合（聯網自動 sync）」。既然使用者資料不進後端，那條路已經作廢；
> 後端相關的里程碑要等 §8 的「後端的剩餘角色」拍板後重寫。

---

## 8. 待釐清 Open Questions

- **命名三套並存** — API（`Plan` / `PlanWorkout` / `Workout`）、app 模組名、PROJECT_PLAN 的散文名（`Personal` / `TrainingRecord`）。→ 拍板以 API 為正規名，其餘逐步退役
- **版本號分軸** — app v0→v3 與 api 0.2.0 各走各的。→ 建議另立一組貫穿三 repo 的「產品里程碑」（如 M1 = app 串上 dev API）
- **排課週期自動推進** — app 端已有循環／長期課表，但這個概念不在 API。→ 要不要進 API？會影響是否需要新端點
- **後端的剩餘角色** ⭐ — 使用者資料已確定不進後端。那 `training-la-api` 還留下什麼？三種可能：(a) 只供應官方／公開範本與動作庫，個人資料完全不碰；(b) 整個退場，連帶要處理 openapi 契約、`training-la-client-swift`、以及「v1 · API Integration」這個 Milestone 的去留；(c) 其他。**這題沒拍板之前，本文件所有關於後端的敘述都應視為過期。**
- **iCloud 的形式** — 檔案匯出／還原（可攜、成本低）vs CloudKit 自動同步（零操作，但要求移除 15 處 `@Attribute(.unique)`、所有屬性補預設值，且前置是把「每記一組刪整棵重插」的寫入模式改掉）。目前傾向先做前者。
- **Aggregate 寫入 vs 同步** — 整包覆蓋＝後寫贏。若最終走 CloudKit，衝突合併策略要及早想
- **狀態列舉語意** — 「完成／跳過／中斷」等語意前後端需有共識

---

## 9. 本文件缺口 Gaps

- 後端為 private repo，資料表結構與部署細節未併入；本文件的後端資訊來自 client 契約與初始描述
- 欄位級模型不複製進來（避免與生成碼漂移），以 `training-la-client-swift/docs/` 為準
- UI/UX 設計方向未納入
