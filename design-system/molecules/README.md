# L2 分子

由原子組成，仍與 domain 無關。**不得認識任何 domain 型別**。住 `Packages/DesignSystem/Sources/DesignSystem/Molecules/`，一律 `TL` 前綴。

每個元件一個目錄，含 `X.spec.md` 與 `X.preview.html`（實作檔的位置由 spec 第 1 節指出）。
規格樣板見 [`../_template.spec.md`](../_template.spec.md)，規則見 [`../README.md`](../README.md)。

規格第 11 節要列出它由哪些 L1 組成 —— `make lint` 會檢查那些原子真的在庫裡，而且會擋「preview 出現不屬於任何 L1 的裸樣式」。

preview 需要假資料時，**不要用真的運動名稱**（臥推、組數…）。那是最順手的假資料，但寫下去的那一刻 L2 就認識 domain 了。機器檢查會擋。
