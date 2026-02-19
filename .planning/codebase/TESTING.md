# Testing Patterns

**Analysis Date:** 2026-02-12

## Test Framework

**Runner:**
- Not detected - This is a static site generator project using Quarto
- No test runner configured (Jest, Vitest, pytest, etc.)

**Assertion Library:**
- Not applicable

**Run Commands:**
```bash
quarto render              # Render entire site
quarto preview            # Watch mode with live server
```

## Test File Organization

**Location:**
- Not applicable - No test files found in codebase
- Test execution happens via CI/CD workflow defined in `.github/workflows/publish.yml`

**Naming:**
- No test files detected
- Workflow files follow GitHub Actions convention: `publish.yml`

**Structure:**
- Project is validation-via-deployment model
- CI pipeline handles build verification

## Test Structure

**Build Validation (CI/CD):**
```yaml
# .github/workflows/publish.yml

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
      - name: Setup Quarto
      - name: Render site          # Validates all .qmd files render
      - name: Upload artifact

  deploy:
    needs: build
    runs-on: ubuntu-latest
```

**Patterns:**
- Pre-execution freezing: `execute: freeze: true` in `_quarto.yml` means R output cached in `_freeze/`
- CI builds against frozen output (no re-execution of R code on deploy)
- Successful render = implicit validation that:
  - YAML frontmatter is valid
  - Markdown syntax is correct
  - All embedded code blocks can execute (if needed)
  - HTML generation completes

## Manual Validation Approach

**What Gets Tested:**
- Quarto rendering (no broken markdown/YAML)
- SCSS compilation to CSS
- HTML output generation
- Site structure integrity (navigation links, pages referenced in config)

**What's NOT Unit Tested:**
- Individual R analysis code
- JavaScript particle animation logic
- CSS visual rendering (relies on browser rendering)

## Data Validation Patterns (R)

**In Blog Posts:** `C:\Users\sxthi\Documents\seanthimons.github.io\posts\2025-11-04\2025-11-04.qmd`

**Booster Pack Installation Pattern:**
```r
install_booster_pack <- function(package, load = TRUE) {
  for (pkg in package) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      pak::pkg_install(pkg)
    }
    if (load) {
      library(pkg, character.only = TRUE)
    }
  }
}
```

**Validation Logic:**
- Checks if package exists before attempting load
- Falls back to installation if not found
- Handles load failures gracefully with `quietly = TRUE`

**File Existence Check:**
```r
if (file.exists('packages.txt')) {
  packages <- read.table('packages.txt')
  install_booster_pack(package = packages$Package, load = FALSE)
} else {
  # Use hardcoded booster_pack list
}
```

## Code Quality Mechanisms

**Quarto Rendering Output:**
- Default: Verbose output during `quarto render` shows any compilation errors
- Cell-level options control visibility: `#| echo: false`, `#| warning: false`, `#| message: false`

**Static Analysis:**
- Not detected (no linters, formatters with validation)

**Browser Compatibility:**
- Reliant on browser vendor support for:
  - CSS Grid (`.grid` class)
  - CSS Variables (used in SCSS)
  - particles.js library (loaded from CDN)

## JavaScript Testing (Implicit)

**Particle Animation:** `C:\Users\sxthi\Documents\seanthimons.github.io\title-block.html`

```javascript
document.addEventListener('DOMContentLoaded', function() {
  if (typeof particlesJS !== 'undefined') {
    particlesJS.load('particles-js', 'particles.json');
  }
});
```

**Defensive Pattern:**
- Checks if `particlesJS` is defined before use
- Falls back silently if library fails to load
- No error logging or retry logic

## OJS/Observable Code (Implicit Testing)

**Project Management Model:** `C:\Users\sxthi\Documents\seanthimons.github.io\project_management_model.qmd`

```ojs
mermaid = {
  const script = document.createElement('script');
  script.src = 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js';
  document.head.appendChild(script);

  return new Promise((resolve) => {
    script.onload = () => resolve(window.mermaid);
  });
}
```

**Test Pattern:**
- Script loads asynchronously
- Promise resolves only when loaded successfully
- Implicit validation: diagram renders = script loaded successfully

## Coverage

**Requirements:** None enforced

**View Coverage:**
- Not applicable - no code coverage metrics configured

**Coverage Gaps:**
- All R analysis code lacks unit tests
- CSS has no visual regression testing
- JavaScript has no automated tests
- HTML structure has no validation (relies on Quarto's defaults)

## Build Success Criteria

**Workflow Validation:** `.github/workflows/publish.yml`

```yaml
- name: Render site
  run: quarto render
```

**Passes if:**
- All `.qmd` files render without error
- No missing resources or broken references
- Output directory `docs/` generated successfully
- GitHub Pages deployment completes

**Fails if:**
- YAML frontmatter is invalid
- Markdown syntax errors
- Missing referenced files/images
- Quarto version incompatibility

## Performance Monitoring

**Not configured** - No performance benchmarks or load testing

**Site Metrics:**
- Rendered site metrics available via GitHub Pages analytics
- No automated performance regression testing

---

*Testing analysis: 2026-02-12*
