// Check the JavaScript Rosetta port (docs/js/rosetta.js) against reference
// output from the USDA-ARS rosetta-soil Python package (v0.3.2, "arith").
// Run from the repository root:  node tests/test_rosetta_js.js
const fs = require("fs");
const { rosettaPredict } = require("../docs/js/rosetta.js");
// Weight files assign JSON to window.ROSETTA_NETS; evaluate them with a stub window
const window = {};
const load = (f) => { new Function("window", fs.readFileSync(`docs/data/${f}.js`, "utf8"))(window); return window.ROSETTA_NETS[f]; };
const nets = { mod2: load("rose3_mod2"), mod3: load("rose3_mod3"), unsatk: load("rose1_unsat_k") };
const ref = JSON.parse(fs.readFileSync("tests/rosetta_reference.json", "utf8"));
let ok = true;
for (const r of ref) {
  const [sa, si, cl, bd] = r.input;
  const p = rosettaPredict(nets, sa, si, cl, bd);
  const got = [p.theta_r, p.theta_s, p.alpha, p.n, p.Ks, p.K0, p.L];
  const rel = Math.max(...got.map((g, i) => Math.abs(g - r.mean[i]) / Math.max(Math.abs(r.mean[i]), 1e-12)));
  const pass = rel < 1e-6 && p.code === r.code;   // weights stored with 10 significant digits
  ok = ok && pass;
  console.log(`${r.input.join("/").padEnd(18)} code ${p.code}  max rel err ${rel.toExponential(1)}  ${pass ? "PASS" : "FAIL"}`);
}
if (!ok) process.exit(1);
console.log("All JavaScript Rosetta reference checks passed.");
