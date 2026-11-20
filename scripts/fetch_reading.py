#!/usr/bin/env python3
"""Write _reading.md: books marked "Currently Reading" on Hardcover.

Needs HARDCOVER_TOKEN (raw token or "Bearer ..."). On any failure, leaves the
existing _reading.md untouched so the site still builds.
"""

import html
import json
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path

OUT = Path(__file__).parent.parent / "_reading.md"
QUERY = """
{ me { user_books(where: {status_id: {_eq: 2}}, order_by: {updated_at: desc}) {
    book { title slug cached_image
      # same author filter as shelfcheck: skip translators, illustrators, etc.
      contributions(where: {_or: [{contribution: {_is_null: true}}, {contribution: {_eq: "Author"}}]}) { author { name } } }
} } }
"""


def esc(s):
    # Titles are community-edited: escape HTML, and braces so Quarto sees no shortcodes.
    # Backticks/newlines too, so a title can't close the ```{=html} fence early.
    s = html.escape(s).replace("{", "&#123;").replace("}", "&#125;")
    return s.replace("`", "&#96;").replace("\n", " ")


def render(user_books):
    if not user_books:
        return "*Between books right now.*\n"
    lines = []
    for ub in user_books:
        b = ub["book"]
        authors = [c["author"]["name"] for c in b.get("contributions") or [] if c.get("author")]
        by = esc(", ".join(authors))
        url = "https://hardcover.app/books/" + urllib.parse.quote(b["slug"], safe="-")
        cover = (b.get("cached_image") or {}).get("url") or ""
        img = (f'<img src="{esc(cover)}" alt="" loading="lazy">'
               if cover.startswith("https://") else '<span class="no-cover"></span>')
        lines.append(f'<li><a href="{url}">{img}<em>{esc(b["title"])}</em></a>'
                     f'<span class="by">{by}</span></li>')
    # Raw-HTML fence: Pandoc would otherwise parse markdown (e.g. [x](javascript:...)) inside the <ul>.
    return '```{=html}\n<ul class="reading">\n' + "\n".join(lines) + "\n</ul>\n```\n"


def main():
    token = os.environ.get("HARDCOVER_TOKEN", "").strip()
    if not token:
        print("HARDCOVER_TOKEN unset; keeping existing _reading.md")
        return
    if not token.lower().startswith("bearer "):
        token = f"Bearer {token}"
    req = urllib.request.Request(
        "https://api.hardcover.app/v1/graphql",
        data=json.dumps({"query": QUERY}).encode(),
        headers={"Content-Type": "application/json", "authorization": token,
                 "User-Agent": "personal-site-reading-list"},
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            payload = json.load(r)
        books = payload["data"]["me"][0]["user_books"]
        text = render(books)
    except Exception as e:  # ponytail: any failure -> stale list beats a broken build
        print(f"::warning::Hardcover fetch failed ({e!r}); keeping existing _reading.md")
        return
    OUT.write_text(text, encoding="utf-8")
    print(f"Wrote {len(books)} book(s) to {OUT.name}")


if __name__ == "__main__":
    assert render([]) == "*Between books right now.*\n"
    assert render([{"book": {"title": "T", "slug": "t", "contributions": [{"author": {"name": "A"}}]}}]) \
        == ('```{=html}\n<ul class="reading">\n<li><a href="https://hardcover.app/books/t"><span class="no-cover"></span>'
            '<em>T</em></a><span class="by">A</span></li>\n</ul>\n```\n')
    nasty = render([{"book": {"title": "<img onerror=x>{{< x >}}", "slug": "a\"b", "contributions": [],
                              "cached_image": {"url": "javascript:x"}}}])
    assert "<img" not in nasty and "{{" not in nasty and 'a"b' not in nasty and "javascript" not in nasty
    quoted = render([{"book": {"title": "T", "slug": "t", "cached_image": {"url": 'https://x/"onerror="y'}}}])
    assert '"onerror' not in quoted
    assert "```" not in render([{"book": {"title": "x\n```\n[a](javascript:b)", "slug": "s"}}])[10:-5]
    sys.exit(main())
