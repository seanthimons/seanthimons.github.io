# External Integrations

**Analysis Date:** 2026-02-12

## APIs & External Services

**Content/References:**
- EPA CompTox Chemistry Dashboard - Referenced in projects listing (https://comptox.epa.gov/dashboard/)
  - Context: Tools developed by author for chemical properties and hazard data
  - No SDK integration - reference only

- EPA Cheminformatics Toolbox - Referenced in projects listing (https://www.epa.gov/comptox-tools/cheminformatics)
  - Context: Tools developed by author for chemical analysis
  - No SDK integration - reference only

- ECOTOX Knowledgebase - Referenced in projects listing (https://cfpub.epa.gov/ecotox/index.cfm)
  - Context: Tools enhanced by author for toxicological data
  - No SDK integration - reference only

**Social/Professional Networks:**
- GitHub API - Not directly integrated
  - Links in hero section: https://github.com/seanthimons
  - Project repositories referenced in projects.qmd
  - CI/CD pipeline uses GitHub Actions

- LinkedIn - Referenced in hero section
  - Social link: https://www.linkedin.com/in/seanthimons/

- ORCID - Referenced in hero section
  - Scholarly identifier: https://orcid.org/0000-0002-3736-2529

## Data Storage

**Databases:**
- None - Static site with no backend database

**File Storage:**
- GitHub repository - Primary storage
  - Repository: seanthimons/seanthimons.github.io
  - Source control for all .qmd, .scss, .html files
  - Frozen R output stored in `_freeze/` directory

- GitHub Pages - Static file hosting
  - Deployment target for rendered HTML
  - Files served from `docs/` directory

**Caching:**
- None - Static site generation with Quarto caching via `_freeze/` directory

## Authentication & Identity

**Auth Provider:**
- GitHub - Default authentication for repository access
  - OAuth used for repository management
  - No custom auth required for site visitors

**Author Identity:**
- ORCID: 0000-0002-3736-2529 - Scholarly identity
- Email: thimons.sean@gmail.com - Contact reference
- GitHub profile: seanthimons - Code identity

## Monitoring & Observability

**Error Tracking:**
- None detected

**Logs:**
- GitHub Actions build logs available in repository Actions tab
- Quarto render logs available locally during development

**Analytics:**
- None detected - no analytics integration or tracking

## CI/CD & Deployment

**Hosting:**
- GitHub Pages - Static site hosting
  - Published to: https://seanthimons.github.io/
  - Custom domain: None detected

**CI Pipeline:**
- GitHub Actions workflow: `.github/workflows/publish.yml`
  - Trigger: Push to master branch or manual workflow dispatch
  - Environment: ubuntu-latest
  - Steps:
    1. Checkout repository
    2. Setup Quarto via `quarto-dev/quarto-actions/setup@v2`
    3. Render site with `quarto render`
    4. Upload artifact to GitHub Pages
    5. Deploy to GitHub Pages environment

**Build Process:**
- Quarto renders all .qmd files to HTML
- Freezes enabled - uses pre-computed R output from `_freeze/` directory
- No R execution occurs during CI/CD build
- Output compiled to `docs/` directory
- Artifacts deployed to GitHub Pages

## Environment Configuration

**Required env vars:**
- None - Static site requires no environment variables

**Secrets location:**
- None stored - No external API keys or credentials needed
- GitHub GITHUB_TOKEN handled automatically by GitHub Actions

## Webhooks & Callbacks

**Incoming:**
- GitHub Actions webhook - Triggered on push to master branch
- Manual workflow dispatch available

**Outgoing:**
- None detected

## External JavaScript Dependencies

**CDN-loaded libraries:**
- particles.js 2.0.0
  - Source: https://cdnjs.cloudflare.com/ajax/libs/particles.js/2.0.0/particles.min.js
  - Configuration: `particles.json`
  - Loaded in: `title-block.html`
  - Purpose: Animated particle background effect on hero section

- Google Fonts (Inter)
  - Source: https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap
  - Imported in: `custom.scss`
  - Purpose: Custom font rendering

## Third-Party Content

**Bibliographic References:**
- BibTeX files: `ppp.bib`, `works.bib`
  - Local storage only
  - Referenced in projects.qmd for publication listings
  - Processed by Quarto during rendering

---

*Integration audit: 2026-02-12*
