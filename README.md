# Soil Hydraulic Properties: van Genuchten–Mualem Explorer

A web app for teaching soil water, in two equivalent versions: a plain **HTML/JavaScript** page (published on GitHub Pages) and an **R Shiny** app. You give it soil **texture** (sand and clay %), optionally **bulk density**, and a **volumetric water content**. It reports:

- **van Genuchten (1980)** retention parameters (θr, θs, α, n) and saturated conductivity Ks, estimated with the **Rosetta3** pedotransfer functions (ported to JavaScript and R, with no web API needed)
- the **water retention curve** θ(h) and **Mualem (1976)** unsaturated hydraulic conductivity K(θ), with a 5–95% uncertainty band from the 1,000-member Rosetta ensemble
- **suction / matric potential** and **K** at the given water content, in mm, cm, and kPa (mm/hr, cm/day, and mm/s for K)
- **field capacity** (−33 kPa, or −10 kPa as an option), **wilting point** (−1500 kPa), **plant-available water**, and the approximate air-entry suction **1/α**
- the **USDA texture class**, with a texture triangle
- CSV downloads of the property table and the curve data

It replaces the Clapp–Hornberger/Cosby-based app previously used in the course.

## Use it online (no R needed)

**<https://kevinjmcguire.github.io/vg-soil-app/>**

The online version is the plain HTML/JavaScript page in `docs/`. It loads in about a second, works on phones and Chromebooks, and runs entirely in the browser, so no data leave your computer.

- **Publishing:** the workflow `.github/workflows/deploy-pages.yml` runs the JavaScript tests and publishes `docs/` on every push to `main`. One-time setup: repository **Settings → Pages → Build and deployment → Source → GitHub Actions**.
- **Smoke test:** after each deploy, `.github/workflows/smoke-test.yml` opens the live page in headless Chromium and saves screenshots and console output to the `smoke-test` branch.
- **Offline use:** you can also download the repository and open `docs/index.html` directly from disk; no web server is needed.

## Run the R Shiny version

You need R (≥ 4.1) and two packages:

```r
install.packages(c("shiny", "bslib"))
```

**From GitHub** (no download needed):

```r
shiny::runGitHub("vg-soil-app", "kevinjmcguire")
```

**From a local copy:** open `app.R` in RStudio and click **Run App**, or run `shiny::runApp("path/to/vg-soil-app")`.

## Other hosting options

GitHub Pages (above) is the default. The R Shiny version can also run on a server:

**shinyapps.io** (free tier available):

```r
install.packages("rsconnect")
rsconnect::setAccountInfo(name = "<account>", token = "<token>", secret = "<secret>")  # from shinyapps.io > Account > Tokens
rsconnect::deployApp("path/to/vg-soil-app", appName = "vg-soil-app")
```

**Posit Connect Cloud** (deploys straight from GitHub): on your own computer, run `rsconnect::writeManifest()` in the app folder, commit the resulting `manifest.json`, then connect the repository at <https://connect.posit.cloud>.

If you fork or rename the repository, update `GITHUB_URL` near the top of `app.R` and the `runGitHub()` line in the *Website code* tab.

## Repository layout

```
docs/index.html           browser version (GitHub Pages): page layout, methods and how-to text
docs/css/style.css        styles (Virginia Tech colors)
docs/js/rosetta.js        Rosetta3 networks in JavaScript
docs/js/soil.js           van Genuchten, Mualem, USDA texture, units
docs/js/app.js            inputs, plots, table, CSV downloads, texture triangle
docs/data/*.js            Rosetta network weights for the browser (CC0)
docs/vendor/              plotly.js 2.35.2 basic bundle (MIT)
app.R                     R Shiny version: UI and server
R/rosetta.R               Rosetta3 neural-network ensemble (models 2 and 3) + unsaturated-K network
R/vg.R                    van Genuchten retention and Mualem conductivity functions, unit helpers
R/texture.R               USDA texture classification and texture triangle
data/*.rds                Rosetta network weights (CC0, from USDA-ARS rosetta-soil v0.3.2)
www/methods.html          "Equations & methods" tab (rendered from docs_src/methods.md)
www/howto.html            "How to use" tab (rendered from docs_src/howto.md)
docs_src/                 Markdown sources for the help tabs; re-render with tools/render_docs.R
tests/test_rosetta.R      checks the R port against the Python reference output
tests/test_rosetta_js.js  checks the JavaScript port against the same reference
tools/                    scripts used to export and convert the Rosetta weights
```

Shiny automatically sources every file in `R/`.

## Testing

```sh
node tests/test_rosetta_js.js     # JavaScript version
Rscript tests/test_rosetta.R      # R version
```

Both compare against predictions from the USDA-ARS `rosetta-soil` Python package (v0.3.2) for eight soils covering both models.

- **R version:** agrees to about 1e-14 relative error.
- **JavaScript version:** agrees to about 1e-8; its weights are stored with 10 significant digits.

GitHub Actions runs both tests on every push.

## Methods in brief

| Quantity | Equation |
|---|---|
| Effective saturation | Se = [1 + (αh)ⁿ]⁻ᵐ, m = 1 − 1/n |
| Water content | θ = θr + (θs − θr)·Se |
| Suction at θ | h = (1/α)(Se^(−1/m) − 1)^(1/n) |
| Conductivity | K = K₀·Se^L·[1 − (1 − Se^(1/m))ᵐ]² |

- **Classic Mualem–van Genuchten (default):** K₀ = Ks and L = 0.5.
- **Rosetta option:** K₀ and L from Schaap & Leij (2000).
- **Rosetta inputs:** model 2 uses sand, silt and clay; model 3 also uses bulk density (0.5–2.0 g/cm³).
- **Reported parameters:** arithmetic means of the bootstrap ensemble, the same default as `rosetta-soil`.

## References

- Mualem, Y. (1976). *Water Resources Research* 12:513–522.
- Schaap, M.G., Leij, F.J. (2000). *Soil Sci. Soc. Am. J.* 64:843–851.
- Schaap, M.G., Leij, F.J., van Genuchten, M.Th. (2001). *J. Hydrology* 251:163–176.
- van Genuchten, M.Th. (1980). *Soil Sci. Soc. Am. J.* 44:892–898.
- Zhang, Y., Schaap, M.G. (2017). *J. Hydrology* 547:39–53.

## License

The app code is MIT licensed (see `LICENSE`). plotly.js (in `docs/vendor/`) is MIT licensed. The Rosetta network weights in `data/` and `docs/data/` come from the USDA-ARS [`rosetta-soil`](https://github.com/usda-ars-ussl/rosetta-soil) package and are released under CC0 1.0.
