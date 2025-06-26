# Define the safe_str_starts function
safe_str_starts <- function(column, pattern) {
  if (is.null(pattern) || is.na(pattern) || pattern == "") {
    return(rep(FALSE, length(column)))  # If pattern is invalid, no rows match
  } else {
    return(str_starts(column, pattern))  # Apply str_starts to valid pattern
  }
}


# Helper function to handle NA correctly
custom_sum <- function(x) {
  if (all(is.na(x))) {
    return(NA)  # Return NA if all values are NA
  } else {
    return(sum(x, na.rm = TRUE))  # Otherwise, sum ignoring NA
  }
}