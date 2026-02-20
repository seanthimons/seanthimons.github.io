#!/usr/bin/env python3
"""Build a week manifest for 52 TidyTuesday weeks (2025-02-25 through 2026-02-17).

Queries the TidyTuesday GitHub repo for dataset metadata via the GitHub API,
flags BYOD/BYOC weeks, and substitutes unused 2024 datasets for those gaps.
Outputs a JSON manifest for the sequential runner to consume.
"""

import json
import subprocess
import re
import sys
from pathlib import Path
from glob import glob

REPO = "rfordatascience/tidytuesday"
OUTPUT_PATH = Path(__file__).parent.parent / "tasks" / "week_manifest.json"

# Our target range: 2025 weeks 8-52 + 2026 weeks 1-7
WEEKS_2025 = [
    (8, "2025-02-25"), (9, "2025-03-04"), (10, "2025-03-11"), (11, "2025-03-18"),
    (12, "2025-03-25"), (13, "2025-04-01"), (14, "2025-04-08"), (15, "2025-04-15"),
    (16, "2025-04-22"), (17, "2025-04-29"), (18, "2025-05-06"), (19, "2025-05-13"),
    (20, "2025-05-20"), (21, "2025-05-27"), (22, "2025-06-03"), (23, "2025-06-10"),
    (24, "2025-06-17"), (25, "2025-06-24"), (26, "2025-07-01"), (27, "2025-07-08"),
    (28, "2025-07-15"), (29, "2025-07-22"), (30, "2025-07-29"), (31, "2025-08-05"),
    (32, "2025-08-12"), (33, "2025-08-19"), (34, "2025-08-26"), (35, "2025-09-02"),
    (36, "2025-09-09"), (37, "2025-09-16"), (38, "2025-09-23"), (39, "2025-09-30"),
    (40, "2025-10-07"), (41, "2025-10-14"), (42, "2025-10-21"), (43, "2025-10-28"),
    (44, "2025-11-04"), (45, "2025-11-11"), (46, "2025-11-18"), (47, "2025-11-25"),
    (48, "2025-12-02"), (49, "2025-12-09"), (50, "2025-12-16"), (51, "2025-12-23"),
    (52, "2025-12-30"),
]

WEEKS_2026 = [
    (1, "2026-01-06"), (2, "2026-01-13"), (3, "2026-01-20"), (4, "2026-01-27"),
    (5, "2026-02-03"), (6, "2026-02-10"), (7, "2026-02-17"),
]

# 2024 datasets available for BYOD substitution (weeks 2-53, skipping week 1 BYOD)
DATASETS_2024 = [
    (2, "2024-01-09"), (3, "2024-01-16"), (4, "2024-01-23"), (5, "2024-01-30"),
    (6, "2024-02-06"), (7, "2024-02-13"), (8, "2024-02-20"), (9, "2024-02-27"),
    (10, "2024-03-05"), (11, "2024-03-12"), (12, "2024-03-19"), (13, "2024-03-26"),
    (14, "2024-04-02"), (15, "2024-04-09"), (16, "2024-04-16"), (17, "2024-04-23"),
    (18, "2024-04-30"), (19, "2024-05-07"), (20, "2024-05-14"), (21, "2024-05-21"),
    (22, "2024-05-28"), (23, "2024-06-04"), (24, "2024-06-11"), (25, "2024-06-18"),
    (26, "2024-06-25"), (27, "2024-07-02"), (28, "2024-07-09"), (29, "2024-07-16"),
    (30, "2024-07-23"), (31, "2024-07-30"), (32, "2024-08-06"), (33, "2024-08-13"),
    (34, "2024-08-20"), (35, "2024-08-27"), (36, "2024-09-03"), (37, "2024-09-10"),
    (38, "2024-09-17"), (39, "2024-09-24"), (40, "2024-10-01"), (41, "2024-10-08"),
    (42, "2024-10-15"), (43, "2024-10-22"), (44, "2024-10-29"), (45, "2024-11-05"),
    (46, "2024-11-12"), (47, "2024-11-19"), (48, "2024-11-26"), (49, "2024-12-03"),
    (50, "2024-12-10"), (51, "2024-12-17"), (52, "2024-12-24"), (53, "2024-12-31"),
]


def gh_api(endpoint: str) -> str | None:
    """Call the GitHub API via gh CLI and return raw text, or None on error."""
    try:
        result = subprocess.run(
            ["gh", "api", f"repos/{REPO}/contents/{endpoint}",
             "-H", "Accept: application/vnd.github.raw+json"],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode == 0:
            return result.stdout
        return None
    except Exception:
        return None


def parse_meta_yaml(raw: str) -> dict:
    """Parse a meta.yaml file (simple key extraction, no yaml dependency needed)."""
    meta = {}
    # Title
    m = re.search(r'^title:\s*["\']?(.+?)["\']?\s*$', raw, re.MULTILINE)
    if m:
        meta["title"] = m.group(1).strip().strip('"').strip("'")

    # Data source URL
    urls = []
    in_data_source = False
    for line in raw.splitlines():
        if re.match(r'^data_source:', line):
            in_data_source = True
            # Inline url
            um = re.search(r'url:\s*["\']?(.+?)["\']?\s*$', line)
            if um:
                urls.append(um.group(1))
            continue
        if in_data_source:
            if re.match(r'^\S', line) and not line.startswith(' ') and not line.startswith('-'):
                in_data_source = False
                continue
            um = re.search(r'url:\s*["\']?(.+?)["\']?\s*$', line)
            if um:
                urls.append(um.group(1))
            # Handle list form: - "url"
            um2 = re.search(r'^\s+-\s+["\']?(.+?)["\']?\s*$', line)
            if um2 and not um:
                val = um2.group(1).strip()
                if val.startswith("http"):
                    urls.append(val)

    if urls:
        meta["data_source_url"] = urls[0] if len(urls) == 1 else urls

    # Data source title
    in_ds = False
    for line in raw.splitlines():
        if re.match(r'^data_source:', line):
            in_ds = True
            tm = re.search(r'title:\s*["\']?(.+?)["\']?\s*$', line)
            if tm:
                meta["data_source_title"] = tm.group(1).strip().strip('"').strip("'")
            continue
        if in_ds:
            if re.match(r'^\S', line) and not line.startswith(' ') and not line.startswith('-'):
                break
            tm = re.search(r'title:\s*["\']?(.+?)["\']?\s*$', line)
            if tm:
                meta["data_source_title"] = tm.group(1).strip().strip('"').strip("'")

    return meta


def slugify(title: str) -> str:
    """Convert a dataset title to a URL-friendly slug."""
    slug = title.lower()
    slug = re.sub(r'[^a-z0-9\s-]', '', slug)
    slug = re.sub(r'[\s]+', '-', slug.strip())
    slug = re.sub(r'-+', '-', slug)
    return slug[:60].rstrip('-')


def fetch_week_metadata(year: int, date: str) -> dict | None:
    """Fetch meta.yaml for a given week and parse it."""
    raw = gh_api(f"data/{year}/{date}/meta.yaml")
    if raw is None:
        return None
    return parse_meta_yaml(raw)


def is_byod(data_name: str) -> bool:
    """Check if a week's dataset name indicates BYOD/BYOC."""
    lower = data_name.lower()
    return "bring your own" in lower or "byod" in lower or "byoc" in lower


def scan_existing_posts_for_2024_datasets(posts_dir: Path, datasets_2024: list, names_2024: dict) -> set:
    """Scan existing posts to find which 2024 datasets are already used.

    Checks post .qmd files for tt_load() calls referencing 2024 dates,
    and for frontmatter fields indicating a substituted 2024 dataset.
    Returns a set of indices into DATASETS_2024 that are already consumed.
    """
    used_indices = set()
    if not posts_dir.exists():
        return used_indices

    # Build a reverse lookup: 2024 date -> index in DATASETS_2024
    date_to_idx = {}
    for idx, (week, date) in enumerate(datasets_2024):
        date_to_idx[date] = idx

    # Also build name -> index lookup for matching by dataset name
    name_to_idx = {}
    for idx, (week, date) in enumerate(datasets_2024):
        name = names_2024.get(date, "")
        if name:
            name_to_idx[name.lower()] = idx

    # Scan all .qmd files in posts/
    for qmd in posts_dir.glob("*/*.qmd"):
        try:
            content = qmd.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue

        # Check for tt_load("2024-XX-XX") patterns
        for m in re.finditer(r'tt_load\s*\(\s*["\']?(2024-\d{2}-\d{2})["\']?\s*\)', content):
            tt_date = m.group(1)
            if tt_date in date_to_idx:
                used_indices.add(date_to_idx[tt_date])

        # Check for substituted_from references in frontmatter or comments
        for m in re.finditer(r'substituted[_-]from[:\s].*?(2024-\d{2}-\d{2})', content):
            sub_date = m.group(1)
            if sub_date in date_to_idx:
                used_indices.add(date_to_idx[sub_date])

        # Check if any 2024 dataset name appears in the frontmatter/content
        content_lower = content.lower()
        for name, idx in name_to_idx.items():
            if name in content_lower:
                used_indices.add(idx)

    return used_indices


def build_manifest():
    """Build the full 52-week manifest."""
    manifest = []
    used_2024_indices = set()

    # Hardcoded dataset names from the yearly readmes (to avoid extra API calls
    # for weeks where we already know the name from the table)
    names_2025 = {
        "2025-02-25": "Academic Literature on Racial and Ethnic Disparities in Reproductive Medicine in the US",
        "2025-03-04": "Long Beach Animal Shelter",
        "2025-03-11": "Pixar Films",
        "2025-03-18": "Palm Trees",
        "2025-03-25": "Text Data From Amazon's Annual Reports",
        "2025-04-01": "Pokemon",
        "2025-04-08": "Timely and Effective Care by US State",
        "2025-04-15": "Base R Penguins",
        "2025-04-22": "Fatal Car Crashes on 4/20",
        "2025-04-29": "useR! 2025 program",
        "2025-05-06": "National Science Foundation Grant Terminations under the Trump Administration",
        "2025-05-13": "Seismic Events at Mount Vesuvius",
        "2025-05-20": "Water Quality at Sydney Beaches",
        "2025-05-27": "Dungeons and Dragons Monsters (2024)",
        "2025-06-03": "Project Gutenberg",
        "2025-06-10": "U.S. Judges and the historydata R package",
        "2025-06-17": "API Specs",
        "2025-06-24": "Measles cases across the world",
        "2025-07-01": "Weekly US Gas Prices",
        "2025-07-08": "The xkcd Color Survey Results",
        "2025-07-15": "British Library Funding",
        "2025-07-22": "MTA Permanent Art Catalog",
        "2025-07-29": "What have we been watching on Netflix?",
        "2025-08-05": "Income Inequality Before and After Taxes",
        "2025-08-12": "Extreme Weather Attribution Studies",
        "2025-08-19": "Scottish Munros",
        "2025-08-26": "Billboard Hot 100 Number Ones",
        "2025-09-02": "Australian Frogs",
        "2025-09-09": "Henley Passport Index Data",
        "2025-09-16": "Allrecipes",
        "2025-09-23": "FIDE Chess Player Ratings",
        "2025-09-30": "Crane Observations at Lake Hornborgasjön, Sweden (1994–2024)",
        "2025-10-07": "EuroLeague Basketball",
        "2025-10-14": "World Food Day",
        "2025-10-21": "Historic UK Meteorological & Climate Data",
        "2025-10-28": "Selected British Literary Prizes (1990-2022)",
        "2025-11-04": "Lead concentration in Flint water samples in 2015",
        "2025-11-11": "WHO TB Burden Data: Incidence, Mortality, and Population",
        "2025-11-18": "The Complete Sherlock Holmes",
        "2025-11-25": "Statistical Performance Indicators",
        "2025-12-02": "Can an exploding snowman predict the summer season?",
        "2025-12-09": "Cars in Qatar",
        "2025-12-16": "Roundabouts across the world",
        "2025-12-23": "The Languages of the World",
        "2025-12-30": "Christmas Novels",
    }

    names_2026 = {
        "2026-01-06": "Bring your own data from 2025!",
        "2026-01-13": "The Languages of Africa",
        "2026-01-20": "Astronomy Picture of the Day (APOD) Archive",
        "2026-01-27": "Brazilian Companies",
        "2026-02-03": "Edible Plants Database",
        "2026-02-10": "The 2026 Winter Olympics!",
        "2026-02-17": "Agricultural Production Statistics in New Zealand",
    }

    names_2024 = {
        "2024-01-09": "Canadian NHL Player Birth Dates",
        "2024-01-16": "US Polling Places 2012-2020",
        "2024-01-23": "Educational attainment of young people in English towns",
        "2024-01-30": "Groundhog predictions",
        "2024-02-06": "World heritage sites",
        "2024-02-13": "Valentine's Day consumer data",
        "2024-02-20": "R Consortium ISC Grants",
        "2024-02-27": "Leap Day",
        "2024-03-05": "Trash Wheel Collection Data",
        "2024-03-12": "Fiscal Sponsors",
        "2024-03-19": "X-Men Mutant Moneyball",
        "2024-03-26": "NCAA Men's March Madness",
        "2024-04-02": "Du Bois Visualization Challenge 2024",
        "2024-04-09": "2023 & 2024 US Solar Eclipses",
        "2024-04-16": "Shiny Packages",
        "2024-04-23": "Objects Launched into Space",
        "2024-04-30": "Worldwide Bureaucracy Indicators",
        "2024-05-07": "Rolling Stone Album Rankings",
        "2024-05-14": "The Great American Coffee Taste Test",
        "2024-05-21": "Carbon Majors emissions data",
        "2024-05-28": "Lisa's Vegetable Garden Data",
        "2024-06-04": "Cheese",
        "2024-06-11": "Campus Pride Index",
        "2024-06-18": "US Federal Holidays",
        "2024-06-25": "tidyRainbow Datasets",
        "2024-07-02": "TidyTuesday Datasets",
        "2024-07-09": "David Robinson's TidyTuesday Functions",
        "2024-07-16": "English Women's Football",
        "2024-07-23": "American Idol data",
        "2024-07-30": "Summer Movies",
        "2024-08-06": "Olympic Medals",
        "2024-08-13": "World's Fairs",
        "2024-08-20": "English Monarchs and Marriages",
        "2024-08-27": "The Power Rangers Franchise",
        "2024-09-03": "Stack Overflow Annual Developer Survey 2024",
        "2024-09-10": "Economic Diversity and Student Outcomes",
        "2024-09-17": "Shakespeare Dialogue",
        "2024-09-24": "International Mathematical Olympiad (IMO) Data",
        "2024-10-01": "Chess Game Dataset (Lichess)",
        "2024-10-08": "National Park Species",
        "2024-10-15": "Southern Resident Killer Whale Encounters",
        "2024-10-22": "The CIA World Factbook",
        "2024-10-29": "Monster Movies",
        "2024-11-05": "Democracy and Dictatorship",
        "2024-11-12": "ISO Country Codes",
        "2024-11-19": "Bob's Burgers Episodes",
        "2024-11-26": "U.S. Customs and Border Protection (CBP) Encounter Data",
        "2024-12-03": "National Highways Traffic Flow",
        "2024-12-10": "The Scent of Data - Exploring the Parfumo Fragrance Dataset",
        "2024-12-17": "Dungeons and Dragons Spells (2024)",
        "2024-12-24": "Global Holidays and Travel",
        "2024-12-31": "James Beard Awards",
    }

    # Process 2025 weeks (8-52)
    print("Fetching 2025 week metadata...")
    for week_num, date in WEEKS_2025:
        name = names_2025.get(date, "")
        print(f"  Week {week_num} ({date}): {name}")

        entry = {
            "week_date": date,
            "year": 2025,
            "week_number": week_num,
            "dataset_name": name,
            "dataset_slug": slugify(name),
            "data_source_url": f"https://github.com/{REPO}/tree/main/data/2025/{date}",
            "is_byod": False,
            "substituted_from": None,
        }
        manifest.append(entry)

    # Process 2026 weeks (1-7)
    print("Fetching 2026 week metadata...")
    for week_num, date in WEEKS_2026:
        name = names_2026.get(date, "")
        byod = is_byod(name)
        print(f"  Week {week_num} ({date}): {name} {'[BYOD]' if byod else ''}")

        entry = {
            "week_date": date,
            "year": 2026,
            "week_number": week_num,
            "dataset_name": name,
            "dataset_slug": slugify(name),
            "data_source_url": f"https://github.com/{REPO}/tree/main/data/2026/{date}",
            "is_byod": byod,
            "substituted_from": None,
        }
        manifest.append(entry)

    # Now fetch meta.yaml for each non-BYOD week to get the actual data_source_url
    print("\nFetching detailed metadata from meta.yaml files...")
    for entry in manifest:
        if entry["is_byod"]:
            continue
        year = entry["year"]
        date = entry["week_date"]
        meta = fetch_week_metadata(year, date)
        if meta:
            if "title" in meta and meta["title"]:
                entry["dataset_name"] = meta["title"]
                entry["dataset_slug"] = slugify(meta["title"])
            if "data_source_url" in meta:
                entry["data_source_url"] = meta["data_source_url"]
            print(f"  ✓ {date}: {entry['dataset_name']}")
        else:
            print(f"  ✗ {date}: meta.yaml not found, using readme table data")

    # US-006: Rescan existing posts to find which 2024 datasets are already used
    posts_dir = Path(__file__).parent.parent / "posts"
    already_used = scan_existing_posts_for_2024_datasets(
        posts_dir, DATASETS_2024, names_2024
    )
    if already_used:
        print(f"\nRescan found {len(already_used)} 2024 dataset(s) already used in existing posts:")
        for idx in sorted(already_used):
            week, date = DATASETS_2024[idx]
            print(f"  - {names_2024.get(date, date)} (2024 week {week})")
    used_2024_indices.update(already_used)

    # Substitute BYOD weeks with unused 2024 datasets
    byod_entries = [e for e in manifest if e["is_byod"]]
    if byod_entries:
        print(f"\nSubstituting {len(byod_entries)} BYOD week(s) with 2024 datasets...")
        sub_idx = 0
        for entry in byod_entries:
            # Find next unused 2024 dataset
            while sub_idx in used_2024_indices and sub_idx < len(DATASETS_2024):
                sub_idx += 1
            if sub_idx < len(DATASETS_2024):
                used_2024_indices.add(sub_idx)
                sub_week, sub_date = DATASETS_2024[sub_idx]
                sub_name = names_2024.get(sub_date, f"2024 Week {sub_week}")
                entry["dataset_name"] = sub_name
                entry["dataset_slug"] = slugify(sub_name)
                entry["data_source_url"] = f"https://github.com/{REPO}/tree/main/data/2024/{sub_date}"
                entry["substituted_from"] = {
                    "year": 2024,
                    "week": sub_week,
                    "date": sub_date,
                }
                print(f"  {entry['week_date']} → {sub_name} (2024 week {sub_week})")
                sub_idx += 1

    # Summary
    print(f"\nManifest built: {len(manifest)} entries")
    print(f"  BYOD substitutions: {len([e for e in manifest if e['substituted_from']])}")
    print(f"  Regular weeks: {len([e for e in manifest if not e['substituted_from']])}")

    # Save
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_PATH, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"\nManifest saved to: {OUTPUT_PATH}")

    return manifest


if __name__ == "__main__":
    manifest = build_manifest()
    # Validate
    if len(manifest) < 52:
        print(f"ERROR: Only {len(manifest)} entries (need at least 52)", file=sys.stderr)
        sys.exit(1)
    print(f"\n✓ Validation passed: {len(manifest)} entries in manifest")
