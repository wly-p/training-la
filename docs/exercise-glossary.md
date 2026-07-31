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

**這張表目前沒有任何程式碼使用。** 它服務於兩件還沒決定的事：

1. 若要做「預設動作庫」（讓新使用者不用從零建動作），這是候選清單
2. 做那件事之前，得先解決一個資料模型缺口——`Exercise`
   （`Packages/Spec/Sources/SpecDomain/Exercise.swift`）目前**沒有任何欄位區分「內建常見動作」
   與「使用者自訂」**，而只有前者要翻譯。怎麼標記（`isPreset` flag？常見項目改存翻譯 key？）
   屬於 i18n 那張票的範圍

器材欄標的是「最常見的做法」，不是唯一做法（臥推也可以用啞鈴）。真的做預設動作庫時，
器材應該由使用者自己選，這欄只是建議預設值。

### 胸 Chest

| 中文 | 英文 | 常見器材 |
|---|---|---|
| 臥推 | Bench Press | `barbell` |
| 上斜臥推 | Incline Bench Press | `barbell` |
| 下斜臥推 | Decline Bench Press | `barbell` |
| 啞鈴臥推 | Dumbbell Bench Press | `dumbbell` |
| 啞鈴飛鳥 | Dumbbell Fly | `dumbbell` |
| 纜繩夾胸 | Cable Crossover | `cable` |
| 蝴蝶機夾胸 | Pec Deck | `machine` |
| 伏地挺身 | Push-Up | `bodyweight` |
| 雙槓撐體 | Chest Dip | `bodyweight` |

### 背 Back

| 中文 | 英文 | 常見器材 |
|---|---|---|
| 硬舉 | Deadlift | `barbell` |
| 羅馬尼亞硬舉 | Romanian Deadlift | `barbell` |
| 槓鈴划船 | Barbell Row | `barbell` |
| 單臂啞鈴划船 | One-Arm Dumbbell Row | `dumbbell` |
| 引體向上 | Pull-Up | `bodyweight` |
| 反手引體向上 | Chin-Up | `bodyweight` |
| 滑輪下拉 | Lat Pulldown | `cable` |
| 坐姿划船 | Seated Cable Row | `cable` |
| T 槓划船 | T-Bar Row | `barbell` |
| 面拉 | Face Pull | `cable` |

### 腿 Legs

| 中文 | 英文 | 常見器材 |
|---|---|---|
| 深蹲 | Back Squat | `barbell` |
| 前蹲 | Front Squat | `barbell` |
| 腿推 | Leg Press | `machine` |
| 保加利亞分腿蹲 | Bulgarian Split Squat | `dumbbell` |
| 弓步蹲 | Lunge | `dumbbell` |
| 腿伸展 | Leg Extension | `machine` |
| 腿彎舉 | Leg Curl | `machine` |
| 臀推 | Hip Thrust | `barbell` |
| 提踵 | Calf Raise | `machine` |
| 六角槓硬舉 | Hex Bar Deadlift | `hex_bar` |

### 肩 Shoulders

| 中文 | 英文 | 常見器材 |
|---|---|---|
| 肩推 | Overhead Press | `barbell` |
| 啞鈴肩推 | Dumbbell Shoulder Press | `dumbbell` |
| 側平舉 | Lateral Raise | `dumbbell` |
| 前平舉 | Front Raise | `dumbbell` |
| 俯身側平舉 | Rear Delt Fly | `dumbbell` |
| 直立划船 | Upright Row | `barbell` |
| 聳肩 | Shrug | `dumbbell` |

### 手臂 Arms

| 中文 | 英文 | 常見器材 |
|---|---|---|
| 槓鈴彎舉 | Barbell Curl | `barbell` |
| 啞鈴彎舉 | Dumbbell Curl | `dumbbell` |
| 錘式彎舉 | Hammer Curl | `dumbbell` |
| 集中彎舉 | Concentration Curl | `dumbbell` |
| 三頭下壓 | Triceps Pushdown | `cable` |
| 過頭三頭伸展 | Overhead Triceps Extension | `dumbbell` |
| 窄距臥推 | Close-Grip Bench Press | `barbell` |
| 三頭撐體 | Triceps Dip | `bodyweight` |

### 核心 Core

| 中文 | 英文 | 常見器材 |
|---|---|---|
| 棒式 | Plank | `bodyweight` |
| 側棒式 | Side Plank | `bodyweight` |
| 捲腹 | Crunch | `bodyweight` |
| 懸垂舉腿 | Hanging Leg Raise | `bodyweight` |
| 俄羅斯轉體 | Russian Twist | `bodyweight` |
| 死蟲 | Dead Bug | `bodyweight` |
| 鳥狗式 | Bird Dog | `bodyweight` |
| 滾輪 | Ab Wheel Rollout | `other` |
| 農夫走路 | Farmer's Walk | `dumbbell` |

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

---

## 相關

- i18n 架構與各 package 的 String Catalog：見 `ARCHITECTURE.md`
- 這份清單的下游票：「訓練項目/肌群/器材 多語系實作方式規劃及實作」
