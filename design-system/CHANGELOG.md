# 元件庫變更紀錄

元件自身的改動記在各自 spec 的第 12 節。**token 與契約層級的改動記這裡** ——
那些改動不屬於任何單一元件，但會影響每一個元件，之前沒有地方可以記。

刪一個 token 是設計決策，不是清理。所以刪除也要記，而且要寫清楚是哪一種情況：
角色不需要了／只是改名／被別的 token 吸收。

---

## 2026-08-30 · 第二輪設計端審閱後

### token

- **刪除語意 token `surfaceSunken`**（原本指向 `sand.raised` `#EBDDC5`，職責「頁面上的表面色塊」）。
  **屬於「角色不需要了」**：查證 `TLColor.surface` 全專案 **0 處使用**，
  它是 0a 建立語意層時，我幫一個從未被用過的色票發明的角色 —— 為沒有用途的顏色發明語意名，
  正是取錯名字的來源。舊名 alias `surface` 一併移除。
  **沒有任何畫面的顏色因此改變。**
  色階層的 `sand.raised` **保留**：它是原始色票的一員，只是目前沒有語意角色指向它。
  之後若有畫面需要「頁面上的表面色塊」，在那時依實際用途命名，不要現在預先發明。

- 新增 `icon`（`s`/`m`/`l`／`weight`／`strokeWeb`）與 `motion`（`fast`/`base`/`curve`）兩組。
  `motion` 的值取自程式碼現況（easeOut 0.2／0.18／0.15），不是憑空定的三階；
  `0.18` 是落單值，收斂前不要新增第四個值。

- 語意色改名：`accentOnLight` → `accentOnSurface`、`dangerOnLight` → `dangerOnSurface`。
  違反 §5「語意 token 名不得帶外觀」—— `OnLight` 預設了底色是淺的，深色接上時會直接說謊。

- `--icon-stroke` 的 `2.75` 原本是生成器裡的字面值，不是從 `tokens.json` 來的。
  補 `icon.strokeWeb` 當來源 —— 單一來源在這裡漏了一個洞。

### 契約

- §7.3 加上**展示骨架的豁免**：色票方塊、示意方塊的尺寸可以用字面值（「色票要畫多大」跟設計系統無關），
  但**字面色值永遠不豁免**。不寫的話，第一次跑 lint 就會有人為了過檢查把 `46px` 塞成 token，汙染 token 表。
- §8 的檢查表改成**從 `check-design-system.py` 的 `CHECKS` 生成**。
  `scripts/` 不進交付包，README 是設計端唯一看得到「實際擋了什麼」的地方；
  手寫一定會過期，然後審閱會針對一份虛構的清單提意見（第二輪就發生了兩次）。

### preview

- 共用外殼 `preview.css` 的**列間分隔線原本橫跨整列寬，是錯的**。
  app 的 `TLDivider` 有 `.padding(.leading, TLSpace.rowInset)`，分隔線左內縮 18。
  改用 `::after` 定位。錯在共用外殼裡，所有元件會一起錯。

### 新增檢查

- **10** preview 用到的字都要在子集字型裡。內嵌中文子集換來 preview 自足，
  代價是「改了文案沒重生子集就靜默缺字」。
- **12** 文件裡提到的 token 名都要真的存在。抓「token 被刪／改名，文件還在講它」。

---

## 已知缺口（留給榨取階段）

不是 bug，是 token 化尚未覆蓋到的地方。記在這裡免得每個階段重新發現一次。

| 缺口 | 規模 | 何時處理 |
|---|---|---|
| `neutral700` 被用 **16 處**，但沒有任何語意角色（`textSecondary` 是 neutral600、比它淺） | 跨 Plan／Training／DesignSystem | 撞到它的第一個階段順手命名 |
| `TLFont.display(N)` 用了 **16 種字面字級**（15／20／16／34／30／28／26／13.5／60／56／19／17／14…），只有 2 處走 token | 全 app | 數字的字級尺度需要一次性收斂，建議在階段 5（訓練）之前決定 |
| Presentation 層 **181 處**字面樣式 | 見 `.presentation-baseline.json` | 每階段往下推，階段 5 結束歸零 |
| `TLExerciseNameWithEquipment` 名字帶 domain 詞彙（實際不 import domain，層級沒錯，只是命名有味道） | 1 處 | 階段 2 |
| `TLCircleIconButton` 是 View 卻住在 `Support/ButtonStyles.swift` | 1 處 | 任一階段順手 |
