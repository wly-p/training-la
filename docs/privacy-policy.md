# Privacy Policy / 隱私政策

> **這份 markdown 是內容的真實來源。** 對外的頁面（HTML）由這份文件產出，
> 版面規格與部署方式見 [`privacy-page-spec.md`](./privacy-page-spec.md)。
>
> ⚠️ 改動 App 的資料處理行為時（例如接上後端同步、加入帳號、引入任何第三方 SDK），
> **必須在同一個 PR 更新這份文件**，並同步修改 App Store Connect 的隱私標籤。
> 隱私政策與實際行為不符是可以導致下架的。

**Effective date / 生效日期：2026-08-07**
**Last updated / 最後更新：2026-08-07**

<!-- TODO(上架前)：把 CONTACT_EMAIL 換成真實信箱。這是 Apple 要求的可聯絡方式，
     且會公開在網頁上——要用哪個位址是產品決定，不要直接沿用個人主信箱。 -->

---

## English

### Summary

**Training La does not collect any data.**

The app has no account system, makes no network requests, and contains no analytics,
advertising, or third-party SDKs. Everything you record stays on your device.

### What the app stores on your device

All of the following is stored locally on your device and never leaves it:

- **Exercises** you create — name, muscle group, equipment, description
- **Plans and templates** — scheduled workouts, routines, and long-term programs
- **Workout records** — sets, weights, repetitions, dates, and notes
- **Ability values** — the maximum weight recorded for each exercise
- **Preferences** — interface language, appearance theme, weight unit (kg/lb),
  weight and rest increments, and rest-reminder settings

Workout content is stored using Apple's SwiftData framework; preferences are stored in
`UserDefaults`. Both are private to the app's own storage on your device.

### What the app does not do

- No account, no sign-in, no user identifier
- No network requests — the app works entirely offline
- No analytics, crash reporting, or usage measurement
- No advertising and no tracking, as defined by Apple's App Tracking Transparency
- No third-party SDKs of any kind
- No data is sold, shared, or transmitted to anyone

### Notifications

If you enable rest reminders, the app asks for permission to send **local** notifications.
These are scheduled and delivered entirely on your device. No notification content is sent
to any server, including Apple's push notification service.

You can revoke this permission at any time in the iOS Settings app.

### Deleting your data

- **Inside the app:** Settings → Delete All Data removes every exercise, plan, and workout
  record from your device.
- **Removing the app:** deleting Training La from your device removes all of its data,
  including preferences.

Because no data ever leaves your device, there is nothing for us to delete on our side and
no data-access request to make.

### Children

The app collects no data from anyone, including children under 13.

### Changes to this policy

If the app's data handling changes — for example if optional cloud sync is added in a
future version — this policy will be updated before that version is released, and the
effective date above will change. Material changes will also be reflected in the app's
privacy information on the App Store.

### Contact

Questions about this policy: `CONTACT_EMAIL`

---

## 繁體中文

### 摘要

**Training La 不收集任何資料。**

這個 App 沒有帳號系統、不會發出任何網路請求，也沒有分析工具、廣告或任何第三方 SDK。
你記錄的一切都留在你自己的裝置上。

### App 在你裝置上儲存了什麼

以下全部儲存在你的裝置本機，不會離開裝置：

- **你建立的動作** — 名稱、肌群、器材、說明
- **課表與範本** — 排定的訓練、循環、長期課表
- **訓練紀錄** — 組數、重量、次數、日期與備註
- **能力值** — 每個動作記錄到的最大重量
- **偏好設定** — 介面語言、外觀主題、重量單位（公斤／磅）、重量與休息級距、休息提醒設定

訓練內容使用 Apple 的 SwiftData 框架儲存，偏好設定存在 `UserDefaults`。
兩者都在 App 自己的私有儲存空間裡。

### App 不會做的事

- 沒有帳號、不需登入、不產生任何使用者識別碼
- 不發出網路請求——完全離線也能使用全部功能
- 沒有分析、當機回報或使用行為統計
- 沒有廣告，也沒有 Apple「App 追蹤透明度」定義下的追蹤行為
- 沒有任何第三方 SDK
- 不販售、不分享、不傳輸任何資料給任何人

### 通知

如果你開啟休息提醒，App 會請求發送**本機**通知的權限。這些通知完全在你的裝置上排程與送出，
通知內容不會傳送到任何伺服器，包括 Apple 的推播通知服務。

你可以隨時在 iOS 的「設定」中收回這個權限。

### 刪除你的資料

- **在 App 內：** 設定 → 刪除所有資料，會清除裝置上全部的動作、課表與訓練紀錄。
- **移除 App：** 把 Training La 從裝置上刪除，會一併移除所有資料，包含偏好設定。

因為資料從未離開你的裝置，我們這邊沒有任何東西可以刪除，你也不需要提出資料存取請求。

### 兒童

本 App 不向任何人收集資料，包含 13 歲以下的兒童。

### 政策變更

如果 App 的資料處理方式改變——例如未來版本加入選用的雲端同步——這份政策會在該版本發布**之前**
更新，上方的生效日期也會隨之改變。重大變更同時會反映在 App Store 上的隱私資訊。

### 聯絡方式

對本政策有疑問：`CONTACT_EMAIL`
