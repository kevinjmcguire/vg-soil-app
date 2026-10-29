# Pre-render the help pages so the app does not depend on the `markdown` package.
# Run from the app root after editing docs_src/*.md:  Rscript tools/render_docs.R
for (nm in c("methods", "howto")) {
  html <- as.character(shiny::includeMarkdown(file.path("docs_src", paste0(nm, ".md"))))
  writeLines(enc2utf8(html), file.path("www", paste0(nm, ".html")), useBytes = TRUE)
  cat("wrote www/", nm, ".html\n", sep = "")
}
