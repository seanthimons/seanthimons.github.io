# Tidy Tuesday: 2026 Winter Olympics Blog Post

## What This Is

A new Tidy Tuesday blog post for seanthimons.github.io analyzing the 2026-02-10 Winter Olympics dataset (Milano-Cortina). Follows the same format as the existing Flint lead post — booster pack setup, data loading, EDA, and visualizations — but with a lighter exploratory focus rather than heavy statistical modeling.

## Core Value

A well-structured, visually engaging Tidy Tuesday post that explores the Winter Olympics data and produces interesting visualizations worth sharing.

## Requirements

### Validated

- ✓ Quarto-based personal website with blog listing — existing
- ✓ Blog post structure: YAML frontmatter, booster pack, data load, EDA, visualization, narrative — existing
- ✓ Section-scoped theming (Oxblood for blog) — existing
- ✓ GitHub Pages deployment pipeline — existing

### Active

- [ ] Create new blog post directory and .qmd file following existing naming convention
- [ ] Load 2026-02-10 Tidy Tuesday dataset (Winter Olympics)
- [ ] Perform exploratory data analysis with `skimr`/`my_skim()`
- [ ] Create polished visualization(s) exploring the data
- [ ] Write brief narrative contextualizing findings
- [ ] Post renders cleanly via Quarto

### Out of Scope

- Heavy statistical modeling (ANOVA, tidymodels) — keeping this lighter
- Custom CSS or theme changes — using existing blog styling
- New R packages beyond the booster pack — use what's available

## Context

- Existing post at `posts/2025-11-04/2025-11-04.qmd` serves as the template
- Posts use `YYYY-MM-DD` directory and filename convention
- Booster pack pattern handles package installation and loading
- The `tidytuesdayR` package loads data via `tt_load('YYYY-MM-DD')`
- `camcorder` used for plot capture at proper resolution
- Blog listing auto-discovers posts from `posts/` directory

## Constraints

- **Stack**: Quarto + R — must match existing site toolchain
- **Format**: Must follow existing post conventions (frontmatter, booster pack, code-fold patterns)
- **Dataset**: 2026-02-10 Tidy Tuesday (Winter Olympics)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Use existing booster pack verbatim | Consistency with existing posts | — Pending |
| Lighter analysis (EDA + viz only) | User preference for exploration over modeling | — Pending |
| Follow `YYYY-MM-DD` directory convention | Match existing post structure | — Pending |

---
*Last updated: 2026-02-12 after initialization*
