# Technology Stack

**Analysis Date:** 2026-02-12

## Languages

**Primary:**
- Quarto Markdown (.qmd) - Content and page authoring
- SCSS - Styling and theme customization
- R - Statistical analysis in blog posts (markdown code blocks)
- HTML - Custom layout templates

**Secondary:**
- JSON - Configuration for particle effects
- JavaScript - Particle animation initialization
- YAML - Frontmatter for pages and configuration

## Runtime

**Environment:**
- Quarto (static site generator) - rendering engine
- R (via frozen/pre-computed execution) - statistical computing runtime

**Package Manager:**
- No package managers required for frontend (dependencies loaded via CDN)
- R packages referenced in .qmd files but pre-computed in `_freeze/` directory

## Frameworks

**Core:**
- Quarto 1.3+ - Static site generation with R support
  - Renders .qmd files to HTML
  - Manages site structure, navigation, and metadata

**Styling:**
- Bootstrap 5 (via Quarto theme system) - CSS framework
- Custom SCSS overrides - Theme customization

**Frontend Libraries:**
- particles.js 2.0.0 (from CDN) - Animated particle effects for hero section

**Build/Dev:**
- GitHub Actions (CI/CD) - Automated rendering and deployment
- Quarto CLI - Local development and rendering

## Key Dependencies

**Critical:**
- Quarto - Required for all site rendering and builds
- particles.js 2.0.0 - Animated background on hero section (loaded from CDN: https://cdnjs.cloudflare.com/ajax/libs/particles.js/2.0.0/particles.min.js)

**Infrastructure:**
- Bootstrap Icons (bi) - Icon library for social links (integrated via Quarto/Bootstrap)
- Google Fonts (Inter) - Custom font family imported from https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap
- flatly theme - Quarto Bootstrap theme base (light mode)

**External Resources:**
- GitHub (hosting) - Source repository at seanthimons/seanthimons.github.io
- GitHub Pages - Deployment target

## Configuration

**Environment:**
- Quarto configuration: `_quarto.yml`
- R project configuration: `seanthimons.github.io.Rproj`
- Custom styling: `custom.scss`
- Particle effects config: `particles.json`

**Build:**
- Quarto config file: `_quarto.yml`
  - Specifies project type: website
  - Output directory: docs/
  - Rendering freezes enabled (uses `_freeze/` for pre-computed R output)
  - Theme: flatly + custom.scss overrides

## Platform Requirements

**Development:**
- Quarto 1.3+ installed
- R runtime (optional - only needed if modifying .qmd files with executable code)
- Text editor or IDE (RStudio recommended for .qmd editing)

**Production:**
- Ubuntu Linux (GitHub Actions runner: ubuntu-latest)
- No server required - static HTML deployment to GitHub Pages

## Output Configuration

**Output:**
- Rendering target: `docs/` directory (committed to repository)
- Static HTML files served via GitHub Pages
- CSS consolidated into HTML or separate stylesheet

---

*Stack analysis: 2026-02-12*
