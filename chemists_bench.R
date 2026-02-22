# ============================================================================
# chemists_bench.R
# Manage "The Chemist's Bench" color palette
# ============================================================================

library(jsonlite)
library(glue)
library(cli)

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

#' Set these paths to match your site structure
PALETTE_JSON <- "chemists-bench-palette.json"
THEMES_JSON <- "chemists-bench-themes.json"
SWATCH_HTML <- "color-palette.html"

# ----------------------------------------------------------------------------
# Core Functions: Read/Write Palette
# ----------------------------------------------------------------------------

#' Load the palette from JSON
#' @return list containing all palette categories
load_palette <- function(path = PALETTE_JSON) {
  if (!file.exists(path)) {
    cli_abort("Palette file not found: {path}")
  }
  fromJSON(path, simplifyVector = FALSE)
}

#' Save the palette to JSON
#' @param palette list containing all palette categories
save_palette <- function(palette, path = PALETTE_JSON) {
  write_json(palette, path, pretty = TRUE, auto_unbox = TRUE)
  cli_alert_success("Saved palette to {.file {path}}")
}

# ----------------------------------------------------------------------------
# Add Colors
# ----------------------------------------------------------------------------

#' Add a new color to the palette
#' 
#' @param category Character. Which section: "core", "metallic_compounds", 
#'   "minerals", "flame_test", "spectral", "biological", "historical", 
#'   "fountain_pen_inks", "toxic_beautiful"
#' @param id Character. Snake_case identifier (e.g., "ruby_laser")
#' @param hex Character. Hex color code including # (e.g., "#E0115F")
#' @param name Character. Display name (e.g., "Ruby Laser")
#' @param description Character. The story/science behind the color
#' @param formula Character. Optional chemical formula or wavelength
#' @param source Character. Optional source citation
#' @param use Character vector. Optional suggested uses
#' @param wavelength_nm Numeric. Optional wavelength in nanometers
#' @param toxic Logical. Optional flag for toxic pigments
#' 
#' @examples
#' add_color(
#'   category = "spectral",
#'   id = "ruby_laser",
#'   hex = "#E0115F",
#'   name = "Ruby Laser",
#'   description = "First working laser (1960). Chromium-doped aluminum oxide.",
#'   formula = "694.3nm",
#'   wavelength_nm = 694.3,
#'   source = "Wikipedia: Ruby laser"
#' )
add_color <- function(
  category,
  id,
  hex,
  name,
  description,
  formula = NULL,
  source = NULL,
  use = NULL,
  wavelength_nm = NULL,
  toxic = NULL,
  path = PALETTE_JSON
) {
  # Validate hex

if (!grepl("^#[0-9A-Fa-f]{6}$", hex)) {
    cli_abort("Invalid hex color: {hex}. Must be format #RRGGBB")
  }
  

  # Load existing palette
  palette <- load_palette(path)
  
  # Check category exists
  valid_categories <- c(
    "core", "section_accents", "metallic_compounds", "minerals", 
    "flame_test", "spectral", "biological", "historical", 
    "fountain_pen_inks", "toxic_beautiful"
  )
  
  if (!category %in% valid_categories) {
    cli_abort(c(
      "Invalid category: {category}",
      "i" = "Valid categories: {.val {valid_categories}}"
    ))
  }
  
  # Check if id already exists
  if (id %in% names(palette[[category]])) {
    cli_warn("Color {.val {id}} already exists in {.val {category}}. Overwriting.")
  }
  
  # Convert hex to RGB
  rgb_vals <- as.integer(col2rgb(hex))
  
# Build the color entry
  color_entry <- list(
    hex = hex,
    rgb = rgb_vals,
    name = name,
    description = description
  )
  
  # Add optional fields
  if (!is.null(formula)) color_entry$formula <- formula
  if (!is.null(source)) color_entry$source <- source
  if (!is.null(use)) color_entry$use <- use
  if (!is.null(wavelength_nm)) color_entry$wavelength_nm <- wavelength_nm
  if (!is.null(toxic)) color_entry$toxic <- toxic
  
  # Add to palette
  palette[[category]][[id]] <- color_entry
  
  # Save
  save_palette(palette, path)
  
  cli_alert_success("Added {.val {name}} ({.val {hex}}) to {.val {category}}")
  
  # Show a preview
  preview_color(hex, name)
  
  invisible(color_entry)
}

#' Add multiple colors at once from a data frame
#' 
#' @param colors_df Data frame with columns: category, id, hex, name, description
#'   Optional columns: formula, source, use, wavelength_nm, toxic
#' 
#' @examples
#' new_colors <- data.frame(
#'   category = c("spectral", "spectral"),
#'   id = c("ruby_laser", "co2_laser"),
#'   hex = c("#E0115F", "#8B0000"),
#'   name = c("Ruby Laser", "CO2 Laser"),
#'   description = c("First working laser", "Industrial cutting laser")
#' )
#' add_colors_bulk(new_colors)
add_colors_bulk <- function(colors_df, path = PALETTE_JSON) {
  cli_progress_bar("Adding colors", total = nrow(colors_df))
  
  for (i in seq_len(nrow(colors_df))) {
    row <- colors_df[i, ]
    
    add_color(
      category = row$category,
      id = row$id,
      hex = row$hex,
      name = row$name,
      description = row$description,
      formula = row$formula %||% NULL,
      source = row$source %||% NULL,
      wavelength_nm = row$wavelength_nm %||% NULL,
      toxic = row$toxic %||% NULL,
      path = path
    )
    
    cli_progress_update()
  }
  
  cli_progress_done()
  cli_alert_success("Added {nrow(colors_df)} colors")
}

# ----------------------------------------------------------------------------
# Remove/Update Colors
# ----------------------------------------------------------------------------
#' Remove a color from the palette
#' 
#' @param category Character. The category containing the color
#' @param id Character. The color's identifier
remove_color <- function(category, id, path = PALETTE_JSON) {
  palette <- load_palette(path)
  
  if (!id %in% names(palette[[category]])) {
    cli_abort("Color {.val {id}} not found in {.val {category}}")
  }
  
  color_name <- palette[[category]][[id]]$name
  palette[[category]][[id]] <- NULL
  
  save_palette(palette, path)
  cli_alert_success("Removed {.val {color_name}} from {.val {category}}")
}

#' Update an existing color
#' 
#' @param category Character. The category containing the color
#' @param id Character. The color's identifier
#' @param ... Named arguments to update (hex, name, description, etc.)
update_color <- function(category, id, ..., path = PALETTE_JSON) {
  palette <- load_palette(path)
  
  if (!id %in% names(palette[[category]])) {
    cli_abort("Color {.val {id}} not found in {.val {category}}")
  }
  
  updates <- list(...)
  
  for (field in names(updates)) {
    palette[[category]][[id]][[field]] <- updates[[field]]
    
    # Recalculate RGB if hex changed
    if (field == "hex") {
      palette[[category]][[id]]$rgb <- as.integer(col2rgb(updates[[field]]))
    }
  }
  
  save_palette(palette, path)
  cli_alert_success("Updated {.val {id}} in {.val {category}}")
}

# ----------------------------------------------------------------------------
# Query/Browse Colors
# ----------------------------------------------------------------------------

#' List all colors in a category
#' 
#' @param category Character. The category to list
#' @return Data frame of colors
list_colors <- function(category = NULL, path = PALETTE_JSON) {
  palette <- load_palette(path)
  
  if (is.null(category)) {
    # List all categories
    categories <- setdiff(names(palette), c("meta", "utilities", "semantic", "gradients"))
    
    cli_h1("Palette Categories")
    for (cat in categories) {
      n <- length(palette[[cat]])
      cli_li("{.val {cat}}: {n} colors")
    }
    
    return(invisible(categories))
  }
  
  # List colors in specific category
  colors <- palette[[category]]
  
  if (is.null(colors)) {
    cli_abort("Category {.val {category}} not found")
  }
  
  # Filter out _comment fields and non-list entries
  color_ids <- names(colors)
  color_ids <- color_ids[!grepl("^_", color_ids)]
  colors <- colors[color_ids]
  colors <- Filter(function(c) is.list(c) && !is.null(c$hex), colors)
  
  # Build data frame
  df <- do.call(rbind, lapply(names(colors), function(id) {
    c <- colors[[id]]
    data.frame(
      id = id,
      hex = c$hex,
      name = c$name,
      description = substr(c$description, 1, 50),
      stringsAsFactors = FALSE
    )
  }))
  
  cli_h2("{category}")
  print(df, row.names = FALSE)
  
  invisible(df)
}

#' Search colors by name or description
#' 
#' @param query Character. Search term (case-insensitive)
#' @return Data frame of matching colors
search_colors <- function(query, path = PALETTE_JSON) {
  palette <- load_palette(path)
  
  results <- list()
  
  categories <- setdiff(names(palette), c("meta", "utilities", "semantic", "gradients"))
  
  for (cat in categories) {
    color_ids <- names(palette[[cat]])
    color_ids <- color_ids[!grepl("^_", color_ids)]
    
    for (id in color_ids) {
      c <- palette[[cat]][[id]]
      
      # Skip non-list entries
      if (!is.list(c) || is.null(c$hex)) next
      
      # Search in name and description
      if (grepl(query, c$name, ignore.case = TRUE) ||
          grepl(query, c$description, ignore.case = TRUE) ||
          grepl(query, c$formula %||% "", ignore.case = TRUE)) {
        results[[length(results) + 1]] <- list(
          category = cat,
          id = id,
          hex = c$hex,
          name = c$name
        )
      }
    }
  }
  
  if (length(results) == 0) {
    cli_alert_warning("No colors found matching {.val {query}}")
    return(invisible(NULL))
  }
  
  df <- do.call(rbind, lapply(results, as.data.frame, stringsAsFactors = FALSE))
  
  cli_h2("Search results for '{query}'")
  print(df, row.names = FALSE)
  
  invisible(df)
}

# ----------------------------------------------------------------------------
# Preview Colors
# ----------------------------------------------------------------------------

#' Preview a color in the console (with ANSI colors if supported)
#' 
#' @param hex Character. Hex color code
#' @param name Character. Optional name to display
preview_color <- function(hex, name = NULL) {
  # Convert hex to RGB for ANSI
  rgb_vals <- col2rgb(hex)
  r <- rgb_vals[1]
  g <- rgb_vals[2]
  b <- rgb_vals[3]
  
  # ANSI true color escape sequence
  block <- paste0("\033[48;2;", r, ";", g, ";", b, "m    \033[0m")
  
  if (!is.null(name)) {
    cat(block, " ", name, " (", hex, ")\n", sep = "")
  } else {
    cat(block, " ", hex, "\n", sep = "")
  }
}

#' Preview all colors in a category
#' 
#' @param category Character. The category to preview
preview_category <- function(category, path = PALETTE_JSON) {
  palette <- load_palette(path)
  colors <- palette[[category]]
  
  if (is.null(colors)) {
    cli_abort("Category {.val {category}} not found")
  }
  
  cli_h2(category)
  
  color_ids <- names(colors)
  color_ids <- color_ids[!grepl("^_", color_ids)]
  
  for (id in color_ids) {
    c <- colors[[id]]
    if (!is.list(c) || is.null(c$hex)) next
    preview_color(c$hex, c$name)
  }
}

# ----------------------------------------------------------------------------
# Generate HTML Swatch Page
# ----------------------------------------------------------------------------

#' Generate the HTML swatch page from the palette JSON
#' 
#' @param palette_path Path to the palette JSON
#' @param output_path Path to write the HTML file
#' @param site_title Your site name for nav
#' @param nav_links Named list of nav links (name = url)
generate_swatch_html <- function(
  palette_path = PALETTE_JSON,
  output_path = SWATCH_HTML,
  site_title = "Sean Thimons",
  nav_links = list(Home = "index.html", Work = "work.html", Blog = "blog.html")
) {
  palette <- load_palette(palette_path)
  
  # Category display config
  category_config <- list(
    core = list(emoji = "🌊", title = "Core Phthalo Waters", 
                desc = "The site's primary palette — phthalocyanine pigments and aquatic tones"),
    section_accents = list(emoji = "🎨", title = "Section Accents",
                           desc = "Distinct colors for different site sections"),
    metallic_compounds = list(emoji = "⚗️", title = "Metallic Compounds",
                              desc = "Colors from copper, iron, cobalt, and other transition metals"),
    minerals = list(emoji = "💎", title = "Minerals & Ores",
                    desc = "Natural mineral pigments — iron oxides, clays, and crystalline structures"),
    flame_test = list(emoji = "🔥", title = "Flame Test Colors",
                      desc = "Element identification via atomic emission — from Bunsen burner to fireworks"),
    spectral = list(emoji = "💡", title = "Spectral Emissions",
                    desc = "Laser lines, hydrogen series, and laboratory light sources"),
    biological = list(emoji = "🌿", title = "Biological Pigments",
                      desc = "Living color — photosynthesis, blood, autumn leaves"),
    historical = list(emoji = "📜", title = "Historical Pigments",
                      desc = "From cave paintings to Renaissance masters — pigments with stories"),
    fountain_pen_inks = list(emoji = "🖋️", title = "Fountain Pen Inks",
                             desc = "Classic formulations and iron gall chemistry"),
    toxic_beautiful = list(emoji = "☠️", title = "Beautiful & Deadly",
                           desc = "Gorgeous colors with murderous histories — arsenic, lead, and mercury")
  )
  
  # Helper to determine text color based on background brightness
  get_text_color <- function(hex) {
    rgb <- col2rgb(hex)
    # Perceived brightness formula
    brightness <- (rgb[1] * 299 + rgb[2] * 587 + rgb[3] * 114) / 1000
    if (brightness > 128) "#1a1a2e" else "white"
  }
  
  # Generate swatch HTML for a single color
  make_swatch <- function(color) {
    text_col <- get_text_color(color$hex)
    
    formula_html <- if (!is.null(color$formula)) {
      glue('<div class="swatch-formula">{color$formula}</div>')
    } else ""
    
    source_html <- if (!is.null(color$source)) {
      glue('<div class="swatch-source">{color$source}</div>')
    } else ""
    
    glue('
        <div class="swatch" onclick="copyColor(\'{color$hex}\')">
          <div class="swatch-color" style="background: {color$hex}; color: {text_col};">Aa</div>
          <div class="swatch-info">
            <div class="swatch-name">{color$name}</div>
            <div class="swatch-hex">{color$hex}</div>
            {formula_html}
            <div class="swatch-desc">{color$description}</div>
            {source_html}
          </div>
        </div>')
  }
  
  # Generate section HTML
  make_section <- function(category_id) {
    config <- category_config[[category_id]]
    colors <- palette[[category_id]]
    
    if (is.null(colors) || length(colors) == 0) return("")
    
    # Filter out _comment fields and non-list entries
    color_ids <- names(colors)
    color_ids <- color_ids[!grepl("^_", color_ids)]  # Skip _comment, _meta, etc.
    colors <- colors[color_ids]
    
    # Filter to only actual color objects (lists with hex field)
    colors <- Filter(function(c) is.list(c) && !is.null(c$hex), colors)
    
    if (length(colors) == 0) return("")
    
    swatches <- paste(sapply(colors, make_swatch), collapse = "\n        ")
    
    glue('
    <!-- {toupper(config$title)} -->
    <div class="palette-section" id="{category_id}">
      <h2 class="section-title">{config$emoji} {config$title}</h2>
      <p class="section-desc">{config$desc}</p>
      <div class="swatches">
        {swatches}
      </div>
    </div>
')
  }
  
  # Generate TOC
  toc_links <- paste(sapply(names(category_config), function(cat_id) {
    config <- category_config[[cat_id]]
    if (is.null(palette[[cat_id]]) || length(palette[[cat_id]]) == 0) return("")
    glue('<a href="#{cat_id}">{config$emoji} {config$title}</a>')
  }), collapse = "\n        ")
  
  # Generate nav links
  nav_html <- paste(sapply(names(nav_links), function(name) {
    glue('<a href="{nav_links[[name]]}">{name}</a>')
  }), collapse = "\n      ")
  
  # Generate all sections
  sections_html <- paste(sapply(names(category_config), make_section), collapse = "\n")
  
  # Full HTML template
  html <- glue('<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>The Chemist\'s Bench - Color Palette | {site_title}</title>
  <meta name="description" content="A scientifically meaningful color palette derived from pigment chemistry, spectral emissions, minerals, and biological compounds.">
  <meta name="author" content="{site_title}">
  <link rel="icon" type="image/svg+xml" href="favicon.svg">
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
    * {{ margin: 0; padding: 0; box-sizing: border-box; }}
    
    body {{
      font-family: \'Inter\', -apple-system, sans-serif;
      background: linear-gradient(135deg, #0a0a1a 0%, #1a1a2e 50%, #0d1117 100%);
      color: #eee;
      min-height: 100vh;
    }}
    
    .site-nav {{
      background: rgba(13, 92, 99, 0.95);
      padding: 1rem 2rem;
      display: flex;
      justify-content: space-between;
      align-items: center;
      position: sticky;
      top: 0;
      z-index: 100;
      backdrop-filter: blur(10px);
    }}
    
    .site-nav a {{
      color: #fff;
      text-decoration: none;
      font-weight: 500;
      transition: color 0.2s;
    }}
    
    .site-nav a:hover {{ color: #78CDD7; }}
    
    .nav-links {{
      display: flex;
      gap: 2rem;
    }}
    
    .nav-links a {{ font-size: 0.9rem; }}
    .site-title {{ font-size: 1.1rem; font-weight: 600; }}
    
    main {{
      padding: 2rem;
      max-width: 1400px;
      margin: 0 auto;
    }}
    
    h1 {{
      text-align: center;
      font-size: 2.8rem;
      margin-bottom: 0.5rem;
      background: linear-gradient(135deg, #78CDD7, #D4AF37, #E34234);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
    }}
    
    .subtitle {{
      text-align: center;
      color: #888;
      margin-bottom: 1rem;
      font-size: 1.1rem;
    }}
    
    .research-note {{
      text-align: center;
      color: #666;
      font-size: 0.85rem;
      margin-bottom: 2rem;
      font-style: italic;
    }}
    
    .download-bar {{
      display: flex;
      justify-content: center;
      gap: 1rem;
      margin-bottom: 3rem;
      flex-wrap: wrap;
    }}
    
    .download-btn {{
      background: #0D5C63;
      color: white;
      padding: 0.6rem 1.2rem;
      border-radius: 6px;
      text-decoration: none;
      font-size: 0.85rem;
      font-weight: 500;
      transition: background 0.2s, transform 0.2s;
      display: inline-flex;
      align-items: center;
      gap: 0.5rem;
    }}
    
    .download-btn:hover {{
      background: #43B3AE;
      transform: translateY(-2px);
    }}
    
    .palette-section {{ margin-bottom: 3rem; }}
    
    .section-title {{
      font-size: 1.4rem;
      font-weight: 600;
      margin-bottom: 1rem;
      padding-bottom: 0.5rem;
      border-bottom: 2px solid #333;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }}
    
    .section-desc {{
      color: #888;
      font-size: 0.9rem;
      margin-bottom: 1rem;
      margin-top: -0.5rem;
    }}
    
    .swatches {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
      gap: 1rem;
    }}
    
    .swatch {{
      border-radius: 12px;
      overflow: hidden;
      background: #252540;
      transition: transform 0.2s, box-shadow 0.2s;
      cursor: pointer;
    }}
    
    .swatch:hover {{
      transform: translateY(-4px);
      box-shadow: 0 8px 24px rgba(0,0,0,0.4);
    }}
    
    .swatch-color {{
      height: 90px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 600;
      font-size: 0.9rem;
      text-shadow: 0 1px 3px rgba(0,0,0,0.4);
    }}
    
    .swatch-info {{ padding: 0.9rem; }}
    .swatch-name {{ font-weight: 600; font-size: 0.95rem; margin-bottom: 0.2rem; }}
    .swatch-hex {{ font-family: \'JetBrains Mono\', monospace; font-size: 0.8rem; color: #78CDD7; margin-bottom: 0.4rem; }}
    .swatch-formula {{ font-family: \'JetBrains Mono\', monospace; font-size: 0.7rem; color: #D4AF37; margin-bottom: 0.4rem; }}
    .swatch-desc {{ font-size: 0.75rem; color: #999; line-height: 1.4; }}
    .swatch-source {{ font-size: 0.65rem; color: #666; margin-top: 0.3rem; font-style: italic; }}
    
    .copied-toast {{
      position: fixed;
      bottom: 2rem;
      left: 50%;
      transform: translateX(-50%) translateY(100px);
      background: #0D5C63;
      color: white;
      padding: 1rem 2rem;
      border-radius: 8px;
      font-weight: 500;
      opacity: 0;
      transition: all 0.3s;
      z-index: 1000;
    }}
    
    .copied-toast.show {{
      transform: translateX(-50%) translateY(0);
      opacity: 1;
    }}
    
    .toc {{
      background: rgba(26, 26, 46, 0.8);
      border-radius: 12px;
      padding: 1.5rem;
      margin-bottom: 3rem;
      border: 1px solid #333;
    }}
    
    .toc h3 {{ margin-bottom: 1rem; color: #78CDD7; }}
    
    .toc-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
      gap: 0.5rem;
    }}
    
    .toc a {{
      color: #ccc;
      text-decoration: none;
      font-size: 0.9rem;
      padding: 0.3rem 0.5rem;
      border-radius: 4px;
      transition: background 0.2s;
    }}
    
    .toc a:hover {{ background: #333; color: #fff; }}
    
    .site-footer {{
      text-align: center;
      padding: 2rem;
      color: #666;
      font-size: 0.85rem;
      border-top: 1px solid #333;
      margin-top: 3rem;
    }}
    
    .site-footer a {{ color: #78CDD7; text-decoration: none; }}
    
    @media (max-width: 768px) {{
      .nav-links {{ gap: 1rem; font-size: 0.8rem; }}
      h1 {{ font-size: 2rem; }}
      .swatches {{ grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); }}
      .download-bar {{ flex-direction: column; align-items: center; }}
    }}
  </style>
</head>
<body>
  <nav class="site-nav">
    <a href="index.html" class="site-title">{site_title}</a>
    <div class="nav-links">
      {nav_html}
    </div>
  </nav>

  <main>
    <h1>🧪 The Chemist\'s Bench</h1>
    <p class="subtitle">An Expanded Scientific Color Palette</p>
    <p class="research-note">Researched via Wikipedia rabbit holes • Click any swatch to copy hex code</p>
    
    <div class="download-bar">
      <a href="chemists-bench-themes.json" download class="download-btn">📥 Download Themes JSON</a>
      <a href="chemists-bench-palette.json" download class="download-btn">📥 Download Full Palette JSON</a>
    </div>
    
    <nav class="toc">
      <h3>📑 Categories</h3>
      <div class="toc-grid">
        {toc_links}
      </div>
    </nav>

{sections_html}
  </main>

  <footer class="site-footer">
    <p>© {format(Sys.Date(), "%Y")} {site_title} · Built with Quarto · <a href="index.html">Back to Home</a></p>
    <p style="margin-top: 0.5rem;">Colors researched via Wikipedia rabbit holes on pigment chemistry, spectral emissions, and historical dyes.</p>
  </footer>

  <div class="copied-toast" id="toast">Copied!</div>
  
  <script>
    function copyColor(hex) {{
      navigator.clipboard.writeText(hex).then(() => {{
        const toast = document.getElementById(\'toast\');
        toast.textContent = `Copied ${{hex}}`;
        toast.classList.add(\'show\');
        setTimeout(() => toast.classList.remove(\'show\'), 1500);
      }});
    }}
  </script>
</body>
</html>')
  
  writeLines(html, output_path)
  cli_alert_success("Generated swatch page: {.file {output_path}}")
}

# ----------------------------------------------------------------------------
# Convenience: Add + Regenerate
# ----------------------------------------------------------------------------

#' Add a color and regenerate the HTML in one step
#' 
#' @inheritParams add_color
#' @param regenerate Logical. Whether to regenerate the HTML after adding
add_and_regenerate <- function(
  category,
  id,
  hex,
  name,
  description,
  formula = NULL,
  source = NULL,
  use = NULL,
  wavelength_nm = NULL,
  toxic = NULL,
  regenerate = TRUE
) {
  add_color(
    category = category,
    id = id,
    hex = hex,
    name = name,
    description = description,
    formula = formula,
    source = source,
    use = use,
    wavelength_nm = wavelength_nm,
    toxic = toxic
  )
  
  if (regenerate) {
    generate_swatch_html()
  }
}

# ----------------------------------------------------------------------------
# Export for Use in Other Scripts
# ----------------------------------------------------------------------------

#' Get a color's hex value by category and id
#' 
#' @param category Character. The category
#' @param id Character. The color id
#' @return Character. The hex value
get_hex <- function(category, id, path = PALETTE_JSON) {
  palette <- load_palette(path)
  palette[[category]][[id]]$hex
}

#' Get all hex values as a named vector
#' 
#' @param category Character. The category (or NULL for all)
#' @return Named character vector of hex values
get_all_hex <- function(category = NULL, path = PALETTE_JSON) {
  palette <- load_palette(path)
  
  if (!is.null(category)) {
    colors <- palette[[category]]
    hexes <- sapply(colors, function(c) c$hex)
    names(hexes) <- sapply(colors, function(c) c$name)
    return(hexes)
  }
  
  # All categories
  all_hexes <- c()
  categories <- setdiff(names(palette), c("meta", "utilities", "semantic", "gradients"))
  
  for (cat in categories) {
    colors <- palette[[cat]]
    color_ids <- names(colors)
    color_ids <- color_ids[!grepl("^_", color_ids)]
    colors <- colors[color_ids]
    colors <- Filter(function(c) is.list(c) && !is.null(c$hex), colors)
    
    if (length(colors) == 0) next
    
    hexes <- sapply(colors, function(c) c$hex)
    names(hexes) <- sapply(colors, function(c) c$name)
    all_hexes <- c(all_hexes, hexes)
  }
  
  all_hexes
}

# ============================================================================
# Theme Management: Load, Validate, Generate CSS
# ============================================================================

# ----------------------------------------------------------------------------
# Color Utility Helpers
# ----------------------------------------------------------------------------

#' Parse a hex color to its RGB components (0-255)
#' @param hex Character. Hex color code (e.g., "#1a1a1a")
#' @return Named numeric vector with r, g, b
hex_to_rgb <- function(hex) {
  rgb_matrix <- col2rgb(hex)
  c(r = rgb_matrix[1, 1], g = rgb_matrix[2, 1], b = rgb_matrix[3, 1])
}

#' Compute relative luminance per WCAG 2.1 spec
#' @param hex Character. Hex color code
#' @return Numeric. Relative luminance (0 = black, 1 = white)
relative_luminance <- function(hex) {
  rgb <- hex_to_rgb(hex) / 255
  # sRGB linearization
  lin <- ifelse(rgb <= 0.03928, rgb / 12.92, ((rgb + 0.055) / 1.055)^2.4)
  0.2126 * lin["r"] + 0.7152 * lin["g"] + 0.0722 * lin["b"]
}

#' Compute WCAG contrast ratio between two colors
#' @param hex1 Character. Foreground hex
#' @param hex2 Character. Background hex
#' @return Numeric. Contrast ratio (1:1 to 21:1)
contrast_ratio <- function(hex1, hex2) {
  l1 <- relative_luminance(hex1)
  l2 <- relative_luminance(hex2)
  lighter <- max(l1, l2)
  darker  <- min(l1, l2)
  (lighter + 0.05) / (darker + 0.05)
}

#' Check if a theme is "dark" based on its background luminance
#' @param bg_hex Character. Background hex color
#' @return Logical
is_dark_theme <- function(bg_hex) {
  relative_luminance(bg_hex) < 0.2
}

# ----------------------------------------------------------------------------
# Theme Loading & Structure
# ----------------------------------------------------------------------------

#' Load themes from the themes JSON
#' @param path Path to themes JSON file
#' @return List of theme objects
load_themes <- function(path = THEMES_JSON) {
  if (!file.exists(path)) {
    cli_abort("Themes file not found: {path}")
  }
  fromJSON(path, simplifyVector = FALSE)
}

#' Get a single theme by name
#' @param theme_name Character. Snake_case theme id (e.g., "toxic_victorian")
#' @param path Path to themes JSON file
#' @return List containing the theme's properties
get_theme <- function(theme_name, path = THEMES_JSON) {
  themes <- load_themes(path)
  theme <- themes$themes[[theme_name]]
  if (is.null(theme)) {
    available <- paste(names(themes$themes), collapse = ", ")
    cli_abort(c(
      "Theme {.val {theme_name}} not found.",
      "i" = "Available themes: {available}"
    ))
  }
  theme
}

#' List all available themes with their mood and dark/light classification
#' @param path Path to themes JSON file
list_themes <- function(path = THEMES_JSON) {
  themes <- load_themes(path)

  cli_h2("Available Themes")

  for (name in names(themes$themes)) {
    t <- themes$themes[[name]]
    bg <- t$colors$background %||% "#ffffff"
    dark_label <- if (is_dark_theme(bg)) " [DARK]" else " [LIGHT]"
    has_heading <- if (!is.null(t$colors$heading)) "\u2713" else "\u2717"
    cli_li("{.val {name}}: {t$mood}{dark_label} (heading: {has_heading})")
  }
}

# ----------------------------------------------------------------------------
# Theme Validation & Contrast Auditing
# ----------------------------------------------------------------------------

#' Audit a theme's color contrast for WCAG compliance
#'
#' Checks text, heading, link, and muted text against the background color.
#' Reports WCAG AA (4.5:1 for normal text, 3:1 for large text/headings) and
#' AAA (7:1) compliance. Returns issues invisibly so you can programmatically
#' act on failures.
#'
#' @param theme_name Character. The theme to audit
#' @param path Path to themes JSON file
#' @return Invisible list of contrast issues
audit_theme_contrast <- function(theme_name, path = THEMES_JSON) {
  theme <- get_theme(theme_name, path)
  colors <- theme$colors
  bg <- colors$background

  cli_h2("Contrast Audit: {theme$name}")
  cli_alert_info("Background: {bg} (luminance: {round(relative_luminance(bg), 3)})")

  # Pairs to check: list(label, foreground_key, min_ratio_for_AA)
  # Headings get 3:1 (large text), body text gets 4.5:1
  pairs <- list(
    list("heading",   colors$heading    %||% colors$text, 3.0),
    list("text",      colors$text,                         4.5),
    list("text_muted", colors$text_muted,                  4.5),
    list("link",      colors$link,                         4.5),
    list("link_hover", colors$link_hover,                  3.0),
    list("code_text vs code_bg", colors$code_text,         4.5,
         colors$code_bg)
  )

  issues <- list()

  for (p in pairs) {
    label <- p[[1]]
    fg    <- p[[2]]
    min_aa <- p[[3]]
    check_bg <- if (length(p) >= 4) p[[4]] else bg

    if (is.null(fg) || is.null(check_bg)) next

    ratio <- contrast_ratio(fg, check_bg)
    pass_aa  <- ratio >= min_aa
    pass_aaa <- ratio >= 7.0

    status <- if (pass_aaa) {
      "AAA"
    } else if (pass_aa) {
      "AA"
    } else {
      "FAIL"
    }

    icon <- switch(status,
      "AAA"  = cli::col_green("\u2713\u2713"),
      "AA"   = cli::col_yellow("\u2713"),
      "FAIL" = cli::col_red("\u2717")
    )

    cli_li("{icon} {label}: {fg} on {check_bg} = {round(ratio, 2)}:1 [{status}]")

    if (!pass_aa) {
      issues[[length(issues) + 1]] <- list(
        label = label, fg = fg, bg = check_bg,
        ratio = ratio, required = min_aa
      )
    }
  }

  if (length(issues) == 0) {
    cli_alert_success("All pairs pass WCAG AA!")
  } else {
    cli_alert_danger("{length(issues)} pair(s) fail WCAG AA minimum contrast.")
  }

  invisible(issues)
}

#' Audit every theme for contrast issues
#' @param path Path to themes JSON file
audit_all_themes <- function(path = THEMES_JSON) {
  themes <- load_themes(path)
  all_issues <- list()

  for (name in names(themes$themes)) {
    issues <- audit_theme_contrast(name, path)
    if (length(issues) > 0) {
      all_issues[[name]] <- issues
    }
  }

  cli_h1("Summary")
  n_total <- length(names(themes$themes))
  n_pass  <- n_total - length(all_issues)
  cli_alert_info("{n_pass}/{n_total} themes pass all WCAG AA checks.")

  if (length(all_issues) > 0) {
    cli_alert_warning("Themes with issues: {paste(names(all_issues), collapse = ', ')}")
  }

  invisible(all_issues)
}

# ----------------------------------------------------------------------------
# CSS Generation for Quarto Blog Posts
# ----------------------------------------------------------------------------

#' Generate CSS custom properties for a theme
#'
#' Produces a `<style>` block that scopes the theme to the article content
#' area so the local theme wins over the global site SCSS without needing
#' `!important` everywhere.
#'
#' The selector strategy for coexisting with the global theme:
#'
#'   - CSS custom properties are declared on `#quarto-document-content`
#'     (Quarto's `<main class="content">` element), not on `:root` or `body`.
#'   - Applied styles use `#quarto-document-content` as a parent selector,
#'     which is more specific than the global SCSS's bare `h1`, `a`, etc.
#'   - For dark themes, the background is applied to `#quarto-content` (the
#'     wider container that includes the sidebar/margin area) so there's no
#'     jarring white gap, but the navbar/footer remain untouched.
#'   - Headings are explicitly set to `var(--cb-heading)` so the global
#'     `$headings-color: #1A2E35` (dark slate, invisible on dark bgs) never
#'     wins the cascade.
#'
#' @param theme_name Character. Theme id
#' @param path Path to themes JSON
#' @return Character. A complete `<style>` block string
generate_theme_css <- function(theme_name, path = THEMES_JSON) {
  theme <- get_theme(theme_name, path)
  colors <- theme$colors

  # Resolve heading: explicit > text > safe fallback
  heading <- colors$heading %||% colors$text
  dark <- is_dark_theme(colors$background)

  # Safety check: if heading is too low contrast against bg, override
  if (!is.null(heading) && !is.null(colors$background)) {
    ratio <- contrast_ratio(heading, colors$background)
    if (ratio < 3.0) {
      cli_warn(c(
        "Heading color {heading} has only {round(ratio, 2)}:1 contrast on {colors$background}.",
        "i" = "Falling back to theme text color: {colors$text}"
      ))
      heading <- colors$text
    }
  }

  # The scoping selector — Quarto's <main> for the article body
  sc <- "#quarto-document-content"

  # For dark themes, we need to also paint the wider content container
  # and handle the title block which lives outside <main>
  dark_extras <- if (dark) {
    glue('
  /* Dark theme: extend background to full content area */
  #quarto-content {{
    background-color: {colors$background};
  }}

  /* Title block sits outside <main>, needs explicit styling */
  .quarto-title-block {{
    color: var(--cb-text);
  }}
  .quarto-title-block .quarto-title {{
    color: var(--cb-heading) !important;
  }}
  .quarto-title-block .description {{
    color: var(--cb-text-muted);
  }}
  .quarto-title-meta-heading,
  .quarto-title-meta-contents {{
    color: var(--cb-text-muted);
  }}
  .quarto-title-meta-contents a {{
    color: var(--cb-link);
  }}

  /* Sidebar / margin note area for dark themes */
  #quarto-margin-sidebar {{
    color: var(--cb-text-muted);
  }}
  #quarto-margin-sidebar a {{
    color: var(--cb-link);
  }}')
  } else {
    # Light themes: just style the title block accent
    glue('
  .quarto-title-block {{
    border-top: 4px solid var(--cb-primary);
    padding-top: 0.5rem;
  }}
  .quarto-title-block .quarto-title {{
    color: var(--cb-heading);
  }}
  .quarto-title-block .description {{
    color: var(--cb-text-muted);
  }}')
  }

  glue('
<style>
  /* Chemist\'s Bench: {theme$name} */
  /* {theme$mood} */
  /* Generated by chemists_bench.R — do not hand-edit */

  /* --- CSS Custom Properties (scoped to article) --- */
  {sc} {{
    --cb-primary:     {colors$primary};
    --cb-secondary:   {colors$secondary};
    --cb-accent:      {colors$accent};
    --cb-background:  {colors$background};
    --cb-surface:     {colors$surface};
    --cb-text:        {colors$text};
    --cb-text-muted:  {colors$text_muted};
    --cb-heading:     {heading};
    --cb-link:        {colors$link};
    --cb-link-hover:  {colors$link_hover};
    --cb-code-bg:     {colors$code_bg};
    --cb-code-text:   {colors$code_text};
    --cb-border:      {colors$border};
    --cb-success:     {colors$success};
    --cb-warning:     {colors$warning};
    --cb-error:       {colors$error};
    --cb-gradient:    {theme$gradient};
  }}

  /* --- Article body: background + text --- */
  {sc} {{
    background-color: var(--cb-background);
    color: var(--cb-text);
  }}

  /* --- Headings: MUST override global $headings-color --- */
  {sc} h1,
  {sc} h2,
  {sc} h3,
  {sc} h4,
  {sc} h5,
  {sc} h6 {{
    color: var(--cb-heading);
  }}

  /* --- Links --- */
  {sc} a {{
    color: var(--cb-link);
  }}
  {sc} a:hover {{
    color: var(--cb-link-hover);
  }}

  /* --- Muted text --- */
  {sc} .text-muted,
  {sc} .subtitle,
  {sc} figcaption {{
    color: var(--cb-text-muted);
  }}

  /* --- Code blocks --- */
  {sc} pre,
  {sc} div.sourceCode {{
    background-color: var(--cb-code-bg);
    border: 1px solid var(--cb-border);
  }}
  {sc} code {{
    color: var(--cb-code-text);
  }}
  {sc} pre > code.sourceCode {{
    background-color: transparent;
  }}

  /* --- Callouts --- */
  {sc} .callout {{
    border-left-color: var(--cb-accent);
    background-color: var(--cb-surface);
    color: var(--cb-text);
  }}

  /* --- Blockquotes --- */
  {sc} blockquote {{
    border-left-color: var(--cb-accent);
    color: var(--cb-text-muted);
  }}

  /* --- Tables --- */
  {sc} table {{
    border-color: var(--cb-border);
  }}
  {sc} th {{
    background-color: var(--cb-surface);
    color: var(--cb-heading);
    border-color: var(--cb-border);
  }}
  {sc} td {{
    border-color: var(--cb-border);
  }}

  /* --- Horizontal rules --- */
  {sc} hr {{
    border-color: var(--cb-border);
  }}

  /* --- Title block + dark/light extras --- */
  {dark_extras}
</style>')
}

#' Generate a YAML-compatible include-in-header string for a Quarto post
#'
#' Use this in your autoblog workflow to inject the theme CSS into the post's
#' YAML front matter via `include-in-header`.
#'
#' @param theme_name Character. Theme id
#' @param output_path Character. Where to write the CSS file. If NULL, returns
#'   the CSS string without writing.
#' @param path Path to themes JSON
#' @return Character. Path to the written file, or the CSS string
generate_theme_include <- function(
  theme_name,
  output_path = NULL,
  path = THEMES_JSON
) {
  css <- generate_theme_css(theme_name, path = path)

  if (is.null(output_path)) return(css)

  writeLines(css, output_path)
  cli_alert_success("Wrote theme CSS to {.file {output_path}}")
  invisible(output_path)
}

#' Generate a raw HTML block for inline use in a .qmd template
#'
#' Returns the theme CSS wrapped in Quarto's ```` ```{=html} ```` fenced block
#' so it can be pasted directly into a .qmd file. This is the preferred
#' approach for the autoblog skill since it keeps everything in one file.
#'
#' @param theme_name Character. Theme id
#' @param path Path to themes JSON
#' @return Character. A ```` ```{=html} ```` block containing the `<style>` tag
generate_theme_qmd_block <- function(theme_name, path = THEMES_JSON) {
  css <- generate_theme_css(theme_name, path = path)
  paste0("```{=html}\n", css, "\n```")
}

#' Generate Quarto front-matter YAML snippet for a themed post
#'
#' Returns a character string you can paste into your .qmd front matter.
#' The CSS include file handles all scoping, so the YAML is minimal.
#'
#' @param theme_name Character. Theme id
#' @param css_file Character. Relative path to the generated CSS include file
#' @param path Path to themes JSON
#' @return Character. YAML snippet
generate_theme_yaml <- function(
  theme_name,
  css_file = "theme.html",
  path = THEMES_JSON
) {
  theme <- get_theme(theme_name, path)

  yaml_lines <- c(
    "format:",
    "  html:",
    glue("    include-in-header: {css_file}")
  )

  yaml_str <- paste(yaml_lines, collapse = "\n")

  cli_h2("YAML for {theme$name}")
  cat(yaml_str, "\n")

  invisible(yaml_str)
}

# ----------------------------------------------------------------------------
# Theme JSON Maintenance
# ----------------------------------------------------------------------------

#' Add or update the heading color for a theme
#'
#' If no heading color is provided, one is computed: for dark themes, a lighter
#' variant of primary is chosen; for light themes, a darker variant.
#'
#' @param theme_name Character. Theme id
#' @param heading_hex Character or NULL. Explicit heading hex, or NULL to auto-compute
#' @param path Path to themes JSON
set_theme_heading <- function(theme_name, heading_hex = NULL, path = THEMES_JSON) {
  themes <- load_themes(path)

  if (is.null(themes$themes[[theme_name]])) {
    cli_abort("Theme {.val {theme_name}} not found.")
  }

  colors <- themes$themes[[theme_name]]$colors
  bg <- colors$background

  if (is.null(heading_hex)) {
    # Auto-compute: for dark bg use primary lightened, for light bg use primary
    if (is_dark_theme(bg)) {
      # Use secondary or primary — whichever has better contrast
      candidates <- c(colors$secondary, colors$primary, colors$accent, "#f0f0f0")
      ratios <- sapply(candidates, function(c) contrast_ratio(c, bg))
      heading_hex <- candidates[which.max(ratios)]
      cli_alert_info(
        "Auto-selected heading {.val {heading_hex}} (contrast {round(max(ratios), 2)}:1)"
      )
    } else {
      # Light theme: use primary or darken it
      heading_hex <- colors$primary
    }
  }

  # Validate contrast
  ratio <- contrast_ratio(heading_hex, bg)
  if (ratio < 3.0) {
    cli_warn(c(
      "Heading {heading_hex} only has {round(ratio, 2)}:1 contrast on {bg}.",
      "i" = "WCAG AA large text requires 3:1 minimum."
    ))
  } else {
    cli_alert_success(
      "Heading contrast: {round(ratio, 2)}:1 on {bg} (AA large text: \u2713)"
    )
  }

  themes$themes[[theme_name]]$colors$heading <- heading_hex
  write_json(themes, path, pretty = TRUE, auto_unbox = TRUE)
  cli_alert_success("Set heading for {.val {theme_name}} to {.val {heading_hex}}")

  invisible(heading_hex)
}

#' Batch-add heading colors to all themes that are missing them
#'
#' Uses `set_theme_heading()` with auto-computation for each theme.
#'
#' @param path Path to themes JSON
populate_all_headings <- function(path = THEMES_JSON) {
  themes <- load_themes(path)

  cli_h1("Populating heading colors")

  for (name in names(themes$themes)) {
    t <- themes$themes[[name]]
    if (!is.null(t$colors$heading)) {
      cli_alert_info("{.val {name}}: already has heading {.val {t$colors$heading}}")
      next
    }
    set_theme_heading(name, path = path)
  }

  cli_alert_success("Done! Run {.fn audit_all_themes} to verify contrast.")
}

# ----------------------------------------------------------------------------
# Print welcome message when sourced
# ----------------------------------------------------------------------------

cli_h1("🧪 The Chemist's Bench")
cli_alert_info("Palette management loaded. Key functions:")
cli_li("{.fn add_color} - Add a new color")
cli_li("{.fn list_colors} - Browse categories/colors")
cli_li("{.fn search_colors} - Search by name/description")
cli_li("{.fn preview_category} - Preview colors in terminal")
cli_li("{.fn generate_swatch_html} - Rebuild the HTML page")
cli_li("{.fn add_and_regenerate} - Add + rebuild in one step")
cli_alert_info("Theme functions:")
cli_li("{.fn list_themes} - Show all themes with dark/light classification")
cli_li("{.fn get_theme} - Load a single theme by name")
cli_li("{.fn generate_theme_css} - Generate scoped CSS for a blog post")
cli_li("{.fn audit_theme_contrast} - WCAG contrast audit for a theme")
cli_li("{.fn audit_all_themes} - Audit every theme at once")
cli_li("{.fn set_theme_heading} - Add/update heading color for a theme")
cli_li("{.fn populate_all_headings} - Batch-fill missing heading colors")
