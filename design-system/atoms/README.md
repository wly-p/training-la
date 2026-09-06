# L1 原子

不可再分。只收 `String` / `Int` / `Bool` / closure。**不得認識任何 domain 型別**。住 `Packages/DesignSystem/Sources/DesignSystem/Atoms/`，一律 `TL` 前綴。

每個元件一個目錄，含 `X.spec.md` 與 `X.preview.html`（實作檔的位置由 spec 第 1 節指出）。
規格樣板見 [`../_template.spec.md`](../_template.spec.md)，規則見 [`../README.md`](../README.md)。

原子沒有第 2 節的 slots、也沒有第 11 節組成；其餘各節都要填。

原子幾乎都**自己不完整** —— 必須放在某個容器裡才成立。規格第 1 節的「獨立使用」與「容器責任」兩格就是為了這件事，一定要填。
