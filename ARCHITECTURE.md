# 架構與資料模型

本文件記錄 **iOS app 本身**的架構決定，聚焦**結構**（分層、模組、邊界、相依）與**目前 domain 的資料模型**，不含實作程式碼。
跨 repo 的產品範圍、後端定位、命名對照、開源授權、產品路線圖，一律以 [`PROJECT_OVERVIEW.md`](./PROJECT_OVERVIEW.md) 為準；iOS 專屬的階段規劃見 [`PROJECT_PLAN.md`](./PROJECT_PLAN.md)。

## 總覽：兩個獨立產物，以 API 契約為界

```
┌────────────────────────────┐        ┌──────────────────────────┐
│  iOS App（主產物・現在做）    │        │  Go 後端（已部署・獨立 repo）│
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
| 後端 | **Go** + Postgres | 獨立 repo，已部署 dev 環境；App v0 尚未串接（見 [`PROJECT_OVERVIEW.md`](./PROJECT_OVERVIEW.md) §4） |
| DB migration | **Go 工具 + 純 SQL 檔**（golang-migrate / goose） | 單一技術棧；不引入 Python 進出貨管線 |
| 契約 → client | OpenAPI → Swift client | 契約真實來源在後端 repo |

## Repo 策略

三個獨立 repo（`training-la` App、`training-la-api` 後端、`training-la-client-swift` 生成的 client），彼此沒有共享程式碼，只共享 OpenAPI 契約。細節見 [`PROJECT_OVERVIEW.md`](./PROJECT_OVERVIEW.md) §9。

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
  Plan/       (同結構：PlanWorkout → PlanSet)
  Training/   (同結構：Workout → WorkoutSet)
  Ability/    (同結構：AbilityValue，一動作一筆能力值；見下方資料模型)
  History/    (讀多，可只有 Domain + Presentation)
  Settings/   (只有 Presentation：主題、App 圖示、提醒偏好)
  Reminders/  ← 通知/提醒中樞（非 domain，是跨 domain 的共用能力）
    Sources/
      RemindersDomain/    ← 純邏輯：偏好、channel ports、dispatcher（可被任何 domain import）
      RemindersKit/       ← 平台實作：UN 本地通知、系統音、UserDefaults（只有 App 接線時 import）
  DesignSystem/           ← 共用 UI 元件與 design token（無 domain 邏輯；Tests/ 只放純函式）
```

相依方向：`SpecData → SpecDomain`、`SpecPresentation → SpecDomain`、`SpecDomain → SharedKernel`。
**Domain 之間互不依賴**；只有 App 認得全部。

例外是 `RemindersDomain`：它跟 SharedKernel 一樣是跨 domain 共用層（Training／Settings 都直接 import），
但只含純 port 與偏好值型別；有副作用的實作全在 `RemindersKit`，僅 App 組裝時使用。
未來要加新通知類型或 Apple Watch，是「換/加一組 channel 實作」，不動各 domain。

## 跨 domain 解耦（ports & adapters）

`Workout`／`PlanWorkout` 只存 `exerciseId`，不直接持有 `Exercise` entity。當 Training／Plan 需要動作名稱顯示時：

- 各自定義 port：Training 的 `ExerciseCatalog`、Plan 的 `PlanExerciseCatalog`（給我 exerciseId → 回動作清單）。
- 由 **App（Composition Root）** 把它接到 Spec domain 的 UseCase。
- → Training／Plan **從不 import Spec package**，仍能用到它的資料。

### 休息結束提醒（Reminders 中樞）

Training 的休息倒數不認識任何提醒手段，只呼叫 `RestEndReminding`（RemindersDomain 的 port）：
`schedule(at:)`／`cancel()`／`deliverForeground()`。背景/前景分工是 iOS 本地通知的硬約束所決定：

- **背景**在 `schedule` 當下就把計畫烤進一則本地通知（到點 App 不會被喚醒執行 code）。
  背景只有兩個旋鈕：「排不排」＋「有無聲音」——做不到「只出聲不顯示橫幅」、震動跟隨系統無法獨立控制。
- **前景**倒數歸零由 `deliverForeground()` 播聲音；彈窗由 View 依偏好顯示；App 進背景會停掉前景
  ticking，避免回前景補跑提醒與背景通知重複發聲。

偏好因此收斂成三個誠實的開關（`RestReminderPreference`，Settings 編輯、與 reminder 共用同一 store）：
前景 `彈窗`／`聲音` ＋ 背景 `背景通知`（聲音跟隨「聲音」開關）。**不設震動開關**——有聲音必伴隨
系統震動，拆不開，設定只會騙人。

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

1. **Unit test**：九個 package（SharedKernel/Spec/Training/Plan/History/Settings/Reminders/Ability/DesignSystem）各自的 `Tests/`，用 Swift Testing（`import Testing`）。DesignSystem 只測純函式（滾輪幾何），元件本身是 View 測不動。
   - `*DomainTests`：UseCase 注 mock repository，純邏輯測，秒級、免模擬器。
   - `*DataTests`：Repository 用 in-memory SwiftData 測。
   - `*PresentationTests`：ViewModel 注 mock repository/port 測。
2. **UI test**：`UITests/`（Xcode UI Testing target `TrainingLaUITests`），跑在模擬器上，走真實 App 畫面互動流程。
3. **E2E UI test（真實後端 API）**：v0 App 刻意純 local-first、尚未串接後端（後端本身已部署，見 [`PROJECT_OVERVIEW.md`](./PROJECT_OVERVIEW.md) §4），暫無此類測試；等 v1 接上 API 後才補。

## 怎麼跑

- `make test-unit`：逐 package 執行 `swift test`（不需模擬器，最快）。
- `make test-uitest`：`xcodegen generate` 重生專案後，用 `UITests.xctestplan` 跑 `TrainingLaUITests`。
  **跑兩輪**：同一批 case，App 繁中一輪、App 英文一輪（見下方「英文覆蓋」）。
- `make test-e2e`：目前是佔位（echo 提示尚無真實後端）。
- `make test`：`test-unit` + `test-uitest`。

同一份 `swift test` 也能在 Xcode 裡跑：`project.yml` 把每個 package 的 unit test target 都掛進 `UnitTests.xctestplan`，跟只含 `TrainingLaUITests` 的 `UITests.xctestplan` 是兩個獨立的 Test Plan（scheme 的 Test Plan 下拉選單可切換），Test Navigator 兩邊都看得到、能分開跑，不會混在一起。

## UI test 怎麼定位元素：`accessibilityIdentifier` 命名

UI test 原本一律靠中文標籤查元素（`app.buttons["儲存"]`）。那在單一語言下沒問題，但 App 支援
在設定裡切語言之後，**任何寫死語言文字的測試就再也跑不了另一種語言**——而「切語言後畫面壞掉」
正是最需要自動化守住的東西。所以要定位的元件一律掛 identifier。

這是**為了測試與工具化**，不是無障礙工程。加 identifier 不等於做了 VoiceOver 支援，
也不要拿它當無障礙覆蓋率的指標。

- **格式 `screen.element`**，點分隔，需要再細分往後接：
  `exerciseForm.save`、`activeWorkout.completeSet`、`tabBar.item.training`、`picker.confirm`。
  早期有一派 camelCase 寫法（`libraryAddButton`、`eraseConfirmButton`），逐步收斂掉，不要再新增。
- **只給測試真的要定位的元件加**，不是全畫面掛滿。
- **測試自己輸入的資料照舊用文字定位**（動作名、課表名）——那是測試自己打進去的字串，
  本來就與介面語言無關。
- **斷言動態內容時只驗「帶這個 id 的元件存在」**，內容正確性歸 unit test。
  測試一旦斷言「目標 60kg × 8」這種字串，就又把自己綁死在某個語言上了。

`XCUIElement` 的 subscript 同時比對 identifier 與 label，所以加 identifier 不會弄壞既有那些
還在用中文查找的測試——**但這也表示「漏改了某一處」不會被測出來**。轉換完成與否要看
「UITests 裡的中文字面值歸零」，不能只看測試綠不綠。這條由 `make lint` 的規則 5 機器擋：
`UITests/` 裡凡是用中文查元素（subscript、`NSPredicate`）一律失敗，只放行測試自己輸入的資料
（白名單）。轉換已完成，腳本的 `PENDING` 是空的——新增測試不該再往裡面加。

### 英文覆蓋：同一批測試跑兩輪

**裝置語系兩輪都維持繁中，只換 App 語言**。兩邊都設英文的話 `String(localized:)` 也會回英文，
反而把「不跟著 App 語言切」這個 bug 藏起來。

```
make test-uitest      # 兩輪都跑（預設，CI 也是這個）
make test-uitest-zh   # 只跑 App 繁中那一輪
make test-uitest-en   # 只跑 App 英文那一輪
make test-uitest-en ONLY="SettingsUITests ExerciseListUITests"   # 只跑指定類別
```

英文那一輪靠 `xcodebuild test TEST_RUNNER_UITEST_APP_LANGUAGE=en` 把語言注入測試 runner，
`UITests/UITestSupport.swift` 讀到就把 `--uitest-language=en` 併進 launch arguments。
測試碼一行都不用重複 —— 不需要每支 case 寫中英兩份 func。

**新測試一律用 `launchForUITest(app)` 啟動**，不要自己設 `launchArguments`。它除了帶齊
`--uitest-inmemory` / `--uitest-today` 之外，還會確認 App 語言真的是這一輪期望的那個：
測試主體改成 identifier 定位之後就跟語言無關了，所以參數萬一失效，英文那一輪會**照樣全過**，
變成假的英文覆蓋（PR #54 發生過一次）。要固定語言（例如「測語言切換本身」的 case）
就傳 `extra: ["--uitest-language=zh-Hant"]`，`extra` 會蓋過該輪的預設。

## `Config.xcconfig`：device / headless 可調參數

`Config.xcconfig`（進版控）定義 `TEST_DEVICE`（跑 UITests 的模擬器機型，預設 `iPhone 17`）與 `TEST_HEADLESS`（bool，預設 `true`＝不開 Simulator.app 視窗）。這是 Makefile 與 Xcode 專案共用的單一真實來源：

- Makefile 用 `awk` 讀這個檔案當預設值，可指令列覆蓋：`make test-uitest DEVICE="iPhone 16 Pro" HEADLESS=false`。
- `project.yml` 用 `configFiles` 把它掛進全部 build configuration，`xcodebuild -showBuildSettings` 可看到同樣的值——但 Xcode GUI 工具列的模擬器下拉選單是互動式狀態，不會被這兩個值動態帶動，這是 Xcode 本身的限制。

## 簽章（實機建置）：Team ID 不進版控

開源 repo 不放任何人的 `DEVELOPMENT_TEAM`（`project.yml` 不寫、生成的 xcodeproj 又不進版控）。實機建置的簽章設定走本機檔案：

1. 在 repo 根目錄建 `Signing.secrets.xcconfig`（已被 `.gitignore` 的 `*.secrets.xcconfig` 排除），內容一行：`DEVELOPMENT_TEAM = <你的 Team ID>`（Xcode → Settings → Accounts 可查）。
2. `Config.xcconfig` 末尾以 `#include?`（optional include）載入它：檔案存在就生效、且能在 `xcodegen generate` 後存活；不存在也不會 build 失敗。
3. 不建這個檔的替代做法：generate 後在 Xcode 的 Signing & Capabilities 手選 team——但每次重生專案都會被洗掉，要重選。

模擬器建置不需要簽章，CI／沒有實機需求的人完全不用理這一段。

## 環境需求

本機 `xcode-select` 必須指向完整的 `Xcode.app`（而非單獨安裝的 Command Line Tools），否則 `swift test` 找不到 `Testing` framework、`xcodebuild`／模擬器也跑不了：

```
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

---

# 資料模型（Domain Entity，plain struct）

命名對齊 API 契約（見 [`PROJECT_OVERVIEW.md`](./PROJECT_OVERVIEW.md) §3、§5）。目前每個 aggregate root 底下的子列整包讀寫，之後接後端也是同一份樹狀結構整包上傳。

```
Exercise 動作庫 ─ 可重複使用的動作定義（Spec 模組）
  id, name, muscleGroup(enum), equipment(enum), description, source(user/official)

WorkoutTemplate 課表範本（aggregate root，Plan 模組）─ 可重複使用、無日期無狀態
  id, name, source(user/official), orderIndex
   └─ sets: PlanSet（與排課共用），實例化時 copy 快照成 PlanWorkout

PlanWorkout 一次排課（aggregate root，Plan 模組）─ 一定綁定某天
  id, name?, date, status, templateId?(來源範本/nil=手建), orderIndex
   └─ PlanSet 一組目標
        id, exerciseId, exerciseIndex, setIndex,
        targetWeight?: {value, unit}, targetReps?, restSec?
   （衍生視圖：PlanBlock，依 exerciseIndex 分組）

Workout 一次訓練場次（aggregate root，Training 模組）
  id, day, planWorkoutId?, startedAt?, endedAt?, overallFeeling?, note?
   └─ WorkoutSet 場次內實際做的一組
        id, exerciseId, exerciseIndex, setIndex,
        weight: {value, unit}, reps, status(done|skipped|interrupted),
        fromPlanSetId?,               // 空 = 臨時加練 / 未照課表
        targetWeight?, targetReps?    // 目標快照，課表事後被改也不影響
   （衍生視圖：ExerciseBlock，依 exerciseIndex 分組）

AbilityValue 能力值（Ability 模組）─ 使用者的 1RM／訓練最大值
  exerciseId(即 id), value: {value, unit}, source(manual|estimated), updatedAt
```

- **能力值是「你的」不是「動作的」**：以 `exerciseId` 為唯一身分，一動作一筆、upsert 語意，
  不是歷史 log。所以它不屬於 Spec（動作定義）也不屬於 Plan（排程），自成一個 domain。
  來源可為手動填入或依最近訓練紀錄推算（`SuggestAbilityValue`）。
- **紀錄可脫離課表**：`WorkoutSet.fromPlanSetId` 可為空。
- `Workout → WorkoutSet` 與 `PlanWorkout → PlanSet` 各自是一棵樹；`(exerciseIndex, setIndex)` 定位一組，兩棵樹用同一組 index 對齊「目標 vs 實際」。
- **v0 App 沒有「Plan（菜單）」這層聚合**：`PlanWorkout` 目前都是獨立排課（對應 API 的 `plan_id = null`），尚未實作把多個 `PlanWorkout` 收進一個 `Plan` 底下的 UI/流程——這是待補的差距，見 [`PROJECT_OVERVIEW.md`](./PROJECT_OVERVIEW.md) §8-4。

## Enum：肌群分類 (muscleGroup)

固定清單，避免自由輸入造成統計分裂：

```
胸 | 背 | 腿 | 肩 | 手臂 | 核心 | 功能性訓練 | 其他
```

## 重量單位：可自由切換

- 每筆重量存為 `{ value, unit }`，`unit ∈ {kg, lb}`，記錄**輸入當下的單位**為**真實來源**。
- 另有**全域顯示偏好**，檢視時即時換算顯示。
- **切換的是「顯示」，不是「已存的資料」**：避免來回換算的四捨五入侵蝕原值，確保進度趨勢真實。
- 適用欄位：`WorkoutSet.weight`、`WorkoutSet.targetWeight`、`PlanSet.targetWeight`。

---

# 後端、開源授權、產品路線圖

後端已獨立部署上線（dev 環境見 [`PROJECT_OVERVIEW.md`](./PROJECT_OVERVIEW.md) §4）、開源授權見 §9、產品路線圖見 §7（iOS 專屬階段規劃另見 [`PROJECT_PLAN.md`](./PROJECT_PLAN.md)）。這幾塊是跨 repo 的產品層資訊，不在本文件重複維護。
