# PRD: Backfill Blog with 52 Weeks of Tidy Tuesday Posts

## Overview
Backfill a Quarto blog with 52 weeks of Tidy Tuesday posts by sequentially invoking the `/tidy-tuesday` skill for each week from 2025-02-25 through 2026-02-17. Each post uses the real TidyTuesday dataset for that week, is rendered as a full Quarto document with EDA and visualizations, and is committed individually. The runner rescans the `posts/` directory before each post to enable safe resume from any point. BYOD/BYOC weeks substitute an unused 2024 TidyTuesday dataset.

## Goals
- Populate the blog with 52 weeks of high-quality Tidy Tuesday content
- Each post uses the historically correct TidyTuesday dataset for its week
- Posts appear chronologically in the blog with accurate frontmatter dates
- All posts render cleanly via `quarto render`
- Handle BYOD/BYOC weeks gracefully by substituting 2024 datasets
- Runner is fully resumable — rescans existing posts before each generation attempt

## Quality Gates

These commands must pass for every user story:
- `quarto render <post-directory>` — Post renders without error

## User Stories

### US-001: Build Week Manifest
As a developer, I want a manifest of all 52 TidyTuesday weeks (2025-02-25 through 2026-02-17) with their dataset metadata so that the sequential runner knows what to generate.

**Acceptance Criteria:**
- [ ] Script queries the TidyTuesday GitHub repo for dataset metadata for each week in range
- [ ] Each entry includes: week date, dataset name, dataset slug, data source URL
- [ ] BYOD/BYOC weeks are flagged and assigned an unused 2024 TidyTuesday dataset instead
- [ ] Manifest is saved as a JSON or CSV file for the runner to consume
- [ ] Manifest includes at least 52 entries (substitutions fill BYOD gaps)

### US-002: Implement Sequential Runner Script
As a developer, I want a script that iterates through the week manifest and invokes the `/tidy-tuesday` skill for each non-skipped week so that posts are generated autonomously.

**Acceptance Criteria:**
- [ ] Script reads the manifest from US-001
- [ ] For each week, invokes the `/tidy-tuesday` skill with the correct dataset
- [ ] Each post is created in `posts/YYYY-MM-DD-dataset-slug/` directory
- [ ] Post frontmatter `date` field matches the original TidyTuesday week date
- [ ] Each post includes full treatment: EDA, visualizations, and narrative
- [ ] Script logs progress (current week number, dataset name, success/failure)
- [ ] On dataset unavailability, logs the failure and continues to the next week

### US-003: Rescan Posts Directory Before Each Week
As a developer, I want the runner to rescan `posts/` before generating each week's post so that I can stop and resume the run at any time without duplicating work.

**Acceptance Criteria:**
- [ ] Before each week's generation, scan `posts/` for directories matching `YYYY-MM-DD-*`
- [ ] Extract the date prefix from each existing post directory
- [ ] If a post directory matching the current week's date already exists, skip that week
- [ ] Rescan happens per-iteration, not just at startup — so posts added externally or in a previous partial run are detected
- [ ] Log message when skipping: "Skipping week YYYY-MM-DD — post already exists at posts/YYYY-MM-DD-slug/"
- [ ] This makes the entire run idempotent and safely resumable from any interruption point

### US-004: Individual Commit Per Post
As a developer, I want each completed post committed individually so that git history clearly shows when each post was added.

**Acceptance Criteria:**
- [ ] After each post renders successfully, it is staged and committed
- [ ] Commit message format: `Add Tidy Tuesday post: YYYY-MM-DD dataset-name`
- [ ] Only the post directory contents are included in each commit (no unrelated changes)
- [ ] Failed/skipped posts do not produce commits

### US-005: Batch Push to Remote
As a developer, I want completed posts pushed to remote in batches of ~10 so that progress is saved incrementally without excessive pushes.

**Acceptance Criteria:**
- [ ] After every 10 successful commits, push to remote
- [ ] Push remaining commits at the end of the full run
- [ ] If fewer than 10 posts remain, push at completion
- [ ] Push failures are logged but do not stop the run

### US-006: BYOD/BYOC Substitution Logic
As a developer, I want BYOD and BYOC weeks to substitute an unused 2024 TidyTuesday dataset so that every week has content.

**Acceptance Criteria:**
- [ ] Identify all BYOD/BYOC weeks in the 52-week range
- [ ] Select a 2024 TidyTuesday dataset not already used by another week or existing post
- [ ] Substituted dataset is noted in the post (e.g., frontmatter or introductory text)
- [ ] No 2024 dataset is used more than once across all substitutions
- [ ] Rescan of existing posts informs which 2024 datasets are already used (avoids duplicates on resume)

### US-007: Run Summary and Error Log
As a developer, I want a summary report after the run completes so that I can review what was generated, skipped, or failed.

**Acceptance Criteria:**
- [ ] Summary printed to console at end of run
- [ ] Includes: total weeks processed, posts generated, posts skipped, posts failed
- [ ] Failed weeks listed with dataset name and error reason
- [ ] Summary also saved to a log file (e.g., `backfill-log.txt`)

## Functional Requirements
- FR-1: The manifest builder must query `https://github.com/rfordatascience/tidytuesday` for dataset metadata for weeks in the 2025-02-25 to 2026-02-17 range
- FR-2: The runner must invoke the `/tidy-tuesday` skill with dataset name, source URL, and target output directory for each week
- FR-3: Each generated post must be a valid Quarto document (`.qmd`) that renders without error
- FR-4: Post frontmatter must include `date`, `title`, `categories` (including "Tidy Tuesday"), and any other fields required by the blog's `_quarto.yml`
- FR-5: The runner must rescan `posts/` before each week's generation to detect existing posts — this is the primary resume mechanism
- FR-6: The runner must handle interruption gracefully — re-running the script picks up exactly where it left off due to per-iteration rescanning
- FR-7: BYOD/BYOC detection must check the TidyTuesday metadata for indicators like "Bring Your Own Data" or "Bring Your Own Challenge"
- FR-8: 2024 substitute datasets must be selected from the official TidyTuesday 2024 archive
- FR-9: Rescan must also account for used 2024 substitute datasets to prevent duplicates across resumed runs

## Non-Goals
- Custom or curated datasets outside the TidyTuesday archive
- Varying post depth (light vs. full) — all posts get full treatment
- Parallel execution of multiple posts simultaneously
- Editing or improving existing posts during the backfill
- Social media promotion or cross-posting
- Maintaining a persistent state file — rescanning replaces the need for one

## Technical Considerations
- The `/tidy-tuesday` skill handles the actual R/Quarto analysis workflow — the runner orchestrates invocation
- TidyTuesday datasets are hosted on GitHub; some weeks may have moved or changed format
- R 4.5.1 is required for script execution
- Blog lives in a Quarto project — `_quarto.yml` must be respected
- Some datasets may be large; consider memory constraints during rendering
- The 52-week range may extend into future weeks where datasets aren't published yet — these should be logged and skipped
- Rescanning `posts/` is cheap (directory listing) and eliminates the need for a separate state/checkpoint file

## Success Metrics
- At least 48 of 52 weeks have successfully generated and rendered posts
- All generated posts render via `quarto render` without errors
- Git history shows clean, individual commits per post
- Blog displays posts in correct chronological order
- No duplicate 2024 datasets used for substitutions
- Runner can be stopped and resumed any number of times with correct behavior

## Open Questions
- How many weeks in the 2025-02-25 to 2026-02-17 range are BYOD/BYOC? (Affects number of 2024 substitutions needed)
- Are there weeks where the TidyTuesday dataset has been retracted or is unavailable?
- Should future weeks (post-today, 2026-02-19) be skipped entirely or generated with the most recent available dataset?