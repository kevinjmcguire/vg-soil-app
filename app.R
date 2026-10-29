# Soil Hydraulic Properties: van Genuchten-Mualem explorer
# ---------------------------------------------------------------------------
# Estimates van Genuchten (1980) retention parameters and saturated hydraulic
# conductivity from soil texture (and optionally bulk density) with the
# Rosetta3 pedotransfer functions, then computes water retention theta(h) and
# Mualem (1976) unsaturated hydraulic conductivity K(theta).
#
# Run locally:      shiny::runApp()          (from this folder)
# Run from GitHub:  shiny::runGitHub("vg-soil-app", "kevinjmcguire")
# Requires:         install.packages(c("shiny", "bslib"))
# Tests:            Rscript tests/test_rosetta.R   (also needs jsonlite)
# ---------------------------------------------------------------------------

library(shiny)
library(bslib)
# Files in R/ (rosetta.R, vg.R, texture.R) are sourced automatically by Shiny.

GITHUB_URL <- "https://github.com/kevinjmcguire/vg-soil-app"

MAROON <- "#861F41"; ORANGE <- "#E5751F"; STONE <- "#75787B"; CREAM <- "#F7F4EF"

theme <- bs_theme(
  version = 5, primary = MAROON, secondary = STONE, success = "#508590",
  info = ORANGE, base_font = font_collection("Acherus Grotesque", "Gineso", "Helvetica Neue", "Arial", "sans-serif"),
  "navbar-bg" = MAROON
)

fmt <- function(x, d = 4) signif_fmt(x, d)

# ---------------------------------------------------------------- UI
sidebar_ui <- sidebar(
  width = 330,
  h6("1. Soil texture", class = "text-primary fw-bold mb-0"),
  sliderInput("sand", "Sand (%)", 0, 100, 40, step = 1),
  sliderInput("clay", "Clay (%)", 0, 100, 20, step = 1),
  uiOutput("silt_text"),
  h6("2. Bulk density (optional)", class = "text-primary fw-bold mb-0 mt-2"),
  checkboxInput("use_bd", "Use bulk density in the estimate", TRUE),
  conditionalPanel("input.use_bd",
    numericInput("bd", HTML("Bulk density, &rho;<sub>b</sub> (g cm<sup>-3</sup>)"), 1.40,
                 min = 0.5, max = 2.0, step = 0.01)),
  h6("3. Water content", class = "text-primary fw-bold mb-0 mt-2"),
  numericInput("theta", HTML("Volumetric water content, &theta; (cm<sup>3</sup> cm<sup>-3</sup>)"),
               0.25, min = 0, max = 0.7, step = 0.001),
  accordion(
    open = FALSE,
    accordion_panel(
      "Options",
      radioButtons("fc_kpa", "Field capacity defined at",
                   choiceNames = list(HTML("&minus;33 kPa (330 cm; standard)"),
                                      HTML("&minus;10 kPa (100 cm; often used for sandy soils)")),
                   choiceValues = list("33", "10")),
      radioButtons("kmodel", "Unsaturated K model",
                   choiceNames = list(HTML("Mualem&ndash;van Genuchten with K<sub>s</sub>, L = 0.5 (classic)"),
                                      HTML("Rosetta K<sub>0</sub> and L (Schaap &amp; Leij, 2000)")),
                   choiceValues = list("classic", "rosetta")),
      checkboxInput("band", "Show Rosetta uncertainty band (5\u201395%)", TRUE)
    ),
    accordion_panel(
      "Custom van Genuchten parameters",
      checkboxInput("custom", "Override Rosetta estimates", FALSE),
      conditionalPanel("input.custom",
        numericInput("c_thr", HTML("&theta;<sub>r</sub>"), 0.05, step = 0.001),
        numericInput("c_ths", HTML("&theta;<sub>s</sub>"), 0.40, step = 0.001),
        numericInput("c_alpha", HTML("&alpha; (cm<sup>-1</sup>)"), 0.02, step = 0.0001),
        numericInput("c_n", "n", 1.5, step = 0.001),
        numericInput("c_ks", "Ks (cm/day)", 50, step = 0.1),
        numericInput("c_l", "L", 0.5, step = 0.1)
      )
    )
  )
)

curves_tab <- nav_panel(
  "Curves",
  layout_columns(
    col_widths = c(6, 6),
    card(full_screen = TRUE, card_header("Water retention curve"),
         plotOutput("p_ret", height = "460px"),
         card_footer(class = "small text-muted", HTML(
           "Orange dot: your &theta;. Shaded band: 5&ndash;95% range of the 1,000 Rosetta predictions.
            Dotted orange line: approximate air-entry suction, 1/&alpha;."))),
    card(full_screen = TRUE,
         card_header(class = "d-flex justify-content-between align-items-center",
                     "Hydraulic conductivity",
                     radioButtons("kx", NULL, inline = TRUE,
                                  choiceNames = list(HTML("vs. &theta;"), "vs. suction"),
                                  choiceValues = list("theta", "h"))),
         plotOutput("p_k", height = "460px"))
  ),
  uiOutput("warn")
)

table_tab <- nav_panel(
  "Properties table",
  card(
    card_header(class = "d-flex justify-content-between align-items-center",
                "Properties of the specified soil",
                div(downloadButton("dl_props", "Table (CSV)", class = "btn-sm btn-outline-primary"),
                    downloadButton("dl_curve", "Curve data (CSV)", class = "btn-sm btn-outline-primary"))),
    tableOutput("props")
  )
)

texture_tab <- nav_panel(
  "Texture triangle",
  card(card_header("USDA soil texture triangle"), plotOutput("p_tri", height = "560px"))
)

methods_tab <- nav_panel(
  "Equations & methods",
  card(withMathJax(includeHTML("www/methods.html")))
)

help_tab <- nav_panel(
  "How to use",
  card(includeHTML("www/howto.html"))
)

about_tab <- nav_panel(
  "Website code",
  card(
    p("This app is open source. Source code, Rosetta weights, and tests:"),
    tags$p(tags$a(href = GITHUB_URL, target = "_blank", GITHUB_URL)),
    p("Run it on your own computer in R:"),
    tags$pre("install.packages(c(\"shiny\", \"bslib\"))\nshiny::runGitHub(\"vg-soil-app\", \"kevinjmcguire\")")
  )
)

ui <- page_sidebar(
  window_title = "Soil Hydraulic Properties",
  title = div(style = sprintf("background:%s; color:#fff; padding:.6rem 1.1rem; border-bottom:5px solid %s; font-size:1.25rem;",
                              MAROON, ORANGE),
              span("Soil Hydraulic Properties", class = "fw-bold"),
              span(" \u00b7 van Genuchten\u2013Mualem", style = "opacity:.85;")),
  theme = theme,
  fillable = FALSE,
  sidebar = sidebar_ui,
  tags$head(tags$style(HTML(sprintf("
    .bslib-value-box .value-box-title { font-size: .85rem; }
    .bslib-value-box .value-box-value { font-size: 1.45rem; }
    .bslib-page-title, .navbar { background: #861F41 !important; color: #fff !important; border-bottom: 5px solid %s; padding: .55rem 1rem; }
    .bslib-page-title * { color: #fff !important; }
    table.props td, table.props th { padding: .3rem .6rem; }
    table.props tr.sec td { background: %s; color: %s; font-weight: 700; }
    .irs--shiny .irs-bar, .irs--shiny .irs-single { background: %s; border-color: %s; }
  ", ORANGE, CREAM, MAROON, MAROON, MAROON)))),
  layout_columns(
    fill = FALSE, col_widths = c(3, 3, 3, 3),
    value_box("Texture class", textOutput("vb_tex"), theme = value_box_theme(bg = MAROON, fg = "white")),
    value_box("Suction at \u03b8", uiOutput("vb_h"), theme = value_box_theme(bg = "#5E0F2C", fg = "white")),
    value_box("K at \u03b8", uiOutput("vb_k"), theme = value_box_theme(bg = ORANGE, fg = "white")),
    value_box("Plant-available water", uiOutput("vb_paw"), theme = value_box_theme(bg = STONE, fg = "white"))
  ),
  navset_card_underline(curves_tab, table_tab, texture_tab, methods_tab, help_tab, about_tab)
)

# ---------------------------------------------------------------- server
server <- function(input, output, session) {

  silt <- reactive(100 - input$sand - input$clay)

  output$silt_text <- renderUI({
    s <- silt()
    if (s < 0) div(class = "text-danger small", "Sand + clay exceeds 100%.")
    else div(class = "small text-muted", sprintf("Silt = %d%%  \u00b7  USDA class: ", s),
             tags$b(class = "text-primary", usda_texture(input$sand, input$clay)))
  })

  ros <- reactive({
    validate(need(silt() >= 0, "Sand + clay must not exceed 100%."))
    bd <- if (isTRUE(input$use_bd)) input$bd else NULL
    if (!is.null(bd)) validate(need(!is.na(bd) && bd >= 0.5 && bd <= 2.0,
                                    "Bulk density must be between 0.5 and 2.0 g/cm\u00b3."))
    rosetta_predict(input$sand, silt(), input$clay, bd)
  })

  # Prefill the custom inputs with the current Rosetta values when switched on
  observeEvent(input$custom, {
    if (isTRUE(input$custom)) {
      r <- ros()
      updateNumericInput(session, "c_thr", value = round(r$theta_r, 4))
      updateNumericInput(session, "c_ths", value = round(r$theta_s, 4))
      updateNumericInput(session, "c_alpha", value = signif(r$alpha, 4))
      updateNumericInput(session, "c_n", value = round(r$n, 4))
      updateNumericInput(session, "c_ks", value = signif(r$Ks, 4))
    }
  })

  pars <- reactive({
    r <- ros()
    if (isTRUE(input$custom)) {
      p <- list(theta_r = input$c_thr, theta_s = input$c_ths, alpha = input$c_alpha,
                n = input$c_n, Ks = input$c_ks, K0 = input$c_ks, L = input$c_l)
      validate(need(all(!is.na(unlist(p))), "Enter all custom parameters."),
               need(p$theta_r >= 0 && p$theta_r < p$theta_s && p$theta_s < 1, "Need 0 \u2264 \u03b8r < \u03b8s < 1."),
               need(p$alpha > 0 && p$n > 1 && p$Ks > 0, "Need \u03b1 > 0, n > 1, Ks > 0."))
      p$source <- "Custom parameters"
      p$kmodel <- "classic"          # custom: K0 = Ks with the user's L
      p$Lclassic <- p$L
    } else {
      p <- r[c("theta_r", "theta_s", "alpha", "n", "Ks", "K0", "L")]
      p$source <- r$model
      p$kmodel <- input$kmodel
      p$Lclassic <- 0.5
    }
    p
  })

  kfun <- function(theta, p) {
    se <- vg_se_theta(theta, p)
    if (p$kmodel == "classic") mualem_k(se, p$n, p$Ks, p$Lclassic) else mualem_k(se, p$n, p$K0, p$L)
  }

  res <- reactive({
    p <- pars(); th <- input$theta
    validate(need(!is.na(th) && th > 0, "Enter a water content greater than 0."))
    fc_cm <- kpa_to_cm(as.numeric(input$fc_kpa)); wp_cm <- kpa_to_cm(1500)
    h <- vg_h(th, p)
    list(p = p, theta = th, se = vg_se_theta(th, p), h = h, K = kfun(th, p),
         fc = vg_theta(fc_cm, p), wp = vg_theta(wp_cm, p), fc_cm = fc_cm, wp_cm = wp_cm,
         Ksat = if (p$kmodel == "classic") p$Ks else kfun(p$theta_s, p))
  })

  # -- value boxes
  output$vb_tex <- renderText(if (silt() < 0) "\u2014" else usda_texture(input$sand, input$clay))
  output$vb_h <- renderUI({
    r <- res()
    HTML(sprintf("%s cm<div style='font-size:.8rem;opacity:.9'>%s mm &middot; %s kPa</div>",
                 fmt(r$h), fmt(10 * r$h), fmt(cm_to_kpa(r$h))))
  })
  output$vb_k <- renderUI({
    r <- res()
    HTML(sprintf("%s mm/hr<div style='font-size:.8rem;opacity:.9'>%s cm/day</div>",
                 fmt(cmday_to_mmhr(r$K)), fmt(r$K)))
  })
  output$vb_paw <- renderUI({
    r <- res()
    HTML(sprintf("%s<div style='font-size:.8rem;opacity:.9'>FC %s \u2212 WP %s cm\u00b3/cm\u00b3</div>",
                 fmt(r$fc - r$wp, 3), fmt(r$fc, 3), fmt(r$wp, 3)))
  })

  output$warn <- renderUI({
    r <- res(); p <- r$p
    if (r$theta >= p$theta_s)
      div(class = "alert alert-warning", HTML(sprintf(
        "&theta; = %s is at or above the estimated saturated water content &theta;<sub>s</sub> = %s, so the soil is treated as saturated (h = 0, K = K<sub>s</sub>).",
        r$theta, fmt(p$theta_s, 3))))
    else if (r$theta <= p$theta_r)
      div(class = "alert alert-warning", HTML(sprintf(
        "&theta; = %s is at or below the residual water content &theta;<sub>r</sub> = %s; suction is undefined (infinite) there.",
        r$theta, fmt(p$theta_r, 3))))
  })

  hgrid <- 10^seq(-1, 7, length.out = 241)

  band <- reactive({
    if (!isTRUE(input$band) || isTRUE(input$custom)) return(NULL)
    b <- ros()$boot
    th <- sapply(hgrid, function(h) b$theta_r + (b$theta_s - b$theta_r) * vg_se(h, b$alpha, b$n))
    kk <- sapply(hgrid, function(h) mualem_k(vg_se(h, b$alpha, b$n), b$n, b$Ks, 0.5))
    list(th = apply(th, 2, quantile, c(.05, .95)),
         k = if (input$kmodel == "classic") apply(kk, 2, quantile, c(.05, .95)) else NULL,
         thk = th)
  })

  log_axis <- function(side, lim) {
    e <- floor(log10(lim[1])):ceiling(log10(lim[2]))
    axis(side, at = 10^e, labels = parse(text = paste0("10^", e)), las = 1)
    axis(side, at = as.vector(outer(2:9, 10^e)), labels = FALSE, tcl = -0.2)
  }

  output$p_ret <- renderPlot(res = 110, expr = {
    r <- res(); p <- r$p
    th <- vg_theta(hgrid, p)
    par(mar = c(4.5, 5, 1, 4.5), family = "sans")
    plot(th, hgrid, log = "y", type = "n", xlim = c(0, max(0.6, p$theta_s + 0.05)),
         ylim = c(0.1, 1e7), axes = FALSE, xlab = expression("Volumetric water content, " * theta ~ (cm^3 ~ cm^-3)),
         ylab = "Suction, h (cm of water)")
    box(col = "#999999"); axis(1); log_axis(2, c(0.1, 1e7))
    kp <- c(0.1, 1, 10, 100, 1000, 1e4, 1e5)
    axis(4, at = kpa_to_cm(kp), labels = c("0.1", "1", "10", "100", "1,000", "10,000", "100,000"), las = 1, cex.axis = 0.8)
    mtext("Suction (kPa)", side = 4, line = 3.2)
    abline(h = 10^(-1:7), col = "#EEEEEE")
    b <- band()
    if (!is.null(b)) polygon(c(b$th[1, ], rev(b$th[2, ])), c(hgrid, rev(hgrid)),
                             col = adjustcolor(ORANGE, 0.22), border = NA)
    abline(h = c(r$fc_cm, r$wp_cm), lty = 2, col = STONE)
    text(0.005, r$fc_cm, sprintf("field capacity (\u2212%s kPa)", input$fc_kpa), adj = c(0, -0.4), cex = 0.8, col = STONE)
    text(0.005, r$wp_cm, "wilting point (\u22121500 kPa)", adj = c(0, -0.4), cex = 0.8, col = STONE)
    abline(h = 1 / p$alpha, lty = 3, col = ORANGE)
    text(max(0.6, p$theta_s + 0.05), 1 / p$alpha, expression(1 / alpha), adj = c(1, -0.4), col = ORANGE, cex = 0.9)
    abline(v = c(p$theta_r, p$theta_s), lty = 3, col = "#BBBBBB")
    mtext(c(expression(theta[r]), expression(theta[s])), side = 3, at = c(p$theta_r, p$theta_s), line = -0.1, cex = 0.85)
    lines(th, hgrid, lwd = 3, col = MAROON)
    if (is.finite(r$h) && r$h > 0.1) {
      segments(r$theta, 0.1, r$theta, r$h, lty = 2, col = MAROON)
      segments(0, r$h, r$theta, r$h, lty = 2, col = MAROON)
      points(r$theta, r$h, pch = 21, bg = ORANGE, col = MAROON, cex = 2, lwd = 2)
    }
  })

  output$p_k <- renderPlot(res = 110, expr = {
    r <- res(); p <- r$p
    th <- vg_theta(hgrid, p)
    k <- cmday_to_mmhr(kfun(th, p))
    kmax <- cmday_to_mmhr(max(r$Ksat, p$Ks)) * 3
    ylim <- c(1e-12, kmax)
    par(mar = c(4.5, 5, 1, 1))
    xh <- input$kx == "h"
    x <- if (xh) hgrid else th
    plot(x, pmax(k, 1e-30), log = if (xh) "xy" else "y", type = "n", ylim = ylim, axes = FALSE,
         xlim = if (xh) c(0.1, 1e7) else c(0, max(0.6, p$theta_s + 0.05)),
         xlab = if (xh) "Suction, h (cm of water)" else expression("Volumetric water content, " * theta ~ (cm^3 ~ cm^-3)),
         ylab = "Hydraulic conductivity, K (mm/hr)")
    box(col = "#999999"); log_axis(2, ylim)
    if (xh) log_axis(1, c(0.1, 1e7)) else axis(1)
    abline(h = 10^(-12:4), col = "#EEEEEE")
    b <- band()
    if (!is.null(b) && !is.null(b$k)) {
      if (xh) polygon(c(hgrid, rev(hgrid)), cmday_to_mmhr(pmax(c(b$k[1, ], rev(b$k[2, ])), 1e-30)),
                      col = adjustcolor(ORANGE, 0.22), border = NA)
    }
    abline(h = cmday_to_mmhr(r$Ksat), lty = 3, col = STONE)
    text(if (xh) 1e7 else 0.005, cmday_to_mmhr(r$Ksat), sprintf("%s = %s mm/hr", if (p$kmodel == "classic") "Ks" else "K(\u03b8s)", fmt(cmday_to_mmhr(r$Ksat), 4)),
         adj = c(if (xh) 1 else 0, -0.4), cex = 0.8, col = STONE)
    lines(x, k, lwd = 3, col = MAROON)
    rx <- if (xh) r$h else r$theta
    if (is.finite(rx) && rx > 0 && r$K > 0) {
      ky <- cmday_to_mmhr(r$K)
      segments(rx, ylim[1], rx, ky, lty = 2, col = MAROON)
      segments(if (xh) 0.1 else 0, ky, rx, ky, lty = 2, col = MAROON)
      points(rx, ky, pch = 21, bg = ORANGE, col = MAROON, cex = 2, lwd = 2)
    }
  })

  output$p_tri <- renderPlot(plot_texture_triangle(input$sand, input$clay, MAROON), res = 110)

  # -- properties table
  props_df <- reactive({
    r <- res(); p <- r$p; sdv <- if (isTRUE(input$custom)) NULL else ros()$sd
    pm <- function(k, d = 3) if (is.null(sdv)) "" else paste0("\u00b1 ", fmt(sdv[[k]], 2))
    row <- function(sec, prop, val, unit = "", note = "") data.frame(Section = sec, Property = prop, Value = val, Units = unit, Note = note)
    rbind(
      row("Soil", "Sand", input$sand, "%"),
      row("Soil", "Silt", silt(), "%"),
      row("Soil", "Clay", input$clay, "%"),
      row("Soil", "USDA texture class", usda_texture(input$sand, input$clay)),
      row("Soil", "Bulk density", if (isTRUE(input$use_bd)) fmt(input$bd, 3) else "not used", "g/cm\u00b3"),
      row("Parameters", "Parameter source", p$source),
      row("Parameters", "Residual water content, \u03b8r", fmt(p$theta_r), "cm\u00b3/cm\u00b3", pm("theta_r")),
      row("Parameters", "Saturated water content, \u03b8s", fmt(p$theta_s), "cm\u00b3/cm\u00b3", pm("theta_s")),
      row("Parameters", "\u03b1", fmt(p$alpha), "1/cm", pm("alpha")),
      row("Parameters", "n", fmt(p$n), "\u2013", pm("n")),
      row("Parameters", "m = 1 \u2212 1/n", fmt(1 - 1 / p$n), "\u2013"),
      row("Parameters", "Saturated hydraulic conductivity, Ks", fmt(cmday_to_mmhr(p$Ks)), "mm/hr", paste(fmt(p$Ks), "cm/day")),
      row("Parameters", "Mualem K\u2080 / L used",
          if (p$kmodel == "classic") paste0("Ks / ", p$Lclassic) else paste0(fmt(p$K0), " cm/day / ", fmt(p$L, 3)), "",
          if (p$kmodel == "classic") "classic Mualem\u2013vG" else "Rosetta (Schaap & Leij 2000)"),
      row("Parameters", "Air-entry suction (approx.), 1/\u03b1", fmt(10 / p$alpha), "mm",
          paste0(fmt(1 / p$alpha), " cm = ", fmt(cm_to_kpa(1 / p$alpha)), " kPa")),
      row("At your \u03b8", "Volumetric water content, \u03b8", fmt(r$theta, 4), "cm\u00b3/cm\u00b3"),
      row("At your \u03b8", "Effective saturation, Se", fmt(r$se), "\u2013", "(\u03b8 \u2212 \u03b8r)/(\u03b8s \u2212 \u03b8r)"),
      row("At your \u03b8", "Suction (= \u2212matric potential), h", fmt(10 * r$h), "mm",
          paste0(fmt(r$h), " cm = ", fmt(cm_to_kpa(r$h)), " kPa")),
      row("At your \u03b8", "Matric potential, \u03c8", if (is.finite(r$h)) fmt(-cm_to_kpa(r$h)) else "\u2212\u221e", "kPa"),
      row("At your \u03b8", "Hydraulic conductivity, K(\u03b8)", fmt(cmday_to_mmhr(r$K)), "mm/hr",
          paste0(fmt(r$K), " cm/day = ", fmt(cmday_to_mms(r$K)), " mm/s")),
      row("At your \u03b8", "K(\u03b8) / Ks", fmt(r$K / r$Ksat), "\u2013"),
      row("Water holding", sprintf("Field capacity (\u03b8 at \u2212%s kPa)", input$fc_kpa), fmt(r$fc), "cm\u00b3/cm\u00b3",
          paste(fmt(r$fc_cm, 3), "cm suction")),
      row("Water holding", "Wilting point (\u03b8 at \u22121500 kPa)", fmt(r$wp), "cm\u00b3/cm\u00b3", "15,300 cm suction"),
      row("Water holding", "Plant-available water (FC \u2212 WP)", fmt(r$fc - r$wp), "cm\u00b3/cm\u00b3",
          paste(fmt(1000 * (r$fc - r$wp), 3), "mm per m of soil"))
    )
  })

  output$props <- renderTable({
    d <- props_df(); out <- NULL
    for (s in unique(d$Section)) {
      out <- rbind(out, data.frame(Property = paste0("<b>", s, "</b>"), Value = "", Units = "", Note = ""),
                   d[d$Section == s, c("Property", "Value", "Units", "Note")])
    }
    out
  }, sanitize.text.function = identity, striped = TRUE, hover = TRUE, spacing = "s", width = "100%",
     class = "props")

  output$dl_props <- downloadHandler(
    filename = function() sprintf("soil_properties_sand%d_clay%d_theta%s.csv", input$sand, input$clay, input$theta),
    content = function(f) write.csv(props_df(), f, row.names = FALSE))

  output$dl_curve <- downloadHandler(
    filename = function() sprintf("vg_curve_sand%d_clay%d.csv", input$sand, input$clay),
    content = function(f) {
      p <- pars(); th <- vg_theta(hgrid, p)
      write.csv(data.frame(suction_cm = hgrid, suction_kPa = cm_to_kpa(hgrid), theta = th,
                           K_cm_per_day = kfun(th, p), K_mm_per_hr = cmday_to_mmhr(kfun(th, p))),
                f, row.names = FALSE)
    })
}

shinyApp(ui, server)
