# =============================================================================
# 03_eda.R
# Purpose : Produce summary statistics and EDA figures
# Input   : data/02-clean/mincome_clean.rds
# Output  : results/figures/fig_famsize_hist.png
#           results/figures/fig_hours_by_site.png
#           results/figures/fig_hours_vs_famsize.png
#           results/figures/fig_eda_grid.png
#           results/tables/tbl_site_summary.rds
#           results/tables/tbl_racial_breakdown.rds
# =============================================================================

library(tidyverse)
library(cowplot)

# ── Paths ──────────────────────────────────────────────────────────────────────
CLEAN_DIR  <- "data/02-clean"
FIG_DIR    <- "results/figures"
TABLE_DIR  <- "results/tables"

dir.create(FIG_DIR,   showWarnings = FALSE, recursive = TRUE)
dir.create(TABLE_DIR, showWarnings = FALSE, recursive = TRUE)

minc_clean <- readRDS(file.path(CLEAN_DIR, "mincome_clean.rds"))

# ── Summary tables ────────────────────────────────────────────────────────────
tbl_site_summary <- minc_clean %>%
  group_by(SITE) %>%
  summarise(
    n          = n(),
    avg_income = mean(TOTFAMINC74, na.rm = TRUE),
    avg_hours  = mean(HHHRWRK,    na.rm = TRUE),
    .groups    = "drop"
  )

tbl_racial_breakdown <- minc_clean %>%
  count(SITE, RACIALHH) %>%
  mutate(RACIALHH = if_else(RACIALHH == 1, "Racialized", "Non-racialized"))

saveRDS(tbl_site_summary,     file.path(TABLE_DIR, "tbl_site_summary.rds"))
saveRDS(tbl_racial_breakdown, file.path(TABLE_DIR, "tbl_racial_breakdown.rds"))

print(tbl_site_summary)
print(tbl_racial_breakdown)

# ── Figures ────────────────────────────────────────────────────────────────────
p1 <- ggplot(minc_clean, aes(x = FAMSIZE)) +
  geom_histogram(bins = 40, fill = "#4E79A7", colour = "white", na.rm = TRUE) +
  labs(title = "Distribution of Household Size",
       x = "Family Size", y = "Count") +
  theme_minimal()

p2 <- ggplot(minc_clean, aes(x = SITE, y = HHHRWRK, fill = SITE)) +
  geom_boxplot(na.rm = TRUE, alpha = 0.8, outlier.alpha = 0.3) +
  labs(title = "Household Work Hours by Site",
       x = "Site of Experiment", y = "Household Work Hours (Annual)") +
  theme_minimal() +
  theme(legend.position = "none")

p3 <- ggplot(minc_clean, aes(x = HHHRWRK, y = FAMSIZE)) +
  geom_point(alpha = 0.35, colour = "#4E79A7", na.rm = TRUE) +
  geom_smooth(method = "lm", colour = "#E15759", na.rm = TRUE) +
  labs(title = "Family Size vs Household Work Hours",
       x = "Household Hours Worked (Annual)", y = "Family Size") +
  theme_minimal()

# Save individual figures
ggsave(file.path(FIG_DIR, "fig_famsize_hist.png"),   p1, width = 6, height = 4, dpi = 150)
ggsave(file.path(FIG_DIR, "fig_hours_by_site.png"),  p2, width = 6, height = 4, dpi = 150)
ggsave(file.path(FIG_DIR, "fig_hours_vs_famsize.png"), p3, width = 6, height = 4, dpi = 150)

# Combined grid
grid_plot <- plot_grid(p1, p2, p3, label_size = 11, ncol = 2)
ggsave(file.path(FIG_DIR, "fig_eda_grid.png"), grid_plot,
       width = 12, height = 8, dpi = 150)

message("✔  03_eda.R complete")
