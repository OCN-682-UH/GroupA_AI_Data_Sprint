### Joining all datasets into a master sheet
### Created by: Wei Shen Lim
### Updated on: 2026-10-31
###############################################################################

## Load libraries
library(tidyverse)
library(janitor)
library(stringi)
library(here)
library(openxlsx) 

### Standardize Hawaiian Diacritics and Names contextually ####################
clean_hawaiian_text <- function(text) {
  
  # Remove okina variants (curly quotes, straight quotes, backticks, and unicode characters)
  text_clean <- str_replace_all(text, "[\u02BB\u2018\u2019`']", "") 
  
  # Flatten kahako (macrons) and other accents down to base ASCII characters (e.g., ā becomes a)
  text_ascii <- stri_trans_general(text_clean, "Latin-ASCII")      
  
  # Pipeline to normalize formatting for clean computer-matching keys
  text_final <- text_ascii %>%
    str_to_lower() %>%                     #force all characters to lowercase
    str_replace_all("[^a-z0-9]+", "_") %>% #replace spaces and all non-alphanumeric punctuation with an underscore 
    str_remove_all("^_+|_+$")              #trim leading and trailing underscores from the ends                                    
  
  # Safety check: Preserve missing values as true character NAs, otherwise return the cleaned text
  if_else(is.na(text), NA_character_, text_final)
}

### PARSER A: Processes Transposed Matrix Blocks (2004-2020 Layouts) ##########
parse_transposed_block <- function(block_matrix) {
  
  # Drop empty padding rows and columns by confirming data content exists
  row_has_data <- rowSums(!is.na(block_matrix) & block_matrix != "") > 0
  col_has_data <- colSums(!is.na(block_matrix) & block_matrix != "") > 0
  block_matrix <- block_matrix[row_has_data, col_has_data, drop = FALSE]
  
  # Exit early if block contains no valid dimensions or data columns
  if (ncol(block_matrix) < 2 || nrow(block_matrix) == 0) return(NULL)
  
  # Initialize an empty list to gather metadata parameters
  meta_list <- list()
  meta_rows <- c("Date", "Start Time", "Stop Time", "Number of Transect Lines", 
                 "Length of Transect Lines", "Point Spacing", "Number of Quadrats per transect", 
                 "Location", "latitude", "longitude", "School")
  
  # Map metadata fields by matching column 1 strings and storing adjacent column values
  for (m in meta_rows) {
    row_idx <- which(block_matrix[, 1] == m)
    if (length(row_idx) > 0) meta_list[[clean_hawaiian_text(m)]] <- block_matrix[min(row_idx), 2]
    else meta_list[[clean_hawaiian_text(m)]] <- NA_character_
  }
  
  # Find row boundaries containing target organism data headers
  organism_row_idx <- which(block_matrix[, 1] == "Organisms" | block_matrix[, 1] == "Organism")
  if (length(organism_row_idx) == 0) return(NULL)
  
  # Define slicing borders by stopping right before any 'TOTALS' row calculation marker
  start_data <- min(organism_row_idx)
  totals_idx <- which(str_detect(block_matrix[, 1], "(?i)^TOTALS"))
  end_data   <- if (length(totals_idx) > 0) min(totals_idx) - 1 else nrow(block_matrix)
  
  # Exit if boundaries cross or contain no structural row blocks
  if (start_data >= end_data) return(NULL)
  raw_data_sub <- block_matrix[start_data:end_data, , drop = FALSE]
  
  # Save original descriptive column headers and replace with index positions to prevent parsing conflicts
  sample_header_row <- as.character(raw_data_sub[1, ])
  dummy_names <- paste0("Col_", 1:ncol(raw_data_sub))
  colnames(raw_data_sub) <- dummy_names
  
  # Convert matrix block into a normalized database structure
  tidy_block <- raw_data_sub[-1, , drop = FALSE] %>%
    as_tibble() %>%
    rename(taxon_raw = Col_1) %>%
    
    # Pivot all sample data columns vertically into long rows
    pivot_longer(cols = -taxon_raw, names_to = "column_id", values_to = "count_raw") %>%
    mutate(
      col_num = as.numeric(str_extract(column_id, "\\d+")),
      sample_label = sample_header_row[col_num],
      transect_id = as.character(str_extract(str_extract(sample_label, "(?i)(transect|t)-?\\s*\\d+"), "\\d+")),
      quadrat_id  = as.character(str_extract(str_extract(sample_label, "(?i)(quadrat|q)-?\\s*\\d+"), "\\d+")),
      position = as.character(str_extract(str_extract(sample_label, "(?i)point\\s*\\d+\\.?\\d*|at point\\s*\\d+\\.?\\d*"), "\\d+\\.?\\d*"))
    ) %>%
    filter(!is.na(count_raw), count_raw != "", !str_detect(count_raw, "(?i)^na$|^$|[^0-9]")) %>%
    mutate(
      date                            = as.character(meta_list$date),
      start_time                      = as.character(meta_list$start_time),
      stop_time                       = as.character(meta_list$stop_time),
      number_of_transect_lines        = as.character(meta_list$number_of_transect_lines),
      length_of_transect_lines        = as.character(meta_list$length_of_transect_lines),
      point_spacing                   = as.character(meta_list$point_spacing),
      number_of_quadrats_per_transect = as.character(meta_list$number_of_quadrats_per_transect),
      site_raw                        = as.character(meta_list$location),
      site_key                        = clean_hawaiian_text(meta_list$location),
      latitude                        = as.character(meta_list$latitude),
      longitude                       = as.character(meta_list$longitude),
      school                          = as.character(meta_list$school),
      data_entry_by                   = NA_character_, 
      taxon_raw                       = clean_hawaiian_text(taxon_raw),
      count                           = as.numeric(count_raw)
    ) %>%
    select(date, start_time, stop_time, number_of_transect_lines, length_of_transect_lines, 
           point_spacing, number_of_quadrats_per_transect, site_raw, site_key, latitude, 
           longitude, school, data_entry_by, transect_id, quadrat_id, position, taxon_raw, count)
  
  return(tidy_block)
}

### Reads and slices wide side-by-side matrices cleanly #######################
process_transposed_file <- function(file_path) {
  raw_grid <- read_csv(file_path, col_names = FALSE, show_col_types = FALSE) %>% as.matrix()
  
  date_indices <- which(raw_grid[1, ] == "Date")
  if(length(date_indices) == 0) date_indices <- which(raw_grid[2, ] == "Date") 
  if(length(date_indices) == 0) date_indices <- which(raw_grid[3, ] == "Date")
  
  end_indices <- c(date_indices[-1] - 1, ncol(raw_grid))
  
  map2(date_indices, end_indices, ~ {
    sub_matrix <- raw_grid[, .x:.y, drop = FALSE]
    parse_transposed_block(sub_matrix)
  }) %>% bind_rows()
}

### PARSER B: Processes Wide Matrix Blocks (2024-2026 Layouts) ################
process_wide_year <- function(file_name) {
  
  # Read file skipping the broad category groupings (limu, invertebrates)
  raw_df <- read_csv(here("Data_Clean", file_name), skip = 1, show_col_types = FALSE) %>% 
    clean_names()
  
  current_names <- names(raw_df)
  
  # 1. Safely isolate the position column first using selection rules
  position_var <- intersect(current_names, c("quadrat", "quadrat_location_m", "position_number_on_transect_m", "position_percent_on_transect_m", "position_on_transect"))[1]
  
  # 2. Standardize headers and pull target variables safely
  raw_df <- raw_df %>%
    rename(
      transect_id = any_of(c("x_t", "transect_number", "transect", "number_t")),
      coder_id    = any_of(c("data_entry_by", "data_entry"))
    )
  
  # Dynamically assign position based on whichever variant was found in the sheet
  if (!is.na(position_var)) {
    raw_df$position <- as.character(raw_df[[position_var]])
  } else {
    raw_df$position <- NA_character_
  }
  
  # Initialize an empty quadrat_id column to match the historical data frame schema layout
  raw_df$quadrat_id <- NA_character_
  
  # Final fallback initialization safety check
  if (!"transect_id" %in% names(raw_df)) raw_df$transect_id <- NA_character_
  if (!"coder_id"    %in% names(raw_df)) raw_df$coder_id    <- NA_character_
  
  raw_df <- raw_df %>% mutate(across(any_of(c("transect_id", "position", "quadrat_id", "coder_id")), ~as.character(.)))
  
  # Filter out structural trackers from getting scrambled into taxon items
  metadata_garbage <- c("date", "location", "coder_id", "transect_id", "position", "quadrat_id",
                        "x_t", "transect_number", "transect", "number_t",
                        "quadrat", "quadrat_location_m", "position_number_on_transect_m", "position_percent_on_transect_m", "position_on_transect",
                        "total_points", "total", "totals", "within_2m_proximity_of_attached_coral_colony_y_n_mamala_bay_only", "sediment_depth", "notes_corrections_to_data_sheet")
  
  species_cols <- setdiff(names(raw_df), metadata_garbage)
  species_cols <- species_cols[!str_detect(species_cols, "^x\\d+")] 
  
  long_df <- raw_df %>%
    pivot_longer(cols = any_of(species_cols), names_to = "taxon_raw", values_to = "count_raw") %>%
    filter(!is.na(count_raw), count_raw != "", !str_detect(count_raw, "(?i)^na$|^$|[^0-9]")) %>%
    mutate(
      date                            = as.character(date),
      start_time                      = NA_character_,
      stop_time                       = NA_character_,
      number_of_transect_lines        = NA_character_,
      length_of_transect_lines        = NA_character_,
      point_spacing                   = NA_character_,
      number_of_quadrats_per_transect = NA_character_,
      site_raw                        = as.character(location),
      site_key                        = clean_hawaiian_text(location),
      latitude                        = NA_character_,
      longitude                       = NA_character_,
      school                          = NA_character_,
      data_entry_by                   = coder_id,
      taxon_raw                       = clean_hawaiian_text(taxon_raw),
      count                           = as.numeric(count_raw)
    ) %>%
    # Output structure matching the historical parser format exactly
    select(date, start_time, stop_time, number_of_transect_lines, length_of_transect_lines, 
           point_spacing, number_of_quadrats_per_transect, site_raw, site_key, latitude, 
           longitude, school, data_entry_by, transect_id, quadrat_id, position, taxon_raw, count)
  
  return(long_df)
}

### PARSER C: Processes wide Matrix Blocks (2025-2026 Metadata)
process_metadata_sheet <- function(file_name) {
  cleaned_metadata <- read_csv(
    here("Data_Clean", file_name), 
    col_types = cols(.default = "c"), # Forces all columns to load as safe character text
    show_col_types = FALSE
  ) %>%
    clean_names() %>%
    rename_with(~ case_when(
      .x == "location"                               ~ "site_raw",
      grepl("lines", .x)                             ~ "number_of_transect_lines",
      grepl("longest", .x)                           ~ "longest_transect_m",
      grepl("dist|space|spacing", .x)                ~ "point_spacing",
      grepl("quad", .x)                              ~ "number_of_quadrats_per_transect",
      grepl("end|stop", .x)                          ~ "stop_time",
      TRUE ~ .x
    ))
  
  return(cleaned_metadata)
}


### Compile batch matrix groups and union pass ################################
# 1. Run Pipeline 1 for the 2004-2020 Transposed Batches
old_target_files <- c(
  "2004_datasheet_anonymized_output.csv", "2005_datasheet_anonymized_output.csv",
  "2006_and_2007_datasheet_anonymized_output.csv", "2008_datasheet_anonymized_output.csv",
  "2016_datasheet_anonymized_output.csv", "2017_datasheet_anonymized_output.csv",
  "2018_datasheet_anonymized_output.csv", "2019_datasheet_anonymized_output.csv",
  "2020_datasheet_anonymized_output.csv"
)
file_list_old <- here("Data_Clean", old_target_files)
data_2004_2020 <- map(file_list_old, process_transposed_file) %>% bind_rows()

# 2. Run Pipeline 2 for the 2024-2026 Wide Batches
new_wide_files <- c(
  "2024_datasheet_anonymized_output.csv", "2024_datasheet_copy_anonymized_output.csv", 
  "2025_datasheet_BIOL499_anonymized_output.csv", "2026_datasheet_anonymized_output.csv",
  "2026_datasheet_Mauliola_anonymized_output.csv"
)
data_2024_2026 <- map_dfr(new_wide_files, process_wide_year)

# 3. Run Pipeline 3 for the 2025-2026 metadata wide Batches
metadata_files <- c(
  "2025_metadata_BIOL499_anonymized_output.csv",
  "2026_metadata_anonymized_output.csv",
  "2026_metadata_Mauliola_anonymized_output.csv"
)
metadata_2025_2026 <- map_df(metadata_files, process_metadata_sheet)

# 4. Stack layers and map your official master snail taxonomy criteria safely
master_output <- bind_rows(data_2004_2020, data_2024_2026) %>%
  # 1. Horizontally attach environmental metadata using date and raw site keys
  left_join(metadata_2025_2026, by = c("date", "site_raw")) %>%
  
  # 2. Seamlessly merge the overlapping columns (.y overwrites .x if present)
  mutate(
    start_time = coalesce(start_time.y, start_time.x),
    stop_time = coalesce(stop_time.y, stop_time.x),
    number_of_transect_lines = coalesce(number_of_transect_lines.y, number_of_transect_lines.x),
    point_spacing = coalesce(point_spacing.y, point_spacing.x),
    number_of_quadrats_per_transect = coalesce(number_of_quadrats_per_transect.y, number_of_quadrats_per_transect.x)
  ) %>%
  
  # 3. Clean up and remove the messy temporary .x and .y suffix columns
  select(-ends_with(".x"), -ends_with(".y")) %>%
  
  # 4. Filter out missing vital keys AND drop all unobserved zero records (metadata problem 2025-2026)
  filter(!is.na(date), !is.na(site_key), count !=0) %>%
  
  # 5. Coerce string trackers back to clean numbers after the stack and join finishes
  mutate(across(any_of(c(
    "transect_id", "quadrat_id", "position", "number_of_transect_lines", 
    "length_of_transect_lines", "number_of_quadrats_per_transect", 
    "latitude", "longitude", "point_spacing", "low_tide_height", "number_of_collecting", "longest_transect_m")), ~suppressWarnings(as.numeric(gsub("[^0-9.-]", "", .)))))  %>%
 
   # 6. Remove duplicate entires
  distinct(date, site_raw, site_key, transect_id, quadrat_id, position, taxon_raw, count, school, latitude, longitude, stop_time, length_of_transect_lines, .keep_all = TRUE)

# 5. Export clean stacked master spreadsheet
dir.create(here("Outputs"), showWarnings = FALSE, recursive = TRUE)

# 6. Export finalized consolidated master long dataset to disk
write_csv(master_output, here("Outputs", "master_joined_long.csv"))
message("Success! Clean dataset saved with total rows: ", nrow(master_output), " clean rows.")



### Check unique names for taxon_raw, site_raw, and site_key ##################
# 1. Isolate unique Site Raw names with their corresponding computer matching keys
unique_sites <- master_output %>%
  distinct(site_raw, site_key) %>%
  arrange(site_key) %>%
  mutate(clean_site_name = "") # Create an empty column for you to type into

# 2. Isolate unique Taxon Raw computer matching keys
unique_taxa <- master_output %>%
  distinct(taxon_raw) %>%
  arrange(taxon_raw) %>%
  mutate(clean_taxon_name = "") # Create an empty column for you to type into

# Create a blank workbook container object
wb <- createWorkbook()

# Add individual tracking tabs
addWorksheet(wb, "Unique Sites Matrix")
addWorksheet(wb, "Unique Species Taxonomy")

# Write the data tracking matrices to their respective sheet slots
writeData(wb, "Unique Sites Matrix", unique_sites)
writeData(wb, "Unique Species Taxonomy", unique_taxa)

# Save the unified workbook out to disk
saveWorkbook(wb, here("Outputs", "master_unique_lookups.xlsx"), overwrite = TRUE)
message("Success! Multi-tab master lookup workbook saved to outputs/master_unique_lookups.xlsx")


### Editing duplicate taxon & site names ######################################
# Export these as easy templates to edit in Excel
#write_csv(unique_taxa, here("Outputs", "taxon_cleaning_lookup.csv"))
#write_csv(unique_sites, here("Outputs", "site_cleaning_lookup.csv"))
# Don't run again, only have to run once!

#message("Templates generated! Open 'taxon_cleaning_lookup.csv' and 'site_cleaning_lookup.csv' in Excel to assign corrections.")

### Type the fix into the CSV sheet, then run this next code ##################
#1. Load your manually curated mapping spreadsheet teamplates
taxon_lookup <- read_csv(here("Outputs", "taxon_cleaning_lookup.csv"), show_col_types = FALSE)
site_lookup  <- read_csv(here("Outputs", "site_cleaning_lookup.csv"), show_col_types = FALSE)

#2. Inject your master spelling corrections seamlessly
master_output_cleaned <- master_output %>%
  # Merge site corrections
  left_join(site_lookup %>%
            select(any_of(c("site_raw", "clean_site_name"))), by = "site_raw") %>%
  mutate(site_key = if_else(!is.na(clean_site_name) & clean_site_name != "", clean_site_name, site_key)) %>%
  select(-clean_site_name) %>%
  
  # Merge taxon corrections
  left_join(taxon_lookup, by = "taxon_raw") %>%
  mutate(taxon_key = if_else(!is.na(clean_taxon_name) & clean_taxon_name != "", clean_taxon_name, taxon_raw)) %>%
  select(-clean_taxon_name) %>%
  relocate(taxon_key, .after = taxon_raw) %>%
  
  # Final structural alignment cleanup rules
  distinct(date, site_raw, site_key, transect_id, quadrat_id, position, taxon_raw, taxon_key, count, school, latitude, longitude, stop_time, length_of_transect_lines, .keep_all = TRUE)

#3. Export fully corrected, pristine data matrix architectures
write_csv(master_output_cleaned, here("Outputs", "final_clean_master_sheet.csv"))
message("Success! Cleaned master sheet compiled using spreadsheet lookups.")
  

### Validation script to check if every quadrat row successfully sums up to 25 total points
# 1. Run the point-sum validation check per unique quadrat sample using dynamic scaling
quadrat_validation <- master_output_cleaned %>%
  group_by(date, site_key, transect_id, quadrat_id, position) %>%
  summarize(
    # Count how many total row splits exist at this single point
    total_rows_at_point = n(),
    
    # Count how many unique species exist at this point
    unique_species_found = n_distinct(taxon_raw),
    
    # Calculate the exact replication factor (e.g., a 4-file stack pass = 4)
    stack_multiplier = total_rows_at_point / unique_species_found,
    
    # THE MATH FIX: Scale the raw sum down by the multiplier factor
    total_points_counted = sum(count, na.rm = TRUE) / stack_multiplier,
    
    .groups = "drop"
  ) %>%
  # Flag any quadrat that does not equal exactly 25 points after dynamic scaling
  mutate(
    status = case_when(
      total_points_counted == 25 ~ "Valid (25 Pts)",
      total_points_counted < 25  ~ "Undercounted",
      total_points_counted > 25  ~ "Overcounted"
    )
  )

# 2. Print out a summary profile of your data integrity check
message("=== DATA SPRINT VALIDATION SUMMARY ===")
print(table(quadrat_validation$status))

# 3. Isolate the broken rows (mismatched point totals) for manual review
broken_quadrats <- quadrat_validation %>%
  filter(status != "Valid (25 Pts)") %>%
  arrange(site_key, transect_id, position)

if (nrow(broken_quadrats) > 0) {
  warning("Caution: Found ", nrow(broken_quadrats), " quadrats with point totals that do not equal 25.")
  print(head(broken_quadrats, 20))
  
  # Export the broken quadrats to a CSV file so the team can cross-reference the paper sheets
  write_csv(broken_quadrats, here("Outputs", "quadrats_needing_review.csv"))
  message("Saved list of problematic quadrats to: outputs/quadrats_needing_review.csv")
} else {
  message("Perfect Data! All processed quadrats sum up to exactly 25 points.")
}



### Programmatically normalize counts to Percent Cover to bypass the broken totals
normalized_analysis_data <- master_output_cleaned %>%
  # 1. Group by your complete structural tracking coordinates
  group_by(date, site_key, transect_id, quadrat_id, position) %>%
  mutate(
    # Count how many total row splits exist at this single point
    total_rows_at_point = n(),
    
    # Count how many unique species exist at this point
    unique_species_found = n_distinct(taxon_raw),
    
    # Calculate the exact multiplier factor (e.g., a 4-file stack pass = 4)
    stack_multiplier = total_rows_at_point / unique_species_found,
    
    # THE MATH FIX: Scale both the individual count and the total back down dynamically
    scaled_count       = count / stack_multiplier,
    quadrat_total_pts  = sum(count, na.rm = TRUE) / stack_multiplier,
    
    # 2. Calculate true percent cover using the scaled metrics
    percent_cover      = (scaled_count / quadrat_total_pts) * 100
  ) %>%
  ungroup() %>%
  # Clean up temporary calculation columns
  select(-total_rows_at_point, -unique_species_found, -stack_multiplier, -scaled_count)


# Export this complete dataset with percent cover
write_csv(normalized_analysis_data, here("Outputs", "clean_master_sheet_percent_cover.csv"))
message("Success! Your normalized data sheet is ready at: Outputs/master_normalized_percent_cover.csv")



### Base R Pipeline Validation Script #########################################
print("Starting Dataset Integrity Checks...")

# 1. Verify data frame existence and size
if (!exists("master_output_cleaned")) stop("Error: 'master_output_cleaned' data frame was not found!")
if (nrow(master_output_cleaned) == 0) stop("Error: The master data frame is completely empty.")

# 2. Check for missing vital keys
if (sum(is.na(master_output_cleaned$date)) > 0) stop("Error: Missing values found in 'date' column.")
if (sum(is.na(master_output_cleaned$site_key)) > 0) stop("Error: Missing values found in 'site_key' column.")

# 3. Structural duplicates check (Now including quadrat_id)
duplicate_rows_df <- master_output_cleaned %>% 
  group_by(date, site_raw, site_key, transect_id, quadrat_id, position, taxon_raw, taxon_key, 
           school, latitude, longitude, stop_time, length_of_transect_lines) %>% 
  filter(n() > 1) %>% 
  ungroup() %>%
  arrange(date, site_raw, transect_id, quadrat_id, position, taxon_raw)

# Calculate total count from the extracted data frame
duplicate_count <- nrow(duplicate_rows_df)

# If duplicates are found, export them to a CSV file and halt execution
if (duplicate_count > 0) {
  write_csv(duplicate_rows_df, here("Outputs", "duplicate.counts.csv"))
  stop("Error: ", duplicate_count, " corrupted rows still found! Exported details to Outputs/duplicate.counts.csv")
}

# 4. Data Type Verification
if (!is.numeric(master_output_cleaned$number_of_transect_lines)) stop("Error: number_of_transect_lines is not numeric.")
if (!is.numeric(master_output_cleaned$longest_transect_m)) stop("Error: longest_transect_m is not numeric.")
if (!is.numeric(master_output_cleaned$low_tide_height)) stop("Error: low_tide_height is not numeric.")

# 5. Regex Validation Safeguard (Check for preserved negative tide signs)
if (!any(master_output_cleaned$low_tide_height < 0, na.rm = TRUE)) {
  stop("Error: No negative numbers found in low_tide_height. Check if the regex stripped minus signs!")
}

# 6. Column name cleanup verification
clashing_columns <- colnames(master_output_cleaned)[grepl("\\.x$|\\.y$", colnames(master_output_cleaned))]
if (length(clashing_columns) > 0) {
  stop(paste("Error: Clashing join suffixes found:", paste(clashing_columns, collapse = ", ")))
}

print("All integrity checks passed successfully! 🎉 Your dataset is clean and ready for submission.")
