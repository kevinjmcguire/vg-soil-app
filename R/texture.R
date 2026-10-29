# USDA soil texture classification and texture-triangle plot (base graphics).

usda_texture <- function(sand, clay, silt = 100 - sand - clay) {
  if (is.na(sand) || is.na(clay) || silt < -1e-9) return(NA_character_)
  if (silt + 1.5 * clay < 15) return("sand")
  if (silt + 2 * clay < 30) return("loamy sand")
  if ((clay >= 7 && clay < 20 && sand > 52) || (clay < 7 && silt < 50)) return("sandy loam")
  if (clay >= 7 && clay < 27 && silt >= 28 && silt < 50 && sand <= 52) return("loam")
  if ((silt >= 50 && clay >= 12 && clay < 27) || (silt >= 50 && silt < 80 && clay < 12)) return("silt loam")
  if (silt >= 80 && clay < 12) return("silt")
  if (clay >= 20 && clay < 35 && silt < 28 && sand > 45) return("sandy clay loam")
  if (clay >= 27 && clay < 40 && sand > 20 && sand <= 45) return("clay loam")
  if (clay >= 27 && clay < 40 && sand <= 20) return("silty clay loam")
  if (clay >= 35 && sand > 45) return("sandy clay")
  if (clay >= 40 && silt >= 40) return("silty clay")
  "clay"
}

# Ternary -> Cartesian: sand corner bottom-left, silt bottom-right, clay top
tri_xy <- function(sand, silt, clay) {
  list(x = (silt + clay / 2) / 100, y = clay / 100 * sqrt(3) / 2)
}

# Pre-computed grid of classified points (fills class regions)
.texture_grid <- local({
  g <- expand.grid(sand = seq(0, 100, by = 0.5), clay = seq(0, 100, by = 0.5))
  g <- g[g$sand + g$clay <= 100, ]
  g$silt <- 100 - g$sand - g$clay
  g$cls <- mapply(usda_texture, g$sand, g$clay, g$silt)
  g
})

TEXTURE_COLS <- c(
  "sand" = "#F3E4C8", "loamy sand" = "#EBD7B3", "sandy loam" = "#E4CA9E",
  "loam" = "#D8C6A6", "silt loam" = "#E2DCC9", "silt" = "#EEEADC",
  "sandy clay loam" = "#D7B48F", "clay loam" = "#C9AE95", "silty clay loam" = "#D3C7B7",
  "sandy clay" = "#C79E80", "silty clay" = "#C2B4A6", "clay" = "#B89A88")

plot_texture_triangle <- function(sand, clay, accent = "#861F41") {
  g <- .texture_grid
  xy <- tri_xy(g$sand, g$silt, g$clay)
  op <- par(mar = c(1, 1, 1, 1)); on.exit(par(op))
  plot(NA, xlim = c(-0.08, 1.08), ylim = c(-0.1, 0.93), asp = 1, axes = FALSE, xlab = "", ylab = "")
  points(xy$x, xy$y, pch = 15, cex = 0.55, col = TEXTURE_COLS[g$cls])
  # class labels at region centroids
  for (cl in names(TEXTURE_COLS)) {
    i <- g$cls == cl
    if (any(i)) text(mean(xy$x[i]), mean(xy$y[i]), cl, cex = 0.8, col = "#4A3B30")
  }
  # frame and grid ticks every 10 %
  polygon(c(0, 1, 0.5), c(0, 0, sqrt(3) / 2), border = "#444444", lwd = 1.5)
  for (v in seq(10, 90, 10)) {
    a <- tri_xy(100 - v, 0, v); b <- tri_xy(0, 100 - v, v)        # clay lines
    segments(a$x, a$y, b$x, b$y, col = "#FFFFFF80", lwd = 0.6)
    text(a$x - 0.025, a$y, v, cex = 0.6, adj = 1, col = "#555555")
    a <- tri_xy(v, 100 - v, 0); b <- tri_xy(v, 0, 100 - v)        # sand lines
    segments(a$x, a$y, b$x, b$y, col = "#FFFFFF80", lwd = 0.6)
    text(a$x, a$y - 0.035, v, cex = 0.6, col = "#555555")
    a <- tri_xy(100 - v, v, 0); b <- tri_xy(0, v, 100 - v)        # silt lines
    segments(a$x, a$y, b$x, b$y, col = "#FFFFFF80", lwd = 0.6)
    text(b$x + 0.025, b$y, v, cex = 0.6, adj = 0, col = "#555555")
  }
  text(0.5, -0.085, "% sand  \u2190", cex = 0.85)
  text(0.13, 0.5, "% clay", srt = 60, cex = 0.85)
  text(0.87, 0.5, "% silt", srt = -60, cex = 0.85)
  silt <- 100 - sand - clay
  if (silt >= 0) {
    p <- tri_xy(sand, silt, clay)
    points(p$x, p$y, pch = 21, bg = accent, col = "white", cex = 2.2, lwd = 2)
  }
}
