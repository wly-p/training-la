#!/usr/bin/env python3
"""把 preview 用到的中文字挑出來，做成 Noto Sans TC 子集。

為什麼要子集：契約禁止 preview 有外部請求，但完整的 Noto Sans TC 有 10MB+，
不適合進版控。所以只把 preview 實際用到的字打包（通常幾百字、幾百 KB）。

原始字型不進版控，需要重生時才下載到 gitignore 的快取。
換一台機器只有在「preview 的中文字變了」時才需要聯網。

跑法（需要 uv）：
    make preview-font
"""
import pathlib, sys, urllib.request

ROOT  = pathlib.Path(__file__).resolve().parent.parent
DS    = ROOT / "design-system"
CACHE = ROOT / ".font-cache"
SRC   = CACHE / "NotoSansTC.ttf"
OUT   = DS / "fonts" / "NotoSansTC-subset.woff2"
MANI  = DS / "fonts" / "subset-chars.txt"
URL   = "https://github.com/google/fonts/raw/main/ofl/notosanstc/NotoSansTC%5Bwght%5D.ttf"

# preview 會渲染的字：所有 HTML 的內容。spec 是 markdown，設計端用自己的檢視器讀，不吃這支字型。
def used_chars() -> set[str]:
    chars = set(
        " !\"#$%&'()*+,-./0123456789:;<=>?@"
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`"
        "abcdefghijklmnopqrstuvwxyz{|}~"
        "—…‧、。「」『』（）％×÷·§→←↑↓✓✘"
    )
    for f in DS.rglob("*.html"):
        chars |= set(f.read_text())
    return {c for c in chars if c.isprintable() and not c.isspace()} | {" "}

def main() -> int:
    try:
        from fontTools import subset
    except ImportError:
        print("✘ 需要 fontTools。用 make preview-font（走 uv），不要直接跑這支。", file=sys.stderr)
        return 1

    chars = used_chars()
    cjk = sum(1 for c in chars if "一" <= c <= "鿿")

    if not SRC.exists():
        CACHE.mkdir(exist_ok=True)
        print(f"下載 Noto Sans TC 原始字型（一次性，存到 {CACHE.name}/，不進版控）…")
        urllib.request.urlretrieve(URL, SRC)
        print(f"  {SRC.stat().st_size / 1_048_576:.1f} MB")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    args = [str(SRC), f"--text={''.join(sorted(chars))}", "--flavor=woff2",
            f"--output-file={OUT}", "--layout-features=*", "--no-hinting"]
    subset.main(args)
    MANI.write_text("".join(sorted(chars)))
    print(f"✔ {OUT.relative_to(ROOT)}  {OUT.stat().st_size / 1024:.0f} KB"
          f"（{len(chars)} 字，其中中日韓 {cjk}）")
    return 0

if __name__ == "__main__":
    sys.exit(main())
