# 隱私政策頁：版面規格、部署方式、上架檢查清單

內容的真實來源是 [`privacy-policy.md`](./privacy-policy.md)；這份文件講的是**怎麼做成對外的頁面、放在哪裡**，
以及 App Store 送審時相關的必填欄位。

---

## 一、為什麼這頁的要求跟一般網頁不同

**隱私政策 URL 掛掉是可以導致 App 下架的。** 它必須比整個系統裡任何其他東西都不容易壞。
下面所有規則都是從這一句推導出來的，不是美學偏好。

Apple 本身**對視覺沒有任何規範**，只要求內容說得清楚、且頁面公開可達（不需登入、載得起來）。

## 二、頁面的硬性規則

| 規則 | 為什麼 |
|---|---|
| **自足單檔，不引任何外部資源** | 不要 CDN 字型、外部 CSS/JS。CDN 掛掉或被牆，政策頁就變成排版崩壞的裸文字 |
| **不依賴 JavaScript** | 少一個失敗模式。純文件沒有需要 JS 的理由 |
| **手機優先** | 多數人是在 App Store 頁面上用手機點進來的。要有 `viewport` meta、可讀字級、不得橫向捲動 |
| **支援深色模式** | iOS 深色模式下點開一片死白很刺眼。`@media (prefers-color-scheme: dark)` 一段就夠 |
| **語意化 HTML ＋ `lang` 屬性** | 中英同頁時兩段各自標 `lang`，螢幕閱讀器與瀏覽器翻譯才不會亂 |
| **中英同一頁，不要拆兩個 URL** | 兩個檔案一定會漂移。頁首放語言錨點連結即可 |

內容面的慣例：**一定要有生效日期／最後更新日**，以及明確的聯絡方式（Apple 要求可聯絡）。

## 三、視覺：呼應 App 的配色

目的是讓這頁看起來是產品的一部分，而不是隨手貼的純文字——對作品集導向的專案值得。
但**不要把 DesignSystem 移植成 CSS**，取幾個 token 就好。

取自 `Packages/DesignSystem/Sources/DesignSystem/DesignTokens.swift`：

| 用途 | 淺色 | 深色（建議） |
|---|---|---|
| 頁面底色 | `#F5EAD8`（奶油） | `#201E1D` |
| 主文字 | `#201E1D` | `#F5EAD8` |
| 次要文字 | `#82796A`（neutral600） | `#A19786`（neutral500） |
| 連結／重點 | `#8C491A`（accent700） | `#F6A06B`（accent400，深底上要夠亮） |
| 分隔線 | `#201E1D` @ 8% | `#F5EAD8` @ 12% |

字型用系統字體堆疊（`-apple-system` 起頭），**不要載 App 用的自訂字體**——那是為 iOS 打包的資源，
放上網會多一個外部相依，違反第二節第一條。

## 四、部署：Cloudflare Pages

網域已經在 Cloudflare，這是最省事也最耐用的組合。

**設定**：production branch 設 `main`、build command 留空、output directory 指到放 HTML 的資料夾。
免費方案每月 500 次 build，只在 `main` 有動作時觸發的話用不到零頭。

**Cloudflare Pages 可以從 private repo 部署**，這一點解掉了一個兩難：政策可以留在 App repo 裡、
跟它描述的程式碼並排、同一個 PR 一起改，而 repo 之後要轉私有也不影響部署。
比另開一個 legal repo 好——「改了 App 行為卻忘了改政策」是這件事最實際的失敗模式。

### 為什麼不是其他選項

- **不要放 Cloud Run**（後端目前的位置）：會把政策頁的可用性綁在 API 服務上，API 掛了或搬遷、
  改配置，政策頁跟著死。靜態頁走 Cloud Run 還要吃冷啟動。
- **GCP 靜態方案不划算**：GCS bucket 要自訂網域 ＋ HTTPS 就得掛 Cloud Load Balancer，
  光是存在就要月費約 18 美金，為一個 HTML 檔付這個很荒謬。Firebase Hosting 免費可行，
  但要多開一個 Firebase 專案。
- **AWS S3 ＋ CloudFront** 能做，但要弄 ACM 憑證與 distribution，比需要的 ops 多，
  而且網域在 Cloudflare 會變成兩邊管。

### 網域取名

建議用子網域（例如 `training-la.wly.lol`），不要 `wly.lol/training-la/privacy`。
因為 App Store Connect 除了隱私政策 URL 之外 **Support URL 也是必填**，之後大概還會想要一個
App 介紹頁——一個子網域可以長成這個站，塞在主網域的路徑底下之後很難整理。

## 五、App Store 送審相關

### 必填 URL（兩個）

| 欄位 | 內容 |
|---|---|
| Privacy Policy URL | 本頁 |
| Support URL | 同一個站的支援頁（尚未撰寫） |

### App Privacy「隱私標籤」問卷

答案是最單純的那一種：**Data Not Collected**（不收集任何資料）。
選了這個之後不需要再回答資料類型、用途、是否連結到使用者、是否用於追蹤等後續問題。

### `PrivacyInfo.xcprivacy`（隱私宣告清單）

**尚未加入，是本主題剩下的實作工作。** 掃描結果如下：

- 第三方 SPM 依賴：**0 個**（全是 local path）——第三方 SDK 的隱私宣告向來是最麻煩的部分，這裡不存在
- 網路呼叫：**0 個**
- Apple「必須說明理由」的 API：**只有 UserDefaults 一類**
  （檔案時間戳、系統開機時間、磁碟可用空間、使用中鍵盤四類全部沒碰）

所以檔案內容會是：

- `NSPrivacyTracking` → `false`
- `NSPrivacyTrackingDomains` → 空陣列
- `NSPrivacyCollectedDataTypes` → 空陣列
- `NSPrivacyAccessedAPITypes` → 一筆 `NSPrivacyAccessedAPICategoryUserDefaults`，
  理由碼 `CA92.1`（存取 App 自身的資料）

⚠️ 要掛進 `project.yml` 的 app target（xcodeproj 不進版控，手動加會被下次 `xcodegen generate` 洗掉）。

## 六、還沒做的事

- [ ] `PrivacyInfo.xcprivacy` ＋ `project.yml` 接線
- [ ] 把 `privacy-policy.md` 的 `CONTACT_EMAIL` 換成真實信箱（產品決定，不要直接用個人主信箱）
- [ ] 依本規格產出 HTML
- [ ] 建 Cloudflare Pages 專案、指定自訂網域
- [ ] 撰寫 Support 頁
- [ ] App Store Connect 填入兩個 URL 與隱私標籤（需要開發者帳號）
