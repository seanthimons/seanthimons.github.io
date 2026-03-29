# Blog Post Hero Image Generator
#
# Generative ggplot2 art for blog post header images.
# Each algorithm accepts a common parameter list driven by the
# Chemist's Bench theme JSON and produces a publication-ready PNG.
#
# Usage:
#   source("hero_generator.R")
#   generate_hero(
#     algorithm = "ray_burst",
#     palette = list(
#       bg = "#1a1a2e", fg = "#4a5568", accent = "#718096",
#       primary = "#2b4c7e", secondary = "#cbd5e0"
#     ),
#     seed = 42,
#     output_path = here::here("posts", "2026-02-20", "hero.png"),
#     width = 10,
#     height = 7
#   )
#
# Algorithms: ray_burst, flow_field, voronoi_shatter,
#             concentric_drift, ridge_wave, reaction_diffusion,
#             topographic
#
# Dependencies: ggplot2, dplyr, purrr, tibble, ggforce, ambient,
#               ggnewscale (ray_burst only), deldir (voronoi only)

library(ggplot2)
library(dplyr)
library(purrr)
library(tibble)

# ============================================================
# Main dispatcher
# ============================================================

#' Generate a hero image for a blog post
#'
#' @param algorithm Character. One of: "ray_burst", "flow_field",
#'   "voronoi_shatter", "concentric_drift", "ridge_wave",
#'   "reaction_diffusion", "topographic", or "random".
#' @param palette Named list with: bg, fg, accent, primary, secondary.
#' @param seed Integer seed for reproducibility.
#' @param output_path File path for the saved PNG.
#' @param width Output width in inches (default 10).
#' @param height Output height in inches (default 7).
#' @return The ggplot object (invisible). Side effect: saves PNG.
generate_hero <- function(
  algorithm = "random",
  palette = list(
    bg = "#1a1a2e",
    fg = "#4a5568",
    accent = "#718096",
    primary = "#2b4c7e",
    secondary = "#cbd5e0"
  ),
  seed = NULL,
  output_path = "hero.png",
  width = 10,
  height = 7
) {
  algorithms <- c(
    "ray_burst",
    "flow_field",
    "voronoi_shatter",
    "concentric_drift",
    "ridge_wave",
    "reaction_diffusion",
    "topographic"
  )

  if (is.null(seed)) {
    seed <- as.integer(Sys.time())
  }
  set.seed(seed)

  if (algorithm == "random") {
    algorithm <- sample(algorithms, 1)
    message(sprintf("Selected algorithm: %s (seed: %d)", algorithm, seed))
  }

  stopifnot(algorithm %in% algorithms)

  p <- switch(
    algorithm,
    ray_burst = algo_ray_burst(palette, seed),
    flow_field = algo_flow_field(palette, seed),
    voronoi_shatter = algo_voronoi_shatter(palette, seed),
    concentric_drift = algo_concentric_drift(palette, seed),
    ridge_wave = algo_ridge_wave(palette, seed),
    reaction_diffusion = algo_reaction_diffusion(palette, seed),
    topographic = algo_topographic(palette, seed)
  )

  # Ensure output directory exists
  output_dir <- dirname(output_path)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  ggsave(
    output_path,
    plot = p,
    width = width,
    height = height,
    units = "in",
    dpi = 300
  )

  message(sprintf("Hero image saved: %s (%s)", output_path, algorithm))
  invisible(p)
}


# ============================================================
# Preview helper
# ============================================================

#' Preview all algorithms with a given palette
#'
#' Generates one PNG per algorithm in the output directory.
#' Useful for comparing styles side-by-side before committing.
#'
#' @param palette Named list with: bg, fg, accent, primary, secondary.
#' @param seed Integer seed (default: 42).
#' @param output_dir Directory to save previews (default: "hero_previews").
#' @param width Output width in inches (default 10).
#' @param height Output height in inches (default 7).
#' @return Invisible tibble of algorithm names and file paths.
preview_all <- function(
  palette,
  seed = 42,
  output_dir = "hero_previews",
  width = 10,
  height = 7
) {
  algorithms <- c(
    "ray_burst",
    "flow_field",
    "voronoi_shatter",
    "concentric_drift",
    "ridge_wave",
    "reaction_diffusion",
    "topographic"
  )

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  paths <- purrr::map_chr(algorithms, function(algo) {
    path <- file.path(output_dir, paste0(algo, ".png"))
    generate_hero(
      algorithm = algo,
      palette = palette,
      seed = seed,
      output_path = path,
      width = width,
      height = height
    )
    path
  })

  result <- tibble::tibble(algorithm = algorithms, path = paths)
  message(sprintf(
    "\nAll %d previews saved to %s/",
    length(algorithms),
    output_dir
  ))
  invisible(result)
}


# ============================================================
# Shared theme helper
# ============================================================

theme_hero <- function(bg_color) {
  theme_void() +
    theme(
      plot.background = element_rect(fill = bg_color, color = NA),
      panel.background = element_rect(fill = bg_color, color = NA),
      plot.margin = margin(25, 25, 25, 25)
    )
}


# ============================================================
# Algorithm 1: Ray Burst
# ============================================================
# Rays emanate from a central circle with sinusoidal wobble.
# Scattered bubble field overlaid. Inspired by midnight_sun.R.

algo_ray_burst <- function(palette, seed) {
  requireNamespace("ggforce", quietly = TRUE)
  requireNamespace("ggnewscale", quietly = TRUE)

  set.seed(seed)

  # Parameters
  n_rays <- 300
  n_dashed_rays <- 60
  n_steps <- 250
  step_length <- 0.005
  wobble_freq <- 25
  wobble_strength <- 1.0
  n_circles <- 100
  x_lim <- c(0, 1)
  y_lim <- c(0, 1.2)

  # Source circle
  sun <- tibble(x0 = 0.3, y0 = 0.65, r = 0.15)

  # Ray tracer
  trace_ray <- function(id) {
    angle <- runif(1, 0, 2 * pi)
    x <- numeric(n_steps)
    y <- numeric(n_steps)
    x[1] <- sun$x0 + sun$r * cos(angle)
    y[1] <- sun$y0 + sun$r * sin(angle)

    for (i in 2:n_steps) {
      rx <- x[i - 1] - sun$x0
      ry <- y[i - 1] - sun$y0
      d <- max(sqrt(rx^2 + ry^2), 1e-6)
      ux <- rx / d
      uy <- ry / d
      px <- -uy
      py <- ux

      wobble <- sin(d * wobble_freq) * d * wobble_strength
      fx <- ux + px * wobble
      fy <- uy + py * wobble
      fn <- max(sqrt(fx^2 + fy^2), 1e-6)

      x[i] <- x[i - 1] + (fx / fn) * step_length
      y[i] <- y[i - 1] + (fy / fn) * step_length

      if (
        is.na(x[i]) ||
          x[i] < x_lim[1] ||
          x[i] > x_lim[2] ||
          y[i] < y_lim[1] ||
          y[i] > y_lim[2]
      ) {
        x <- x[1:(i - 1)]
        y <- y[1:(i - 1)]
        break
      }
    }
    tibble(x = x, y = y, id = id)
  }

  rays <- map_df(1:n_rays, trace_ray) %>%
    group_by(id) %>%
    filter(n() > 1) %>%
    ungroup() %>%
    mutate(
      ray_linetype = ifelse(id <= n_dashed_rays, "dashed", "solid"),
      ray_linewidth = ifelse(id <= n_dashed_rays, 2.0, 1.4)
    )

  bubbles <- tibble(
    x0 = runif(n_circles, x_lim[1] - 0.20, x_lim[2] + 0.20),
    y0 = runif(n_circles, y_lim[1] - 0.20, y_lim[2] + 0.20),
    r = 0.02 + 0.18 * rbeta(n_circles, 1, 5),
    alpha = runif(n_circles, 0.60, 0.98)
  )

  # Map palette
  bg_col <- palette$bg
  fg_col <- palette$fg
  ray_col <- palette$accent
  sun_col <- palette$primary
  fill_col <- colorspace::darken(palette$bg, 0.3)

  ggplot() +
    geom_path(
      data = rays,
      aes(
        x = x,
        y = y,
        group = id,
        linetype = ray_linetype,
        linewidth = ray_linewidth
      ),
      color = ray_col,
      alpha = 0.65
    ) +
    scale_linetype_manual(
      values = c("dashed" = "dashed", "solid" = "solid"),
      guide = "none"
    ) +
    scale_linewidth_identity(guide = "none") +
    ggforce::geom_circle(
      data = bubbles,
      aes(x0 = x0, y0 = y0, r = r, alpha = alpha),
      fill = fill_col,
      color = NA
    ) +
    scale_alpha_identity(guide = "none") +
    ggnewscale::new_scale("linewidth") +
    ggforce::geom_circle(
      data = bubbles,
      aes(x0 = x0, y0 = y0, r = r),
      color = fg_col,
      linewidth = 0.9
    ) +
    ggforce::geom_circle(
      data = sun,
      aes(x0 = x0, y0 = y0, r = r),
      fill = sun_col,
      color = NA
    ) +
    ggforce::geom_circle(
      data = sun,
      aes(x0 = x0, y0 = y0, r = r),
      fill = NA,
      color = bg_col,
      linewidth = 1.1
    ) +
    coord_fixed(ratio = 1, xlim = x_lim, ylim = y_lim, expand = FALSE) +
    theme_hero(bg_col)
}


# ============================================================
# Algorithm 2: Flow Field
# ============================================================
# Particles trace paths through a curl/perlin noise field.
# Produces organic, wind-like patterns.

algo_flow_field <- function(palette, seed) {
  requireNamespace("ambient", quietly = TRUE)

  set.seed(seed)

  # Parameters
  n_particles <- 500
  n_steps <- 200
  step_length <- 0.003
  x_lim <- c(0, 1)
  y_lim <- c(0, 0.7)
  noise_freq <- 3

  # Generate noise grid for angle field
  get_angle <- function(x, y) {
    val <- ambient::gen_simplex(
      x = x * noise_freq,
      y = y * noise_freq,
      seed = seed
    )
    val * 2 * pi
  }

  # Trace particles
  trace_particle <- function(id) {
    x <- numeric(n_steps)
    y <- numeric(n_steps)
    x[1] <- runif(1, x_lim[1], x_lim[2])
    y[1] <- runif(1, y_lim[1], y_lim[2])

    for (i in 2:n_steps) {
      angle <- get_angle(x[i - 1], y[i - 1])
      x[i] <- x[i - 1] + cos(angle) * step_length
      y[i] <- y[i - 1] + sin(angle) * step_length

      if (
        x[i] < x_lim[1] || x[i] > x_lim[2] || y[i] < y_lim[1] || y[i] > y_lim[2]
      ) {
        x <- x[1:(i - 1)]
        y <- y[1:(i - 1)]
        break
      }
    }
    tibble(x = x, y = y, id = id)
  }

  particles <- map_df(1:n_particles, trace_particle) %>%
    group_by(id) %>%
    filter(n() > 1) %>%
    ungroup()

  # Assign colors from palette gradient
  particle_ids <- unique(particles$id)
  color_map <- tibble(
    id = particle_ids,
    color = colorRampPalette(
      c(palette$primary, palette$accent, palette$secondary)
    )(length(particle_ids))
  )

  particles <- particles %>% left_join(color_map, by = "id")

  ggplot(particles, aes(x = x, y = y, group = id, color = color)) +
    geom_path(alpha = 0.4, linewidth = 0.4) +
    scale_color_identity() +
    coord_fixed(
      ratio = 1,
      xlim = x_lim,
      ylim = y_lim,
      expand = FALSE
    ) +
    theme_hero(palette$bg)
}


# ============================================================
# Algorithm 3: Voronoi Shatter
# ============================================================
# Voronoi tessellation with theme-colored fills and accent borders.
# Produces stained-glass / geological fracture patterns.

algo_voronoi_shatter <- function(palette, seed) {
  requireNamespace("deldir", quietly = TRUE)

  set.seed(seed)

  # Parameters
  n_points <- 80
  x_lim <- c(0, 10)
  y_lim <- c(0, 7)

  pts <- tibble(
    x = runif(n_points, x_lim[1], x_lim[2]),
    y = runif(n_points, y_lim[1], y_lim[2])
  )

  # Build color palette — near-black cells with faint color tints.
  # The borders carry the visual weight; fills barely emerge from dark.
  dark_tints <- c(
    colorspace::darken(palette$primary, 0.85),
    colorspace::darken(palette$primary, 0.75),
    colorspace::darken(palette$accent, 0.85),
    colorspace::darken(palette$accent, 0.75),
    colorspace::darken(palette$secondary, 0.85),
    colorspace::darken(palette$secondary, 0.75),
    palette$bg
  )
  fill_colors <- sample(dark_tints, n_points, replace = TRUE)

  # A handful of cells glow faintly — poisonous color seeping through
  n_glow <- ceiling(n_points * 0.10)
  glow_idx <- sample(1:n_points, n_glow)
  glow_colors <- c(
    colorspace::darken(palette$primary, 0.45),
    colorspace::darken(palette$accent, 0.45),
    colorspace::darken(palette$secondary, 0.50)
  )
  fill_colors[glow_idx] <- sample(glow_colors, n_glow, replace = TRUE)

  # Compute Voronoi tessellation via deldir
  dd <- deldir::deldir(pts$x, pts$y, rw = c(x_lim, y_lim))
  tiles <- deldir::tile.list(dd)

  # Build polygon data frame from tiles
  tile_list <- lapply(seq_along(tiles), function(i) {
    tile <- tiles[[i]]
    data.frame(
      x = tile$x,
      y = tile$y,
      cell_id = i,
      cell_fill = fill_colors[i],
      stringsAsFactors = FALSE
    )
  })
  tile_polys <- do.call(rbind, tile_list)

  ggplot(tile_polys, aes(x = x, y = y, group = cell_id, fill = cell_fill)) +
    geom_polygon(color = palette$accent, linewidth = 0.6) +
    scale_fill_identity() +
    coord_fixed(
      ratio = 1,
      xlim = x_lim,
      ylim = y_lim,
      expand = FALSE
    ) +
    theme_hero(palette$bg)
}


# ============================================================
# Algorithm 4: Concentric Drift
# ============================================================
# Nested ellipses/circles with jitter, overlap, and transparency.
# Produces ripple / interference / topographic patterns.

algo_concentric_drift <- function(palette, seed) {
  requireNamespace("ggforce", quietly = TRUE)

  set.seed(seed)

  # Parameters
  n_centers <- 3
  n_rings <- 25
  x_lim <- c(0, 10)
  y_lim <- c(0, 7)

  centers <- tibble(
    cx = runif(n_centers, 2, 8),
    cy = runif(n_centers, 1.5, 5.5),
    center_id = 1:n_centers
  )

  # Generate concentric rings per center with drift
  rings <- centers %>%
    tidyr::crossing(ring = 1:n_rings) %>%
    mutate(
      # Rings expand outward with slight jitter
      r = ring * 0.18 + rnorm(n(), 0, 0.02),
      # Drift the center slightly per ring
      x0 = cx + cumsum(rnorm(n(), 0, 0.015)),
      y0 = cy + cumsum(rnorm(n(), 0, 0.015)),
      alpha = scales::rescale(ring, to = c(0.8, 0.15)),
      # Assign colors cycling through palette
      color = rep_len(
        c(palette$primary, palette$accent, palette$secondary, palette$fg),
        n()
      )
    )

  ggplot(rings) +
    ggforce::geom_circle(
      aes(x0 = x0, y0 = y0, r = r, alpha = alpha, color = color),
      fill = NA,
      linewidth = 0.8
    ) +
    scale_alpha_identity() +
    scale_color_identity() +
    coord_fixed(
      ratio = 1,
      xlim = x_lim,
      ylim = y_lim,
      expand = FALSE
    ) +
    theme_hero(palette$bg)
}


# ============================================================
# Algorithm 5: Ridge Wave
# ============================================================
# Stacked sinusoidal waveforms with noise perturbation.
# Joy Division / Unknown Pleasures aesthetic. Good for
# data-adjacent or analytical posts.

algo_ridge_wave <- function(palette, seed) {
  set.seed(seed)

  # Parameters
  n_lines <- 40
  n_points <- 500
  x_lim <- c(0, 10)
  amplitude <- 0.3
  noise_oct <- 4

  x <- seq(x_lim[1], x_lim[2], length.out = n_points)

  lines <- map_df(1:n_lines, function(i) {
    # Base y position (stacked)
    base_y <- i * 0.25

    # Composite wave: sin + noise
    y <- base_y +
      amplitude *
        sin(x * runif(1, 0.8, 1.5) + runif(1, 0, 2 * pi)) *
        dnorm(x, mean = runif(1, 3, 7), sd = runif(1, 1.2, 2.5)) *
        5

    # Add small-scale noise
    y <- y + rnorm(n_points, 0, 0.01)

    tibble(x = x, y = y, line_id = i)
  })

  # Color gradient across lines
  line_ids <- unique(lines$line_id)
  color_map <- tibble(
    line_id = line_ids,
    color = colorRampPalette(
      c(palette$secondary, palette$accent, palette$primary)
    )(length(line_ids))
  )

  lines <- lines %>% left_join(color_map, by = "line_id")

  ggplot(lines, aes(x = x, y = y, group = line_id, color = color)) +
    geom_line(linewidth = 0.5, alpha = 0.7) +
    scale_color_identity() +
    coord_cartesian(xlim = x_lim, expand = FALSE) +
    theme_hero(palette$bg)
}


# ============================================================
# Algorithm 6: Reaction-Diffusion (Turing Patterns)
# ============================================================
# Gray-Scott reaction-diffusion simulation producing labyrinthine
# stripe patterns, spots, or coral-like structures.
# Pure matrix math — no additional dependencies.

algo_reaction_diffusion <- function(palette, seed) {
  set.seed(seed)

  # --- Grid setup ---
  # Non-square grid matching 10:7 output aspect ratio — no black bars
  nx <- 400 # columns (width)
  ny <- 280 # rows (height)
  dx <- 1.0 # grid spacing
  dt <- 1.0 # timestep

  # Standard Gray-Scott diffusion rates
  Du <- 0.16 # diffusion rate for U
  Dv <- 0.08 # diffusion rate for V

  # --- Pattern presets (well-known stable Gray-Scott regimes) ---
  presets <- list(
    # Labyrinthine stripes (the Priscus III look)
    stripes1 = list(f = 0.029, k = 0.057),
    stripes2 = list(f = 0.030, k = 0.058),
    stripes3 = list(f = 0.031, k = 0.057),
    # Spots / mitosis
    spots = list(f = 0.025, k = 0.056),
    # Coral / worms
    coral = list(f = 0.034, k = 0.059)
  )

  pick <- presets[[(seed %% length(presets)) + 1]]
  # Very tight jitter — these basins are narrow
  f <- pick$f + runif(1, -0.0005, 0.0005)
  k <- pick$k + runif(1, -0.0005, 0.0005)

  preset_name <- names(presets)[(seed %% length(presets)) + 1]
  message(sprintf(
    "  Reaction-diffusion: f=%.4f, k=%.4f, preset=%s",
    f,
    k,
    preset_name
  ))

  # --- Initialize concentrations ---
  U <- matrix(1, nrow = ny, ncol = nx)
  V <- matrix(0, nrow = ny, ncol = nx)

  # Seed a large central region + scattered patches
  cx <- ny %/% 2
  cy <- nx %/% 2
  sz <- min(nx, ny) %/% 5
  for (r in max(1, cx - sz):min(ny, cx + sz)) {
    for (cc in max(1, cy - sz):min(nx, cy + sz)) {
      U[r, cc] <- 0.50 + runif(1, -0.10, 0.10)
      V[r, cc] <- 0.25 + runif(1, -0.10, 0.10)
    }
  }

  # Additional scattered patches for full coverage
  n_extra <- sample(15:25, 1)
  for (i in seq_len(n_extra)) {
    px <- sample(10:(ny - 10), 1)
    py <- sample(10:(nx - 10), 1)
    ps <- sample(5:12, 1)
    rows <- max(1, px - ps):min(ny, px + ps)
    cols <- max(1, py - ps):min(nx, py + ps)
    U[rows, cols] <- 0.50 + runif(length(rows) * length(cols), -0.10, 0.10)
    V[rows, cols] <- 0.25 + runif(length(rows) * length(cols), -0.10, 0.10)
  }

  # --- 5-point Laplacian with periodic boundary ---
  laplacian <- function(M, nr, nc) {
    up <- rbind(M[nr, , drop = FALSE], M[-nr, , drop = FALSE])
    down <- rbind(M[-1, , drop = FALSE], M[1, , drop = FALSE])
    left <- cbind(M[, nc, drop = FALSE], M[, -nc, drop = FALSE])
    right <- cbind(M[, -1, drop = FALSE], M[, 1, drop = FALSE])
    (up + down + left + right - 4 * M) / (dx * dx)
  }

  # --- Run simulation ---
  steps <- 10000
  message(sprintf("  Running %d steps on %dx%d grid...", steps, nx, ny))

  for (step in seq_len(steps)) {
    uvv <- U * V * V
    lu <- laplacian(U, ny, nx)
    lv <- laplacian(V, ny, nx)

    U <- U + (Du * lu - uvv + f * (1 - U)) * dt
    V <- V + (Dv * lv + uvv - (f + k) * V) * dt
  }

  # --- Diagnostics ---
  u_range <- range(U)
  v_range <- range(V)
  message(sprintf(
    "  U range: [%.4f, %.4f], V range: [%.4f, %.4f]",
    u_range[1],
    u_range[2],
    v_range[1],
    v_range[2]
  ))

  # --- Convert to tidy data for ggplot ---
  df <- tibble::tibble(
    x = rep(seq_len(nx), each = ny),
    y = rep(seq_len(ny), times = nx),
    u = as.vector(U)
  )

  # --- Build the plot ---
  mid <- mean(u_range)

  ggplot(df, aes(x = x, y = y, fill = u)) +
    geom_raster(interpolate = FALSE) +
    scale_fill_gradient2(
      low = palette$primary,
      mid = palette$accent,
      high = palette$bg,
      midpoint = mid,
      guide = "none"
    ) +
    scale_x_continuous(expand = c(0, 0)) +
    scale_y_continuous(expand = c(0, 0)) +
    theme_hero(palette$bg) +
    theme(plot.margin = margin(0, 0, 0, 0))
}


# ============================================================
# Algorithm 7: Topographic Map (Noise Contours)
# ============================================================
# Fake topographic maps from blended fractal noise.
# Contour lines with bold majors and altitude color gradients.
# Requires: ambient (already needed by flow_field)

algo_topographic <- function(palette, seed) {
  requireNamespace("ambient", quietly = TRUE)

  set.seed(seed)

  # --- Parameters ---
  grid_n <- 400 # resolution of the noise grid
  n_layers <- 3 # number of noise seeds to blend
  octaves <- 6 # fractal octaves (detail layers)
  frequency <- sample(c(2, 3, 4), 1) # base frequency (slope/ruggedness)
  n_minor <- 30 # total contour levels
  major_every <- 5 # every Nth contour is bold
  lacunarity <- 2.0 # frequency multiplier per octave
  gain <- 0.5 # amplitude multiplier per octave

  # --- Generate blended noise field ---
  grid <- ambient::long_grid(
    x = seq(0, 1, length.out = grid_n),
    y = seq(0, 1, length.out = grid_n)
  )

  # Blend multiple noise fields with different seeds for organic terrain
  noise_layers <- purrr::map(seq_len(n_layers), function(i) {
    layer_seed <- seed + i * 137
    ambient::fracture(
      noise = ambient::gen_simplex,
      fractal = ambient::fbm,
      octaves = octaves,
      lacunarity = lacunarity,
      gain = gain,
      x = grid$x,
      y = grid$y,
      frequency = frequency * (1 + (i - 1) * 0.3),
      seed = layer_seed
    )
  })

  # Weighted blend — first layer dominates, others add detail
  weights <- c(0.55, 0.30, 0.15)[seq_len(n_layers)]
  weights <- weights / sum(weights)

  grid$z <- purrr::reduce2(
    noise_layers,
    weights,
    .init = rep(0, nrow(grid)),
    function(acc, layer, w) acc + layer * w
  )

  # Normalize to [0, 1]
  grid$z <- (grid$z - min(grid$z)) / (max(grid$z) - min(grid$z))

  # Tidy format for ggplot
  df <- tibble::tibble(
    x = grid$x,
    y = grid$y,
    z = grid$z
  )

  # --- Contour breaks ---
  minor_breaks <- seq(0, 1, length.out = n_minor + 1)
  major_breaks <- minor_breaks[seq(1, length(minor_breaks), by = major_every)]

  # --- Altitude color ramp ---
  altitude_colors <- c(
    palette$primary,
    palette$accent,
    palette$secondary,
    palette$fg
  )

  # --- Plot: minor contours, then bold majors on top ---
  ggplot(df, aes(x = x, y = y, z = z)) +
    # Minor contour lines — thin, lower alpha
    geom_contour(
      aes(color = after_stat(level)),
      breaks = minor_breaks,
      linewidth = 0.25,
      alpha = 0.5
    ) +
    # Major contour lines — bold, full alpha
    geom_contour(
      aes(color = after_stat(level)),
      breaks = major_breaks,
      linewidth = 0.7,
      alpha = 0.9
    ) +
    scale_color_gradientn(
      colors = altitude_colors,
      guide = "none"
    ) +
    coord_fixed(expand = FALSE) +
    theme_hero(palette$bg)
}
