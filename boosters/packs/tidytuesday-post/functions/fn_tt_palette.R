# Palette helpers for TidyTuesday posts.

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

tt_palette_manual <- function(colors, source = "manual", name = "custom", type = "discrete") {
  colors <- as.character(colors)
  structure(
    colors,
    source = source,
    name = name,
    type = type,
    id = paste0(source, "::", name),
    class = c("tt_palette", class(colors))
  )
}

tt_palette <- function(source, name, n = NULL, type = c("discrete", "continuous")) {
  type <- match.arg(type)
  id <- paste0(source, "::", name)

  if (!requireNamespace("paletteer", quietly = TRUE)) {
    stop("Package 'paletteer' is required for tt_palette().", call. = FALSE)
  }

  colors <- if (identical(type, "continuous")) {
    as.character(paletteer::paletteer_c(id, n = n %||% 256L))
  } else {
    as.character(paletteer::paletteer_d(id, n = n))
  }

  tt_palette_manual(colors, source = source, name = name, type = type)
}

tt_palette_hero <- function(colors, subtitle = NULL, stripes = 18L) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for tt_palette_hero().", call. = FALSE)
  }
  if (!requireNamespace("tidyr", quietly = TRUE)) {
    stop("Package 'tidyr' is required for tt_palette_hero().", call. = FALSE)
  }
  if (!requireNamespace("dplyr", quietly = TRUE)) {
    stop("Package 'dplyr' is required for tt_palette_hero().", call. = FALSE)
  }

  source <- attr(colors, "source") %||% "unknown"
  name <- attr(colors, "name") %||% "custom"
  colors <- as.character(colors)

  swatch_df <- tidyr::expand_grid(
    idx = seq_along(colors),
    stripe = seq_len(stripes)
  ) |>
    dplyr::mutate(
      xmin = idx - 1 + (stripe - 1) / stripes,
      xmax = idx - 1 + stripe / stripes,
      ymin = 0,
      ymax = 1,
      fill = colors[idx],
      shade = rep(seq(0.78, 1.08, length.out = stripes), times = length(colors))
    )

  ggplot2::ggplot(swatch_df) +
    ggplot2::geom_rect(
      ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax, fill = fill, alpha = shade),
      color = "white",
      linewidth = 0.08,
      show.legend = FALSE
    ) +
    ggplot2::scale_fill_identity() +
    ggplot2::scale_alpha_identity() +
    ggplot2::annotate(
      "text",
      x = 0,
      y = -0.20,
      hjust = 0,
      label = paste0("Palette: ", name),
      fontface = "bold",
      size = 4.4
    ) +
    ggplot2::annotate(
      "text",
      x = length(colors),
      y = -0.20,
      hjust = 1,
      label = paste0("Source: ", source, if (!is.null(subtitle)) paste0(" — ", subtitle) else ""),
      color = "grey35",
      size = 3.7
    ) +
    ggplot2::annotate(
      "segment",
      x = 0,
      xend = length(colors),
      y = -0.05,
      yend = -0.05,
      linewidth = 0.45,
      color = "grey55"
    ) +
    ggplot2::coord_cartesian(xlim = c(0, length(colors)), ylim = c(-0.35, 1), clip = "off", expand = FALSE) +
    ggplot2::theme_void() +
    ggplot2::theme(plot.margin = ggplot2::margin(5.5, 0, 20, 0))
}
