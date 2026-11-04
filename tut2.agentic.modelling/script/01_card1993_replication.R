#!/usr/bin/env Rscript
# ============================================================================
# Card (1993) replication: "Using Geographic Variation in College Proximity to
# Estimate the Return to Schooling" (NBER Working Paper No. 4483)
#
# Research question: what is the effect of education on income?
#
# This single script:
#   1. installs (if needed) and loads every package used below;
#   2. exports the raw NLS Young Men extract distributed with the wooldridge
#      package and builds the cleaned analysis file (n = 3,010);
#   3. estimates Model 1 (OLS, no controls), Model 2 (OLS, with controls), and
#      Model 3 (2SLS, schooling instrumented by nearc4);
#   4. draws the education-income scatter plot and the effect-size plot
#      following docs/APA/FIGURE.md;
#   5. exports an APA-7 table in Markdown and LaTeX, and a results paragraph
#      generated entirely from the fitted models (docs/APA/TABLE.md,
#      LATEX-APA.md, STATISTICS.md).
#
# Usage (from the project root):
#   Rscript script/01_card1993_replication.R
# ============================================================================

## ---------------------------------------------------------------- packages --
cran_repo <- "https://cloud.r-project.org"

required_packages <- c(
  "wooldridge",  # Card (1993) NLS data
  "ggplot2",     # figures
  "dplyr",       # data manipulation
  "AER",         # ivreg() for 2SLS
  "broom",       # tidy model output
  "kableExtra"   # APA tables
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0) {
  message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages, repos = cran_repo, dependencies = TRUE)
}
invisible(lapply(required_packages, function(pkg) {
  suppressPackageStartupMessages(
    library(pkg, character.only = TRUE, quietly = TRUE)
  )
}))

## ------------------------------------------------------------------- paths --
script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
project_root <- if (length(script_arg) == 1) {
  normalizePath(file.path(dirname(sub("^--file=", "", script_arg)), ".."))
} else {
  normalizePath(getwd())
}

path <- function(...) file.path(project_root, ...)

for (dir in c("data/raw", "data/cleaned", "data/process", "data/result",
              "output/fig", "output/tex")) {
  dir.create(path(dir), recursive = TRUE, showWarnings = FALSE)
}

## --------------------------------------------------------------- utilities --
# APA number format: three decimals and no leading zero (TABLE.md, rule 2).
fmt <- function(x, digits = 3) {
  s <- formatC(x, format = "f", digits = digits)
  s <- sub("^(-?)0\\.", "\\1.", s)
  s <- sub("^-\\.0+$", paste0(".", strrep("0", digits)), s)
  s
}

# Text numbers keep the leading zero (statistical prose).
fmt0 <- function(x, digits = 3) formatC(x, format = "f", digits = digits)

fmt_p <- function(p, digits = 3) {
  if (is.na(p)) return("NA")
  if (p < .001) return("< .001")
  paste("=", sub("^0", "", formatC(p, format = "f", digits = digits)))
}

fmt_n <- function(x) format(x, big.mark = ",", scientific = FALSE)

pct_change <- function(b) 100 * (exp(b) - 1)

## -------------------------------------------------------------------- data --
# The 3,010-man extract used by Card (1993) ships with the wooldridge package
# as `card`; it is the NLS Young Men cohort with valid wage and schooling data.
data("card", package = "wooldridge")
raw_data <- as.data.frame(card)
write.csv(raw_data, path("data/raw/card1993_nls_raw.csv"), row.names = FALSE)

controls <- c(
  "black", "south", "smsa", "smsa66",
  paste0("reg66", 2:9),  # region 1 (reg661, Northeast) is the reference
  "exper", "expersq"
)
model_vars <- c("lwage", "educ", controls, "nearc4")

analysis_data <- raw_data[complete.cases(raw_data[, model_vars]), ]
stopifnot(nrow(analysis_data) == 3010)

analysis_data <- analysis_data[, c("id", "wage", "lwage", "educ", "nearc4",
                                   "black", "south", "smsa", "smsa66",
                                   paste0("reg66", 2:9), "exper", "expersq")]
write.csv(analysis_data, path("data/cleaned/card1993_analysis.csv"),
          row.names = FALSE)

descriptives <- data.frame(
  variable = c("Log hourly wage", "Hourly wage (1976 cents)",
               "Years of schooling", "Grew up near a 4-year college",
               "Black", "South", "SMSA", "SMSA in 1966",
               "Experience (years)", "Experience squared"),
  mean = c(mean(analysis_data$lwage), mean(analysis_data$wage),
           mean(analysis_data$educ), mean(analysis_data$nearc4),
           mean(analysis_data$black), mean(analysis_data$south),
           mean(analysis_data$smsa), mean(analysis_data$smsa66),
           mean(analysis_data$exper), mean(analysis_data$expersq)),
  sd = c(sd(analysis_data$lwage), sd(analysis_data$wage),
         sd(analysis_data$educ), sd(analysis_data$nearc4),
         sd(analysis_data$black), sd(analysis_data$south),
         sd(analysis_data$smsa), sd(analysis_data$smsa66),
         sd(analysis_data$exper), sd(analysis_data$expersq))
)
write.csv(descriptives, path("data/result/descriptives.csv"), row.names = FALSE)

## ------------------------------------------------------------------ models --
fml_controls <- paste(controls, collapse = " + ")

model_1 <- lm(lwage ~ educ, data = analysis_data)
model_2 <- lm(as.formula(paste("lwage ~ educ +", fml_controls)),
              data = analysis_data)
model_3 <- AER::ivreg(
  as.formula(paste("lwage ~ educ +", fml_controls, "| nearc4 +", fml_controls)),
  data = analysis_data
)
first_stage <- lm(as.formula(paste("educ ~ nearc4 +", fml_controls)),
                  data = analysis_data)

saveRDS(list(model_1 = model_1, model_2 = model_2, model_3 = model_3,
             first_stage = first_stage),
        path("data/process/card1993_models.rds"))

## --------------------------------------------------------- model extraction --
model_labels <- c(
  model_1 = "Model 1: OLS (no controls)",
  model_2 = "Model 2: OLS (with controls)",
  model_3 = "Model 3: 2SLS (nearc4)"
)

tidy_with_model <- function(model, label) {
  out <- broom::tidy(model, conf.int = TRUE)
  out$model <- label
  out
}

coefficient_table <- dplyr::bind_rows(
  tidy_with_model(model_1, model_labels[["model_1"]]),
  tidy_with_model(model_2, model_labels[["model_2"]]),
  tidy_with_model(model_3, model_labels[["model_3"]]),
  tidy_with_model(first_stage, "First stage: educ on nearc4")
)[, c("model", "term", "estimate", "std.error", "statistic", "p.value",
      "conf.low", "conf.high")]
write.csv(coefficient_table, path("data/result/model_coefficients.csv"),
          row.names = FALSE)

diagnostics_3 <- summary(model_3, diagnostics = TRUE)$diagnostics
first_stage_f <- unname(diagnostics_3["Weak instruments", "statistic"])
first_stage_df1 <- unname(diagnostics_3["Weak instruments", "df1"])
first_stage_df2 <- unname(diagnostics_3["Weak instruments", "df2"])
first_stage_p <- unname(diagnostics_3["Weak instruments", "p-value"])

model_fit <- data.frame(
  model = unname(model_labels),
  n = c(nobs(model_1), nobs(model_2), nobs(model_3)),
  r_squared = c(summary(model_1)$r.squared,
                summary(model_2)$r.squared,
                summary(model_3)$r.squared),
  adj_r_squared = c(summary(model_1)$adj.r.squared,
                    summary(model_2)$adj.r.squared,
                    summary(model_3)$adj.r.squared),
  first_stage_f = c(NA, NA, first_stage_f),
  first_stage_df1 = c(NA, NA, first_stage_df1),
  first_stage_df2 = c(NA, NA, first_stage_df2),
  first_stage_p = c(NA, NA, first_stage_p)
)
write.csv(model_fit, path("data/result/model_fit.csv"), row.names = FALSE)

# Effect sizes for schooling, expressed in log points and as implied wage changes.
educ_effects <- coefficient_table[
  coefficient_table$term == "educ" & grepl("^Model", coefficient_table$model),
]
educ_effects$implied_pct_change <- pct_change(educ_effects$estimate)
educ_effects$implied_pct_low <- pct_change(educ_effects$conf.low)
educ_effects$implied_pct_high <- pct_change(educ_effects$conf.high)
write.csv(educ_effects, path("data/result/effect_sizes.csv"), row.names = FALSE)

# Side-by-side comparison with the published Card (1993) headline estimates.
replication_comparison <- data.frame(
  quantity = c(
    "OLS return to schooling (Card, 1993, conclusion)",
    "OLS return to schooling (Model 2, this replication)",
    "2SLS return to schooling (Card, 1993, Table 3, column 5)",
    "2SLS return to schooling (Model 3, this replication)"
  ),
  estimate = c(0.073, coef(model_2)[["educ"]], 0.132, coef(model_3)[["educ"]]),
  std_error = c(NA, summary(model_2)$coefficients["educ", "Std. Error"],
                0.055, summary(model_3)$coefficients["educ", "Std. Error"])
)
write.csv(replication_comparison, path("data/result/replication_comparison.csv"),
          row.names = FALSE)

## ---------------------------------------------------------------- figure 1 --
# Education is recorded in whole years, so points are jittered horizontally;
# green markers show mean log wages by year of schooling and the vermillion
# line is the fitted OLS slope from Model 1.
figure_1 <- ggplot(analysis_data, aes(x = educ, y = lwage)) +
  geom_jitter(aes(colour = "Individual men"), width = 0.18, height = 0,
              size = 0.5, alpha = 0.06) +
  geom_smooth(aes(colour = "OLS fit"), method = "lm", formula = y ~ x,
              se = FALSE, linewidth = 0.8) +
  scale_colour_manual(
    values = c("Individual men" = "#0072B2", "OLS fit" = "#D55E00"),
    name = NULL,
    guide = guide_legend(
      override.aes = list(alpha = c(0.45, 1), size = c(2, 0.8),
                          linetype = c(0, 1), shape = c(16, NA))
    )
  ) +
  scale_x_continuous(breaks = seq(2, 18, by = 2)) +
  labs(x = "Years of schooling", y = "Log hourly wage (1976)") +
  theme_bw(base_size = 11, base_family = "sans") +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour = "grey92", linewidth = 0.3),
    axis.text = element_text(colour = "black"),
    axis.ticks = element_line(colour = "black", linewidth = 0.3),
    panel.border = element_rect(colour = "black", linewidth = 0.5),
    legend.position = "bottom",
    legend.direction = "horizontal",
    legend.key = element_blank(),
    legend.margin = margin(0, 0, 0, 0)
  )

ggsave(path("output/fig/fig1_education_wage_scatter.pdf"), figure_1,
       width = 6.5, height = 4.2, device = "pdf")
ggsave(path("output/fig/fig1_education_wage_scatter.png"), figure_1,
       width = 6.5, height = 4.2, dpi = 320, device = "png", bg = "white")

## ---------------------------------------------------------------- figure 2 --
effect_plot_data <- educ_effects
effect_plot_data$model_label <- factor(
  c(
    sprintf("Model 1: OLS (no controls)\n%.3f [%.3f, %.3f]",
            educ_effects$estimate[1], educ_effects$conf.low[1], educ_effects$conf.high[1]),
    sprintf("Model 2: OLS (with controls)\n%.3f [%.3f, %.3f]",
            educ_effects$estimate[2], educ_effects$conf.low[2], educ_effects$conf.high[2]),
    sprintf("Model 3: 2SLS (nearc4)\n%.3f [%.3f, %.3f]",
            educ_effects$estimate[3], educ_effects$conf.low[3], educ_effects$conf.high[3])
  ),
  levels = c(
    sprintf("Model 3: 2SLS (nearc4)\n%.3f [%.3f, %.3f]",
            educ_effects$estimate[3], educ_effects$conf.low[3], educ_effects$conf.high[3]),
    sprintf("Model 2: OLS (with controls)\n%.3f [%.3f, %.3f]",
            educ_effects$estimate[2], educ_effects$conf.low[2], educ_effects$conf.high[2]),
    sprintf("Model 1: OLS (no controls)\n%.3f [%.3f, %.3f]",
            educ_effects$estimate[1], educ_effects$conf.low[1], educ_effects$conf.high[1])
  )
)

figure_2 <- ggplot(effect_plot_data,
                   aes(x = estimate, y = model_label)) +
  geom_vline(xintercept = 0, linetype = "dashed",
             colour = "grey30", alpha = 0.3, linewidth = 0.5) +
  geom_errorbar(aes(xmin = conf.low, xmax = conf.high), width = 0.12,
                orientation = "y", colour = "#0072B2", linewidth = 0.8) +
  geom_point(size = 2.8, colour = "#0072B2") +
  scale_x_continuous(
    breaks = seq(0, 0.30, by = 0.05),
    limits = c(-0.02, 0.28),
    sec.axis = sec_axis(~ 100 * (exp(.x) - 1),
                        name = "Implied change in hourly wage (%)")
  ) +
  labs(x = "Estimated return to one year of schooling (log wage points)",
       y = NULL) +
  theme_bw(base_size = 11, base_family = "sans") +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(colour = "grey92", linewidth = 0.3),
    axis.text = element_text(colour = "black"),
    axis.text.y = element_text(size = 8.5, lineheight = 0.95),
    axis.ticks = element_line(colour = "black", linewidth = 0.3),
    panel.border = element_rect(colour = "black", linewidth = 0.5),
    plot.margin = margin(6, 8, 6, 6)
  )

ggsave(path("output/fig/fig2_returns_by_model.pdf"), figure_2,
       width = 6.5, height = 3.8, device = "pdf")
ggsave(path("output/fig/fig2_returns_by_model.png"), figure_2,
       width = 6.5, height = 3.8, dpi = 320, device = "png", bg = "white")

## ------------------------------------------------------------------- table --
term_labels <- c(
  educ = "Years of schooling",
  black = "Black",
  south = "South",
  smsa = "SMSA",
  smsa66 = "SMSA in 1966",
  exper = "Experience (years)",
  expersq = "Experience squared"
)

cell_b <- function(model, term) {
  td <- broom::tidy(model)
  row <- td[td$term == term, ]
  if (nrow(row) == 0) return("---")
  paste0(fmt(row$estimate), " (", fmt(row$std.error), ")")
}

cell_ci <- function(model, term) {
  td <- broom::tidy(model, conf.int = TRUE)
  row <- td[td$term == term, ]
  if (nrow(row) == 0) return("")
  paste0("[", fmt(row$conf.low), ", ", fmt(row$conf.high), "]")
}

table_body <- data.frame(
  variable = unname(term_labels),
  m1_b = vapply(names(term_labels), function(t) cell_b(model_1, t), character(1)),
  m1_ci = vapply(names(term_labels), function(t) cell_ci(model_1, t), character(1)),
  m2_b = vapply(names(term_labels), function(t) cell_b(model_2, t), character(1)),
  m2_ci = vapply(names(term_labels), function(t) cell_ci(model_2, t), character(1)),
  m3_b = vapply(names(term_labels), function(t) cell_b(model_3, t), character(1)),
  m3_ci = vapply(names(term_labels), function(t) cell_ci(model_3, t), character(1)),
  stringsAsFactors = FALSE
)

table_body <- rbind(
  table_body,
  data.frame(
    variable = c("Region controls", "N",
                 "R-squared", "Adjusted R-squared", "First-stage F"),
    m1_b = c("No", fmt_n(nobs(model_1)), fmt(summary(model_1)$r.squared),
             fmt(summary(model_1)$adj.r.squared), "---"),
    m1_ci = rep("", 5),
    m2_b = c("Yes", fmt_n(nobs(model_2)), fmt(summary(model_2)$r.squared),
             fmt(summary(model_2)$adj.r.squared), "---"),
    m2_ci = rep("", 5),
    m3_b = c("Yes", fmt_n(nobs(model_3)), fmt(summary(model_3)$r.squared),
             fmt(summary(model_3)$adj.r.squared), fmt(first_stage_f)),
    m3_ci = rep("", 5),
    stringsAsFactors = FALSE
  )
)

rownames(table_body) <- NULL

table_note <- paste(
  "Standard errors are in parentheses and 95% confidence intervals are in brackets.",
  "The dependent variable is the log hourly wage in 1976.",
  "All models use the 3,010 men in the NLS Young Men cohort with valid schooling and wage data.",
  "Region controls are indicators for the nine census regions in 1966 (reg662 to reg669), with the Northeast (reg661) as the reference category.",
  "Model 3 instruments years of schooling with nearc4, an indicator for growing up in a labor market with a four-year college;",
  "the first-stage F statistic refers to the excluded instrument."
)

table_note_tex <- gsub("%", "\\\\%", table_note)

# LaTeX (APA-7): bold table number, italic title handled by the apa7 class.
tex_column_names <- c("Variable", "b (SE)", "95\\% CI", "b (SE)", "95\\% CI",
                      "b (SE)", "95\\% CI")
tex_body <- kableExtra::kbl(
  table_body, format = "latex", booktabs = TRUE, linesep = "",
  align = c("l", "c", "c", "c", "c", "c", "c"),
  col.names = tex_column_names, escape = FALSE
) |>
  kableExtra::add_header_above(
    c(" " = 1, "Model 1 (OLS)" = 2, "Model 2 (OLS)" = 2, "Model 3 (2SLS)" = 2),
    bold = TRUE, escape = FALSE
  )

tex_table <- c(
  "\\begin{table}[htbp]",
  "\\centering",
  "\\begin{threeparttable}",
  "\\caption{Returns to Schooling Estimated by OLS and 2SLS}",
  "\\label{tab:returns}",
  "\\footnotesize",
  "\\setlength{\\tabcolsep}{4pt}",
  sub("\nVariable &", "\n\\\\multicolumn{1}{c}{Variable} &", tex_body),
  paste0("\\tablenote{", table_note_tex, "}"),
  "\\end{threeparttable}",
  "\\end{table}"
)
writeLines(tex_table, path("output/tex/table1.tex"))

# Markdown version with the same numbers and APA layout.
md_column_names <- c("Variable",
                     "Model 1 b (SE)", "Model 1 95% CI",
                     "Model 2 b (SE)", "Model 2 95% CI",
                     "Model 3 b (SE)", "Model 3 95% CI")
md_body <- kableExtra::kbl(
  table_body, format = "pipe", booktabs = TRUE, linesep = "",
  align = c("l", "c", "c", "c", "c", "c", "c"),
  col.names = md_column_names, escape = FALSE
)
md_table <- c(
  "**Table 1**",
  "",
  "*Returns to Schooling Estimated by OLS and 2SLS*",
  "",
  md_body,
  "",
  paste0("*Note.* ", table_note)
)
writeLines(md_table, path("output/tex/table1.md"))

## --------------------------------------------------------- results paragraph --
b1 <- unname(coef(model_1)[["educ"]]);  se1 <- summary(model_1)$coefficients["educ", "Std. Error"]
b2 <- unname(coef(model_2)[["educ"]]);  se2 <- summary(model_2)$coefficients["educ", "Std. Error"]
b3 <- unname(coef(model_3)[["educ"]]);  se3 <- summary(model_3)$coefficients["educ", "Std. Error"]
p1 <- summary(model_1)$coefficients["educ", "Pr(>|t|)"]
p2 <- summary(model_2)$coefficients["educ", "Pr(>|t|)"]
p3 <- summary(model_3)$coefficients["educ", "Pr(>|t|)"]
ci3_low <- confint(model_3)["educ", 1]
ci3_high <- confint(model_3)["educ", 2]
pct1 <- pct_change(b1); pct2 <- pct_change(b2); pct3 <- pct_change(b3)
gap <- pct3 - pct2
n_obs <- nobs(model_1)

para_tex <- paste0(
  "Residence near a four-year college produces a larger estimated return to schooling than ",
  "ordinary least squares, consistent with attenuation in the OLS estimates. ",
  "Among the ", fmt_n(n_obs), " men in the NLS Young Men cohort, one additional year of ",
  "schooling is associated with ", sprintf("%.1f", pct1), "\\% higher hourly wages in the ",
  "baseline model (\\textit{b} = ", fmt0(b1), ", \\textit{SE} = ", fmt0(se1),
  ", \\textit{p} ", fmt_p(p1), ") and ", sprintf("%.1f", pct2),
  "\\% higher wages after controlling for race, region, urban residence, and ",
  "experience (\\textit{b} = ", fmt0(b2), ", \\textit{SE} = ", fmt0(se2),
  ", \\textit{p} ", fmt_p(p2), "). Instrumenting schooling with an indicator for ",
  "growing up near a four-year college (nearc4) raises the return to ",
  sprintf("%.1f", pct3), "\\% (\\textit{b} = ", fmt0(b3), ", \\textit{SE} = ", fmt0(se3),
  ", \\textit{p} ", fmt_p(p3), ", 95\\% CI [", fmt0(ci3_low), ", ", fmt0(ci3_high),
  "]); the instrument is not weak (first-stage \\textit{F}(", first_stage_df1, ", ",
  first_stage_df2, ") = ", fmt0(first_stage_f, 2), ", \\textit{p} ", fmt_p(first_stage_p),
  "). If college proximity affects wages only through schooling, the gap between the ",
  "OLS and 2SLS estimates implies that conventional estimates understate the return to ",
  "schooling by about ", sprintf("%.0f", gap), " percentage points; the wide 2SLS interval ",
  "and the local-average interpretation of the IV estimand nonetheless caution against ",
  "treating ", sprintf("%.0f", pct3), "\\% as a population-wide causal effect."
)
writeLines(para_tex, path("output/tex/results_paragraph.tex"))

para_md <- paste0(
  "Residence near a four-year college produces a larger estimated return to schooling than ",
  "ordinary least squares, consistent with attenuation in the OLS estimates. ",
  "Among the ", fmt_n(n_obs), " men in the NLS Young Men cohort, one additional year of ",
  "schooling is associated with ", sprintf("%.1f", pct1), "% higher hourly wages in the ",
  "baseline model (*b* = ", fmt0(b1), ", *SE* = ", fmt0(se1), ", *p* ", fmt_p(p1),
  ") and ", sprintf("%.1f", pct2), "% higher wages after controlling for race, region, ",
  "urban residence, and experience (*b* = ", fmt0(b2), ", *SE* = ", fmt0(se2),
  ", *p* ", fmt_p(p2), "). Instrumenting schooling with an indicator for growing up near ",
  "a four-year college (nearc4) raises the return to ", sprintf("%.1f", pct3),
  "% (*b* = ", fmt0(b3), ", *SE* = ", fmt0(se3), ", *p* ", fmt_p(p3), ", 95% CI [",
  fmt0(ci3_low), ", ", fmt0(ci3_high), "]); the instrument is not weak (first-stage *F*(",
  first_stage_df1, ", ", first_stage_df2, ") = ", fmt0(first_stage_f, 2),
  ", *p* ", fmt_p(first_stage_p), "). If college proximity affects wages only through ",
  "schooling, the gap between the OLS and 2SLS estimates implies that conventional ",
  "estimates understate the return to schooling by about ", sprintf("%.0f", gap),
  " percentage points; the wide 2SLS interval and the local-average interpretation of ",
  "the IV estimand nonetheless caution against treating ", sprintf("%.0f", pct3),
  "% as a population-wide causal effect."
)
writeLines(para_md, path("output/tex/results_paragraph.md"))

## ------------------------------------------------------------------ session --
writeLines(capture.output(sessionInfo()), path("data/result/session_info.txt"))

message("\nCard (1993) replication complete.")
message("Models: OLS = ", fmt0(b1), "; OLS + controls = ", fmt0(b2),
        "; 2SLS = ", fmt0(b3), " (first-stage F = ", fmt0(first_stage_f, 2), ")")
message("Outputs written to data/, output/fig/, and output/tex/.")
