# =============================================================================
# 02_clean_data.R
# Purpose : Clean raw MINCOME data, engineer features, build panel dataset
# Input   : data/02-clean/mincome_raw.rds, data/02-clean/payments_raw.rds
# Output  : data/02-clean/mincome_clean.rds
#           data/02-clean/merged_data.rds
#           data/02-clean/panel_df.rds
#           data/02-clean/mincome_clean.csv  (for sharing)
#           data/02-clean/merged_panel_data.csv
#           data/02-clean/panel_df.csv
# =============================================================================

library(tidyverse)

# ── Paths ──────────────────────────────────────────────────────────────────────
CLEAN_DIR <- "data/02-clean"

mincome_raw  <- readRDS(file.path(CLEAN_DIR, "mincome_raw.rds"))
payments_raw <- readRDS(file.path(CLEAN_DIR, "payments_raw.rds"))

# ── 1. Ethnic group lookup (shared by male and female head) ───────────────────
ethnic_labels <- c(
  "1"  = "English",               "2"  = "French",
  "3"  = "German",                "4"  = "Irish",
  "5"  = "Italian",               "6"  = "Jewish",
  "7"  = "Native Indian band",    "8"  = "Native Indian non-band",
  "9"  = "Norwegian",             "10" = "Polish",
  "11" = "Scottish",              "12" = "Ukrainian",
  "13" = "Metis",                 "14" = "Finnish",
  "15" = "Canadian",              "16" = "Philippine",
  "17" = "Belgian/Dutch",         "18" = "Icelandic",
  "19" = "Chinese",               "20" = "Other",
  "21" = "African",               "22" = "Yugoslavian/Czech/Hungarian",
  "23" = "Swedish",               "24" = "West Indian",
  "25" = "Mennonite",             "26" = "South American",
  "27" = "Latvian/Lithuanian/Estonian",
  "28" = "Spanish/Portuguese",    "29" = "Russian",
  "30" = "Welsh",                 "31" = "Greek",
  "32" = "Black",                 "33" = "Japanese",
  "34" = "Danish",                "35" = "American"
)

# Ethnic code values considered racialized minorities
minorities <- c(16, 19, 7, 8, 20, 21, 24, 26, 32, 33)

# ── 2. Clean cross-sectional MINCOME data ─────────────────────────────────────
minc_clean <- mincome_raw %>%
  mutate(
    HHHRWRK  = MHHOURS + FHHOURS,
    RACIALHH = if_else(MHETHNIC %in% minorities | FHETHNIC %in% minorities, 1L, 0L),
    AVGPROD  = if_else(HHHRWRK != 0, TOTFAMINC74 / HHHRWRK, 0)
  ) %>%
  select(
    FAMNUM, `SITE CODE`, FAMSIZE, TREAT, TOTFAMINC74,
    HHHRWRK, RACIALHH, MHETHNIC, FHETHNIC,
    AVGPROD, HMEVAL, VEHVAL, OTHVAL, LIQASSETS, DEBTS
  ) %>%
  rename(SITE = `SITE CODE`) %>%
  mutate(
    SITE = case_when(
      SITE == 1 ~ "Winnipeg",
      SITE == 2 ~ "Dauphin",
      SITE == 0 ~ "Rural",
      TRUE      ~ NA_character_
    ),
    MHETHNIC = ethnic_labels[as.character(MHETHNIC)],
    FHETHNIC = ethnic_labels[as.character(FHETHNIC)]
  ) %>%
  mutate(SITE = factor(SITE))

colnames(minc_clean) <- toupper(colnames(minc_clean))

# ── 3. Clean payments / panel data ────────────────────────────────────────────
payments_clean <- payments_raw

# Compute household totals for hours and wages across 11 periods
for (i in 1:11) {
  payments_clean[[paste0("HH_HOURS", i)]] <-
    rowSums(payments_clean[, c(paste0("HOURS", i), paste0("FHOURS", i))],
            na.rm = TRUE)
  payments_clean[[paste0("HH_WAGE", i)]] <-
    rowSums(payments_clean[, c(paste0("WAGE", i), paste0("FWAGE", i))],
            na.rm = TRUE)
}

payments_clean <- payments_clean %>%
  mutate(
    GBI_LVL_YR = case_when(
      PLAN %in% c("1", "3", "6") ~ 3800,
      PLAN %in% c("2", "4", "7") ~ 4800,
      PLAN %in% c("5", "8")      ~ 5800,
      PLAN == "9"                 ~ 0,
      TRUE                        ~ NA_real_
    ),
    TAX_RATE = case_when(
      PLAN %in% c("1", "2")      ~ 0.35,
      PLAN %in% c("3", "4", "5") ~ 0.50,
      PLAN %in% c("6", "7", "8") ~ 0.75,
      PLAN == "9"                 ~ 0,
      TRUE                        ~ NA_real_
    ),
    GBI_MON = GBI_LVL_YR / 12
  ) %>%
  select(
    FAMNUM, PLAN, GBI_LVL_YR, GBI_MON, TAX_RATE,
    starts_with("HH_HOURS"), starts_with("HH_WAGE")
  )

# ── 4. Merge cross-sectional + panel ──────────────────────────────────────────
merged_data <- minc_clean %>%
  left_join(payments_clean, by = "FAMNUM") %>%
  mutate(
    HH_WAGE0  = (mincome_raw$MHTOTERN73 + mincome_raw$FHTOTERN73) / 12,
    HH_HOURS0 = HHHRWRK / 12
  )

# Compute actual payment received each period (benefit rule)
for (i in 1:11) {
  merged_data[[paste0("PAYMENT", i)]] <-
    pmax(0,
         merged_data$GBI_MON -
           merged_data$TAX_RATE * merged_data[[paste0("HH_WAGE", i)]])
}

# ── 5. Pivot to long panel format ─────────────────────────────────────────────
panel_df <- merged_data %>%
  pivot_longer(
    cols         = matches("HH_HOURS|HH_WAGE|PAYMENT"),
    names_to     = c(".value", "period"),
    names_pattern = "(HH_HOURS|HH_WAGE|PAYMENT)(\\d+)"
  ) %>%
  mutate(
    period  = as.numeric(period),
    TREATED = if_else(TREAT != 9, 1L, 0L),
    post    = if_else(period > 0, 1L, 0L),
    treat_post  = TREATED * post,
    triple_diff = TREATED * post * RACIALHH
  ) %>%
  select(-MHETHNIC, -FHETHNIC, -AVGPROD, -PLAN)

# ── 6. Save outputs ───────────────────────────────────────────────────────────
saveRDS(minc_clean,   file.path(CLEAN_DIR, "mincome_clean.rds"))
saveRDS(merged_data,  file.path(CLEAN_DIR, "merged_data.rds"))
saveRDS(panel_df,     file.path(CLEAN_DIR, "panel_df.rds"))

write.csv(minc_clean,  file.path(CLEAN_DIR, "mincome_clean.csv"),    row.names = FALSE)
write.csv(merged_data, file.path(CLEAN_DIR, "merged_panel_data.csv"), row.names = FALSE)
write.csv(panel_df,    file.path(CLEAN_DIR, "panel_df.csv"),          row.names = FALSE)

message("✔  02_clean_data.R complete")
