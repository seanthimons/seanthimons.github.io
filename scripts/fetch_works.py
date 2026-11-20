#!/usr/bin/env python3
"""Write works.json (CSL-JSON): publications from OpenAlex, for the CV.

No key needed. On any failure or an empty result, leaves the existing
works.json untouched so the site still builds.
"""

import json
import re
import urllib.request
from pathlib import Path

OUT = Path(__file__).parent.parent / "works.json"
# ponytail: OpenAlex splits these works across three author profiles; merge them on
# openalex.org and this list can shrink to one ID.
AUTHORS = ["A5113190126", "A5075830739", "A5092232412"]
# Whitelist keeps errata/paratext off the CV. Add "preprint" once one exists.
TYPES = {"article": "article-journal", "review": "article-journal", "book": "book",
         "book-chapter": "chapter", "dissertation": "thesis",
         "conference-paper": "paper-conference", "report": "report"}
URL = ("https://api.openalex.org/works?per-page=200&filter=author.id:" + "|".join(AUTHORS)
       + ",type:" + "|".join(TYPES))


def clean(s):
    # Keep only CSL rich-text tags; publishers' <scp> etc. would print literally.
    return re.sub(r"</?(?!(?:i|b|sup|sub)>)[a-z][^>]*>", "", s or "").strip()


def name(display_name):
    # ponytail: splits on the last space; multi-word surnames ("van Dyke") split wrong.
    # Upgrade: fetch CSL-JSON per DOI from doi.org if one ever does.
    given, _, family = display_name.rpartition(" ")
    return {"family": family, "given": given} if given else {"literal": family}


def to_csl(w):
    src = (w.get("primary_location") or {}).get("source") or {}
    b = w.get("biblio") or {}
    item = {
        "id": w["id"].rsplit("/", 1)[-1],
        "type": TYPES.get(w["type"], "report"),
        "title": clean(w.get("title")),
        "author": [name(a["author"]["display_name"]) for a in w.get("authorships") or []],
    }
    if w.get("publication_date"):
        item["issued"] = {"date-parts": [[int(x) for x in w["publication_date"].split("-")]]}
    if item["type"] == "thesis":
        item["publisher"] = src.get("host_organization_name") or src.get("display_name")
    elif src.get("display_name"):
        item["container-title"] = src["display_name"]
    first, last = b.get("first_page"), b.get("last_page")
    if first:
        item["page"] = first if last in (None, first) else f"{first}-{last}"
    for k in ("volume", "issue"):
        if b.get(k):
            item[k] = b[k]
    if w.get("doi"):
        item["DOI"] = w["doi"].removeprefix("https://doi.org/")
    url = (w.get("primary_location") or {}).get("landing_page_url")
    if url and url.startswith("https://"):
        item["URL"] = url
    return {k: v for k, v in item.items() if v}


def main():
    req = urllib.request.Request(URL, headers={"User-Agent": "personal-site-publications"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            works = json.load(r)["results"]
        items = [to_csl(w) for w in works]
        if not items:
            raise ValueError("no works returned")
    except Exception as e:  # ponytail: stale list beats a broken build
        print(f"::warning::OpenAlex fetch failed ({e!r}); keeping existing works.json")
        return
    OUT.write_text(json.dumps(sorted(items, key=lambda i: i["id"]), indent=2, ensure_ascii=False) + "\n",
                   encoding="utf-8")
    print(f"Wrote {len(items)} work(s) to {OUT.name}")


if __name__ == "__main__":
    got = to_csl({"id": "https://openalex.org/W1", "type": "article", "title": "A <scp>PFAS</scp> <i>in vivo</i> study",
                  "publication_date": "2023-07-04", "doi": "https://doi.org/10.1/x",
                  "authorships": [{"author": {"display_name": "Mary E. Schoen"}}, {"author": {"display_name": "Plato"}}],
                  "biblio": {"volume": "57", "issue": "26", "first_page": "9559", "last_page": "9566"},
                  "primary_location": {"landing_page_url": "javascript:x", "source": {"display_name": "ES&T"}}})
    assert got == {"id": "W1", "type": "article-journal", "title": "A PFAS <i>in vivo</i> study",
                   "author": [{"family": "Schoen", "given": "Mary E."}, {"literal": "Plato"}],
                   "issued": {"date-parts": [[2023, 7, 4]]}, "container-title": "ES&T",
                   "page": "9559-9566", "volume": "57", "issue": "26", "DOI": "10.1/x"}, got
    thesis = to_csl({"id": "W2", "type": "dissertation", "title": "T", "biblio": {"first_page": "e1", "last_page": "e1"},
                     "primary_location": {"source": {"display_name": "Repo", "host_organization_name": "Uni"}}})
    assert thesis == {"id": "W2", "type": "thesis", "title": "T", "publisher": "Uni", "page": "e1"}, thesis
    assert to_csl({"id": "W3", "type": "article", "title": "T", "primary_location": None})["type"] == "article-journal"
    main()
