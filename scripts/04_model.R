# =============================================================================
# 04_model.R
# Purpose : Fit Fixed Effect, Difference-in-Differences, Triple Differences,
#           robust SE variants, and event study models
# Input   : data/02-clean/panel_df.rds, data/02-clean/mincome_clean.rds
# Output  : results/models/fe_model.rds
#           results/models/did_model.rds
#           results/models/ddd_model.rds
#           results/models/fe_robust.rds
#           results/models/did_robust.rds
#           results/models/ddd_robust.rds
#           results/models/event_model.rds
#           results/figures/fig_event_study.png
# =============================================================================

library(tidyverse)
library(fixest)
library(modelsummary)
library(ggplot2)

# ── Paths ──────────────────────────────────────────────────────────────────────
CLEAN_DIR <- "data/02-clean"
MODEL_DIR <- "results/models"
FIG_DIR   <- "results/figures"

dir.create(MODEL_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(FIG_DIR,   showWarnings = FALSE, recursive = TRUE)

panel_df   <- readRDS(file.path(CLEAN_DIR, "panel_df.rds"))
minc_clean <- readRDS(file.path(CLEAN_DIR, "mincome_clean.rds"))

# model_df drops RACIALHH for the FE and DiD models (not needed there)
model_df <- panel_df %>% select(-RACIALHH)

# ── 2.1 Fixed Effect Model ─────────────────────────────────────────────────────
fe_model <- feols(
  HH_HOURS ~ HH_WAGE + PAYMENT | FAMNUM + period,
  data    = model_df,
  cluster = ~FAMNUM
)
summary(fe_model)

# ── 2.2 Difference-in-Differences Model ───────────────────────────────────────
did_model <- feols(
  HH_HOURS ~ TREATED * post | FAMNUM + period,
  data    = model_df,
  cluster = ~FAMNUM
)
summary(did_model)

# ── 2.3 Triple Differences (Racialized vs Non-racialized) ─────────────────────
ddd_model <- feols(
  HH_HOURS ~ treat_post + triple_diff | FAMNUM + period,
  data    = panel_df,
  cluster = ~FAMNUM
)
summary(ddd_model)

# ── 2.4 Comparison table ──────────────────────────────────────────────────────
modelsummary(
  list(
    "Fixed Effects"     = fe_model,
    "Diff-in-Diff"      = did_model,
    "Triple Diff (DDD)" = ddd_model
  ),
  stars = TRUE,
  output = "results/tables/tbl_main_models.html"
)

# ── 3. Robustness Checks (heteroskedasticity-robust SE) ───────────────────────
fe_robust <- feols(
  HH_HOURS ~ HH_WAGE + PAYMENT | FAMNUM + period,
  data  = panel_df,
  vcov  = "hetero"
)

did_robust <- feols(
  HH_HOURS ~ TREATED:post | FAMNUM + period,
  data  = panel_df,
  vcov  = "hetero"
)

ddd_robust <- feols(
  HH_HOURS ~ TREATED:post + TREATED:post:RACIALHH | FAMNUM + period,
  data  = panel_df,
  vcov  = "hetero"
)

modelsummary(
  list(
    "FE Robust"  = fe_robust,
    "DiD Robust" = did_robust,
    "DDD Robust" = ddd_robust
  ),
  stars  = TRUE,
  output = "results/tables/tbl_robust_models.html"
)

# ── Appendix: Event Study ──────────────────────────────────────────────────────
event_model <- feols(
  HH_HOURS ~ i(period, TREATED, ref = 0) | FAMNUM + period,
  data    = panel_df,
  cluster = ~FAMNUM
)
summary(event_model)

# Save event study figure
png(file.path(FIG_DIR, "fig_event_study.png"), width = 800, height = 500, res = 100)
iplot(event_model,
      main = "Event Study: Treatment Effect on Household Hours",
      xlab = "Period Relative to Treatment",
      ylab = "Effect on Monthly Household Hours")
dev.off()

# ── Save model objects ────────────────────────────────────────────────────────
saveRDS(fe_model,    file.path(MODEL_DIR, "fe_model.rds"))
saveRDS(did_model,   file.path(MODEL_DIR, "did_model.rds"))
saveRDS(ddd_model,   file.path(MODEL_DIR, "ddd_model.rds"))
saveRDS(fe_robust,   file.path(MODEL_DIR, "fe_robust.rds"))
saveRDS(did_robust,  file.path(MODEL_DIR, "did_robust.rds"))
saveRDS(ddd_robust,  file.path(MODEL_DIR, "ddd_robust.rds"))
saveRDS(event_model, file.path(MODEL_DIR, "event_model.rds"))

message("✔  04_model.R complete")
