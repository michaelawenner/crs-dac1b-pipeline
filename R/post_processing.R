# ------------------------------------------------------------------------------
# Applies (Swiss-specific) post-processing rules to the aggregated results.
#
# This function performs several final adjustments to the output table, including:
#   1. Writing values for Positive and Negative Grant Equivalent (GEQ) fields:
#      - If present, Positive_Grant_Equivalent and Negative_Grant_Equivalent are written to column 1160.
#      - Amounts_mobilized is written to column 1122 if available.
#   2. Adjusting specific row values:
#      - For row ID 420: move the value from column 1160 to 1130 (negated), and clear 1160.
#      - For row ID 425: subtract the value of row 420 / column 1130 from 1121.
#   3. Handling MDRI-specific entry (Swiss-specific logic!):
#      - Filters CRS data for rows where "MDRI" appears in the project title but not "HIPC".
#      - Aggregates extended amounts and GEQs.
#      - Writes the values to row ID 2902, columns 1121 and 1160.
#   4. Adding custom summary rows:
#      - New aggregate rows for:
#         - ID 1030 (sum of 10301, 10302, 10303)
#         - ID 207  (sum of 20701, 20702)
#         - ID 3102 (sum of 31021, 31022, 31023)
#      - The sums are computed across all numeric columns.
#      - The result is sorted by ID at the end.
#
# Arguments:
#   result   : Aggregated results data frame (after applying rules)
#   crs_data : Raw CRS data frame (used for MDRI filtering)
#
# Returns:
#   A modified result data frame with final adjustments and added rows.
# ------------------------------------------------------------------------------

post_process_result <- function(result, crs_data) {
  print("...Performing post-processing...")
  # 1. Write Positive and Negative GEQ values to column 1160 and mobilized to 1122
  result <- result %>%
    mutate(
      `1160` = ifelse(!is.na(Positive_Grant_Equivalent), Positive_Grant_Equivalent, `1160`),
      `1160` = ifelse(!is.na(Negative_Grant_Equivalent), Negative_Grant_Equivalent, `1160`),
      `1122` = ifelse(!is.na(Amounts_mobilized), Amounts_mobilized, `1122`)
    )
  
  # 2. Adjust values for specific rows
  result <- result %>%
    mutate(
      `1130` = ifelse(ID == 420, -`1160`, `1130`),
      `1160` = ifelse(ID == 420, NA, `1160`)
    )
  
  value_420_1130 <- result %>% filter(ID == 420) %>% pull(`1130`)
  
  result <- result %>%
    mutate(
      `1121` = ifelse(ID == 425, `1121` - value_420_1130, `1121`)
    )
  
  # 3. Handle MDRI (ID 2902) - specific for Swiss data!
  mdri_data <- crs_data %>%
    filter(
      str_detect(Short_description___Project_Title, "MDRI") &
        !str_detect(Short_description___Project_Title, "HIPC")
    )
  
  mdri_sum <- list(
    `1121` = sum(mdri_data[[COL_EXTENDED]], na.rm = TRUE),
    `1160` = sum(mdri_data[[COL_GEQ]], na.rm = TRUE)
  )
  
  result <- result %>%
    mutate(
      `1121` = ifelse(ID == 2902, mdri_sum$`1121`, `1121`),
      `1160` = ifelse(ID == 2902, mdri_sum$`1160`, `1160`)
    )
  
  # 4. Add summary rows (e.g. 1030, 207, 3102)
  add_summary_rows <- function(result) {
    result$ID <- as.character(result$ID)
    
    custom_sum <- function(x) sum(x, na.rm = TRUE)
    
    summarise_ids <- list(
      `1030` = c("10301", "10302", "10303"),
      `207`  = c("20701", "20702"),
      `3102` = c("31021", "31022", "31023")
    )
    
    new_rows <- lapply(names(summarise_ids), function(new_id) {
      result %>%
        filter(ID %in% summarise_ids[[new_id]]) %>%
        summarize(across(-ID, custom_sum)) %>%
        mutate(ID = new_id)
    })
    
    result <- bind_rows(result, do.call(bind_rows, new_rows))
    result$ID <- as.numeric(result$ID)
    result <- result %>% arrange(ID)
    
    return(result)
  }
  
  result <- add_summary_rows(result)
  result$ID <- as.integer(result$ID)
  
  return(result)
}
