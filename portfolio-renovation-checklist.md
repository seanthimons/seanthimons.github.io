# Portfolio Site Renovation Checklist

**Site:** seanthimons.github.io  
**Framework:** Quarto  
**Goal:** Transform from "cloned template" to polished, employer-ready portfolio

---

## Critical Fixes (Do First)

These are embarrassing issues that should be fixed immediately:

- [ ] **Blog: Fix Unix epoch date** — "My First Post" shows "Jan 1, 1970". Either set a real date or delete the post entirely.
- [ ] **Homepage: Fix work history date order** — Currently shows "Present - 2025" which looks like a typo. Should be "2025 - Present" or rewritten entirely (see narrative option below).
- [ ] **Projects: Fix typo** — "Shooting Start Award" should probably be "Shooting Star Award"
- [ ] **Volunteer: Fix typo** — "meeting organize" → "meeting organizer"
- [ ] **Blog: Remove "No matching items"** — This appears at the bottom of the blog listing page, likely a Quarto listing filter issue.

---

## Content Improvements

### Homepage (index.qmd)

- [ ] **Rewrite bio in first person** — Current third-person voice ("Thimons holds...", "His research aims...") creates distance. Change to first person ("I focus on...", "My research aims...").
- [ ] **Change page title** — Current title is "Water reuse, data science, risk characterization, community engagement" which is keyword soup. Change to something like "Sean Thimons – Water Data Scientist & EPA Researcher"
- [ ] **Add a clear call-to-action** — After the bio, add a prominent link like "View My Projects →" or "Read My Latest Post →"
- [ ] **Restructure work experience** — Replace the confusing bullet list with a narrative paragraph:

```markdown
I'm currently a Physical Scientist in EPA's Office of Water, working on wastewater 
technology and analytics. Previously, I spent four years with the Office of Research 
and Development (first as an ORISE Fellow, then as a Physical Scientist), where I 
focused on risk characterization for water reuse and chemical safety data curation.
```

- [ ] **Add headshot alt text** — For accessibility and SEO: `![Sean Thimons headshot](images/headshot.jpg)`

### Projects Page (projects.qmd)

- [ ] **Rename "Fun things I work on"** — Change to "Open Source Tools" or "R Packages & Applications"
- [ ] **Add descriptions to each GitHub project:**
  - **CompToxR**: One sentence explaining what it does (e.g., "R package for accessing EPA's CompTox Chemistry Dashboard API for chemical risk evaluation")
  - **Curation**: Brief explanation of what data/workflows
  - **THREAT**: Explain what the Shiny app does and who it's for
- [ ] **Remove or explain StRAP bullets** — "406.1", "407.1", "408.3" mean nothing to external readers. Either add brief plain-English descriptions or remove this section.
- [ ] **Consider splitting the page** — Navigation item "Projects, Technical Support, Publications" is long. Options:
  - Rename to just "Work" or "Portfolio"
  - Split into separate pages: "Projects" and "Publications"
- [ ] **Add visual hierarchy** — See UI section below for project card implementation

### Blog Page (blog.qmd)

- [ ] **Delete or complete "My First Post"** — A placeholder post with no content looks worse than no posts at all
- [ ] **Add descriptions to TidyTuesday listings** — Each post should have a one-sentence description visible in the listing
- [ ] **Decide: commit or remove** — If you're not going to post regularly (1x/month minimum), consider removing the blog section entirely and featuring TidyTuesday work under Projects instead

### Volunteer Page (volunteer.qmd)

- [ ] **Delete opening sentence** — "I currently volunteer in my local community in a variety of ways!" adds nothing. Start directly with the ML Meetup section.
- [ ] **Add links to talk materials** — You mention giving talks on EDA and time-series analysis. Link to slides, recordings, or GitHub repos if available.
- [ ] **Tighten hackathon description** — Change "We ended winning" to "We won" and consider removing "Not bad for three days of work!" (slightly defensive tone)

---

## UI/Design Improvements

### _quarto.yml changes

- [ ] **Add a favicon** — Create or find a simple favicon.ico and add to project root. In _quarto.yml:
```yaml
website:
  favicon: favicon.ico
```

- [ ] **Set custom theme colors** — In _quarto.yml or a custom .scss file, define at least:
  - Primary accent color (for links, buttons)
  - Consider a subtle background tint for cards/callouts
  
Example in _quarto.yml:
```yaml
format:
  html:
    theme:
      light: [cosmo, custom.scss]
```

- [ ] **Add footer** — In _quarto.yml:
```yaml
website:
  page-footer:
    center: "© 2025 Sean Thimons · Built with Quarto"
```

### Headshot styling

- [ ] **Make headshot circular and smaller** — Add CSS or use Quarto's built-in options:
```css
img[src*="headshot"] {
  border-radius: 50%;
  max-width: 200px;
  margin: 0 auto;
  display: block;
}
```

### Project cards (projects.qmd)

- [ ] **Create visual cards for open source projects** — Instead of a plain list, use Quarto's card layout or custom divs:

```markdown
::: {.grid}

::: {.g-col-12 .g-col-md-4}
::: {.card}
### CompToxR
R package for accessing EPA's CompTox Chemistry Dashboard API.

[GitHub](https://github.com/seanthimons/ComptoxR){.btn .btn-primary}
:::
:::

::: {.g-col-12 .g-col-md-4}
::: {.card}
### THREAT
Shiny application for cross-walking observational data against environmental water quality benchmarks.

[GitHub](https://github.com/seanthimons/THREAT){.btn .btn-primary}
:::
:::

:::
```

- [ ] **Add screenshots** — For THREAT especially (it's a Shiny app!), a screenshot would be worth 1000 words

### Link styling

- [ ] **Make links more visible** — In custom.scss:
```scss
a {
  text-decoration: underline;
  text-underline-offset: 2px;
}
a:hover {
  text-decoration-thickness: 2px;
}
```

### Navigation

- [ ] **Shorten nav item** — Change "Projects, Technical Support, Publications" to "Work" or "Portfolio"

---

## Design Direction: "Phthalo Waters" Theme with Particles.js

Sean wants a site that looks intentionally designed rather than cloned from a template.
The visual inspiration is [Yan Holtz's site](https://www.yan-holtz.com/) — specifically the
animated network graph background, generous whitespace, and single-accent-color approach.

Color direction is rooted in earth tones and scientifically meaningful pigments:
phthalo green, oxblood red, Tyrian purple, aquamarine, Nd:YAG laser yellow.

### Color Palette: "Phthalo Waters"

Given Sean's water reuse focus and EPA work, a water/earth palette is the most
thematically coherent. These are starting points — adjust as needed:

```
Primary accent (links, buttons, highlights):  #0D5C63  (deep phthalo teal)
Secondary accent (hover states, borders):     #78CDD7  (light aquamarine)
Dark text / headings:                         #1A2E35  (dark slate)
Body text:                                    #3D4F58  (softer dark)
Light background (cards, callouts):           #F0F5F4  (barely-there teal tint)
Page background:                              #FAFBFB  (near-white)
Code block background:                        #EEF2F3  (light gray-teal)
```

Alternative palettes if Sean changes his mind:
- **Oxblood Scholar**: Primary `#6B1C23`, Secondary `#D4A373` (warm, academic)
- **Tyrian Chemist**: Primary `#5D2E8C`, Secondary `#B8A9C9` (regal, distinctive)
- **Laser Lab**: Primary `#2B4141`, Secondary `#D4AF37` (dark + gold, technical)

### Particles.js Integration

Yan Holtz wrote a guide for exactly this use case in Quarto. The approach uses
Quarto's **template partials** to inject particles.js into the title-block header.

#### Key Resources

- **Yan's Quarto tips page (particles section)**: https://www.productive-r-workflow.com/quarto-tricks
- **Yan's example repo**: https://github.com/holtzy/quarto-tricks/tree/main/particle-js
- **Particles.js config playground**: https://vincentgarreau.com/particles.js/
- **François Perruchas's approach** (particles in a grid column): https://www.fperruchas.eu/notes/2023-09-02-personal-website-with-quarto.html
- **Emil Hvitfeldt's iframe approach** (for presentations but adaptable): https://emilhvitfeldt.github.io/quarto-iframe-examples/

#### Implementation Steps

**1. Create a `title-block.html` partial** in the project root:

```html
<header id="title-block-header" style="position: relative">
  <!-- Particle container -->
  <div id="particles-js"></div>

  <!-- Content overlaid on particles -->
  <div class="title-block-content">
    <!-- Your name, subtitle, social links go here -->
    <!-- This replaces the default Quarto title block -->
  </div>

  <!-- Load particles.js from CDN -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/particles.js/2.0.0/particles.min.js"></script>

  <!-- Initialize with config -->
  <script>
    particlesJS.load("particles-js", "./particles.json");
  </script>
</header>
```

**2. Create a `particles.json` config file.**

Use the playground at https://vincentgarreau.com/particles.js/ to customize, then export.
Recommended starting config for a network/molecular feel:

```json
{
  "particles": {
    "number": { "value": 60, "density": { "enable": true, "value_area": 900 } },
    "color": { "value": "#78CDD7" },
    "shape": { "type": "circle" },
    "opacity": { "value": 0.3, "random": true },
    "size": { "value": 3, "random": true },
    "line_linked": {
      "enable": true,
      "distance": 180,
      "color": "#0D5C63",
      "opacity": 0.2,
      "width": 1
    },
    "move": {
      "enable": true,
      "speed": 1.5,
      "direction": "none",
      "random": true,
      "straight": false,
      "out_mode": "out"
    }
  },
  "interactivity": {
    "detect_on": "canvas",
    "events": {
      "onhover": { "enable": true, "mode": "grab" },
      "onclick": { "enable": false },
      "resize": true
    },
    "modes": {
      "grab": { "distance": 150, "line_linked": { "opacity": 0.4 } }
    }
  },
  "retina_detect": true
}
```

The above config creates subtle, slow-moving particles with a network/molecular
connection effect. "grab" on hover pulls connections toward the cursor — a nice
interactive touch. The colors use the Phthalo Waters palette.

**3. Wire it up in `_quarto.yml`** (homepage only):

For a Quarto **website** (not a single document), the partial approach works differently.
Two approaches:

**Approach A: Homepage-only particles via `index.qmd` YAML:**
```yaml
# In index.qmd front matter:
---
title: "Sean Thimons"
subtitle: "Water Data Scientist & EPA Researcher"
format:
  html:
    template-partials:
      - title-block.html
resources:
  - particles.json
---
```

**Approach B: Full-page background (all pages) via `_quarto.yml`:**
```yaml
# In _quarto.yml (applies to all pages):
format:
  html:
    include-after-body:
      - file: particles-background.html
```

Approach A is recommended — particles on every page gets distracting.

**4. CSS for the particles container:**

Add to `custom.scss`:
```scss
/*-- scss:rules --*/

#particles-js {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  z-index: 0;
}

.title-block-content {
  position: relative;
  z-index: 1;
  text-align: center;
  padding: 4rem 2rem;
}
```

#### Known Gotcha with Template Partials in Quarto Websites

There is a known issue (discussed in quarto-dev/quarto-cli#8237) where providing
a `title-block.html` partial in a website context places the partial inside
`main.content` rather than replacing the original header. This means:

- The custom partial won't span full viewport width by default
- There may be a duplicate empty `<header>` element in the DOM

Workarounds:
- Use `page-layout: custom` on the homepage to escape the default layout constraints
- Or use `include-in-header` / `include-after-body` with raw HTML instead of a
  partial, positioning the particles div with CSS `position: fixed`
- Test in browser DevTools and adjust accordingly

### Custom SCSS Theme File

Create `custom.scss` in the project root. This replaces the generic Bootswatch theme:

```scss
/*-- scss:defaults --*/

// ---- Phthalo Waters Palette ----
$phthalo-deep:    #0D5C63;
$aquamarine:      #78CDD7;
$dark-slate:      #1A2E35;
$soft-dark:       #3D4F58;
$light-teal-bg:   #F0F5F4;
$near-white:      #FAFBFB;
$code-bg:         #EEF2F3;

// ---- Bootstrap / Quarto Variable Overrides ----
$body-bg:         $near-white;
$body-color:      $soft-dark;
$link-color:      $phthalo-deep;
$primary:         $phthalo-deep;

$font-family-sans-serif: "Inter", "Source Sans Pro", -apple-system, sans-serif;
$headings-color:  $dark-slate;
$headings-font-weight: 600;

$navbar-bg:       $near-white;
$navbar-fg:       $dark-slate;
$footer-bg:       $light-teal-bg;
$footer-fg:       $soft-dark;

$code-block-bg:   $code-bg;

/*-- scss:rules --*/

// ---- Links ----
a {
  text-decoration: underline;
  text-underline-offset: 3px;
  text-decoration-color: rgba($phthalo-deep, 0.3);
  transition: text-decoration-color 0.2s;

  &:hover {
    text-decoration-color: $phthalo-deep;
  }
}

// ---- Headshot ----
img[src*="headshot"] {
  border-radius: 50%;
  max-width: 180px;
  margin: 0 auto;
  display: block;
  border: 3px solid $light-teal-bg;
}

// ---- Project cards ----
.card {
  border: 1px solid rgba($phthalo-deep, 0.1);
  border-radius: 8px;
  padding: 1.5rem;
  background: white;
  transition: box-shadow 0.2s;

  &:hover {
    box-shadow: 0 4px 12px rgba($phthalo-deep, 0.1);
  }
}

// ---- Navbar refinements ----
.navbar {
  border-bottom: 1px solid rgba($phthalo-deep, 0.08);
}

// ---- General spacing ----
h2, h3 {
  margin-top: 2rem;
}
```

### _quarto.yml Theme Configuration

```yaml
format:
  html:
    theme:
      light: [flatly, custom.scss]
    # Or for a fully custom theme (no Bootswatch base):
    # theme: custom.scss
```

Using `flatly` as a base gives sensible defaults. The `custom.scss` layered on top
overrides colors and adds the Phthalo Waters personality. Sean can also start from
`cosmo` or `litera` as alternative bases — `flatly` is clean and stays out of the way.

### Typography Suggestion

Consider importing a web font for headings. "Inter" is a strong choice for
scientific/technical sites. Add to `custom.scss`:

```scss
/*-- scss:defaults --*/
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
```

Or for a more distinctive look, "IBM Plex Sans" pairs well with technical/government work.

---

## Nice-to-Have (Lower Priority)

- [ ] Add a "Featured Project" callout on the homepage highlighting CompToxR or THREAT
- [ ] Consider adding a "Now" page (what you're currently working on / reading / thinking about)
- [ ] Add Open Graph meta tags for better social sharing previews
- [ ] Test mobile layout, especially projects page
- [ ] Add a 404.qmd custom error page
- [ ] Dark mode variant (Quarto supports light/dark toggle natively)

---

## File Structure Reference

Target structure after renovation:
```
seanthimons.github.io/
├── _quarto.yml              # Site config, theme, nav, footer
├── index.qmd                # Homepage (with particles partial)
├── blog.qmd                 # Blog listing page
├── projects.qmd             # Projects / Portfolio page
├── volunteer.qmd            # Volunteer page
├── custom.scss              # Phthalo Waters theme
├── title-block.html         # Particles.js partial (homepage)
├── particles.json           # Particles.js configuration
├── favicon.ico              # Favicon
├── images/
│   ├── headshot.jpg
│   └── threat-screenshot.png  # Add screenshot of THREAT app
└── posts/
    ├── 2025-11-11/
    ├── 2025-11-04/
    └── 1970-01-01/          # DELETE this folder
```

---

## Summary: Priority Order

1. **Critical fixes** — Dates, typos, broken listings (quick wins)
2. **Content rewrites** — First-person bio, work history narrative, project descriptions
3. **Theme + colors** — Create `custom.scss` with Phthalo Waters palette
4. **Particles.js** — Homepage hero section with animated network background
5. **Project cards** — Visual hierarchy on projects page
6. **Blog decision** — Commit or remove
7. **Polish** — Favicon, footer, Open Graph, mobile testing

Good luck with the renovation!
