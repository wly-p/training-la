#!/usr/bin/env python3
"""把 design-system/ 底下的 markdown 渲染成可在瀏覽器讀的 HTML。

為什麼：設計端從 index.html 進來，點到 .md 連結時瀏覽器會當純文字開或直接下載。
規則書、變更紀錄、規格全是 markdown，那等於「寫了但對方讀不到」。

`.md` 仍然是來源（可編輯、可 diff），`.html` 是生成物。
連結會一起改寫成 .html，讓瀏覽時不會跳回純文字。

跑法（需要 uv）：
    make doc-html
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DS   = ROOT / "design-system"

SHELL = """<!doctype html>
<meta charset="utf-8">
<title>{title}</title>
<link rel="stylesheet" href="{depth}tokens/tokens.css">
<link rel="stylesheet" href="{depth}preview.css">
<style>
  body {{ max-width: 62rem; line-height: 1.7; }}
  h1, h2, h3 {{ font-family: var(--font-page-title-family); line-height: 1.35; }}
  h1 {{ font-size: var(--font-page-title); margin: 0 0 var(--space-gap-l); }}
  h2 {{ font-size: var(--font-card-title); margin: var(--space-section) 0 var(--space-gap-m);
       padding-top: var(--space-gap-m); border-top: 1px solid var(--border-subtle); }}
  h3 {{ font-size: var(--font-row-title); margin: var(--space-gap-l) 0 var(--space-gap-s); }}
  a {{ color: var(--accent-on-surface); }}
  table {{ border-collapse: collapse; width: 100%; margin: var(--space-gap-m) 0;
          display: block; overflow-x: auto; }}
  th, td {{ text-align: left; padding: var(--space-gap-s) var(--space-gap-m);
           border-bottom: 1px solid var(--border-subtle); vertical-align: top; }}
  th {{ font-size: var(--font-kicker); letter-spacing: var(--font-kicker-tracking);
       text-transform: uppercase; color: var(--text-tertiary); }}
  pre {{ background: var(--surface-raised); border-radius: var(--radius-inner);
        padding: var(--space-gap-m); overflow-x: auto; }}
  pre code {{ background: none; padding: 0; }}
  blockquote {{ margin: var(--space-gap-m) 0; padding-left: var(--space-gap-m);
               border-left: 3px solid var(--border-subtle); color: var(--text-secondary); }}
  .back {{ font-size: var(--font-row-sub); margin-bottom: var(--space-gap-l); display: block; }}
</style>
<a class="back" href="{depth}index.html">← 元件庫索引</a>
{body}
"""

def targets():
    for p in sorted(DS.rglob("*.md")):
        yield p

def render(md_path, md_mod):
    rel   = md_path.relative_to(DS)
    depth = "../" * (len(rel.parts) - 1)
    text  = md_path.read_text()
    title = next((l.lstrip("# ").strip() for l in text.splitlines() if l.startswith("# ")), rel.stem)
    html  = md_mod.markdown(text, extensions=["tables", "fenced_code", "sane_lists", "attr_list"])
    # 連結一起改寫，否則點下去又跳回純文字
    html  = re.sub(r'(<a [^>]*href="[^"]+)\.md(")', r"\1.html\2", html)
    return SHELL.format(title=title, depth=depth, body=html)

def main() -> int:
    try:
        import markdown
    except ImportError:
        print("✘ 需要 markdown。用 make doc-html（走 uv），不要直接跑這支。", file=sys.stderr)
        return 1

    check = "--check" in sys.argv
    bad = n = 0
    for md in targets():
        out = md.with_suffix(".html")
        content = render(md, markdown)
        if check:
            if not out.exists() or out.read_text() != content:
                print(f"✘ {out.relative_to(ROOT)} 與 {md.name} 不一致——請跑 make doc-html")
                bad += 1
        else:
            out.write_text(content)
            n += 1
    if check:
        return 1 if bad else 0
    print(f"✔ {n} 份 markdown → HTML")
    return 0

if __name__ == "__main__":
    sys.exit(main())
