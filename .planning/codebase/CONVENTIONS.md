# Coding Conventions

**Analysis Date:** 2026-02-12

## Naming Patterns

**Files:**
- Quarto documents: lowercase with hyphens (`index.qmd`, `blog.qmd`, `projects.qmd`, `project_management_model.qmd`)
- Directories: lowercase with hyphens (`posts/2025-11-04/`)
- SCSS stylesheets: `custom.scss` (single main theme file)
- JSON configuration: lowercase (`particles.json`, `_quarto.yml`)
- HTML partials: lowercase with descriptive names (`title-block.html`)

**Variables (SCSS):**
- Palette colors: kebab-case with descriptive suffixes (`$phthalo-deep`, `$oxblood-light`, `$light-teal-bg`, `$near-white`)
- Bootstrap overrides: kebab-case matching Bootstrap convention (`$body-bg`, `$link-color`, `$primary`)
- Grouped with comments: `// ---- Group Name ----` for logical sections

**CSS Classes:**
- kebab-case for component classes (`.hero-section`, `.hero-content`, `.page-footer`, `.btn-primary`)
- BEM-like patterns for nested elements (`.hero-links a`, `.card h3`)
- Scoped page classes: `body.page-blog`, `body.page-work`, `body.page-volunteer`

**Functions:**
- R functions: snake_case (`install_booster_pack`, `requireNamespace`)
- JavaScript functions: camelCase (`particlesJS.load`, `document.addEventListener`)
- OJS blocks: declared inline with `mermaid =`, `mermaidDef =`

**Variables:**
- Quarto YAML: lowercase with hyphens (`title:`, `format:`, `body-classes:`)
- R vectors/lists: camelCase for readability (`booster_pack`, `packages`)

## Code Style

**Formatting:**
- Editor: VSCode with extensions configured in `.vscode/settings.json`
- R files: Formatted on save by Posit air-vscode extension
- Quarto files: Formatted on save by Quarto extension
- SCSS: Formatted manually or through editor extensions

**Indentation:**
- R/RProj: 2 spaces (`UseSpacesForTab: Yes`, `NumSpacesForTab: 2`)
- HTML/YAML: 2 spaces
- SCSS: 2-space nesting

**Line Length:**
- No strict enforced limit observed
- SCSS comments follow logical grouping (e.g., `// ---- Buttons ----`)

**Linting:**
- Not detected in configuration

## Import Organization

**R Code:**
1. Conditional pak installation
2. Helper functions (e.g., `install_booster_pack`)
3. Package installation and loading via function
4. Order within booster_pack: grouped by category with comments
   - IO packages (fs, here, janitor, rio, tidyverse)
   - DB packages (commented out but show intended organization)
   - EDA packages (skimr)
   - Web packages (commented)

**SCSS:**
1. Variable overrides at top with `/*-- scss:defaults --*/`
2. Color palette definitions grouped by section/use
3. Bootstrap/Quarto variable overrides
4. Font configuration
5. Rules section `/*-- scss:rules --*/`
6. Google Font imports
7. Component-specific styles
8. Section-specific color schemes at bottom

**Quarto YAML:**
- Front matter with `---` delimiters
- Order: title, format, resources, optional attributes
- Format section nested under `html:`
- Listing configurations for blog

## Error Handling

**Patterns:**
- R: Conditional package checking with `requireNamespace(..., quietly = TRUE)`
- R: `if (file.exists(...))` for configuration files
- JavaScript: Event listener with `if (typeof particlesJS !== 'undefined')` before use
- R: Optional package installation with pak fallback

**Defensive Programming:**
- Check if external libraries are loaded before use
- Gracefully handle missing packages
- Use `quietly = TRUE` to suppress unnecessary output

## Logging

**Framework:** console output (R via `print`, JavaScript via `console`)

**Patterns:**
- R code uses message suppression flags: `#| message: false`, `#| warning: false`
- HTML/JavaScript errors handled silently (no console logging observed)
- No structured logging framework detected

## Comments

**When to Comment:**
- Section separators with visual emphasis: `// ---- Section Name ----`
- Grouping related styles and variables
- Explaining non-obvious CSS specificity rules (e.g., `!important` for button styling)
- Quarto cell options: `#| label:`, `#| echo:`, `#| code-fold:`
- Context notes (e.g., "Adjust to frame face better" for image positioning)

**JSDoc/TSDoc:**
- Not used in this codebase (primarily Quarto/R/SCSS project)

## Function Design

**Size:** Not enforced; observed functions are small
- Helper functions like `install_booster_pack` fit on ~15 lines
- Focused on single responsibility

**Parameters:**
- R functions use named parameters: `install_booster_pack(package, load = TRUE)`
- Defaults provided where sensible: `load = TRUE`
- Named arguments used at call sites for clarity

**Return Values:**
- R: Functions return data structures or TRUE/FALSE
- R: Silent return when side effects are primary (e.g., package loading)
- JavaScript: DOM API methods chain naturally (e.g., `document.addEventListener`)

## Module Design

**Exports:**
- No module system detected (Quarto renders to static HTML)
- R code: Functions defined at top-level for use in chunks
- Quarto documents: Self-contained with embedded SCSS and JavaScript

**Barrel Files:**
- Not applicable (no JavaScript bundling)
- SCSS uses single main file (`custom.scss`) included in `_quarto.yml`

## CSS Specificity Patterns

**Selectors:**
- Use of descendant selectors for scoped styling: `.page-work #quarto-content a`
- :not() pseudo-class for exclusion: `a:not(.btn)` to exclude buttons from link styles
- Multiple selector rules to increase specificity: `#quarto-content a, .quarto-title a, main a`
- `!important` used strategically for button text color override to ensure visibility

**Pattern:** Start with low specificity, increase only when needed. Scoped themes (page-blog, page-work, page-volunteer) isolate styling by body class.

---

*Convention analysis: 2026-02-12*
