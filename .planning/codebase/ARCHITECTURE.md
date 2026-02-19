# Architecture

**Analysis Date:** 2026-02-12

## Pattern Overview

**Overall:** Static website generator pattern using Quarto with section-scoped theming

**Key Characteristics:**
- Single-source document rendering (Quarto markdown → HTML)
- Page-based CSS class scoping for theme switching
- Client-side particle animation for hero section
- Pre-rendered static output with no server runtime
- Content-first design with minimal JavaScript dependencies

## Layers

**Presentation (HTML/CSS/JS):**
- Purpose: Render themed user interface with responsive design
- Location: `custom.scss`, `styles.css`, `title-block.html`, `particles.json`
- Contains: SCSS variables, theme definitions, hero section styling, section-scoped color schemes
- Depends on: Bootstrap framework via Quarto, particles.js library from CDN
- Used by: All `.qmd` files that render to HTML

**Content (Markdown/Quarto):**
- Purpose: Semantic content definition and page structure
- Location: `*.qmd` files (`index.qmd`, `blog.qmd`, `projects.qmd`, `volunteer.qmd`, `project_management_model.qmd`, `posts/`)
- Contains: YAML frontmatter with metadata, markdown content, embedded code blocks (R, OJS)
- Depends on: Quarto build system, references to images and data files
- Used by: Quarto renderer to generate static HTML

**Configuration:**
- Purpose: Build orchestration and project settings
- Location: `_quarto.yml`, `seanthimons.github.io.Rproj`
- Contains: Website metadata, navbar structure, output directory, theme references, execution settings
- Depends on: Quarto CLI
- Used by: Quarto build process

**Assets:**
- Purpose: Static resources loaded at runtime
- Location: `images/` (headshot.jpg, flywheel.jpg), `particles.json`, `*.bib` (works.bib, ppp.bib)
- Contains: Image files, particle animation config, bibliography data
- Depends on: HTTP requests from generated HTML
- Used by: Browser to render images and load particle configurations

## Data Flow

**Build Process:**
1. Quarto reads `_quarto.yml` configuration
2. Quarto discovers all `.qmd` files in project root and `posts/` subdirectory
3. For each `.qmd`:
   - Parse YAML frontmatter (title, date, categories, body-classes)
   - Render markdown + embedded code (R, OJS)
   - Apply template partials (`title-block.html` for index only)
   - Inject CSS theme references from `custom.scss` and `styles.css`
   - Output HTML to `docs/` directory
4. Quarto copies assets and site libraries to `docs/site_libs/`
5. Static HTML, CSS, and images ready for GitHub Pages deployment

**Page Rendering at Runtime:**
1. Browser loads HTML from `docs/` (GitHub Pages)
2. HTML includes:
   - Custom SCSS variables as CSS custom properties
   - Body class attribute matching page (e.g., `page-blog`, `page-work`, `page-volunteer`)
   - Link to `particles.json` config (hero section only)
   - Navbar with links from `_quarto.yml`
3. Browser loads Bootstrap CSS via Quarto's site_libs
4. Browser loads `custom.scss` compiled CSS (section-scoped selectors active)
5. Browser loads `styles.css` (supplemental styling)
6. Hero section JavaScript executes:
   - Detects `#particles-js` container on index page
   - Loads particles.js from CDN
   - Initializes animation with `particles.json` config

**Page Listing:**
1. `blog.qmd` defines listing configuration: `type: default`, `sort: "date desc"`, `categories: true`
2. Quarto scans `posts/` directory for `.qmd` files
3. For each post, extracts metadata from frontmatter (date, title, description, categories)
4. Renders listing cards in reverse chronological order
5. Category badges applied with `page-blog` body class for Oxblood color scheme

**State Management:**
- No persistent state (static site)
- URL-based navigation via navbar links
- Client-side OJS (Observable JavaScript) for interactive diagrams (`project_management_model.qmd`)
- OJS maintains zoom/pan state of mermaid diagram in browser memory only

## Key Abstractions

**Section Color Scheme:**
- Purpose: Apply distinct visual identity to different page sections
- Examples: `body.page-blog` (Oxblood), `body.page-work` (Tyrian), `body.page-volunteer` (Amber)
- Pattern: CSS selectors prefixed with `body.[page-*]` to target descendant elements
- Implementation in `custom.scss` lines 224-343: Each section defines color palette, then applies to links, headings, cards, buttons

**Hero Section:**
- Purpose: Animated hero banner on homepage
- Examples: `#particles-js` container, `title-block.html` template partial
- Pattern: Absolute positioned particles background with overlaid content layer
- Implementation: Particles.js library loads JSON config at runtime; hero content renders in z-index 1 above particles at z-index 0

**Button Styling:**
- Purpose: CTA buttons with section-specific colors
- Examples: `.btn-primary` base style, `.page-work .btn-primary` override
- Pattern: Base button defined with `!important` flags to override Bootstrap; section scopes then override with stronger specificity
- Implementation in `custom.scss`: Lines 172-192 (base) and per-section overrides (lines 301-311 for Work section)

**Card Component:**
- Purpose: Grid layout for project showcases
- Examples: `.card` in `projects.qmd` with `.grid` and `.g-col-*` Bootstrap grid classes
- Pattern: CSS Grid with equal-height flex columns; hover effects with shadow/transform
- Implementation: Custom card styling lines 141-170 in `custom.scss`

## Entry Points

**Homepage (`index.qmd`):**
- Location: `C:\Users\sxthi\Documents\seanthimons.github.io\index.qmd`
- Triggers: User navigates to domain root or clicks "Home" in navbar
- Responsibilities:
  - Load custom template partial `title-block.html` for animated hero
  - Render bio and education/work sections
  - Initialize particles.js animation on DOMContentLoaded
  - Link to projects page with CTA button

**Blog Listing (`blog.qmd`):**
- Location: `C:\Users\sxthi\Documents\seanthimons.github.io\blog.qmd`
- Triggers: User clicks "Blog" in navbar
- Responsibilities:
  - Apply Oxblood color scheme via `body-classes: page-blog`
  - Render listing of all posts from `posts/` directory
  - Sort posts by date descending
  - Display category badges for filtering

**Work Projects (`projects.qmd`):**
- Location: `C:\Users\sxthi\Documents\seanthimons.github.io\projects.qmd`
- Triggers: User clicks "Work" in navbar
- Responsibilities:
  - Apply Tyrian Purple color scheme via `body-classes: page-work`
  - Render three project cards (CompToxR, THREAT, Curation)
  - Display research focus and technical support sections
  - Include bibliography citations from `works.bib`

**Mental Model (`project_management_model.qmd`):**
- Location: `C:\Users\sxthi\Documents\seanthimons.github.io\project_management_model.qmd`
- Triggers: User clicks "Mental Model" in navbar
- Responsibilities:
  - Render interactive mermaid flowchart via OJS
  - Manage zoom/pan controls and state
  - Display legend explaining color-coded categories (principles, warnings, outputs, tradeoffs, risks, strategies)
  - No page-specific body class (uses default theme)

**Volunteering (`volunteer.qmd`):**
- Location: `C:\Users\sxthi\Documents\seanthimons.github.io\volunteer.qmd`
- Triggers: User clicks "Volunteer" in navbar
- Responsibilities:
  - Apply Amber/Gold color scheme via `body-classes: page-volunteer`
  - Describe Cincinnati ML Meetup involvement
  - Document housing stability hackathon participation
  - Embed project images

**Blog Posts (`posts/YYYY-MM-DD/YYYY-MM-DD.qmd`):**
- Location: `C:\Users\sxthi\Documents\seanthimons.github.io\posts\2025-11-04\2025-11-04.qmd`
- Triggers: User clicks post title in blog listing
- Responsibilities:
  - Render individual post content with R code execution
  - Apply blog color scheme via inherited `page-blog` class
  - Display post metadata (title, author, date, categories)
  - Execute R code blocks and embed visualizations

## Error Handling

**Strategy:** Silent fallback for missing assets

**Patterns:**
- Particles.js: Checks if `particlesJS` is defined before initialization (`if (typeof particlesJS !== 'undefined')`)
- Missing images: Browser renders broken image icon; theme still loads
- Missing CDN resources: Graceful degradation (no particles animation, but page loads)
- Quarto errors: Build fails; developer must fix before deployment to GitHub Pages

## Cross-Cutting Concerns

**Logging:** Not applicable (static site, no server runtime)

**Validation:** Not applicable (no form inputs or user submissions)

**Authentication:** Not applicable (public portfolio site, no auth required)

**Styling Consistency:**
- All links use consistent underline pattern with opacity transitions (lines 115-125 in custom.scss)
- All cards use same hover effect (shadow + transform) for consistent interaction
- Section-scoped colors ensure visual hierarchy doesn't break across page transitions
- Color palette defined in SCSS variables at file top for single source of truth

**Responsive Design:**
- Bootstrap 5 grid system via Quarto (`.g-col-12 .g-col-md-4` for project cards)
- Hero section uses flexbox for centering across all viewport sizes
- Typography scales with responsive units (rem for most properties)
- Mobile-first approach: particles animation disabled at smaller breakpoints (inferred from DOM-based initialization)

---

*Architecture analysis: 2026-02-12*
