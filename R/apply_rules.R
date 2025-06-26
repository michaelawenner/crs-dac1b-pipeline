# apply_rules.R
# -------------
# This script filters the CRS dataset row-wise using rule definitions and calculates
# aggregated financial indicators. The logic supports:
#   - exact matches
#   - exclusions (<>)
#   - prefix matches (e.g., 42x)
#
# External inputs:
#   - PLACEHOLDER: Placeholder string for skipping filters
#   - column_mapping: Mapping between rule column names and data column names
#
# Output:
#   - one-row data frame per rule with summed values for key indicators


# Functions
finance_filter <- function(data, finance_value) {
  # If finance_value is NULL or NA, return the data unfiltered
  if (is.null(finance_value) || is.na(finance_value)) {
    return(data)
  }
  
  # Split finance_value into individual conditions
  conditions <- str_split(finance_value, ",", simplify = TRUE)
  
  # Separate conditions for exact matches, "not in" exclusions, and "starts with"
  exact_matches <- conditions[!grepl("^<>", conditions) & !grepl("x$", conditions)]
  exclusions <- conditions[grepl("^<>", conditions)]
  starts_with <- conditions[grepl("x$", conditions)]
  
  # Apply the filtering
  data %>%
    filter(
      # Filter for exact matches
      (Type_of_finance %in% exact_matches) |
        
        # Exclude types specified with <>
        (any(grepl("^<>", exclusions)) & !Type_of_finance %in% str_replace(exclusions, "^<>", "")) |
        
        # Filter for starts with conditions (e.g., "42x" matches anything starting with "42")
        any(sapply(starts_with, function(prefix) {
          # Extract the part before "x" and match
          prefix_num <- substr(prefix, 1, regexpr("x$", prefix) - 1)
          safe_str_starts(Type_of_finance, prefix_num)
        }))
    )
}

# Function to filter data based on a specific rule column and corresponding data column
filter_by_rule <- function(data, rule_column, data_column) {
  if (is.null(rule_column) || is.na(rule_column) || rule_column == "") {
    return(data)  # Return the unfiltered data if no rule is provided
  }
  
  # Split the rule values by comma
  rule_values <- unlist(str_split(rule_column, ","))
  
  # Initialize logical vectors
  include <- rep(FALSE, nrow(data))  # Start with all rows excluded
  exclude <- rep(FALSE, nrow(data))  # Start with no rows excluded
  
  # Loop through each rule value
  for (value in rule_values) {
    if (grepl("^<>", value)) {
      # Exclusion case: Starts with "<>", exclude rows matching the condition
      exclusion_value <- substr(value, 3, nchar(value))
      exclude <- exclude | (data[[data_column]] == exclusion_value)
    } else if (grepl("x$", value)) {
      # Starts-with case: Ends with "x", include rows starting with the prefix
      prefix <- substr(value, 1, nchar(value) - 1)
      include <- include | str_starts(data[[data_column]], prefix)
    } else {
      # Exact match case: Include rows matching the value exactly
      include <- include | (data[[data_column]] == value) 
    }
  }
  
  # Combine inclusion and exclusion rules
  if (any(grepl("^<>", rule_values)) && !any(!grepl("^<>", rule_values))) {
    # Special case: Only exclusions defined, include all rows that are not excluded
    include <- !exclude
    include <- include | is.na(data[[data_column]]) | (data[[data_column]] == "")
  } else {
    # Regular case: Apply inclusion and exclusion logic
    include <- include & !exclude
  }
  
  # Return filtered data based on the logical vector
  data[include, , drop = FALSE]
}



# Apply rules to filter the data and calculate results
apply_rules <- function(rule_row, crs_data, column_mapping, PLACEHOLDER) {
  # Extract conditions from the rule row
  rule_row <- as.list(rule_row)
  
  # Filtered data starts as the full dataset
  filtered_data <- crs_data
  
  # Input validation 
  missing_cols <- setdiff(names(column_mapping), names(rule_row))
  if (length(missing_cols) > 0) {
    warning("Missing rule columns in input: ", paste(missing_cols, collapse = ", "))
  }
  
  
  # Apply each rule column to the corresponding data column
  for (rule_column in names(column_mapping)) {
    if (!is.null(rule_row[[rule_column]]) && !is.na(rule_row[[rule_column]]) && rule_row[[rule_column]] != "") {
      data_column <- column_mapping[[rule_column]]
      filtered_data <- filter_by_rule(filtered_data, rule_row[[rule_column]], data_column)
    }
  }
  
  # Extract relevant columns from rule_row for finance filtering
  type_of_finance_grants <- rule_row$`Type of finance grants`
  type_of_finance_non_grants <- rule_row$`Type of finance non grants`
  type_of_finance_amounts_received <- rule_row$`Type of finance Amounts received`
  sum_of_positive_GEQ <- rule_row$`Sum of postive GEQ`
  sum_of_negative_GEQ <- rule_row$`Sum of negative GEQ`
  sum_of_GEQ <- rule_row$`Sum of GEQ`
  sum_amounts_mobilized <- rule_row$`Amounts Mobilized`
  
  
  # Determine whether to skip calculation based on the placeholder
  skip_grants <- isTRUE(type_of_finance_grants == PLACEHOLDER)
  skip_non_grants <- isTRUE(type_of_finance_non_grants == PLACEHOLDER)
  skip_received <- isTRUE(type_of_finance_amounts_received == PLACEHOLDER)
  skip_pGEQ <- isTRUE(sum_of_positive_GEQ == PLACEHOLDER)
  skip_nGEQ <- isTRUE(sum_of_negative_GEQ == PLACEHOLDER)
  skip_GEQ <- isTRUE(sum_of_GEQ == PLACEHOLDER)
  skip_amounts_mobilized <- isTRUE(sum_amounts_mobilized == PLACEHOLDER)
  
  # Safe ID handling
  id <- ifelse(!is.null(rule_row$ID) && !is.na(rule_row$ID), rule_row$ID, NA)
  
  # Sum 1: Only apply `Type of finance grants` rule, with conditional filtering
  grant_sum <- if (!skip_grants) {
    filtered_data %>%
      finance_filter(type_of_finance_grants) %>%
      summarize(sum = sum(.data[[COL_EXTENDED]], na.rm = TRUE)) %>%
      pull(sum)
  } else {
    NA
  }
  
  com_grant_sum <- if (!skip_grants) {
    filtered_data %>%
      finance_filter(type_of_finance_grants) %>%
      summarize(sum = sum(.data[[COL_COMMITMENTS]], na.rm = TRUE)) %>%
      pull(sum)
  } else {
    NA
  }
  
  # Sum 2: Only apply `Type of finance non grants` rule, with conditional filtering
  non_grant_sum <- if (!skip_non_grants) {
    filtered_data %>%
      finance_filter(type_of_finance_non_grants) %>%
      summarize(sum = sum(.data[[COL_EXTENDED]], na.rm = TRUE)) %>%
      pull(sum)
  } else {
    NA
  }
  
  com_non_grant_sum <- if (!skip_non_grants) {
    filtered_data %>%
      finance_filter(type_of_finance_non_grants) %>%
      summarize(sum = sum(.data[[COL_COMMITMENTS]], na.rm = TRUE)) %>%
      pull(sum)
  } else {
    NA
  }
  
  # Sum 3: Only apply `Type of finance amounts received` rule, with conditional filtering
  received_sum <- if (!skip_received) {
    filtered_data %>%
      finance_filter(type_of_finance_amounts_received) %>%
      summarize(sum = sum(.data[[COL_RECEIVED]], na.rm = TRUE)) %>%
      pull(sum)
  } else {
    NA
  }
  
  # Sum 4: Only apply positive GEQ rule, with conditional filtering
  pGEQ_sum <- if (!skip_pGEQ) {
    filtered_data %>%
      finance_filter(sum_of_positive_GEQ) %>%
      filter(.data[[COL_GEQ]] > 0) %>%  # Ensure only positive values are included
      summarize(sum = sum(.data[[COL_GEQ]], na.rm = TRUE)) %>%
      pull(sum)
  } else {
    NA
  }
  
  # Sum 5: Only apply negative GEQ rule, with conditional filtering
  nGEQ_sum <- if (!skip_nGEQ) {
    filtered_data %>%
      finance_filter(sum_of_negative_GEQ) %>%
      filter(.data[[COL_GEQ]] < 0) %>%  # Ensure only negative values are included
      summarize(sum = sum(.data[[COL_GEQ]], na.rm = TRUE)) %>%
      pull(sum)
  } else {
    NA
  }
  
  # Sum 6: General GEQ rule, with conditional filtering
  GEQ_sum <- if (!skip_GEQ) {
    filtered_data %>%
      finance_filter(sum_of_GEQ) %>%
      summarize(sum = sum(.data[[COL_GEQ]], na.rm = TRUE)) %>%
      pull(sum)
  } else {
    NA
  }
  
  # Sum 7: General amounts mobilized rule, with conditional filtering
  AM_sum <- if (!skip_amounts_mobilized) {
    filtered_data %>%
      finance_filter(sum_amounts_mobilized) %>%
      summarize(sum = sum(.data[[COL_MOBILIZED]], na.rm = TRUE)) %>%
      pull(sum)
  } else {
    NA
  }
  
  
  # Return a data frame with the results for the current rule
  data.frame(
    ID = id, 
    "1121" = grant_sum, 
    "1122" = non_grant_sum, 
    "1130" = -received_sum,
    "1151" = com_grant_sum,
    "1152" = com_non_grant_sum,
    "1160" = GEQ_sum,
    Positive_Grant_Equivalent = pGEQ_sum,
    Negative_Grant_Equivalent = nGEQ_sum,
    Amounts_mobilized = AM_sum,
    check.names = FALSE
  )
  
}