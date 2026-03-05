library(tidyverse)
minorities <- c(16,19,7,8,21,24,26,32,33)
minc_clean <- mutate(MINC3, HHHRWRK = MHHOURS + FHHOURS)
minc_clean <- minc_clean %>% mutate(RACIALHH = if_else(
  MHETHNIC %in% minorities |
    FHETHNIC %in% minorities,
  1,  
  0
)
)
minc_clean <- minc_clean %>% mutate(AVGPROD = if_else(HHHRWRK != 0,
                                                      TOTFAMINC74 / HHHRWRK,
                                                      0))

minc_summary <- select(minc_clean, 
                       FAMSIZE,
                       TOTFAMINC74,
                       HHHRWRK,
                       RACIALHH,
                       AVGPROD)
summary(minc_summary)
