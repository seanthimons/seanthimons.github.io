# Lightweight plotting theme for TidyTuesday posts.

tt_theme <- function(base_size = 13, legend_position = "top") {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required for tt_theme().", call. = FALSE)
  }

  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(color = "grey35"),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = legend_position
    )
}
