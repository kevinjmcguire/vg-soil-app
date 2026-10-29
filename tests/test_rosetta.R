# Check the R port of Rosetta3 against reference output from the USDA-ARS
# rosetta-soil Python package (v0.3.2, estimate_type = "arith").
# Run from the app root:  Rscript tests/test_rosetta.R
source("R/rosetta.R")
ref <- jsonlite::fromJSON("tests/rosetta_reference.json", simplifyVector = FALSE)
nm <- c("theta_r", "theta_s", "alpha", "n", "Ks", "K0", "L")
ok <- TRUE
for (r in ref) {
  x <- unlist(r$input)
  p <- rosetta_predict(x[1], x[2], x[3], if (length(x) > 3) x[4] else NULL)
  got <- c(p$theta_r, p$theta_s, p$alpha, p$n, p$Ks, p$K0, p$L)
  want <- unlist(r$mean)
  rel <- abs(got - want) / pmax(abs(want), 1e-12)
  pass <- all(rel < 1e-8) && p$code == r$code
  ok <- ok && pass
  cat(sprintf("%-22s code %d  max rel err %.1e  %s\n",
              paste(x, collapse = "/"), p$code, max(rel), if (pass) "PASS" else "FAIL"))
}
if (!ok) quit(status = 1)
cat("All Rosetta reference checks passed.\n")
