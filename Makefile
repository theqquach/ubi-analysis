RSCRIPT = Rscript --vanilla
QUARTO  = quarto render

THIS_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
ROOT     := $(shell \
	if [ -d "$(THIS_DIR)/../scripts" ] || [ -f "$(THIS_DIR)/../renv.lock" ]; then \
		cd "$(THIS_DIR)/.." && pwd; \
	else \
		echo "$(THIS_DIR)"; \
	fi)

$(info → Repo root: $(ROOT))

RENV_STAMP   = $(ROOT)/.renv_restored
RAW_RDS      = $(ROOT)/data/02-clean/mincome_raw.rds \
               $(ROOT)/data/02-clean/payments_raw.rds
CLEAN_RDS    = $(ROOT)/data/02-clean/mincome_clean.rds \
               $(ROOT)/data/02-clean/merged_data.rds \
               $(ROOT)/data/02-clean/panel_df.rds
EDA_FIGS     = $(ROOT)/results/figures/fig_eda_grid.png
MODEL_OBJS   = $(ROOT)/results/models/fe_model.rds \
               $(ROOT)/results/models/did_model.rds \
               $(ROOT)/results/models/ddd_model.rds
REPORT_HTML  = $(ROOT)/reports/ubi_analysis_report.html
REPORT_PDF   = $(ROOT)/reports/ubi_analysis_report.pdf

.PHONY: all data analysis report clean

all: $(REPORT_HTML) $(REPORT_PDF)

data: $(CLEAN_RDS)

analysis: $(EDA_FIGS) $(MODEL_OBJS)

report: $(REPORT_HTML) $(REPORT_PDF)

$(RENV_STAMP): $(ROOT)/renv.lock
	cd $(ROOT) && $(RSCRIPT) -e "renv::restore(prompt = FALSE)"
	touch $(RENV_STAMP)

$(RAW_RDS): $(RENV_STAMP)
	@test -f $(ROOT)/data/01-raw/MINC3.xlsx || \
	  (echo "ERROR: $(ROOT)/data/01-raw/MINC3.xlsx not found." && exit 1)
	@test -f $(ROOT)/data/01-raw/MINC4.xlsx || \
	  (echo "ERROR: $(ROOT)/data/01-raw/MINC4.xlsx not found." && exit 1)
	cd $(ROOT) && $(RSCRIPT) scripts/01_load_data.R

$(CLEAN_RDS): $(RAW_RDS)
	cd $(ROOT) && $(RSCRIPT) scripts/02_clean_data.R

$(EDA_FIGS): $(CLEAN_RDS)
	cd $(ROOT) && $(RSCRIPT) scripts/03_eda.R

$(MODEL_OBJS): $(CLEAN_RDS)
	cd $(ROOT) && $(RSCRIPT) scripts/04_model.R

$(REPORT_HTML) $(REPORT_PDF): $(EDA_FIGS) $(MODEL_OBJS)
	cd $(ROOT) && $(QUARTO) reports/ubi_analysis_report.qmd

clean:
	rm -rf $(ROOT)/data/02-clean \
	       $(ROOT)/results \
	       $(ROOT)/reports/ubi_analysis_report.html \
	       $(ROOT)/reports/ubi_analysis_report.pdf \
	       $(ROOT)/reports/ubi_analysis_report_files
	@echo "Cleaned all derived files."

