# 訓練項目 / 肌群 / 器材 中英文對照

這份清單是**參考資料，不是程式碼的一部分**——沒有任何 build 或 test 依賴它。

## 為什麼有這份文件

i18n 主線（Part 1–3）完成了全 app 介面文字的中英雙語，但依當時約定刻意排除「資料值」：
`MuscleGroup`（8 類）與 `Equipment`（9 類）的 `displayName` 目前寫死中文。要補上那塊，得先有一份
講定的英文對照——這份文件就是那個前置。

範圍上有一條已確認的界線：**「常見／預設」動作要多語系，使用者自己新增的動作不翻譯、原樣顯示**。
所以表 3 只是「未來若要做預設動作庫」的候選清單，不是使用者資料的翻譯字典。

清單以人工整理，沒有爬蟲。理由是 `MuscleGroup` / `Equipment` 的英文其實已經在程式碼裡
（`rawValue` 就是英文 token），只需要決定顯示用的措辭；而動作名稱各家健身網站的命名帶有商標與
流派差異，爬下來反而要花更多力氣挑，人工精選比較可靠也好維護。

---

## 表 1 · 肌群 MuscleGroup

定義於 `Packages/SharedKernel/Sources/SharedKernel/MuscleGroup.swift`。
`rawValue` 是儲存與 API 契約共用的 token，不要改。

| rawValue | 中文（現有 displayName） | 英文 |
|---|---|---|
| `chest` | 胸 | Chest |
| `back` | 背 | Back |
| `legs` | 腿 | Legs |
| `shoulders` | 肩 | Shoulders |
| `arms` | 手臂 | Arms |
| `core` | 核心 | Core |
| `functional` | 功能性訓練 | Functional |
| `other` | 其他 | Other |

措辭說明：中文是單字（胸、背、腿），英文用複數形（Chest、Legs）——這是英文健身語境的慣例，
篩選 chip 上讀起來也自然。`functional` 中文是「功能性訓練」四個字，英文只用 `Functional`
不加 Training，因為它出現的位置（chip、副標）已經有「肌群」的語境。

## 表 2 · 器材 Equipment

定義於 `Packages/SharedKernel/Sources/SharedKernel/Equipment.swift`。

| rawValue | 中文（現有 displayName） | 英文 |
|---|---|---|
| `barbell` | 槓鈴 | Barbell |
| `dumbbell` | 啞鈴 | Dumbbell |
| `kettlebell` | 壺鈴 | Kettlebell |
| `hex_bar` | 六角槓 | Hex Bar |
| `machine` | 機械 | Machine |
| `cable` | 纜繩 | Cable |
| `band` | 彈力帶 | Resistance Band |
| `bodyweight` | 自體重量 | Bodyweight |
| `other` | 其他 | Other |

措辭說明：`band` 英文用 `Resistance Band` 而不是單獨的 `Band`——後者在英文裡歧義太大。
`hex_bar` 也有人叫 trap bar，但 Hex Bar 對非母語使用者比較好懂，且跟中文「六角槓」對得上。

---

## 表 3 · 常見動作

**這張表目前沒有任何程式碼使用。** 它是「預設動作庫」（讓新使用者不用從零建動作）的候選清單。

這張表列的**全部都是系統內建**的動作，seed 進去時 `source` 應為 `.official`
（`Exercise.source: ContentSource`，`Packages/Spec/Sources/SpecDomain/Exercise.swift`）。
欄位早就存在、存取層也接好了，不需要另外加 `isPreset` 之類的旗標——目前只是還沒有任何地方
寫入 `.official`，因為還沒有官方內容來源。

`.user`（使用者自建）與 `.official` 的實際差別只有一個：**自建的動作不做 i18n，原樣顯示**。

器材欄標的是「最常見的做法」，不是唯一做法（臥推也可以用啞鈴）。真的做預設動作庫時，
器材應該由使用者自己選，這欄只是建議預設值。

分組是**互斥**的：`Exercise` 一個動作只有一個 `muscleGroup`，所以同一個動作不會出現在兩組。
邊界上的動作依「主要訓練目標」歸類——硬舉歸腿不歸背、面拉歸肩不歸背、農夫走路歸功能性不歸核心，
雖然它們對第二個部位也有明顯刺激。

**名稱允許重複**（2026-08-01 決議）。`Exercise` 只有 `id` 是唯一鍵，名稱本來就不唯一；
同一個動作在不同器材上仍叫同一個名字（肩推有槓鈴／啞鈴／機械三筆），**靠 UI 顯示器材來分辨**，
不用「機械肩推」這種前綴把器材塞進名稱裡。名稱只描述動作本身；握法、角度、單邊這類**不是器材**
的變化才寫進名稱（窄距臥推、上斜臥推、單臂划船）。

⚠️ 這條對 i18n 有直接後果：**中文同名時英文常常不同名**（肩推 → 槓鈴 Overhead Press
／機械 Shoulder Press；夾胸 → 纜繩 Cable Crossover／機械 Pec Deck）。

所以**翻譯一律以 `id` 為 key，中文和英文名稱都只是那個 id 的某個語言的值**（2026-08-01 決議）。
拿名稱當 key 兩邊都不成立：中文會撞（肩推有三筆），英文則不是一對一。

### 胸 Chest

| 中文 | 英文 | 常見器材 |
|---|---|---|
| 臥推 | Bench Press | `barbell` |
| 臥推 | Bench Press | `dumbbell` |
| 胸推 | Chest Press | `machine` |
| 上斜臥推 | Incline Bench Press | `barbell` |
| 上斜臥推 | Incline Bench Press | `dumbbell` |
| 下斜臥推 | Decline Bench Press | `barbell` |
| 飛鳥 | Dumbbell Fly | `dumbbell` |
| 夾胸 | Cable Crossover | `cable` |
| 夾胸 | Pec Deck | `machine` |
| 伏地挺身 | Push-Up | `bodyweight` |
| 雙槓撐體 | Chest Dip | `bodyweight` |

### 背 Back

| 中文 | 英文 | 常見器材 |
|---|---|---|
| 槓鈴划船 | Barbell Row | `barbell` |
| 單臂划船 | One-Arm Row | `dumbbell` |
| 坐姿划船 | Seated Cable Row | `cable` |
| 坐姿划船 | Seated Row | `machine` |
| 滑輪下拉 | Lat Pulldown | `cable` |
| 引體向上 | Pull-Up | `bodyweight` |
| 引體向上 | Assisted Pull-Up | `machine` |
| 反手引體向上 | Chin-Up | `bodyweight` |
| T 槓划船 | T-Bar Row | `barbell` |

### 腿 Legs

| 中文 | 英文 | 常見器材 |
|---|---|---|
| 深蹲 | Back Squat | `barbell` |
| 前蹲 | Front Squat | `barbell` |
| 哈克深蹲 | Hack Squat | `machine` |
| 硬舉 | Deadlift | `barbell` |
| 羅馬尼亞硬舉 | Romanian Deadlift | `barbell` |
| 六角槓硬舉 | Hex Bar Deadlift | `hex_bar` |
| 腿推 | Leg Press | `machine` |
| 保加利亞分腿蹲 | Bulgarian Split Squat | `dumbbell` |
| 弓步蹲 | Lunge | `dumbbell` |
| 腿伸展 | Leg Extension | `machine` |
| 腿彎舉 | Leg Curl | `machine` |
| 臀推 | Hip Thrust | `barbell` |
| 臀推 | Hip Thrust Machine | `machine` |
| 髖外展 | Hip Abduction | `machine` |
| 髖外展 | Lateral Band Walk | `band` |
| 髖內收 | Hip Adduction | `machine` |
| 提踵 | Calf Raise | `machine` |

### 肩 Shoulders

| 中文 | 英文 | 常見器材 |
|---|---|---|
| 肩推 | Overhead Press | `barbell` |
| 肩推 | Shoulder Press | `dumbbell` |
| 肩推 | Shoulder Press | `machine` |
| 阿諾肩推 | Arnold Press | `dumbbell` |
| 側平舉 | Lateral Raise | `dumbbell` |
| 側平舉 | Lateral Raise Machine | `machine` |
| 前平舉 | Front Raise | `dumbbell` |
| 俯身側平舉 | Rear Delt Fly | `dumbbell` |
| 面拉 | Face Pull | `cable` |
| 面拉 | Band Pull-Apart | `band` |
| 直立划船 | Upright Row | `barbell` |
| 聳肩 | Shrug | `dumbbell` |

### 手臂 Arms

| 中文 | 英文 | 常見器材 |
|---|---|---|
| 彎舉 | Barbell Curl | `barbell` |
| 彎舉 | Dumbbell Curl | `dumbbell` |
| 彎舉 | Machine Curl | `machine` |
| 牧師椅彎舉 | Preacher Curl | `barbell` |
| 錘式彎舉 | Hammer Curl | `dumbbell` |
| 集中彎舉 | Concentration Curl | `dumbbell` |
| 三頭下壓 | Triceps Pushdown | `cable` |
| 過頭三頭伸展 | Overhead Triceps Extension | `dumbbell` |
| 過頭三頭伸展 | Triceps Extension Machine | `machine` |
| 窄距臥推 | Close-Grip Bench Press | `barbell` |
| 三頭撐體 | Triceps Dip | `bodyweight` |

### 核心 Core

| 中文 | 英文 | 常見器材 |
|---|---|---|
| 棒式 | Plank | `bodyweight` |
| 側棒式 | Side Plank | `bodyweight` |
| 捲腹 | Crunch | `bodyweight` |
| 捲腹 | Ab Crunch Machine | `machine` |
| 懸垂舉腿 | Hanging Leg Raise | `bodyweight` |
| 俄羅斯轉體 | Russian Twist | `bodyweight` |
| 死蟲 | Dead Bug | `bodyweight` |
| 鳥狗式 | Bird Dog | `bodyweight` |
| 滾輪 | Ab Wheel Rollout | `other` |

### 功能性訓練 Functional

| 中文 | 英文 | 常見器材 |
|---|---|---|
| 壺鈴擺盪 | Kettlebell Swing | `kettlebell` |
| 土耳其起立 | Turkish Get-Up | `kettlebell` |
| 抓舉 | Snatch | `barbell` |
| 上膊 | Power Clean | `barbell` |
| 挺舉 | Clean and Jerk | `barbell` |
| 波比跳 | Burpee | `bodyweight` |
| 跳箱 | Box Jump | `bodyweight` |
| 藥球砸地 | Medicine Ball Slam | `other` |
| 戰繩 | Battle Rope | `other` |
| 雪橇推拉 | Sled Push / Drag | `other` |
| 農夫走路 | Farmer's Walk | `dumbbell` |

---

## 相關

- i18n 架構與各 package 的 String Catalog：見 `ARCHITECTURE.md`
- 這份清單的下游票：「訓練項目/肌群/器材 多語系實作方式規劃及實作」
