# Training La — 專案共用文件 / Shared Project Doc

> 前後端共用的單一事實來源，用來對齊大方向、統一詞彙、追蹤差異。
> Single source of truth shared across the **iOS app** and the **Go backend**.
>
> ⚠️ **本檔為同步複本**：正本在 `Training-la/PROJECT_OVERVIEW.md`（parent 目錄）。異動請先改正本，再複製到各 repo 底下這份，保持三份一致。

**相關 repo Repos**

| 角色 | Repo | 說明 |
|---|---|---|
| App（iOS） | `wly-p/training-la` | SwiftUI app，local-first |
| API 契約 / Client | `wly-p/training-la-client-swift` | 由 OpenAPI 產生的 Swift client；**API 契約的真實來源** |
| Backend | *(private)* | Go；OpenAPI 由此產出 |

> ⚠️ 命名／資料模型若有疑義，**以 API client 契約為準**（API version 0.2.0）。

---

## 1. 大方向 Vision

一款**本地優先（local-first）**的重量訓練 app：安排要練什麼、訓練時逐組記錄、事後回顧單一動作的進展。無帳號、無網路也能完整使用；資料存在裝置上。後端負責跨裝置同步與範本分享，為漸進加值，非核心前提。

> A local-first strength-training app. Works fully offline with no account. The backend adds cross-device sync and shareable templates as progressive enhancement.

**基本原則 Principles**

- **本地優先** Local-first — 單機即為完整產品，網路只是加值
- **前後端徹底切開** FE/BE decoupled — 以 **OpenAPI 為契約**，後端產生 Swift client 給 app 用
- **開源** Open source — app 為 Apache-2.0，公開於 GitHub

---

## 2. 產品範圍 Product Scope

**核心閉環 Core loop**

```
建立動作 Exercise → (可選)排課 Plan/PlanWorkout → 逐組記錄 Workout/WorkoutSet → 檢視歷史 History
```

**功能 Features**

- **動作庫 Exercise library** — 自建動作（名稱、肌群、器材、說明），跨計劃與紀錄重用
- **計劃與排課 Plans & scheduling** — 建個人菜單、或排單一訓練日；可從範本複製（見下）
- **範本 / 分享 Templates** — `Specs*` 範本（菜單範本、獨立訓練積木）可整套或積木式複製套用〔API 已具備；即「下載熱門菜單」的基礎〕
- **訓練記錄 Workout tracking** — 逐組記錄重量與次數；排課或臨時加練皆可
- **歷史 History** — 依日期看過往場次，或鑽入單一動作看歷來每一組
- **主題 Theme** — 淺 / 深 / 跟隨系統（app 端）

---

## 3. 核心概念與資料模型 Core Concepts & Data Model

> 以 API 契約（`training-la-client-swift`）為準。欄位級細節見該 repo `docs/`，本節只定調**概念與階層**，避免與生成碼漂移。

### 兩條平行階層 Two parallel hierarchies

```
計劃 Planned                          實際 Actual
  Plan  菜單                            Workout  訓練紀錄
   └─ PlanWorkout  排課/訓練日            └─ WorkoutSet  實際完成的組
        └─ TargetSet  預定組
                    ╲                  ╱
                     └── Exercise 動作 ──┘   （兩邊都引用動作庫）
```

- **Plan → PlanWorkout → TargetSet**：預定要練什麼、預定重量/次數
- **Workout → WorkoutSet**：實際做了什麼、實際重量/次數 + 狀態
- **Exercise**：動作庫，被上面兩條共同引用
- `PlanWorkout` 可獨立存在（`plan_id = null`，純排課）或掛在 `Plan` 底下

### 範本層 Templates（`Specs*`）

個人資料的「範本鏡像」，用來複製套用、日後做公開分享：

- **SpecsPlan** 菜單範本 — 整套（plan + workouts + sets）
- **SpecsPlanWorkout** 訓練範本積木 — 獨立積木（workout + sets），或掛在 SpecsPlan 底下
- 複製路徑：`Plan.from_specs_plan_id` / `PlanWorkout.from_specs_plan_workout_id`

### 值物件與列舉 Value objects & enums

| 名稱 | 說明 |
|---|---|
| `Weight` | **數值 + 單位**；單位隨輸入當下存下為真實來源，切換只影響顯示 |
| `MuscleGroup` | 固定 enum：胸 / 背 / 腿 / 肩 / 手臂 / 核心 / 功能性訓練 / 其他 |
| `Equipment` | 器材 enum |
| `PlanStatus` / `PlanWorkoutStatus` / `WorkoutSetStatus` | 各層狀態列舉 |

### 寫入模型 Write model（重要）

- `Plan` / `Workout`（及範本）皆為 **aggregate 整包寫入**；`PUT` 會**整包取代** header + 底下 workouts / sets。
- **v0 沒有單一 set 的端點**——app 端編輯任何一組，都得送出整包重建。〔對日後 sync 的合併策略有影響，見 §8〕

---

## 4. 系統架構 Architecture

### App（iOS）— `wly-p/training-la`

- **Clean Architecture**，每個 domain 一個本地 SPM package（`Spec / Plan / Training / History / Settings`），各含 `Domain / Data / Presentation` 三層
- Domain 層純 Swift、無框架相依，可脫離 SwiftUI / SwiftData / 模擬器單測
- **v0 依設計為純本地、刻意不串後端**，資料只存在裝置上；串接 API 排在 v1（見 §7 / §8 #5）

### Backend（Go）— private repo

- **已部署 dev 環境**：`https://training-la-api-dev.wly.lol`，API version **0.2.0**
- **v0 API 範圍**：單用戶（伺服器寫死 dev user）、**無 auth**、純 CRUD
- 以 **OpenAPI 為契約**，產出 `training-la-client-swift`
- **契約先行 Contract-first**：後端與契約提前備妥，讓 app 之後接上時零猜測；這是刻意的解耦，**不代表 app「落後」**——app v0 本來就不消費此 API

### API 面 API surface（資源群組）

| 資源 Resource | 路徑 | 用途 |
|---|---|---|
| Exercises | `/v1/specs/exercises` | 動作庫 CRUD |
| Plans | `/v1/plans` | 個人菜單（整包） |
| PlanWorkouts | `/v1/plan-workouts` | 排課（獨立或掛菜單下） |
| Workouts | `/v1/workouts` | 訓練紀錄（整包） |
| WorkoutSets | `/v1/workout-sets` | 某動作的歷史組數（唯讀） |
| Specs·Plans | `/v1/specs/plans` | 菜單範本 |
| Specs·PlanWorkouts | `/v1/specs/plan-workouts` | 獨立訓練範本積木 |
| System | `/health` | 健康檢查（含 DB） |

### 前後端契約 FE/BE contract

```
Go backend ──(OpenAPI 0.2.0)──► training-la-client-swift ──► iOS app
```

---

## 5. 命名對照 Naming Map

> 目前**三套命名**並存。建議一律以 **API 契約**為正規名；app 內部層與計劃文件的舊名逐步對齊。

| 概念 Concept | API（正規 canonical） | App 模組/層 | PROJECT_PLAN 散文 |
|---|---|---|---|
| 動作庫 | `Exercise` / `Specs·Exercises` | `Spec` | Spec |
| 個人菜單 | `Plan` | `Plan` | Personal |
| 排課 / 訓練日 | `PlanWorkout` | （Plan 內） | Personal |
| 預定組 | `TargetSet` | — | — |
| 訓練紀錄 | `Workout` | `Training` | TrainingRecord |
| 實際組 | `WorkoutSet` | （Training 內） | — |
| 歷史查詢 | `WorkoutSet(History)` | `History` | 訓練紀錄檢視 |
| 範本 / 分享 | `Specs*` | — | （v1 之後） |
| 設定 | —（純 app 端） | `Settings` | — |

---

## 6. 技術棧 Tech Stack

| 面向 | App（iOS） | Backend |
|---|---|---|
| 語言 | Swift 6.0 | Go |
| UI / 框架 | SwiftUI | — |
| 儲存 | SwiftData（on-device） | Supabase〔目前〕 |
| 模組化 | 本地 SPM，每 domain 一個 | — |
| 專案產生 | XcodeGen | — |
| 測試 | Swift Testing | — |
| API 契約 | 用 `training-la-client-swift` | OpenAPI（產 client） |
| 部署 | App Store〔規劃〕 | Cloud Run + `wly.lol` 網域〔目前〕 |
| 認證 | — | v0 無 auth（單 dev user） |
| 授權 | Apache-2.0 | — |

---

## 7. 路線圖 Roadmap

> app repo 與 api 各自獨立編號；下面並列，並標出「產品級」里程碑待統一（見 §8 #3）。

**App（`training-la` PROJECT_PLAN.md）**

- **v0 可行性** — 純本地驗證核心閉環 ✅ 進行中/基本完成
- **v1.0 MVP** — 補齊本地基礎管理（Spec/Plan/紀錄/查詢）
- **v2.0** — 週期範本、進度圖表、匯出
- **v3.0** — 智能建議、缺課提醒、AI 生成

**API（`training-la-client-swift`）**

- **0.2.0（現行）** — 單用戶無 auth、CRUD、範本 `Specs*`、aggregate 寫入
- 後續 — auth / 多用戶、單一 set 端點、公開分享

**平台軸（整體產品 · 待與上面兩軸對齊里程碑）Platform track**

_功能軸把本地 app 做完整；平台軸把能力擴到雲端與其他裝置。兩者可並行。_

- **v1 · API 整合 API integration** — app 接上後端：下載範本（`Specs*`）、離線可用、聯網自動 sync。〔範圍見 §8 #5〕
- **v1 · Apple Watch** — 見下方獨立小節。

### Apple Watch（平台軸 · v1 候選）

- **定位 Role** — 排課與計劃仍在**手機端**；Watch 專注「開始訓練」的當下體驗
- **功能 Features** — Watch 顯示項目、重量、次數；過程中可即時調整；一樣有組間休息提示
- **資料流 Data flow** — 訓練結束在 Watch 存成 workout 紀錄 → 加入 **sync task** → 連上手機時自動同步
  （接力模型：**Watch → 手機 → 後端**，Watch 不直連後端）
- **對應模型 Maps to §3** — 消費 `PlanWorkout / TargetSet`（顯示預定值），產生 `Workout / WorkoutSet`（實際紀錄）；沿用同一套資料模型
- **依賴 Depends on** — 手機端 sync 機制需先就緒（與 v1 API 整合相關）；核心訓練記錄邏輯已存在

---

## 8. 待釐清 / 差異點 Open Questions & Discrepancies

1. **組間休息計時 Rest timer**
   最初當核心功能、README 稱內建、PROJECT_PLAN v0 卻列「先砍」。**API 沒有此概念**（純 app 端 UX）。→ app 端實際做了沒？做了就更新 PROJECT_PLAN。

2. **命名統一 Naming** — 三套並存（見 §5）。→ 拍板以 API 為正規名，退役 PROJECT_PLAN 的 `Personal / TrainingRecord`。

3. **版本號分軸 Versioning** — app v0→v3、api 0.2.0 各走各的。→ 建議：各 repo 保留自己的版本號，另立一組「產品里程碑」（如 M1 = app 串上 dev API）貫穿兩者；後端 / Apple Watch 明確掛在里程碑上。

4. **排課深度 Scheduling depth** — API 有獨立 PlanWorkout + 範本複製，但**「push/pull/legs 週期自動推進」不在 API**。→ 這是 app 端邏輯還是要進 API？（會影響是否需要新端點）

5. **v1 整合範圍 v1 integration scope** — v0 app 純本地是**既定設計**，非落差；問題是往前看：v1 接上 API 時先做什麼（先讀取範本？先同步 workout？離線佇列與 sync 觸發時機？）。此為規劃項，非現況矛盾。

6. **Aggregate 寫入 vs 同步** — v0 無單一 set 端點，任何編輯都整包 PUT 重建。→ 日後多裝置同步的衝突合併策略要及早想（整包覆蓋 = 後寫贏，可能覆蓋他裝置變更）。

7. **狀態列舉語意 Status enums** — `PlanStatus / PlanWorkoutStatus / WorkoutSetStatus` 各有值。→ 前後端需對「完成 / 跳過 / 中斷」等語意有共識（app 的訓練狀態需求 vs API 現有 enum）。

---

## 9. 專案管理 / repo 結構 Project Management

### repo 佈局 Repo layout（維持三個，Watch 不新增 repo）

| Repo | 可見性 | 內容 |
|---|---|---|
| `training-la-api` | private | Go 後端；**擁有 OpenAPI spec** 與部署 |
| `training-la-client-swift` | public | 由 spec **生成的 SPM SDK**；版本跟隨 API |
| `training-la` | public | **iOS + watchOS 兩個 target**；共用 domain/data SPM 套件 |

- **Apple Watch = target，不是 repo** — 與 iOS app 同一 Xcode 專案，共用現有 SPM 模組，Watch 只補自己的 Presentation 層。Clean Architecture 分模組正是為此鋪路。
- **維持多 repo，不合併** — 不同語言（Go/Swift）、不同可見性、client 需獨立版本化 → monorepo 不適合。
- **依賴單向 One-way** — `api(spec) → client → app`；app 不被反向依賴。

> **假設（待確認）Assumption**：採 **companion 模式** —— Watch app 隨 iOS app 一起遞送、**App Store 單一 listing**、一次審核。若要 Watch 可獨立安裝／獨立 listing，屬 independent watchOS app，設定不同，需另行決定。

### 版本與發布 Versioning & release

- 三個 repo 各自 **semver**。
- `client` 的 tag **對齊 API 版本**（API 0.2.0 → client 0.2.x）。
- `app` 以 SPM **pin 住某個 client 版本**，避免被後端變更突襲。
- 契約紀律：OpenAPI 非破壞性變更照常；**破壞性變更必 bump 版本**。
- 以 §8 #3 的「產品里程碑」貫穿三 repo（含後端整合、Apple Watch 落點）。

### CI / 自動化

- **api** — 測試 + 部署 + 發布 spec
- **client** — 由 spec 重新生成 → build → tag（已有 workflows）
- **app** — build + test（iOS 與 watchOS 兩 target）

### 開源待辦 Open-source housekeeping

- [ ] `client` repo 補 **LICENSE**（建議與 app 一致 Apache-2.0）
- [ ] `client` README 標明「**本 repo 由 OpenAPI 生成，請勿手改**」（避免 PR 被覆蓋）
- [ ] `app` README 說明「後端為 optional/private，app 本地即可用」

---

## 10. 本文件缺口 Gaps

- **後端 repo 為 private** — 資料表結構、部署細節未併入；本文件後端資訊來自 client 契約與初始描述
- **欄位級模型** — 未複製進本文件（以避免與生成碼漂移）；請以 `training-la-client-swift/docs/` 為準
- **UI/UX** — 目前 MVP 功能先行，設計方向尚未納入
