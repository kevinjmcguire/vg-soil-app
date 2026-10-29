# van Genuchten (1980) water retention and Mualem (1976) unsaturated hydraulic
# conductivity.  Suction h is positive (cm of water); matric potential = -h.
#
#   Se(h)   = [1 + (alpha h)^n]^(-m),        m = 1 - 1/n
#   theta   = theta_r + (theta_s - theta_r) Se
#   K(Se)   = K0 Se^L [1 - (1 - Se^(1/m))^m]^2
#
# Classic Mualem-van Genuchten uses K0 = Ks and L = 0.5. Rosetta also provides
# a fitted match point K0 and exponent L (Schaap & Leij, 2000), which usually
# describe unsaturated K better than extrapolating from Ks.

CM_PER_KPA <- 1 / 0.0980665          # 1 kPa = 10.197 cm of water

vg_se <- function(h, alpha, n) {
  m <- 1 - 1 / n
  h <- pmax(h, 0)
  (1 + (alpha * h)^n)^(-m)
}

vg_theta <- function(h, p) p$theta_r + (p$theta_s - p$theta_r) * vg_se(h, p$alpha, p$n)

# Effective saturation from water content (clipped to [0, 1])
vg_se_theta <- function(theta, p) pmin(pmax((theta - p$theta_r) / (p$theta_s - p$theta_r), 0), 1)

# Suction h (cm) at a given water content; Inf at/below theta_r, 0 at/above theta_s
vg_h <- function(theta, p) {
  m <- 1 - 1 / p$n
  se <- vg_se_theta(theta, p)
  out <- ((se^(-1 / m) - 1)^(1 / p$n)) / p$alpha
  out[se <= 0] <- Inf
  out[se >= 1] <- 0
  out
}

mualem_k <- function(se, n, K0, L) {
  m <- 1 - 1 / n
  K0 * se^L * (1 - (1 - se^(1 / m))^m)^2
}

# K at water content theta, using the selected conductivity model
vg_k_theta <- function(theta, p, kmodel = c("classic", "rosetta")) {
  kmodel <- match.arg(kmodel)
  se <- vg_se_theta(theta, p)
  if (kmodel == "classic") mualem_k(se, p$n, p$Ks, 0.5) else mualem_k(se, p$n, p$K0, p$L)
}

vg_k_h <- function(h, p, kmodel = c("classic", "rosetta")) {
  vg_k_theta(vg_theta(h, p), p, kmodel)
}

# Unit helpers ---------------------------------------------------------------
cmday_to_mmhr <- function(k) k * 10 / 24
cmday_to_mms  <- function(k) k * 10 / 86400
cm_to_kpa     <- function(h) h / CM_PER_KPA
kpa_to_cm     <- function(kpa) kpa * CM_PER_KPA

signif_fmt <- function(x, digits = 4) {
  ifelse(is.infinite(x), "\u221e",
         formatC(signif(x, digits), digits = digits, format = "fg", flag = "#", big.mark = ","))
}
