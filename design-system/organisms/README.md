# L3 有機體

綁自己 package 的 model，會出現在多個畫面。可以 import domain 型別 —— 這正是它留在 package 裡的原因。住 各 package 的 `Presentation/Components/`，**無**前綴。

每個元件一個目錄，含 `X.spec.md` 與 `X.preview.html`（實作檔的位置由 spec 第 1 節指出）。
規格樣板見 [`../_template.spec.md`](../_template.spec.md)，規則見 [`../README.md`](../README.md)。

實作檔留在 package 裡，但 `X.spec.md` 與 `X.preview.html` 集中放這裡、preview 用假資料 —— 否則設計端拿不到完整的一包。

判斷法：**這個元件需要 import 某個 package 的 model 嗎？**需要 → L3；不需要 → 往 L1／L2 移。
