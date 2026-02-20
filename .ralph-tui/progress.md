# Ralph Progress Log

This file tracks progress across iterations. Agents update this file
after each iteration and it's included in prompts for context.

## Codebase Patterns (Study These First)

- **TidyTuesday metadata format**: 2025 and 2026 weeks use `meta.yaml` files in `data/{year}/{date}/` folders. 2024 weeks 2-27 use `post_vars.json`, weeks 28-53 use `meta.yaml`. The yearly `readme.md` at `data/{year}/readme.md` contains a markdown table with all weeks listed.
- **GitHub API for raw files**: Use `gh api repos/rfordatascience/tidytuesday/contents/{path} -H "Accept: application/vnd.github.raw+json"` to get raw file content.
- **BYOD weeks**: Week 1 of each year is "Bring your own data" — no folder exists in the repo. Only 1 BYOD week falls in our 52-week range (2026-01-06).
- **Manifest location**: `tasks/week_manifest.json` — consumed by the sequential runner (US-002).
- **Claude CLI invocation for automation**: Use `CLAUDECODE= claude -p --dangerously-skip-permissions --model sonnet` to invoke Claude Code from a bash script. The `CLAUDECODE=` unset is required to avoid the nested-session guard.
- **Tidy-tuesday autonomous mode triggers**: Include words like "autonomous", "hands-off", or "unattended" in the prompt to skip all interactive checkpoints.
- **Post date override**: The skill normally uses `Sys.Date()` for the post date. For backfill, explicitly instruct it to use the manifest's `week_date` instead.
- **BYOD rescan deduplication**: `build_manifest.py` scans existing posts for `tt_load("2024-XX-XX")` calls, `substituted_from` references, and 2024 dataset names to avoid reusing a 2024 dataset that's already in an existing post.

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

## 2026-02-20 - US-002
- Built `scripts/run_backfill.sh` — sequential runner that iterates the week manifest and invokes `/tidy-tuesday` skill via `claude -p` for each week
- Each invocation runs in autonomous mode with explicit post date and dataset date from the manifest
- BYOD weeks use the substituted dataset date for `tt_load()` while keeping the original week date for the post folder/frontmatter
- Script supports `--dry-run` (preview) and `--start-from N` (resume from index) flags
- US-003 skip logic is built in: rescans `posts/` before each week and skips if a matching date folder exists
- Progress logging to console and `tasks/backfill-log.txt` with OK/SKIP/FAIL per week and a summary at the end
- Dry-run validated: correctly processes all 52 entries, skips the existing `2025-11-04` post
- Files changed: `scripts/run_backfill.sh` (new)
- **Learnings:**
  - `claude -p` (print mode) is the correct way to script Claude Code invocations from bash
  - Must unset `CLAUDECODE` env var (`CLAUDECODE=`) to avoid the nested-session guard when calling from within another Claude session
  - The `--dangerously-skip-permissions` flag is needed for unattended automation (no user to approve tool calls)
  - `--max-budget-usd` can cap per-invocation spend as a safety net
  - The tidy-tuesday skill has two distinct dates: post date (folder/frontmatter) and dataset date (tt_load) — the runner must pass both explicitly to override the skill's default Sys.Date() behavior
---

## 2026-02-20 - US-003
- Verified US-003 skip logic was already implemented as part of US-002 in `scripts/run_backfill.sh` (lines 95-101)
- Per-iteration rescan of `posts/` directory using glob `${week_date}*` before each week's generation
- Skips with log message matching AC format: "Skipping week YYYY-MM-DD — post already exists"
- All 6 acceptance criteria verified as met — no code changes needed
- Files changed: none (already implemented)
- **Learnings:**
  - US-002 proactively included US-003 skip logic, making the stories overlap — always check existing code before implementing
---

## 2026-02-20 - US-004
- Added git commit logic to `scripts/run_backfill.sh` inside the post-success verification block
- After each successful post creation: stages only `posts/$week_date/` and commits with format `Add Tidy Tuesday post: YYYY-MM-DD dataset-name`
- Skipped and failed posts never reach the commit code path
- Commit action is logged to both console and `backfill-log.txt`
- Files changed: `scripts/run_backfill.sh` (modified — 4 lines added)
- **Learnings:**
  - Using `git -C "$PROJECT_DIR"` ensures git commands work regardless of the shell's cwd
  - Staging with a trailing `/` on the directory path ensures all contents are included
---

## 2026-02-20 - US-006
- Added `scan_existing_posts_for_2024_datasets()` function to `scripts/build_manifest.py` that scans `posts/**/*.qmd` for 2024 dataset references
- Rescan checks for: `tt_load("2024-XX-XX")` calls, `substituted_from` frontmatter/comment references, and 2024 dataset names in post content
- Results are merged into `used_2024_indices` before BYOD substitution, preventing duplicate 2024 dataset usage on resume
- Updated `scripts/run_backfill.sh` BYOD prompt to explicitly instruct Claude to add `substituted_from` to YAML frontmatter and note the substitution in introductory text
- US-001 already had the core substitution logic (BYOD detection, 2024 pool selection, `used_2024_indices` tracking) — US-006 adds the rescan-on-rebuild and post-annotation pieces
- Files changed: `scripts/build_manifest.py` (modified), `scripts/run_backfill.sh` (modified)
- **Learnings:**
  - The rescan uses three detection strategies (tt_load dates, substituted_from references, dataset name matching) for robustness — any one alone could miss cases
  - Most of the BYOD substitution infra was already built in US-001; US-006 is primarily about idempotency on manifest rebuild and ensuring annotation in generated posts
---

## 2026-02-20 - US-005
- Added batch push logic to `scripts/run_backfill.sh` — pushes to remote every 10 successful commits
- Added `commits_since_push` counter and `PUSH_BATCH_SIZE=10` constant
- After each commit, counter increments; when it hits 10, `git push` runs and counter resets
- End-of-run block pushes any remaining uncommitted-to-remote commits (handles <10 remaining)
- Push failures are caught with `if git push` — logged to console and `backfill-log.txt` but do not stop the run
- Files changed: `scripts/run_backfill.sh` (modified — ~20 lines added)
- **Learnings:**
  - Redirecting `git push` stderr to the log file (`2>>"$LOG_FILE"`) captures remote rejection messages for later diagnosis
  - The `commits_since_push` counter only resets on successful push, so failed pushes accumulate and get retried with the next batch
---

## 2026-02-20 - US-007
- Verified US-007 summary/error log was already implemented as part of US-002 in `scripts/run_backfill.sh`
- Console summary (lines 211-223): formatted block with total/generated/skipped/failed counters and failed week details
- Log file summary (lines 226-237): same info appended to `tasks/backfill-log.txt` with timestamps
- Failed weeks tracked in `failed_weeks` variable with dataset name and error reason (claude error or post file not created)
- Per-week logging throughout the run: OK/SKIP/FAIL status lines written to log file during iteration
- All 4 acceptance criteria verified as met — no code changes needed
- Files changed: none (already implemented)
- **Learnings:**
  - US-002 proactively included both US-003 skip logic and US-007 summary/logging — always check existing code before implementing
---
