# ------------------------------------------------------------------------------
# Splits purpose codes and redistributes financial amounts accordingly.
#
# Some CRS data rows contain multiple purpose codes with associated percentages 
# (e.g., "14030:50|15110:50"), indicating how the financial data should be split.
# This function processes such cases by:
#   - Expanding each purpose code into its own row
#   - Parsing and applying the percentage
#   - Adjusting all relevant financial columns proportionally
#
# Arguments:
#   df               : The input CRS data frame.
#   col_purpose      : The column name containing the purpose code strings.
#   col_extended     : Column with extended amounts in 1,000 CHF.
#   col_received     : Column with received amounts (loan principal only).
#   col_commitments  : Column with commitment amounts in 1,000 CHF.
#   col_geq          : Column with OECD grant equivalent in 1,000 CHF.
#   col_mobilized    : Column with private finance mobilized in 1,000 CHF.
#
# Returns:
#   A new data frame where rows with multiple purpose codes are split and
#   financial values are adjusted by the specified percentage.
# ------------------------------------------------------------------------------
process_purpose_codes <- function(df,
                                  col_purpose = COL_PURPOSE_CODE,
                                  col_extended = COL_EXTENDED,
                                  col_received = COL_RECEIVED,
                                  col_commitments = COL_COMMITMENTS,
                                  col_geq = COL_GEQ,
                                  col_mobilized = COL_MOBILIZED) {
  
  df %>%
    rowwise() %>%
    mutate(
      # Split the purpose code string into a list (e.g., "14030:50|15110:50" → ["14030:50", "15110:50"])
      Purpose_codes = ifelse(
        !is.na(.data[[col_purpose]]) & .data[[col_purpose]] != "",
        str_split(.data[[col_purpose]], "\\|"),
        list(NULL)  # Keep NULL if column is empty
      )
    ) %>%
    # Unnest the list so each purpose code gets its own row (if there were multiple)
    unnest(Purpose_codes, keep_empty = TRUE) %>%
    mutate(
      # Extract only the numeric purpose code part (e.g., "14030" from "14030:50")
      !!col_purpose := ifelse(
        !is.na(Purpose_codes),
        str_extract(Purpose_codes, "^\\d+"),
        .data[[col_purpose]]
      ),
      # Extract the percentage value (e.g., "50" from "14030:50")
      Percentages = ifelse(
        !is.na(Purpose_codes),
        str_extract(Purpose_codes, "(?<=:)\\d+"),
        NA
      ),
      # Convert percentages to numeric and default to 100% if missing
      Percentages = ifelse(is.na(Percentages), 100, as.numeric(Percentages))
    ) %>%
    # Adjust all relevant financial columns by the parsed percentage
    mutate(
      !!col_extended := ifelse(!is.na(Purpose_codes),
                               .data[[col_extended]] * (Percentages / 100),
                               .data[[col_extended]]),
      !!col_received := ifelse(!is.na(Purpose_codes),
                               .data[[col_received]] * (Percentages / 100),
                               .data[[col_received]]),
      !!col_commitments := ifelse(!is.na(Purpose_codes),
                                  .data[[col_commitments]] * (Percentages / 100),
                                  .data[[col_commitments]]),
      !!col_geq := ifelse(!is.na(Purpose_codes),
                          .data[[col_geq]] * (Percentages / 100),
                          .data[[col_geq]]),
      !!col_mobilized := ifelse(!is.na(Purpose_codes),
                                .data[[col_mobilized]] * (Percentages / 100),
                                .data[[col_mobilized]])
    ) %>%
    select(-Purpose_codes) %>%  # Drop intermediate column
    ungroup()  # Ungroup after row-wise operations
}


# ------------------------------------------------------------------------------
# Loads and cleans CRS and channel mapping data for processing.
#
# This function performs the following steps:
#   - Loads CRS data from a CSV file
#   - Standardizes column names (replacing spaces and slashes with underscores)
#   - Ensures key fields are read as characters (especially before joins)
#   - Loads and cleans channel mapping data
#   - Joins channel parent categories to the CRS data using Channel_Code
#   - Applies the process_purpose_codes() function to expand purpose codes
#
# Arguments:
#   crs_path     : File path to the CRS CSV file (semicolon-separated)
#   channel_path : File path to the Channel to DAC category mapping CSV
#   col_currency : Column which indicated currency ID.
#   col_psi_flag : Column with PSI Flags.
#
# Returns:
#   A cleaned CRS data frame, enriched with channel metadata and split purpose codes
# ------------------------------------------------------------------------------
load_and_prepare_crs_data <- function(crs_path, 
                                      channel_path,
                                      col_currency = COL_CURRENCY,
                                      col_psi_flag = COL_PSI_FLAG) {
  
  print("...Loading and preparing CRS data...")
  # --- Load CRS Data ---
  crs_data <- read.csv(crs_path, sep = ";", header = TRUE, stringsAsFactors = FALSE, check.names = FALSE)
  
  # Convert columns from beginning to "Currency" into character type to preserve formatting
  currency_col_index <- which(colnames(crs_data) == col_currency)
  crs_data[1:currency_col_index] <- lapply(crs_data[1:currency_col_index], as.character)
  # Ensure PSI_flag is character (important for rule matching)
  if (col_psi_flag %in% colnames(crs_data)) {
    crs_data[[col_psi_flag]] <- as.character(crs_data[[col_psi_flag]])
  }
  
  # Clean column names (replace spaces and slashes with underscores)
  colnames(crs_data) <- gsub(" ", "_", colnames(crs_data))
  colnames(crs_data) <- gsub("/", "_", colnames(crs_data))
  
  # --- Load and Clean Channel Mapping ---
  print("...Loading and preparing Channel data...")
  channel_data <- read.csv(channel_path, sep = ";", check.names = FALSE)
  colnames(channel_data) <- gsub(" ", "_", colnames(channel_data))
  channel_data[] <- lapply(channel_data, as.character)
  
  # --- Join CRS with Channel Category ---
  crs_data <- crs_data %>%
    left_join(channel_data, by = c("Channel_Code" = "Channel_ID"))
  
  # --- Process purpose code column into multiple rows and adjust values ---
  print("...Processing multiple purpose codes...")
  crs_data <- process_purpose_codes(crs_data)
  
  return(crs_data)
}


# ------------------------------------------------------------------------------
# Loads and cleans the rule table from the Excel input file.
#
# This function performs the following steps:
#   - Loads the specified sheet from an Excel file
#   - Converts all columns to character type for consistency
#
# Arguments:
#   rules_path : File path to the Excel file containing the rule table
#   sheet_name : Name of the sheet containing rules (default: "DAC1b_input")
#
# Returns:
#   A cleaned data frame with all rule values as character strings
# ------------------------------------------------------------------------------
load_rules <- function(rules_path, sheet_name = "DAC1b_input") {
  print("...Loading rules...")
  rules <- readxl::read_excel(rules_path, sheet = sheet_name)
  rules[] <- lapply(rules, as.character)  # Convert all columns to character
  return(rules)
}


