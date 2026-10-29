"""Export Rosetta (Schaap et al., 2001; Zhang & Schaap, 2017) network weights
from the CC0-licensed `rosetta-soil` Python package (USDA-ARS, v0.3.2) to JSON,
so that tools/convert_weights.R can store them as .rds for the Shiny app.

Usage:  python export_rosetta_weights.py <path-to-unzipped-rosetta-soil-wheel> <outdir>
"""
import json, sys, numpy as np
src, out = sys.argv[1], sys.argv[2]
for name in ["rose3_mod2_0", "rose3_mod3_0", "rose1_unsat_k"]:
    d = np.load(f"{src}/rosetta/data/{name}.npz", allow_pickle=True)
    W = d["weights"].tolist(); B = d["biases"].tolist()
    nl = int(d["nlayer"].item())
    obj = {
        "name": str(d["name"].item()), "ninput": int(d["ninput"].item()),
        "noutput": int(d["noutput"].item()), "nboot": int(d["nboot"].item()),
        "layers": [{"nnodes": int(l["nnodes"]), "activate": l["activate"]} for l in d["layers"].tolist()],
        "inputs": [{"scale": c["scale"], "params": [float(x) for x in np.ravel(c["params"])]} for c in d["inputs"].tolist()],
        "outputs": [{"scale": c["scale"], "params": [float(x) for x in np.ravel(c["params"])]} for c in d["outputs"].tolist()],
        # W[layer] has shape (nboot, out_units, in_units); b[layer] (nboot, out_units)
        "W": [np.stack([np.asarray(W[k][i], float) for k in range(len(W))]).tolist() for i in range(nl)],
        "b": [np.stack([np.atleast_1d(np.asarray(B[k][i], float)) for k in range(len(B))]).tolist() for i in range(nl)],
    }
    json.dump(obj, open(f"{out}/{name}.json", "w"))
    print(name, "ok")
