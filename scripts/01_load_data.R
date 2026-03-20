# =============================================================================
# 01_load_data.R
# Purpose : Read raw MINCOME xlsx files and save as RDS for downstream scripts
# Input   : data/01-raw/MINC3.xlsx, data/01-raw/MINC4.xlsx
# Output  : data/02-clean/mincome_raw.rds, data/02-clean/payments_raw.rds
# =============================================================================

library(readxl)

# ── Paths ──────────────────────────────────────────────────────────────────────
RAW_DIR   <- "data/01-raw"
CLEAN_DIR <- "data/02-clean"

dir.create(CLEAN_DIR, showWarnings = FALSE, recursive = TRUE)

# ── Load raw data ──────────────────────────────────────────────────────────────
mincome_raw  <- read_xlsx(file.path(RAW_DIR, "MINC3.xlsx"))
payments_raw <- read_xlsx(file.path(RAW_DIR, "MINC4.xlsx"),
                          skip = 1, col_names = TRUE)

# ── Save as RDS ────────────────────────────────────────────────────────────────
saveRDS(mincome_raw,  file.path(CLEAN_DIR, "mincome_raw.rds"))
saveRDS(payments_raw, file.path(CLEAN_DIR, "payments_raw.rds"))

message("✔  01_load_data.R complete")
