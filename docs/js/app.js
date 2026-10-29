/* Soil Hydraulic Properties - page logic (inputs, plots, table, triangle). */
(function () {
  "use strict";
  const S = window.Soil, fmt = S.fmt;
  const NETS = {
    mod2: window.ROSETTA_NETS.rose3_mod2,
    mod3: window.ROSETTA_NETS.rose3_mod3,
    unsatk: window.ROSETTA_NETS.rose1_unsat_k,
  };
  const C = { maroon: "#861F41", maroonDark: "#5E0F2C", orange: "#E5751F", stone: "#75787B", grid: "#EEEEEE" };
  const $ = (id) => document.getElementById(id);
  const HGRID = Array.from({ length: 241 }, (_, i) => Math.pow(10, -1 + (8 * i) / 240));   // 0.1 to 1e7 cm

  const state = { kx: "theta", ros: null, rosKey: "", res: null };

  // ------------------------------------------------------------------ inputs
  function linkRange(numId) {
    const num = $(numId), rng = $(numId + "-r");
    rng.addEventListener("input", () => { num.value = rng.value; update(); });
    num.addEventListener("input", () => { if (num.value !== "") rng.value = num.value; update(); });
  }
  linkRange("sand"); linkRange("clay");
  ["bd", "theta", "c-thr", "c-ths", "c-alpha", "c-n", "c-ks", "c-l"].forEach((id) => $(id).addEventListener("input", update));
  ["use-bd", "band"].forEach((id) => $(id).addEventListener("change", update));
  document.querySelectorAll("input[name=fc], input[name=kmodel]").forEach((el) => el.addEventListener("change", update));
  $("custom").addEventListener("change", () => {
    if ($("custom").checked && state.ros) {
      const r = state.ros;
      $("c-thr").value = r.theta_r.toFixed(4); $("c-ths").value = r.theta_s.toFixed(4);
      $("c-alpha").value = Number(r.alpha.toPrecision(4)); $("c-n").value = r.n.toFixed(4);
      $("c-ks").value = Number(r.Ks.toPrecision(4));
    }
    update();
  });
  $("kx-theta").addEventListener("click", () => setKx("theta"));
  $("kx-h").addEventListener("click", () => setKx("h"));
  function setKx(v) {
    state.kx = v;
    $("kx-theta").setAttribute("aria-pressed", v === "theta");
    $("kx-h").setAttribute("aria-pressed", v === "h");
    drawK();
  }

  const num = (id) => { const v = $(id).value; return v === "" ? NaN : Number(v); };
  const radio = (name) => document.querySelector(`input[name=${name}]:checked`).value;

  function readInputs() {
    return {
      sand: num("sand"), clay: num("clay"), useBD: $("use-bd").checked, bd: num("bd"),
      theta: num("theta"), fcKpa: Number(radio("fc")), kmodel: radio("kmodel"), band: $("band").checked,
      custom: $("custom").checked,
      c: { theta_r: num("c-thr"), theta_s: num("c-ths"), alpha: num("c-alpha"), n: num("c-n"), Ks: num("c-ks"), L: num("c-l") },
    };
  }

  // ------------------------------------------------------------------ tabs
  const tabs = Array.from(document.querySelectorAll(".tabs button"));
  tabs.forEach((b) => b.addEventListener("click", () => {
    tabs.forEach((t) => { t.setAttribute("aria-selected", t === b); $(t.getAttribute("aria-controls")).hidden = t !== b; });
    if (b.id === "t-tri") drawTriangle();
    if (b.id === "t-curves") { Plotly.Plots.resize("p-ret"); Plotly.Plots.resize("p-k"); }
  }));

  // ------------------------------------------------------------------ compute
  function compute() {
    const inp = readInputs();
    const errs = [];
    const silt = 100 - inp.sand - inp.clay;
    if (!(inp.sand >= 0 && inp.sand <= 100 && inp.clay >= 0 && inp.clay <= 100)) errs.push("Sand and clay must be between 0 and 100%.");
    else if (silt < 0) errs.push("Sand + clay exceeds 100%.");
    if (inp.useBD && !(inp.bd >= 0.5 && inp.bd <= 2.0)) errs.push("Bulk density must be between 0.5 and 2.0 g/cm³.");
    if (!(inp.theta > 0)) errs.push("Enter a water content greater than 0.");
    if (errs.length) return { inp, errs };

    const bd = inp.useBD ? inp.bd : null;
    const key = [inp.sand, inp.clay, bd].join("|");
    if (key !== state.rosKey) { state.ros = Rosetta.rosettaPredict(NETS, inp.sand, silt, inp.clay, bd); state.rosKey = key; }
    const ros = state.ros;

    let p;
    if (inp.custom) {
      const c = inp.c;
      if (Object.values(c).some((v) => !isFinite(v))) errs.push("Enter all custom parameters.");
      else if (!(c.theta_r >= 0 && c.theta_r < c.theta_s && c.theta_s < 1)) errs.push("Custom parameters need 0 ≤ θr < θs < 1.");
      else if (!(c.alpha > 0 && c.n > 1 && c.Ks > 0)) errs.push("Custom parameters need α > 0, n > 1, Ks > 0.");
      if (errs.length) return { inp, errs };
      p = { ...c, K0: c.Ks, source: "Custom parameters", kmodel: "classic", Lc: c.L, sd: null };
    } else {
      p = { theta_r: ros.theta_r, theta_s: ros.theta_s, alpha: ros.alpha, n: ros.n, Ks: ros.Ks, K0: ros.K0, L: ros.L,
            source: ros.model, kmodel: inp.kmodel, Lc: 0.5, sd: ros.sd };
    }
    const K = (th) => S.kOfTheta(th, p, p.kmodel, p.Lc);
    const fcCm = S.kpaToCm(inp.fcKpa), wpCm = S.kpaToCm(1500);
    return {
      inp, errs, silt, p, K,
      cls: S.usdaTexture(inp.sand, inp.clay),
      se: S.seTheta(inp.theta, p), h: S.hOfTheta(inp.theta, p), k: K(inp.theta),
      fc: S.theta(fcCm, p), wp: S.theta(wpCm, p), fcCm, wpCm,
      ksat: p.kmodel === "classic" ? p.Ks : K(p.theta_s),
      boot: inp.custom ? null : ros.boot,
    };
  }

  // ------------------------------------------------------------------ render
  let pending = null;
  function update() { if (pending) cancelAnimationFrame(pending); pending = requestAnimationFrame(render); }

  function render() {
    pending = null;
    const r = compute();
    state.res = r;
    const silt = 100 - r.inp.sand - r.inp.clay;
    $("silt-text").innerHTML = isFinite(silt) && silt >= 0
      ? `Silt = ${silt}% &middot; USDA class: <b>${S.usdaTexture(r.inp.sand, r.inp.clay)}</b>` : "";
    $("bd-field").style.display = r.inp.useBD ? "" : "none";
    $("custom-fields").style.opacity = r.inp.custom ? 1 : 0.5;
    $("input-err").textContent = r.errs.join(" ");
    if (r.errs.length) return;

    // value boxes
    $("vb-tex").textContent = r.cls;
    $("vb-tex-s").textContent = `${r.inp.sand}% sand · ${r.silt}% silt · ${r.inp.clay}% clay`;
    $("vb-h").textContent = `${fmt(r.h)} cm`;
    $("vb-h-s").textContent = `${fmt(10 * r.h)} mm · ${fmt(S.cmToKpa(r.h))} kPa`;
    $("vb-k").textContent = `${fmt(S.cmdayToMmhr(r.k))} mm/hr`;
    $("vb-k-s").textContent = `${fmt(r.k)} cm/day`;
    $("vb-paw").textContent = fmt(r.fc - r.wp, 3);
    $("vb-paw-s").textContent = `FC ${fmt(r.fc, 3)} − WP ${fmt(r.wp, 3)} cm³/cm³`;

    // warnings
    const p = r.p;
    let warn = "";
    if (r.inp.theta >= p.theta_s) warn = `&theta; = ${r.inp.theta} is at or above the estimated saturated water content &theta;<sub>s</sub> = ${fmt(p.theta_s, 3)}, so the soil is treated as saturated (h = 0, K = K<sub>s</sub>).`;
    else if (r.inp.theta <= p.theta_r) warn = `&theta; = ${r.inp.theta} is at or below the residual water content &theta;<sub>r</sub> = ${fmt(p.theta_r, 3)}; suction is undefined (infinite) there.`;
    $("warn").innerHTML = warn ? `<div class="alert">${warn}</div>` : "";
    $("k-foot").innerHTML = p.kmodel === "classic"
      ? `K from Mualem&ndash;van Genuchten with K<sub>0</sub> = K<sub>s</sub>, L = ${fmt(p.Lc, 2)}.` + (r.boot && r.inp.band ? " Band shown on the suction axis." : "")
      : `K from Mualem&ndash;van Genuchten with Rosetta K<sub>0</sub> = ${fmt(p.K0)} cm/day and L = ${fmt(p.L, 3)}.`;

    state.band = r.boot && r.inp.band ? bandOf(r.boot) : null;
    drawRet(); drawK(); drawTable();
    if (!$("tab-tri").hidden) drawTriangle();
  }

  function quantile(sorted, q) {
    const pos = (sorted.length - 1) * q, lo = Math.floor(pos), hi = Math.ceil(pos);
    return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
  }
  function bandOf(boot) {
    const th05 = [], th95 = [], k05 = [], k95 = [];
    for (const h of HGRID) {
      const th = boot.map((b) => b.theta_r + (b.theta_s - b.theta_r) * S.se(h, b.alpha, b.n)).sort((a, b) => a - b);
      const kk = boot.map((b) => S.mualemK(S.se(h, b.alpha, b.n), b.n, b.Ks, 0.5)).sort((a, b) => a - b);
      th05.push(quantile(th, 0.05)); th95.push(quantile(th, 0.95));
      k05.push(S.cmdayToMmhr(quantile(kk, 0.05))); k95.push(S.cmdayToMmhr(quantile(kk, 0.95)));
    }
    return { th05, th95, k05, k95 };
  }

  const AXIS = { linecolor: "#999999", mirror: true, ticks: "outside", gridcolor: C.grid, zeroline: false };
  const LAYOUT = {
    margin: { l: 70, r: 70, t: 24, b: 56 }, paper_bgcolor: "#fff", plot_bgcolor: "#fff", showlegend: false,
    font: { family: "Helvetica Neue, Arial, sans-serif", size: 13, color: "#2B2B2B" }, hovermode: "closest",
  };
  const CONFIG = { responsive: true, displaylogo: false, modeBarButtonsToRemove: ["lasso2d", "select2d"] };
  const expTicks = (lo, hi) => {
    const v = [], t = [];
    for (let e = lo; e <= hi; e++) { v.push(Math.pow(10, e)); t.push(e === 0 ? "1" : e === 1 ? "10" : `10<sup>${e}</sup>`); }
    return { tickvals: v, ticktext: t };
  };
  const hline = (y, color, dash, xref = "paper") => ({ type: "line", xref, x0: 0, x1: 1, yref: "y", y0: y, y1: y, line: { color, width: 1.3, dash } });
  const vline = (x, color, dash) => ({ type: "line", xref: "x", x0: x, x1: x, yref: "paper", y0: 0, y1: 1, line: { color, width: 1, dash } });
  const label = (x, y, text, color, xanchor = "left", xref = "paper") => ({ xref, x, yref: "y", y: Math.log10(y), text, showarrow: false, font: { size: 11, color }, xanchor, yanchor: "bottom" });

  function drawRet() {
    const r = state.res; if (!r || r.errs.length) return;
    const p = r.p, xmax = Math.max(0.6, p.theta_s + 0.05);
    const th = HGRID.map((h) => S.theta(h, p));
    const traces = [];
    if (state.band) {
      traces.push({ x: state.band.th05, y: HGRID, mode: "lines", line: { width: 0 }, hoverinfo: "skip" });
      traces.push({ x: state.band.th95, y: HGRID, mode: "lines", line: { width: 0 }, fill: "tonextx", fillcolor: "rgba(229,117,31,0.22)", hoverinfo: "skip" });
    }
    traces.push({ x: th, y: HGRID, mode: "lines", line: { color: C.maroon, width: 3 },
      customdata: HGRID.map((h) => S.cmToKpa(h)),
      hovertemplate: "θ = %{x:.4f}<br>h = %{y:,.4~r} cm (%{customdata:,.4~r} kPa)<extra></extra>" });
    const shapes = [
      hline(r.fcCm, C.stone, "dash"), hline(r.wpCm, C.stone, "dash"), hline(1 / p.alpha, C.orange, "dot"),
      vline(p.theta_r, "#BBBBBB", "dot"), vline(p.theta_s, "#BBBBBB", "dot"),
    ];
    const ann = [
      label(0.01, r.fcCm, `field capacity (−${r.inp.fcKpa} kPa)`, C.stone),
      label(0.01, r.wpCm, "wilting point (−1500 kPa)", C.stone),
      label(0.99, 1 / p.alpha, "1/α", C.orange, "right"),
      { xref: "x", x: p.theta_r, yref: "paper", y: 1, text: "θ<sub>r</sub>", showarrow: false, yanchor: "bottom", font: { size: 12 } },
      { xref: "x", x: p.theta_s, yref: "paper", y: 1, text: "θ<sub>s</sub>", showarrow: false, yanchor: "bottom", font: { size: 12 } },
    ];
    if (isFinite(r.h) && r.h > 0.1) {
      shapes.push({ type: "line", xref: "x", x0: r.inp.theta, x1: r.inp.theta, yref: "y", y0: 0.1, y1: r.h, line: { color: C.maroon, dash: "dash", width: 1.2 } });
      shapes.push({ type: "line", xref: "x", x0: 0, x1: r.inp.theta, yref: "y", y0: r.h, y1: r.h, line: { color: C.maroon, dash: "dash", width: 1.2 } });
      traces.push({ x: [r.inp.theta], y: [r.h], mode: "markers", marker: { size: 13, color: C.orange, line: { color: C.maroon, width: 2 } },
        hovertemplate: `your θ = %{x}<br>h = ${fmt(r.h)} cm<extra></extra>` });
    }
    // invisible trace that carries the right-hand kPa axis
    traces.push({ x: [null], y: [1], yaxis: "y2", hoverinfo: "skip", showlegend: false });
    const kpaTicks = [0.01, 0.1, 1, 10, 100, 1000, 10000, 100000];
    Plotly.react("p-ret", traces, {
      ...LAYOUT, shapes, annotations: ann,
      xaxis: { ...AXIS, title: { text: "Volumetric water content, θ (cm³ cm⁻³)" }, range: [0, xmax] },
      yaxis: { ...AXIS, type: "log", range: [-1, 7], title: { text: "Suction, h (cm of water)" }, ...expTicks(-1, 7) },
      yaxis2: { type: "log", overlaying: "y", side: "right", range: [-1 - Math.log10(S.CM_PER_KPA), 7 - Math.log10(S.CM_PER_KPA)],
        title: { text: "Suction (kPa)" }, tickvals: kpaTicks, ticktext: kpaTicks.map((v) => v.toLocaleString("en-US")),
        showgrid: false, ticks: "outside", linecolor: "#999999" },
    }, CONFIG);
  }

  function drawK() {
    const r = state.res; if (!r || r.errs.length) return;
    const p = r.p, xh = state.kx === "h";
    const th = HGRID.map((h) => S.theta(h, p));
    const k = th.map((t) => S.cmdayToMmhr(r.K(t)));
    const kmax = S.cmdayToMmhr(Math.max(r.ksat, p.Ks)) * 3;
    const ylo = -12, yhi = Math.ceil(Math.log10(kmax));
    const x = xh ? HGRID : th;
    const traces = [];
    if (xh && state.band && p.kmodel === "classic") {
      traces.push({ x: HGRID, y: state.band.k05.map((v) => Math.max(v, 1e-30)), mode: "lines", line: { width: 0 }, hoverinfo: "skip" });
      traces.push({ x: HGRID, y: state.band.k95.map((v) => Math.max(v, 1e-30)), mode: "lines", line: { width: 0 }, fill: "tonexty", fillcolor: "rgba(229,117,31,0.22)", hoverinfo: "skip" });
    }
    traces.push({ x, y: k.map((v) => Math.max(v, 1e-30)), mode: "lines", line: { color: C.maroon, width: 3 },
      hovertemplate: (xh ? "h = %{x:,.4~r} cm" : "θ = %{x:.4f}") + "<br>K = %{y:.4~r} mm/hr<extra></extra>" });
    const kv = S.cmdayToMmhr(r.k), xv = xh ? r.h : r.inp.theta;
    const shapes = [hline(S.cmdayToMmhr(r.ksat), C.stone, "dot")];
    const ann = [label(xh ? 0.99 : 0.01, S.cmdayToMmhr(r.ksat),
      `${p.kmodel === "classic" ? "K<sub>s</sub>" : "K(θ<sub>s</sub>)"} = ${fmt(S.cmdayToMmhr(r.ksat))} mm/hr`, C.stone, xh ? "right" : "left")];
    if (isFinite(xv) && xv > 0 && kv > 0) {
      shapes.push({ type: "line", xref: "x", x0: xv, x1: xv, yref: "y", y0: 1e-12, y1: kv, line: { color: C.maroon, dash: "dash", width: 1.2 } });
      shapes.push({ type: "line", xref: "x", x0: xh ? 0.1 : 0, x1: xv, yref: "y", y0: kv, y1: kv, line: { color: C.maroon, dash: "dash", width: 1.2 } });
      traces.push({ x: [xv], y: [kv], mode: "markers", marker: { size: 13, color: C.orange, line: { color: C.maroon, width: 2 } },
        hovertemplate: `your θ = ${r.inp.theta}<br>K = ${fmt(kv)} mm/hr<extra></extra>` });
    }
    Plotly.react("p-k", traces, {
      ...LAYOUT, margin: { ...LAYOUT.margin, r: 24 }, shapes, annotations: ann,
      xaxis: xh ? { ...AXIS, type: "log", range: [-1, 7], title: { text: "Suction, h (cm of water)" }, ...expTicks(-1, 7) }
                : { ...AXIS, range: [0, Math.max(0.6, p.theta_s + 0.05)], title: { text: "Volumetric water content, θ (cm³ cm⁻³)" } },
      yaxis: { ...AXIS, type: "log", range: [ylo, yhi], title: { text: "Hydraulic conductivity, K (mm/hr)" }, ...expTicks(ylo, yhi) },
    }, CONFIG);
  }

  // ------------------------------------------------------------------ table + CSV
  function rows() {
    const r = state.res, p = r.p, sd = p.sd;
    const pm = (k) => (sd ? `± ${fmt(sd[k], 2)}` : "");
    const hK = isFinite(r.h);
    return [
      ["Soil", "Sand", r.inp.sand, "%", ""],
      ["Soil", "Silt", r.silt, "%", ""],
      ["Soil", "Clay", r.inp.clay, "%", ""],
      ["Soil", "USDA texture class", r.cls, "", ""],
      ["Soil", "Bulk density", r.inp.useBD ? fmt(r.inp.bd, 3) : "not used", "g/cm³", ""],
      ["Parameters", "Parameter source", p.source, "", ""],
      ["Parameters", "Residual water content, θr", fmt(p.theta_r), "cm³/cm³", pm("theta_r")],
      ["Parameters", "Saturated water content, θs", fmt(p.theta_s), "cm³/cm³", pm("theta_s")],
      ["Parameters", "α", fmt(p.alpha), "1/cm", pm("alpha")],
      ["Parameters", "n", fmt(p.n), "–", pm("n")],
      ["Parameters", "m = 1 − 1/n", fmt(1 - 1 / p.n), "–", ""],
      ["Parameters", "Saturated hydraulic conductivity, Ks", fmt(S.cmdayToMmhr(p.Ks)), "mm/hr", `${fmt(p.Ks)} cm/day`],
      ["Parameters", "Mualem K0 / L used", p.kmodel === "classic" ? `Ks / ${fmt(p.Lc, 2)}` : `${fmt(p.K0)} cm/day / ${fmt(p.L, 3)}`, "",
        p.kmodel === "classic" ? "classic Mualem–vG" : "Rosetta (Schaap & Leij 2000)"],
      ["Parameters", "Air-entry suction (approx.), 1/α", fmt(10 / p.alpha), "mm", `${fmt(1 / p.alpha)} cm = ${fmt(S.cmToKpa(1 / p.alpha))} kPa`],
      ["At your θ", "Volumetric water content, θ", fmt(r.inp.theta), "cm³/cm³", ""],
      ["At your θ", "Effective saturation, Se", fmt(r.se), "–", "(θ − θr)/(θs − θr)"],
      ["At your θ", "Suction (= −matric potential), h", fmt(10 * r.h), "mm", `${fmt(r.h)} cm = ${fmt(S.cmToKpa(r.h))} kPa`],
      ["At your θ", "Matric potential, ψ", hK ? fmt(-S.cmToKpa(r.h)) : "−∞", "kPa", ""],
      ["At your θ", "Hydraulic conductivity, K(θ)", fmt(S.cmdayToMmhr(r.k)), "mm/hr", `${fmt(r.k)} cm/day = ${fmt(S.cmdayToMms(r.k))} mm/s`],
      ["At your θ", "K(θ) / Ks", fmt(r.k / r.ksat), "–", ""],
      ["Water holding", `Field capacity (θ at −${r.inp.fcKpa} kPa)`, fmt(r.fc), "cm³/cm³", `${fmt(r.fcCm, 3)} cm suction`],
      ["Water holding", "Wilting point (θ at −1500 kPa)", fmt(r.wp), "cm³/cm³", "15,300 cm suction"],
      ["Water holding", "Plant-available water (FC − WP)", fmt(r.fc - r.wp), "cm³/cm³", `${fmt(1000 * (r.fc - r.wp), 3)} mm per m of soil`],
    ];
  }
  const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;");
  function drawTable() {
    let html = "<thead><tr><th>Property</th><th>Value</th><th>Units</th><th>Note</th></tr></thead><tbody>", sec = "";
    for (const [s, prop, val, unit, note] of rows()) {
      if (s !== sec) { html += `<tr class="sec"><td colspan="4">${esc(s)}</td></tr>`; sec = s; }
      html += `<tr><td>${esc(prop)}</td><td class="num">${esc(val)}</td><td>${esc(unit)}</td><td class="note">${esc(note)}</td></tr>`;
    }
    $("props").innerHTML = html + "</tbody>";
  }
  function download(name, text) {
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob(["﻿" + text], { type: "text/csv;charset=utf-8" }));
    a.download = name; document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  }
  // Numbers go to CSV without thousands separators and with an ASCII minus, so spreadsheets read them as numbers
  const csvCell = (v) => {
    let s = String(v);
    if (/^[\u2212-]?[\d,]+(\.\d+)?$/.test(s)) s = s.replace(/,/g, "").replace("\u2212", "-");
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  $("dl-props").addEventListener("click", () => {
    const r = state.res; if (!r || r.errs.length) return;
    const lines = [["Section", "Property", "Value", "Units", "Note"], ...rows()].map((row) => row.map(csvCell).join(","));
    download(`soil_properties_sand${r.inp.sand}_clay${r.inp.clay}_theta${r.inp.theta}.csv`, lines.join("\n"));
  });
  $("dl-curve").addEventListener("click", () => {
    const r = state.res; if (!r || r.errs.length) return;
    const lines = ["suction_cm,suction_kPa,theta,K_cm_per_day,K_mm_per_hr"];
    for (const h of HGRID) {
      const t = S.theta(h, r.p), kk = r.K(t);
      lines.push([h, S.cmToKpa(h), t, kk, S.cmdayToMmhr(kk)].map((v) => Number(v.toPrecision(8))).join(","));
    }
    download(`vg_curve_sand${r.inp.sand}_clay${r.inp.clay}.csv`, lines.join("\n"));
  });

  // ------------------------------------------------------------------ texture triangle (canvas)
  const TEX_COLS = {
    "sand": "#F3E4C8", "loamy sand": "#EBD7B3", "sandy loam": "#E4CA9E", "loam": "#D8C6A6", "silt loam": "#E2DCC9",
    "silt": "#EEEADC", "sandy clay loam": "#D7B48F", "clay loam": "#C9AE95", "silty clay loam": "#D3C7B7",
    "sandy clay": "#C79E80", "silty clay": "#C2B4A6", "clay": "#B89A88",
  };
  let triGrid = null;
  function drawTriangle() {
    const r = state.res, cv = $("triangle");
    const W = cv.clientWidth || 700, H = W / 1.15, dpr = window.devicePixelRatio || 1;
    cv.width = W * dpr; cv.height = H * dpr;
    const g = cv.getContext("2d"); g.setTransform(dpr, 0, 0, dpr, 0, 0); g.clearRect(0, 0, W, H);
    const pad = 0.1 * W, side = W - 2 * pad, ht = side * Math.sqrt(3) / 2, top = (H - ht) / 2 - 6;
    const xy = (sand, silt, clay) => [pad + side * (silt + clay / 2) / 100, top + ht - ht * clay / 100];
    if (!triGrid) {
      triGrid = [];
      for (let clay = 0; clay <= 100; clay += 0.5) for (let sand = 0; sand + clay <= 100; sand += 0.5) triGrid.push([sand, clay, S.usdaTexture(sand, clay)]);
    }
    const cell = side / 200 + 0.8, cent = {};
    for (const [sand, clay, cls] of triGrid) {
      const [x, y] = xy(sand, 100 - sand - clay, clay);
      g.fillStyle = TEX_COLS[cls]; g.fillRect(x - cell / 2, y - cell / 2, cell, cell);
      (cent[cls] = cent[cls] || [0, 0, 0]); cent[cls][0] += x; cent[cls][1] += y; cent[cls][2]++;
    }
    // clip overspill outside the triangle
    g.save(); g.globalCompositeOperation = "destination-in"; g.beginPath();
    g.moveTo(...xy(100, 0, 0)); g.lineTo(...xy(0, 100, 0)); g.lineTo(...xy(0, 0, 100)); g.closePath(); g.fill(); g.restore();
    g.strokeStyle = "rgba(255,255,255,.55)"; g.lineWidth = 0.7; g.fillStyle = "#555555"; g.font = "11px Helvetica Neue, Arial";
    for (let v = 10; v < 100; v += 10) {
      let a = xy(100 - v, 0, v), b = xy(0, 100 - v, v); g.beginPath(); g.moveTo(...a); g.lineTo(...b); g.stroke();
      g.textAlign = "right"; g.fillText(v, a[0] - 6, a[1] + 4);
      a = xy(v, 100 - v, 0); b = xy(v, 0, 100 - v); g.beginPath(); g.moveTo(...a); g.lineTo(...b); g.stroke();
      g.textAlign = "center"; g.fillText(v, a[0], a[1] + 16);
      a = xy(100 - v, v, 0); b = xy(0, v, 100 - v); g.beginPath(); g.moveTo(...a); g.lineTo(...b); g.stroke();
      g.textAlign = "left"; g.fillText(v, b[0] + 6, b[1] + 4);
    }
    g.strokeStyle = "#444444"; g.lineWidth = 1.5; g.beginPath();
    g.moveTo(...xy(100, 0, 0)); g.lineTo(...xy(0, 100, 0)); g.lineTo(...xy(0, 0, 100)); g.closePath(); g.stroke();
    g.fillStyle = "#4A3B30"; g.textAlign = "center"; g.font = `${Math.max(10, W / 62)}px Helvetica Neue, Arial`;
    for (const [cls, [sx, sy, n]] of Object.entries(cent)) g.fillText(cls, sx / n, sy / n + 4);
    g.fillStyle = "#2B2B2B"; g.font = "13px Helvetica Neue, Arial";
    g.fillText("% sand ←", pad + side / 2, top + ht + 36);
    g.save(); g.translate(pad + side * 0.2 - 30, top + ht * 0.55); g.rotate(-Math.PI / 3); g.fillText("% clay", 0, 0); g.restore();
    g.save(); g.translate(pad + side * 0.8 + 30, top + ht * 0.55); g.rotate(Math.PI / 3); g.fillText("% silt", 0, 0); g.restore();
    if (r && r.inp && r.silt >= 0 && isFinite(r.silt)) {
      const [x, y] = xy(r.inp.sand, r.silt, r.inp.clay);
      g.beginPath(); g.arc(x, y, 8, 0, 2 * Math.PI); g.fillStyle = C.maroon; g.fill(); g.lineWidth = 2.5; g.strokeStyle = "#fff"; g.stroke();
    }
  }
  window.addEventListener("resize", () => { if (!$("tab-tri").hidden) drawTriangle(); });

  // ------------------------------------------------------------------ start
  render();
  $("loading").hidden = true;
})();
