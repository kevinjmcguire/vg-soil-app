/*
 * van Genuchten (1980) retention, Mualem (1976) conductivity, USDA texture
 * classes, and unit helpers. Same equations as R/vg.R and R/texture.R.
 * Suction h is positive, in cm of water; matric potential = -h.
 */
(function (root) {
  "use strict";

  const CM_PER_KPA = 1 / 0.0980665;     // 1 kPa = 10.197 cm of water

  const se = (h, alpha, n) => {
    const m = 1 - 1 / n;
    return Math.pow(1 + Math.pow(alpha * Math.max(h, 0), n), -m);
  };
  const theta = (h, p) => p.theta_r + (p.theta_s - p.theta_r) * se(h, p.alpha, p.n);
  const seTheta = (th, p) => Math.min(Math.max((th - p.theta_r) / (p.theta_s - p.theta_r), 0), 1);

  // Suction (cm) at water content th; Infinity at/below theta_r, 0 at/above theta_s
  function hOfTheta(th, p) {
    const s = seTheta(th, p);
    if (s <= 0) return Infinity;
    if (s >= 1) return 0;
    const m = 1 - 1 / p.n;
    return Math.pow(Math.pow(s, -1 / m) - 1, 1 / p.n) / p.alpha;
  }

  function mualemK(s, n, K0, L) {
    const m = 1 - 1 / n;
    if (s <= 0) return 0;
    return K0 * Math.pow(s, L) * Math.pow(1 - Math.pow(1 - Math.pow(s, 1 / m), m), 2);
  }

  // K (cm/day) at water content th. kmodel: "classic" (K0 = Ks, L = Lc) or "rosetta" (K0, L)
  function kOfTheta(th, p, kmodel, Lc = 0.5) {
    const s = seTheta(th, p);
    return kmodel === "rosetta" ? mualemK(s, p.n, p.K0, p.L) : mualemK(s, p.n, p.Ks, Lc);
  }

  function usdaTexture(sand, clay) {
    const silt = 100 - sand - clay;
    if (!isFinite(sand) || !isFinite(clay) || silt < -1e-9) return null;
    if (silt + 1.5 * clay < 15) return "sand";
    if (silt + 2 * clay < 30) return "loamy sand";
    if ((clay >= 7 && clay < 20 && sand > 52) || (clay < 7 && silt < 50)) return "sandy loam";
    if (clay >= 7 && clay < 27 && silt >= 28 && silt < 50 && sand <= 52) return "loam";
    if ((silt >= 50 && clay >= 12 && clay < 27) || (silt >= 50 && silt < 80 && clay < 12)) return "silt loam";
    if (silt >= 80 && clay < 12) return "silt";
    if (clay >= 20 && clay < 35 && silt < 28 && sand > 45) return "sandy clay loam";
    if (clay >= 27 && clay < 40 && sand > 20 && sand <= 45) return "clay loam";
    if (clay >= 27 && clay < 40 && sand <= 20) return "silty clay loam";
    if (clay >= 35 && sand > 45) return "sandy clay";
    if (clay >= 40 && silt >= 40) return "silty clay";
    return "clay";
  }

  // Format with d significant figures, thousands separators, trailing zeros kept
  function fmt(x, d = 4) {
    if (x === Infinity) return "∞";
    if (x === -Infinity) return "−∞";
    if (x == null || !isFinite(x)) return "–";
    if (x === 0) return "0";
    const s = new Intl.NumberFormat("en-US", { minimumSignificantDigits: d, maximumSignificantDigits: d }).format(x);
    return s.replace("-", "−");
  }

  const api = {
    CM_PER_KPA, se, theta, seTheta, hOfTheta, mualemK, kOfTheta, usdaTexture, fmt,
    kpaToCm: (kpa) => kpa * CM_PER_KPA,
    cmToKpa: (h) => h / CM_PER_KPA,
    cmdayToMmhr: (k) => k * 10 / 24,
    cmdayToMms: (k) => k * 10 / 86400,
  };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.Soil = api;
})(typeof globalThis !== "undefined" ? globalThis : this);
