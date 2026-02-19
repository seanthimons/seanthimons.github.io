# Codebase Concerns

**Analysis Date:** 2026-02-12

## CSS Specificity & !important Overuse

**Issue:** Excessive use of `!important` flags throughout `custom.scss`

**Files:** `custom.scss` (lines 174-310)

**Impact:**
- Makes future style modifications difficult and brittle
- Creates specificity wars if additional styling is needed
- Indicates underlying architectural CSS issues rather than proper cascade use
- All 26+ instances of `!important` across button styles, link colors, and section-specific rules suggest overreliance on this mechanism

**Current State:**
- Lines 174-192: Button styling uses `!important` on background, border, and color
- Lines 225-312: Section-specific color schemes (.page-blog, .page-work, .page-volunteer) use `!important` for nearly all color declarations
- This was added to override Bootstrap's default link and button styles

**Fix Approach:**
1. Refactor CSS selector specificity to eliminate `!important` where possible
2. Use CSS custom properties (--variables) for section-scoped colors to reduce repetitive declarations
3. Move section-specific styles into separate imported SCSS files rather than nesting all in one file
4. Properly scope button styles with more specific selectors rather than relying on `!important`
5. Test thoroughly when removing `!important` to ensure Bootstrap overrides still work

## Section-Specific Color Theming Fragility

**Issue:** Complex multi-selector color scheme targeting is fragile and difficult to maintain

**Files:** `custom.scss` (lines 224-343)

**Why Fragile:**
- Each section (.page-blog, .page-work, .page-volunteer) requires 15+ selectors to target links, headings, buttons, and cards
- Selectors are overly specific and brittle (e.g., `#quarto-content a:not(.btn)`)
- Adding new page sections requires duplicating large blocks of color overrides
- Risk of color leakage between sections if Quarto's HTML structure changes
- Recent commits (097866a, a784cd8, 5500c13) show multiple iterations to fix button visibility and color targeting, indicating instability

**Pattern Problem:**
```scss
// This pattern repeats for 3 different color palettes
body.page-work {
  #quarto-content a:not(.btn) { color: $tyrian !important; }
  main a:not(.btn) { color: $tyrian !important; }
  // ... 15+ more selectors
  .btn-primary { background-color: $tyrian !important; }
}
```

**Better Approach:**
- Use CSS custom properties at the body level: `--section-primary-color`, `--section-text-color`
- Define once per section, use consistently throughout
- Eliminates repetition and makes adding new sections trivial

## Duplicate Multiple-Color Palettes

**Issue:** Five separate color schemes defined but only three are actively used

**Files:** `custom.scss` (lines 1-34)

**Current State:**
- Phthalo Waters palette (primary/default) - USED
- Oxblood Scholar palette - USED (.page-blog)
- Tyrian Chemist palette - USED (.page-work)
- Amber/Gold palette - USED (.page-volunteer)
- Laser Lab palette - DEFINED but NEVER USED (lines 17-18 commented concept only)

**Impact:**
- Unused palette definition adds visual clutter and confusion
- No clear convention for when to add new color schemes
- Increases maintenance burden if color values need updating

**Fix Approach:**
- Remove "Laser Lab" reference entirely since it's never implemented
- Add comments documenting which palette applies to which page
- Consider extracting palettes into separate SCSS modules if more will be added

## Particles.js CDN Dependency & No Fallback

**Issue:** Hero section depends on external CDN for particles.js with no degradation path

**Files:** `title-block.html` (lines 27-36)

**Risk:**
- If CDN is unreachable, particles.js fails silently (code checks `typeof particlesJS !== 'undefined'` but doesn't fall back gracefully)
- No local copy of particles.js available
- Breaks dynamic hero experience if network is slow or unavailable
- Page still loads but visual impact is significantly degraded

**Current Implementation:**
```html
<script src="https://cdnjs.cloudflare.com/ajax/libs/particles.js/2.0.0/particles.min.js"></script>
<script>
  document.addEventListener('DOMContentLoaded', function() {
    if (typeof particlesJS !== 'undefined') {
      particlesJS.load('particles-js', 'particles.json');
    }
  });
</script>
```

**Safe Fallback:**
- Provide a CSS-only background fallback (gradient, pattern, or solid color) for when particles fail to load
- Consider bundling particles.js locally or using a self-hosted version
- Add visible loading indicator or animate fallback background

## Blog Section with Minimal Content

**Issue:** Blog page configured but only has one post from 2025-11-04 (actual date shows as November 13, 2025)

**Files:** `blog.qmd`, `posts/2025-11-04/2025-11-04.qmd`

**Risk:**
- Portfolio-renovation-checklist.md (line 54) notes: "A placeholder post with no content looks worse than no posts at all"
- Listing page exists but sparse content undermines credibility
- If blog is not actively maintained, better to remove or feature work elsewhere

**Current State:**
- One visible post with output images but no clear post content/metadata
- Blog listing configured with categories enabled (blog.qmd line 10)
- Disclaimer about personal opinions vs. employer views is present (good practice)

**Recommendation:**
- If committing to blog: add regular content schedule or remove entirely
- Move TidyTuesday work to Projects page if not blogging regularly
- Consider "Now" page as lightweight alternative for current work

## Shared Headshot Image Dependency

**Issue:** Hero section and potentially other pages depend on `images/headshot.jpg`

**Files:** `title-block.html` (line 7), `custom.scss` (lines 85-93)

**Risk:**
- Single image file dependency - if missing, hero section breaks visually
- No alt text consistency checking across usages
- Object positioning hardcoded in CSS (`object-position: center 30%`) assumes specific image composition

**Current Implementation:**
```html
<img src="images/headshot.jpg" alt="Sean Thimons headshot" class="hero-headshot">
```

**Safety:**
- Verify image exists before rendering
- Consider providing a text fallback (initials or icon) if image fails to load
- Document the assumed image dimensions and crop requirements

## Quarto Freeze Configuration Risk

**Issue:** `_quarto.yml` sets `freeze: true` which prevents R code re-execution on CI

**Files:** `_quarto.yml` (lines 30-31)

**Impact:**
- R code outputs are cached in `_freeze/` and never re-run during CI builds
- If data sources change or bugs are discovered, outputs won't update unless manually re-rendered locally
- New contributors must know to run `quarto render` locally before pushing

**Current Policy:**
```yaml
execute:
  freeze: true  # never re-execute on CI; render locally to update _freeze/
```

**Why It's Risky:**
- Workflow documentation is only in comments (line 31)
- Prevents automated validation of code correctness during CI
- GitHub Actions workflow (publish.yml) has no check for stale _freeze/ cache
- If someone adds new R code expecting it to run on CI, it will silently fail

**Mitigation:**
- Add build-time validation that all .qmd files referenced in `_quarto.yml` have corresponding entries in `_freeze/`
- Document freeze policy prominently in README or CONTRIBUTING guide
- Consider adding a CI job that warns if any .qmd files are modified without corresponding `_freeze/` updates

## CSS Specificity Test Coverage Gaps

**Issue:** Section-specific color schemes were recently fixed multiple times, indicating poor testing

**Files:** `custom.scss`, recent commits (097866a, a784cd8, 5500c13, 2921241)

**Evidence:**
- Commit 097866a: "Increase CSS specificity for section colors"
- Commit a784cd8: "Fix button text and expand section color targeting"
- Commit 5500c13: "Fix button text visibility with !important"
- Commit 2921241: "Exclude buttons from link color override on Work page"

**Problem:**
- Each commit addresses a previous fix that broke something else
- Indicates lack of systematic testing across different sections
- No mention of rendering all pages to verify consistency

**Safe Modification Approach:**
- Create a checklist: render all 4 pages (Home, Blog, Work, Volunteer) locally
- Verify: links are visible, buttons work, headings display correctly in each color scheme
- Test at multiple screen sizes (mobile, tablet, desktop)
- Check for color contrast accessibility (WCAG AA minimum)

## Content Quality Issues

**Issue:** Several content quality problems documented in portfolio-renovation-checklist.md remain unresolved

**Files:** `portfolio-renovation-checklist.md` (lines 9-18), specific source files

**Identified but Not Fixed:**
1. Line 15: "Homepage: Fix work history date order" — Currently shows "Present - 2025" which looks like a typo
2. Line 41: "Projects: Fix typo" — "Shooting Start Award" should be "Shooting Star Award" (currently in projects.qmd)
3. Line 16: "Volunteer: Fix typo" — "meeting organize" → "meeting organizer" (appears to be FIXED in volunteer.qmd)
4. Line 52: Blog decision — "Commit or remove" remains unresolved

**Impact:**
- Affects employer perception (portfolio-renovation-checklist.md line 11 notes "embarrassing issues")
- Easy wins that build credibility when fixed

## Missing Documentation

**Issue:** No README or CONTRIBUTING guide for contributors or future maintainers

**Files:** Missing (should exist in root: README.md)

**Gaps:**
- No explanation of the freeze: true policy or how to update _freeze/
- No guide for adding new pages or sections
- No documented color palette or design system
- No mobile testing instructions
- No accessibility requirements

**Impact:**
- Makes site harder to contribute to
- New collaborators must read through checklist and commits to understand patterns
- Increases onboarding time for any contributor

## Unused Files in Repository

**Issue:** Multiple unused or redundant files tracked in git

**Files:**
- `air.toml` - Empty development server config (line 6 of root listing)
- `seanthimons.github.io.Rproj` - RStudio project file (rarely needed for CI/CD)
- `ppp.bib`, `works.bib` - Bibliography files (works.bib is used in projects.qmd, but ppp.bib may be unused)

**Fix Approach:**
- Remove unused .toml config files
- Consider .gitignoring .Rproj files (add to .gitignore)
- Verify ppp.bib is not referenced anywhere before removing

## Rendering Complexity with Bootstrap Versions

**Issue:** Multiple cached Bootstrap CSS versions exist in `/docs/site_libs/bootstrap/`

**Files:** `docs/site_libs/bootstrap/` (10+ differently-named bootstrap versions)

**Impact:**
- Indicates Quarto may be generating multiple theme variants or that cache wasn't cleaned between builds
- Adds unnecessary bloat to the docs/ directory
- Site_libs/ is in .gitignore which is correct, but generated files shouldn't accumulate locally

**Note:**
- This is in docs/ which is gitignored (line 10 of .gitignore), so doesn't affect repo size
- However, local builds will accumulate cached versions over time

---

*Concerns audit: 2026-02-12*
