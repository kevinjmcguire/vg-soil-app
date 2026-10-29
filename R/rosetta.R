# Rosetta pedotransfer functions (version 3), ported to R from the CC0-licensed
# USDA-ARS `rosetta-soil` Python package (v0.3.2).
#
#   Schaap, M.G., Leij, F.J., van Genuchten, M.Th. (2001). ROSETTA: a computer
#     program for estimating soil hydraulic parameters with hierarchical
#     pedotransfer functions. J. Hydrology 251:163-176.
#   Zhang, Y., Schaap, M.G. (2017). Weighted recalibration of the Rosetta
#     pedotransfer model with improved estimates of hydraulic parameter
#     distributions and summary statistics (Rosetta3). J. Hydrology 547:39-53.
#
# Each model is an ensemble of 1,000 bootstrap-trained two-layer networks.
# Model 2 uses sand/silt/clay (SSC); model 3 uses SSC + bulk density.

.rosetta_cache <- new.env()

rosetta_net <- function(name) {
  if (is.null(.rosetta_cache[[name]])) {
    .rosetta_cache[[name]] <- readRDS(file.path("data", paste0(name, ".rds")))
  }
  .rosetta_cache[[name]]
}

.act <- function(x, type) {
  switch(tolower(type),
         tansig  = -1 + 2 / (1 + exp(-2 * x)),
         sigmoid = 1 / (1 + exp(-x)),
         relu    = pmax(0, x),
         linear  = x,
         stop("unknown activation ", type))
}

.scale <- function(x, type, p) {
  switch(tolower(type),
         asis     = x,
         division = x / p[1],
         logtr    = log10(x) / p[1] + p[2],
         affine   = p[1] * (x + p[2]),
         minmax   = (x - p[1]) * p[2] + p[3],
         linear   = x * p[1] + p[2],
         stop("unknown scaler ", type))
}

# Run all bootstrap members of a network for ONE input vector.
# Returns a matrix (nboot x noutput) of scaled outputs.
nn_predict <- function(net, x) {
  stopifnot(length(x) == net$ninput)
  a <- vapply(seq_len(net$ninput), function(i)
    .scale(x[i], net$in_scale[i], net$in_par[[i]]), numeric(1))
  nboot <- net$nboot
  h <- NULL
  for (L in seq_along(net$W)) {
    W <- net$W[[L]]                       # nboot x out x in
    nout <- dim(W)[2]
    z <- matrix(0, nboot, nout)
    for (k in seq_len(nout)) {
      wk <- matrix(W[, k, ], nrow = nboot)  # nboot x in
      z[, k] <- if (is.null(h)) as.vector(wk %*% a) else rowSums(wk * h)
    }
    z <- z + net$b[[L]]
    h <- .act(z, net$activate[L])
  }
  for (k in seq_len(net$noutput)) h[, k] <- .scale(h[, k], net$out_scale[k], net$out_par[[k]])
  h
}

# Predict van Genuchten-Mualem parameters.
#   sand, silt, clay in percent; bd (g/cm3) optional (NULL/NA -> SSC-only model)
# Returns a list with arithmetic-mean parameters (as the rosetta-soil default),
# bootstrap standard deviations, and the per-bootstrap parameter sets.
#   theta_r, theta_s (cm3/cm3); alpha (1/cm); n (-); Ks (cm/day);
#   K0 (cm/day) and L (-) from the Schaap & Leij (2000) unsaturated-K network.
rosetta_predict <- function(sand, silt, clay, bd = NULL) {
  use_bd <- !is.null(bd) && !is.na(bd) && bd >= 0.5 && bd <= 2.0
  net <- rosetta_net(if (use_bd) "rose3_mod3" else "rose3_mod2")
  x <- if (use_bd) c(sand, silt, clay, bd) else c(sand, silt, clay)
  out <- nn_predict(net, x)               # thr, ths, log10 alpha, log10 n, log10 Ks
  boot <- data.frame(theta_r = out[, 1], theta_s = out[, 2],
                     alpha = 10^out[, 3], n = 10^out[, 4], Ks = 10^out[, 5])
  m <- colMeans(boot)
  s <- apply(boot, 2, stats::sd)

  uk <- rosetta_net("rose1_unsat_k")
  kout <- nn_predict(uk, c(m[["theta_r"]], m[["theta_s"]], m[["alpha"]], m[["n"]]))
  K0 <- 10^kout[, 1]; Lp <- kout[, 2]

  list(model = if (use_bd) "Rosetta3 model 3 (sand, silt, clay, bulk density)"
               else "Rosetta3 model 2 (sand, silt, clay)",
       code = if (use_bd) 3L else 2L,
       theta_r = m[["theta_r"]], theta_s = m[["theta_s"]], alpha = m[["alpha"]],
       n = m[["n"]], Ks = m[["Ks"]], K0 = mean(K0), L = mean(Lp),
       sd = c(s, K0 = stats::sd(K0), L = stats::sd(Lp)),
       boot = boot)
}
