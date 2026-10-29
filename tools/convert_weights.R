# Convert the JSON exported by export_rosetta_weights.py into compact .rds files
# used by the app.  Usage: Rscript tools/convert_weights.R <json_dir> data
args <- commandArgs(trailingOnly = TRUE)
src <- args[1]; out <- args[2]
for (nm in c("rose3_mod2_0", "rose3_mod3_0", "rose1_unsat_k")) {
  j <- jsonlite::fromJSON(file.path(src, paste0(nm, ".json")), simplifyVector = TRUE)
  # jsonlite gives W[[layer]] as array (nboot, out, in) and b[[layer]] as matrix (nboot, out)
  W <- lapply(seq_along(j$layers$nnodes), function(i) {
    w <- j$W[[i]]; if (is.null(dim(w))) stop("unexpected shape"); w })
  b <- lapply(seq_along(j$layers$nnodes), function(i) {
    x <- j$b[[i]]; if (is.null(dim(x))) matrix(x, ncol = 1) else x })
  net <- list(name = j$name, ninput = j$ninput, noutput = j$noutput, nboot = j$nboot,
              activate = j$layers$activate,
              in_scale = j$inputs$scale, in_par = j$inputs$params,
              out_scale = j$outputs$scale, out_par = j$outputs$params,
              W = W, b = b)
  saveRDS(net, file.path(out, paste0(sub("_0$", "", nm), ".rds")), compress = "xz")
  cat(nm, "->", paste(dim(W[[1]]), collapse = "x"), paste(dim(W[[2]]), collapse = "x"), "\n")
}
