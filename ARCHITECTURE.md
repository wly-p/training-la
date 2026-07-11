# 架構與資料模型

本文件記錄「健身課表追踪工具」的架構決定，聚焦**結構**（分層、模組、邊界、相依），不含實作程式碼。
搭配 [`PROJECT_PLAN.md`](./PROJECT_PLAN.md) 一起閱讀。

## 總覽：兩個獨立產物，以 API 契約為界

```
┌────────────────────────────┐        ┌──────────────────────────┐
│  iOS App（主產物・現在做）    │        │  Go 後端（之後・獨立 repo） │
│  SwiftUI + SwiftData         │        │  Go + Postgres            │
│  Clean Architecture 多模組    │        │  登入同步 / 公開分享        │
└────────────┬───────────────┘        └────────────┬─────────────┘
             │                                        │
             │        OpenAPI 契約（真實來源在後端）      │
             └──────── 產生 Swift client ◀─────────────┘
```

- **兩端徹底切開**：不同語言、不同 repo、不同發行節奏、不同貢獻者。
- **唯一介面 = API 契約**：後端維護一份 `openapi.yaml`，iOS 端據此**產生 Swift client**（打包成 SPM package 使用）。
- **local-first**：App 不依賴後端也能完整運作；同步/分享是**可選、後加**的能力。

## 平台與技術棧

| | 選擇 | 備註 |
|---|---|---|
| iOS | SwiftUI + **SwiftData** | on-device local-first；`@Model` 只在 Data 層 |
| 模組管理 | **SPM（local packages）** | 不用 CocoaPods，貢獻者免裝 Ruby、免 `pod install` |
| 後端 | **Go** + Postgres | 獨立 repo，之後才開工 |
| DB migration | **Go 工具 + 純 SQL 檔**（golang-migrate / goose） | 單一技術棧；不引入 Python 進出貨管線 |
| 契約 → client | OpenAPI → Swift client | 契約真實來源在後端 repo |

## Repo 策略

- **現在**：只在 `training_la_ios/` 建 git repo（App 是目前唯一實體）。
- **之後**：後端用 Go → **獨立新 repo**（`training_la_api`）。兩端沒有共享程式碼，只共享 OpenAPI 契約。
- `training_la_web/` 已停用（改走 iOS，可移除）。

---

# iOS：Clean Architecture（多模組）

## 分層與依賴規則（依賴只准往內指）

```
Presentation (SwiftUI View + ViewModel)
        │  依賴
        ▼
Domain  (純 Swift：Entity struct + UseCase + Repository「protocol」)  ← 不 import 任何框架
        ▲  實作
        │
Data    (SwiftData @Model + Mapper + Repository 實作)
```

- **Domain 完全純 Swift**：不 import SwiftData、不 import SwiftUI。可抽換、可測的來源。
- Data 與 Presentation 都只依賴 Domain 的 **protocol**，彼此互不知道。

## 核心規矩（決定「可抽換 / 可測」）

1. **Domain 的 Entity 是 plain struct**；SwiftData 的 `@Model` **只活在 Data 層**，兩者用 Mapper 互轉。
   → 之後把 SwiftData 換成別的儲存、或接遠端同步，Domain 一行都不用改。代價是多一層 Mapper 樣板。
2. **每個 domain = 一個 SPM package**：跨層/跨 domain 亂 import 會**編譯期被擋**，邊界不靠自律。

## 模組結構

```
App/                      ← 主 target = Composition Root（唯一認識所有具體實作的地方）
Packages/
  SharedKernel/           ← 跨 domain 純值物件：Weight{value,unit}、Unit、MuscleGroup enum、ID 型別
  Spec/
    Sources/
      SpecDomain/         ← Entity(struct) + UseCase + SpecRepository(protocol)
      SpecData/           ← @Model + Mapper + Repository 實作（依賴 SpecDomain）
      SpecPresentation/   ← View + ViewModel（依賴 SpecDomain）
    Tests/
      SpecDomainTests/       ← UseCase 注 mock repo，純邏輯測（秒級、免模擬器）
      SpecDataTests/         ← Repository 用 in-memory SwiftData 測
      SpecPresentationTests/ ← ViewModel 注 mock repo/port 測
  Plan/       (同結構)
  Training/   (同結構：Session → SessionExercise → SetRecord)
  History/    (讀多，可只有 Domain + Presentation)
```

相依方向：`SpecData → SpecDomain`、`SpecPresentation → SpecDomain`、`SpecDomain → SharedKernel`。
**Domain 之間互不依賴**；只有 App 認得全部。

## 跨 domain 解耦（ports & adapters）

`Session` 只存 `specId`，不直接持有 `Spec` entity。當 Training 需要動作名稱顯示時：

- Training 自己定義 port：`SpecCatalog`（給我 specId → 回 SpecInfo）。
- 由 **App（Composition Root）** 把它接到 Spec domain 的 UseCase。
- → Training **從不 import Spec package**，仍能用到它的資料。

## DI：建構子注入 + Composition Root

- 整個相依圖只在 **App 層組一次**：建立具體 Repository → 注入 UseCase（protocol）→ 傳給 ViewModel/View。
- 測試時把具體 Repository 換成 Mock 即可——上層只認 protocol，**測試零改動、免模擬器**。
- 不用重量級 DI 框架。

## SwiftData 在 Clean Arch 下的兩個雷（必避）

1. **View 裡不要用 `@Query`**：它把 SwiftUI 直接綁死 SwiftData，破壞分層。改走 View→ViewModel→UseCase→Repo；要反應式就讓 Repo 對外吐 `AsyncStream`。
2. **`@Model` 不准漏出 Data 層**：邊界一律轉成 Domain struct。

---

# 測試

三類測試，各自獨立：

1. **Unit test**：六個 package（SharedKernel/Spec/Training/Plan/History/Settings）各自的 `Tests/`，用 Swift Testing（`import Testing`）。
   - `*DomainTests`：UseCase 注 mock repository，純邏輯測，秒級、免模擬器。
   - `*DataTests`：Repository 用 in-memory SwiftData 測。
   - `*PresentationTests`：ViewModel 注 mock repository/port 測。
2. **UI test**：`UITests/`（Xcode UI Testing target `TrainingLaUITests`），跑在模擬器上，走真實 App 畫面互動流程。
3. **E2E UI test（真實後端 API）**：v0 是 local-first、尚無後端（見 [`PROJECT_PLAN.md`](./PROJECT_PLAN.md)），暫無此類測試；等 v1 接 Go 後端後才補。

## 怎麼跑

- `make test-unit`：逐 package 執行 `swift test`（不需模擬器，最快）。
- `make test-uitest`：`xcodegen generate` 重生專案後，用 `UITests.xctestplan` 跑 `TrainingLaUITests`。
- `make test-e2e`：目前是佔位（echo 提示尚無真實後端）。
- `make test`：`test-unit` + `test-uitest`。

同一份 `swift test` 也能在 Xcode 裡跑：`project.yml` 把每個 package 的 unit test target 都掛進 `UnitTests.xctestplan`，跟只含 `TrainingLaUITests` 的 `UITests.xctestplan` 是兩個獨立的 Test Plan（scheme 的 Test Plan 下拉選單可切換），Test Navigator 兩邊都看得到、能分開跑，不會混在一起。

## `Config.xcconfig`：device / headless 可調參數

`Config.xcconfig`（進版控）定義 `TEST_DEVICE`（跑 UITests 的模擬器機型，預設 `iPhone 17`）與 `TEST_HEADLESS`（bool，預設 `true`＝不開 Simulator.app 視窗）。這是 Makefile 與 Xcode 專案共用的單一真實來源：

- Makefile 用 `awk` 讀這個檔案當預設值，可指令列覆蓋：`make test-uitest DEVICE="iPhone 16 Pro" HEADLESS=false`。
- `project.yml` 用 `configFiles` 把它掛進全部 build configuration，`xcodebuild -showBuildSettings` 可看到同樣的值——但 Xcode GUI 工具列的模擬器下拉選單是互動式狀態，不會被這兩個值動態帶動，這是 Xcode 本身的限制。

## 環境需求

本機 `xcode-select` 必須指向完整的 `Xcode.app`（而非單獨安裝的 Command Line Tools），否則 `swift test` 找不到 `Testing` framework、`xcodebuild`／模擬器也跑不了：

```
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

---

# 資料模型（Domain Entity，plain struct）

```
Spec 動作庫 ─ 可重複使用的動作定義
  id, name, muscleGroup(enum), description, createdAt

PlanItem 課表項目 ─ 某天「打算做」的（可選，僅作記錄時的預填來源）
  id, date, specId, order,
  target: { sets, reps, weight: {value, unit}, restSec }

Session 訓練場次 ─ 一次訓練（同步時的批次上傳單位）
  id, date, startAt, endAt, overallFeeling, note
   └─ SessionExercise 場次內的一個動作
        id, specId, order, fromPlanItemId?   // 空 = 臨時加練 / 未排課
         └─ SetRecord 逐組
              setNo, weight: {value, unit}, reps,
              status(done|skipped|interrupted),
              target?: { reps, weight: {value, unit} }
```

- **紀錄可脫離課表**：`SessionExercise.fromPlanItemId` 可為空。
- `Session → SessionExercise → SetRecord` 為一棵樹；同步時整棵樹整包上傳。

## Enum：肌群分類 (muscleGroup)

固定清單，避免自由輸入造成統計分裂：

```
胸 | 背 | 腿 | 肩 | 手臂 | 核心 | 功能性訓練 | 其他
```

## 重量單位：可自由切換

- 每筆重量存為 `{ value, unit }`，`unit ∈ {kg, lb}`，記錄**輸入當下的單位**為**真實來源**。
- 另有**全域顯示偏好**，檢視時即時換算顯示。
- **切換的是「顯示」，不是「已存的資料」**：避免來回換算的四捨五入侵蝕原值，確保進度趨勢真實。
- 適用欄位：`SetRecord.weight`、`PlanItem.target.weight`。

---

# 後端（Go・之後才做）

- **獨立 repo、完全開源**，單一技術棧（Go）。
- **DB migration**：用 Go 工具（golang-migrate / goose）驅動**純 SQL 檔**，可 embed 進 binary，部署時自己跑。**不把 Python 放進出貨管線**（Python 僅留給 ad-hoc 分析 / seed 腳本）。
- **契約優先**：維護 `openapi.yaml` 為真實來源 → iOS 端產生 Swift client。
- **多租戶預留**：本地 schema 維持單用戶且為真實來源；伺服器 schema 額外加 `userId` 與 `visibility(public/private)`。現在講好，之後加後端不用大改。
- **公開分享的附帶責任**（自架公開站才承擔）：內容審核、使用者上傳內容的授權（ToS + 內容授權，與程式碼授權分開）、帳號隱私/刪除。

---

# 開源與發行

- **授權**：**Apache-2.0**（含專利授權；與 App Store 相容）。**避免 GPL/AGPL**——與 App Store 的 DRM 條款衝突。
- **上架 ≠ 閉源**：原始碼公開 + 簽章 build 上架，兩者可並行。
- **密鑰永不進 git**：簽章憑證、描述檔、App Store Connect key、後端 secrets 一律走 `.gitignore` / CI secrets。
- **發行節奏**：免費簽章 build 自用 → 功能齊 → TestFlight → 上架（屆時才需 Apple Developer $99/年）。

---

# 分階段路線

1. **v0（現在）**：iOS 純 local-first，免登入，資料在 SwiftData。單機可用。
2. **v1**：接 Go 後端 → 登入 + 跨裝置同步（先做簡單同步）。
3. **v2**：spec/菜單 `public/private` 公開分享，配 ToS + 內容授權 + 基本審核。
