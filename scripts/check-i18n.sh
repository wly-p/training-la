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
allow_han='Localizable\.xcstrings|FontRegistration\.swift|TrainingLaApp\.swift|PlanUseCases\.swift|AppLanguage\.swift'

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

if [ "$fail" -eq 0 ]; then
    echo "✔ i18n 檢查通過"
fi
exit "$fail"
