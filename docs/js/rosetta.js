/*
 * Rosetta3 pedotransfer functions in JavaScript.
 * Port of the CC0-licensed USDA-ARS `rosetta-soil` Python package (v0.3.2);
 * same networks as R/rosetta.R in this repository.
 *
 *   Schaap, Leij & van Genuchten (2001) J. Hydrology 251:163-176
 *   Zhang & Schaap (2017) J. Hydrology 547:39-53
 *   Schaap & Leij (2000) Soil Sci. Soc. Am. J. 64:843-851 (unsaturated K)
 *
 * Model 2: sand, silt, clay (%).  Model 3: + bulk density (g/cm3).
 * Each model is an ensemble of 1,000 bootstrap-trained two-layer networks.
 */
(function (root) {
  "use strict";

  const ACT = {
    tansig: (x) => -1 + 2 / (1 + Math.exp(-2 * x)),
    sigmoid: (x) => 1 / (1 + Math.exp(-x)),
    relu: (x) => Math.max(0, x),
    linear: (x) => x,
  };

  function scale(x, type, p) {
    switch (type.toLowerCase()) {
      case "asis": return x;
      case "division": return x / p[0];
      case "logtr": return Math.log10(x) / p[0] + p[1];
      case "affine": return p[0] * (x + p[1]);
      case "minmax": return (x - p[0]) * p[1] + p[2];
      case "linear": return x * p[0] + p[1];
      default: throw new Error("unknown scaler " + type);
    }
  }

  // Run every bootstrap member for one input vector.
  // Returns an array (length nboot) of output arrays (scaled to physical units).
  function nnPredict(net, x) {
    const a0 = x.map((v, i) => scale(v, net.inputs[i].scale, net.inputs[i].params));
    const out = new Array(net.nboot);
    for (let k = 0; k < net.nboot; k++) {
      let a = a0;
      for (const L of net.layers) {
        const f = ACT[L.activate.toLowerCase()];
        const z = new Array(L.nout);
        const wOff = k * L.nout * L.nin, bOff = k * L.nout;
        for (let o = 0; o < L.nout; o++) {
          let s = L.b[bOff + o];
          const row = wOff + o * L.nin;
          for (let i = 0; i < L.nin; i++) s += L.W[row + i] * a[i];
          z[o] = f(s);
        }
        a = z;
      }
      out[k] = a.map((v, i) => scale(v, net.outputs[i].scale, net.outputs[i].params));
    }
    return out;
  }

  const mean = (v) => v.reduce((s, x) => s + x, 0) / v.length;
  const sd = (v) => { const m = mean(v); return Math.sqrt(v.reduce((s, x) => s + (x - m) ** 2, 0) / (v.length - 1)); };

  /*
   * nets = {mod2, mod3, unsatk} (parsed JSON from docs/data/).
   * Returns arithmetic-mean parameters (the rosetta-soil default), bootstrap SDs,
   * and the per-bootstrap parameter sets:
   *   theta_r, theta_s (cm3/cm3); alpha (1/cm); n; Ks (cm/day); K0 (cm/day); L
   */
  function rosettaPredict(nets, sand, silt, clay, bd) {
    const useBD = bd != null && isFinite(bd) && bd >= 0.5 && bd <= 2.0;
    const net = useBD ? nets.mod3 : nets.mod2;
    const raw = nnPredict(net, useBD ? [sand, silt, clay, bd] : [sand, silt, clay]);
    const boot = raw.map((o) => ({ theta_r: o[0], theta_s: o[1], alpha: 10 ** o[2], n: 10 ** o[3], Ks: 10 ** o[4] }));
    const keys = ["theta_r", "theta_s", "alpha", "n", "Ks"];
    const p = {}, s = {};
    for (const key of keys) { const v = boot.map((b) => b[key]); p[key] = mean(v); s[key] = sd(v); }
    const uk = nnPredict(nets.unsatk, [p.theta_r, p.theta_s, p.alpha, p.n]);
    const K0 = uk.map((o) => 10 ** o[0]), Lp = uk.map((o) => o[1]);
    p.K0 = mean(K0); p.L = mean(Lp); s.K0 = sd(K0); s.L = sd(Lp);
    return {
      model: useBD ? "Rosetta3 model 3 (sand, silt, clay, bulk density)" : "Rosetta3 model 2 (sand, silt, clay)",
      code: useBD ? 3 : 2, ...p, sd: s, boot,
    };
  }

  const api = { nnPredict, rosettaPredict };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.Rosetta = api;
})(typeof globalThis !== "undefined" ? globalThis : this);
