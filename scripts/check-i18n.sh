#!/bin/bash
# i18n 迴歸防護：擋住兩種會讓「app 內語言設定」失效的寫法。
#
# 為什麼是自寫腳本而不是 SwiftLint：這個 repo 沒有裝 linter，為了兩條規則引進整套工具
# （設定檔、既有違規的 baseline、CI 安裝步驟）不划算。這裡只查兩件很具體的事。
#
# 規則 1：禁止裸 String(localized:)
#   它是立即求值、只認 process locale（＝手機語系），不吃我們注入的 \.locale environment。
#   要 plain String 就用各 package 的 localString(_:_:)；要 View 就直接 Text(key, bundle:)。
#
# 規則 2：禁止 Sources 裡出現中文字串字面值
#   代表這段文字根本沒進 String Catalog，切成英文一定露餡。
#
# 用法：./scripts/check-i18n.sh（或 make lint）。有違規回傳 1。

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fail=0

# --- 規則 1 ------------------------------------------------------------------
# 允許清單：helper 自己的實作與說明文件。
allow_localized='Localization\.swift|AppLanguage\.swift|check-i18n\.sh'

hits=$(grep -rn 'String(localized:' Packages App --include='*.swift' 2>/dev/null \
        | grep -Ev "$allow_localized" \
        | grep -Ev '^[^:]*:[0-9]+: *(//|\*)')

if [ -n "$hits" ]; then
    echo "✘ 發現裸 String(localized:)——它不吃 app 的語言設定，請改用 localString(_:_:) 或 Text(key, bundle:)："
    echo "$hits" | sed 's/^/    /'
    fail=1
fi

# --- 規則 2 ------------------------------------------------------------------
# 允許清單：非 UI 的字串（log／診斷訊息／資料值），以及 catalog 本身。
# 有正當理由要留中文的話加進這裡，並在該行寫明原因。
# AppLanguage.nativeName 刻意不翻譯：語言選單要用各語言的母語名，這樣不論目前介面是哪一種語言，
# 使用者都認得自己的選項。PlanUseCases 的「· 副本」是寫進資料的名稱（資料值，非 UI 文案）。
# OfficialExerciseCatalog 只有一句 assertionFailure 的診斷訊息；它是 domain 層的資料載入器，
# 本來就不該有 UI 文案（內建動作的名稱全在它讀的 String Catalog 裡）。
allow_han='Localizable\.xcstrings|FontRegistration\.swift|TrainingLaApp\.swift|PlanUseCases\.swift|AppLanguage\.swift|OfficialExerciseCatalog\.swift'

# 先砍掉行尾註解（`sed 's|//.*||'` 會連 URL 一起砍，但這裡只用來判斷有無違規，夠用），
# 註解裡出現中文是正常的，不該當違規。
han=$(grep -rn '"[^"]*[一-龥][^"]*"' Packages/*/Sources App --include='*.swift' 2>/dev/null \
       | grep -Ev "$allow_han" \
       | awk -F: '{ line = $0; sub(/[^:]*:[0-9]+:/, "", line); sub(/\/\/.*/, "", line);
                    if (line ~ /"[^"]*[\x{4e00}-\x{9fa5}][^"]*"/) print $0 }')

if [ -n "$han" ]; then
    echo "✘ 發現寫死的中文字串——請改成 String Catalog 的 key："
    echo "$han" | sed 's/^/    /'
    fail=1
fi

# --- 規則 3 ------------------------------------------------------------------
# 顯示用的日期文字／星期月份符號必須指定 locale。
#
# 這是跟規則 1、2 完全不同的一條漏水路徑：這些符號由系統提供、不經過 String Catalog，
# 而 Calendar.current / Locale.current 讀的是**裝置語系**，同樣不吃 \.locale environment。
# 規則 1、2 對它們完全視而不見，所以英文模式下星期照樣是中文（PR #54 沒抓到、後來才被回報）。
#
# 日期「運算」用 Calendar.current 是正當的（週界、isToday 跟裝置設定走沒問題），
# 所以這裡只擋「取顯示字串」的兩種寫法。

dates=$(python3 - <<'PY'
import pathlib, re, sys

# 兩種違規：
#   1. 讀星期／月份符號（xxxWeekdaySymbols / xxxMonthSymbols）
#   2. 建了 DateFormatter
# 只要往上／往下數行內都沒有指定 locale，就是吃裝置語系。用「附近有沒有設 locale」判斷，
# 是因為實務上寫法會拆行（let c = Calendar.current 之後才 c.shortWeekdaySymbols），
# 只比對單行的 pattern 會整個漏掉——這個洞第一次寫這條規則時就踩到了。
SYMBOLS = re.compile(r'\b\w*(?:Weekday|Month)Symbols\b')
FORMATTER = re.compile(r'\bDateFormatter\(\)')
SETS_LOCALE = re.compile(r'\.locale\s*=|locale:\s*locale')
# 裝置語系的來源。附近只要出現就算違規——即使有設 .locale，設成 `?? .current` 一樣是錯的，
# 而且「同一個函式裡別處有設 locale」不能證明這一行安全（這兩個洞第一版都漏了）。
DEVICE_LOCALE = re.compile(r'\.current\b')
COMMENT = re.compile(r'//.*$', re.M)
WINDOW = 4

violations = []
for path in sorted(pathlib.Path(".").glob("Packages/*/Sources/**/*.swift")) + \
            sorted(pathlib.Path("App").glob("**/*.swift")):
    lines = path.read_text().split("\n")
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith(("//", "///", "*")):
            continue
        if not (SYMBOLS.search(line) or FORMATTER.search(line)):
            continue
        # 註解要先拿掉再判斷：說明文字裡提到 Calendar.current 是正常的，
        # 不先剝掉的話這條規則會被自己的說明註解觸發。
        near = COMMENT.sub("", "\n".join(lines[max(0, i - WINDOW): i + WINDOW + 1]))
        if DEVICE_LOCALE.search(near) or not SETS_LOCALE.search(near):
            violations.append(f"{path}:{i + 1}:{stripped}")

print("\n".join(violations))
PY
)

if [ -n "$dates" ]; then
    echo "✘ 日期／星期文字沒指定 locale——預設吃裝置語系，不是 app 的語言設定："
    echo "$dates" | sed 's/^/    /'
    fail=1
fi

# --- 規則 4 ------------------------------------------------------------------
# 程式碼查表用的 key，必須真的存在於該 target 的 String Catalog。
#
# 查不到時 `localizedString` 回傳 key 本身，畫面就直接顯示 "template.block.percentOfMax 3"
# 這種東西——而且**兩種語言一起壞**，切語言看不出差別，翻譯齊備性的測試也抓不到
# （它只檢查 catalog 裡已有的 key 翻譯齊不齊，不知道有 key 根本沒進 catalog）。
#
# 實際踩過：1RM → 最大重量 更名時改了程式碼的 key，翻譯卻留在舊 key 底下。
# rename 很容易再犯，所以用機器擋。

missing=$(python3 - <<'PY'
import json, pathlib, re, sys

# 各 package 的本地化 helper。key 一律是呼叫的第一個字串字面值。
HELPERS = re.compile(
    r'\b(?:localText|localString|localizedString)\s*\('
    r'|\.(?:plan|spec|training|history)\s*\('
    r'|\bText\s*\((?=[^)]*bundle:)'
)


def literals_in_call(text: str, start: int) -> list[str]:
    """從 `(` 之後掃到對應的 `)`，回傳這一段裡的所有字串字面值。

    要自己數括號而不是用正則：key 常帶插值（"a \\(n)"），`[^)]*` 會在插值的
    `)` 就停掉。順帶也涵蓋三元寫法 localText(cond ? "a" : "b")。
    """
    depth, i, out, n = 0, start, [], len(text)
    while i < n:
        c = text[i]
        if c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == '\\' else 1
            out.append(text[i + 1:j])
            i = j + 1
            continue
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return out
        elif c == '\n' and depth == 0:
            return out
        i += 1
    return out


def catalog_for(path: pathlib.Path) -> pathlib.Path | None:
    """往上找該 target 自帶的 Localizable.xcstrings。"""
    for parent in path.parents:
        candidate = parent / "Localizable.xcstrings"
        if candidate.exists():
            return candidate
        if parent.name in ("Sources", "Packages") or parent == pathlib.Path("."):
            return None
    return None


catalogs: dict[pathlib.Path, set[str]] = {}
violations = []

for path in sorted(pathlib.Path(".").glob("Packages/*/Sources/**/*.swift")) + \
            sorted(pathlib.Path("App").glob("**/*.swift")):
    source = path.read_text()
    cat_path = catalog_for(path)
    if cat_path is None:
        continue
    if cat_path not in catalogs:
        data = json.loads(cat_path.read_text())
        source_language = data.get("sourceLanguage")
        # 只有「來源語言有值」的 key 才算數。光是 key 存在不夠——Xcode 掃到程式碼裡的新 key
        # 會自動補一個空殼進 catalog，那時查表仍然回傳 key 本身，畫面照樣壞。
        # percentOfMax 那個 bug 就是這個形狀，只檢查 key 在不在會漏掉。
        catalogs[cat_path] = {
            key
            for key, entry in data.get("strings", {}).items()
            if (entry.get("localizations", {})
                     .get(source_language, {})
                     .get("stringUnit", {})
                     .get("value") or "").strip()
        }
    keys = catalogs[cat_path]

    for m in HELPERS.finditer(source):
        for raw in literals_in_call(source, m.end() - 1):
            # 插值的 key（"a \(n)"）在 catalog 裡是 "a %lld" 之類，比前綴就好。
            prefix = raw.split("\\(")[0]
            if not re.match(r'^[A-Za-z][A-Za-z0-9_]*\.', prefix):
                continue          # 不像 key（格式參數、verbatim 文字…），跳過
            if any(k.startswith(prefix) for k in keys):
                continue
            line = source[:m.start()].count("\n") + 1
            violations.append(f"{path}:{line}:{raw}  →  {cat_path}")

print("\n".join(sorted(set(violations))))
PY
)

if [ -n "$missing" ]; then
    echo "✘ 這些 key 在 String Catalog 裡沒有翻譯——畫面會直接顯示 key 本身（中英文都會壞）："
    echo "$missing" | sed 's/^/    /'
    fail=1
fi

if [ "$fail" -eq 0 ]; then
    echo "✔ i18n 檢查通過"
fi
exit "$fail"
