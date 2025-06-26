# ------------------------------------------------------------------------------
# Fills predefined Excel sheets with data from the aggregated results.
#
# This function writes numeric values from the final result data frame into 
# predefined positions in two sheets of a DAC template Excel workbook:
#   - One sheet with values in local currency (e.g. CHF)
#   - One sheet with values in USD (converted from local currency)
#
# This assumes the Excel sheets already exist in the workbook and contain:
#   - IDs in column 2 (used to match rows)
#   - CRS column identifiers in row 5 (used to match columns)
#
# The function performs the following:
#   - For each cell in the `result_df`, finds the correct row and column
#     in both Excel sheets based on ID and CRS code.
#   - Writes the raw value into the local currency sheet.
#   - Converts the value to USD (divide by exchange rate and 1000),
#     and writes it into the USD sheet.
#   - Catches and logs errors when a match is not found.
#
# Arguments:
#   result_df     : Data frame with final values (must include an 'ID' column)
#   template_path : Path to the original Excel template (not used here)
#   output_path   : Path to the Excel file to modify and save (must already exist)
#   sheet_lc      : Name of the sheet for values in local currency (e.g. "CHF")
#   sheet_usd     : Name of the sheet for values in Mio USD
#   exchange_rate : Conversion rate from local currency to USD
#
# Returns:
#   This function does not return a value. It modifies the Excel workbook in-place
#   and saves it at `output_path`, overwriting if the file already exists.
#
# Notes:
#   - The function expects the `output_path` workbook to contain both target sheets
#     (`sheet_lc` and `sheet_usd`) pre-created with the correct structure.
#   - This is tailored to the Swiss CRS-DAC process and may need adaptation elsewhere.
# ------------------------------------------------------------------------------

fill_excel_template <- function(result_df,
                                template_path,
                                output_path,
                                sheet_lc,
                                sheet_usd,
                                exchange_rate) {
  library(openxlsx)
  library(readr)
  library(dplyr)
  library(stringr)
  
  print("...Filling templates...")
  
  if (!"ID" %in% colnames(result_df)) {
    stop("Missing 'ID' column in result dataframe.")
  }
  
  # Ensure ID is character (for comparison with Excel cells)
  result_df$ID <- as.character(result_df$ID)
  # Load the existing workbook
  workbook <- loadWorkbook(template_path)
  
  # Read sheets to find coordinates
  sheet_data_lc <- read.xlsx(workbook, sheet = sheet_lc, colNames = FALSE, rowNames = FALSE)
  sheet_data_usd <- read.xlsx(workbook, sheet = sheet_usd, colNames = FALSE, rowNames = FALSE)
  
  # Write values to CHF sheet
  for (i in seq_len(nrow(result_df))) {
    row_id <- result_df$ID[i]
    for (col_name in colnames(result_df)) {
      tryCatch({
        excel_row <- which(sheet_data_lc[, 2] == row_id)
        excel_col <- which(sheet_data_lc[5, ] == as.character(col_name))
        
        # Write the value to the correct cell in the Excel sheet
        writeData(workbook, sheet = sheet_lc, 
                  x = result_df[i, col_name], 
                  startCol = excel_col, startRow = excel_row + 1)
      }, error = function(e) {
        # Handle errors (e.g., if no row or column is found)
        #cat("Error: No row or column found for row:", row_id, "col:", col_name, "\n")
      })
    }
  }
  
  # Write values to USD sheet
  for (i in seq_len(nrow(result_df))) {
    row_id <- result_df$ID[i]
    for (col_name in colnames(result_df)) {
      tryCatch({
        excel_row <- which(sheet_data_usd[, 2] == row_id)
        excel_col <- which(sheet_data_usd[5, ] == as.character(col_name))
        
        # Write the value to the correct cell in the Excel sheet
        writeData(workbook, sheet = sheet_usd, 
                  x = result_df[i, col_name]/exchange_rate/1000, 
                  startCol = excel_col, startRow = excel_row + 1)
      }, error = function(e) {
        # Handle errors (e.g., if no row or column is found)
        #cat("Error: No row or column found for row:", row_id, "col:", col_name, "\n")
      })
    }
  }
  
  # Save the filled workbook to the specified output path
  saveWorkbook(workbook, output_path, overwrite = TRUE)
  print("...DONE!")
}
