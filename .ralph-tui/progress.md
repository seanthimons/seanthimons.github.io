# Ralph Progress Log

This file tracks progress across iterations. Agents update this file
after each iteration and it's included in prompts for context.

## Codebase Patterns (Study These First)

- **TidyTuesday metadata format**: 2025 and 2026 weeks use `meta.yaml` files in `data/{year}/{date}/` folders. 2024 weeks 2-27 use `post_vars.json`, weeks 28-53 use `meta.yaml`. The yearly `readme.md` at `data/{year}/readme.md` contains a markdown table with all weeks listed.
- **GitHub API for raw files**: Use `gh api repos/rfordatascience/tidytuesday/contents/{path} -H "Accept: application/vnd.github.raw+json"` to get raw file content.
- **BYOD weeks**: Week 1 of each year is "Bring your own data" — no folder exists in the repo. Only 1 BYOD week falls in our 52-week range (2026-01-06).
- **Manifest location**: `tasks/week_manifest.json` — consumed by the sequential runner (US-002).

---

## 2026-02-20 - US-001
- Built `scripts/build_manifest.py` that queries the TidyTuesday GitHub repo for all 52 weeks in range (2025-02-25 through 2026-02-17)
- Each manifest entry includes: week_date, year, week_number, dataset_name, dataset_slug, data_source_url, is_byod flag, substituted_from info
- Script fetches `meta.yaml` from each week's folder via `gh api` to get accurate data_source_url
- 1 BYOD week (2026-01-06) substituted with 2024 dataset "Canadian NHL Player Birth Dates"
- Manifest saved as JSON to `tasks/week_manifest.json` with exactly 52 entries
- Files changed: `scripts/build_manifest.py` (new), `tasks/week_manifest.json` (new)
- **Learnings:**
  - TidyTuesday repo has consistent `meta.yaml` format for 2025+ weeks with title, data_source, article, credit fields
  - The `data_source_url` can be a single URL or a list (e.g., Sydney Beaches has 2 sources, Netflix has 4)
  - Simple regex parsing of `meta.yaml` works well enough — no need for a yaml library dependency
  - 2026 data folder already exists with 7 weeks (through 2026-02-17)
  - Only 1 BYOD week in range means 51 of 52 datasets from their respective 2024 pool are still available for future substitution needs
---
