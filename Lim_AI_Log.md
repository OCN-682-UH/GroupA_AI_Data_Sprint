## Group AI Developer Log

Project: OPIHI Ecological Survey Data Cleaning Pipeline (2004-2026)\
Created: November 1, 2026

------------------------------------------------------------------------

### 1A. Selected Prompts & Outputs

Our sessions focused on transitioning raw, multi-year files into an analytical master sheet. The workflow utilized the `tidyverse (dplyr, tidyr, readr, purrr)` and `janitor` packages in R.

#### Key Implementation Snippets

- Environmental Field Metadata Parser Function:

```{r}
process_metadata_sheet <- function(file_name) {
  cleaned_metadata <- read_csv(
    here("Data_Clean", file_name), 
    col_types = cols(.default = "c"),
    show_col_types = FALSE
  ) %>%
    clean_names() %>%
    rename_with(~ case_when(
      .x == "location"                ~ "site_raw",
      grepl("lines", .x)              ~ "number_of_transect_lines",
      grepl("longest", .x)            ~ "longest_transect_m",
      grepl("dist|space|spacing", .x) ~ "point_spacing",
      grepl("quad", .x)               ~ "number_of_quadrats_per_transect",
      grepl("end|stop", .x)           ~ "stop_time",
      TRUE ~ .x
    ))
  
  return(cleaned_metadata)
}
```

- Integrated Master Pipeline Sequence:

```{r}
master_output <- bind_rows(data_2004_2020, data_2024_2026) %>%
  left_join(metadata_2025_2026, by = c("date", "site_raw")) %>%
  mutate(
    start_time = coalesce(start_time.y, start_time.x),
    stop_time = coalesce(stop_time.y, stop_time.x),
    number_of_transect_lines = coalesce(number_of_transect_lines.y, number_of_transect_lines.x),
    point_spacing = coalesce(point_spacing.y, point_spacing.x),
    number_of_quadrats_per_transect = coalesce(number_of_quadrats_per_transect.y, number_of_quadrats_per_transect.x)
  ) %>%
  select(-ends_with(".x"), -ends_with(".y")) %>%
  filter(!is.na(date), !is.na(site_key), count !=0) %>%
  mutate(across(any_of(c(
    "transect_id", "quadrat_id", "position", "number_of_transect_lines", 
    "length_of_transect_lines", "number_of_quadrats_per_transect", 
    "latitude", "longitude", "point_spacing", "low_tide_height",
    "number_of_collecting", "longest_transect_m")), 
    ~suppressWarnings(as.numeric(gsub("[^0-9.-]", "", .)))))  %>%
  distinct(date, site_raw, site_key, transect_id, quadrat_id, position, taxon_raw,
           count, school, latitude, longitude, stop_time, length_of_transect_lines,
           .keep_all = TRUE)
```

### 1B. Concrete AI Mistake & Questionable Assumption

- **The Assumption:** When the AI was asked to read in three new metadata files, it assumed they followed the same tall/long design architecture as the previous biological data sheets (`Parser A` and `Parser B`). It generated a long-pivot function mapping the headers to `taxon_raw` and `count`.
- **The Reality:** The new files were purely horizontal environmental metadata tracking conditions (e.g., weather, low tide height, wave heights). Pivoting them long corrupted the structure of the data matrix, and vertically stacking them using `bind_rows()` left all environmental observations completely detached from their corresponding biological observations.
- **Rigorous Verification Check:** A validation test checking for the existence of values in columns like `weather` on rows containing biological data returned 100% `NA` values. This confirmed that environmental metrics were sitting underneath the main observations instead of beside them.

### 1C. Debugging Steps & Manual Checks

We systematically resolved four major console execution bottlenecks:

- **File Pathing Resolution:** Code execution crashed initially because the metadata parser could not locate files in the root path. We diagnosed that `process_wide_year()` had project pathing hardcoded within it. We updated `process_metadata_sheet()` to use `here("Data_Clean", file_name)` internally to achieve parity.
- **Header Sanitization (`rename()` vs `rename_with()`):** Strict renaming failed because headers varied across years (e.g., `# T lines` vs `t_lines`). We replaced explicit renaming with `rename_with()` and a `case_when(grepl())` configuration to clean columns dynamically based on fuzzy keyword matches.
- **Data Type Collisions:** `bind_row()` crashed because some files imported numeric values as characters due to mixed input strings (e.g., `"34m"`, `"N/A"`). We resolved this by forcing all initial raw imports to character text using `col_types = cols(.default = "c")`.
- **Downstream Regex Corrections:** Standard numeric conversions stripped the negative sign out of tidal fluctuation. We added manual checks and updated the text extraction regex from `"[^9-0.]"` to `"[^0-9.-]"` to preserve negative low tide metrics (e.g., `-0.3`).

### 1D. Taxonomy Harmonization Feature Addition

In our final optimization block, we corrected how the pipeline handles taxonomic updates. Instead of overwriting the historical field records directly inside the `taxon_raw` column, we created a localized `taxon_key` tracking index. This approach maps validated nomenclature cleanly while keeping the raw fieldwork fields untouched fro tracking purposes.

```{r}
master_output_cleaned <- master_output %>%
  left_join(taxon_lookup, by = "taxon_raw") %>%
  mutate(taxon_key = if_else(!is.na(clean_taxon_name) & clean_taxon_name != "",
                             clean_taxon_name, taxon_raw)) %>%
  select(-clean_taxon_name) %>%
  relocate(taxon_key, .after = taxon_raw)
```

### 1E. Disclosure Statement

- **Models utilized:** Google Gemini
- **Execution Verification:** Code snippets were checked against `dplyr 1.1.4` and `stringr 1.5.1` structural rules to ensure compatibility with the existing parsing modules.

------------------------------------------------------------------------

### 2A. Selected Prompts & Outputs

Our workflow focused on shifting an intertidal survey dataset from disparate, seasonal wide matrices into a unified horizontal and vertical master relational structure using `tidyverse (dplyr, tidyr, readr, purrr)` and `janitor` packages in R.

#### Key Implementation Snippets

- Final Transposed Block Parser Segment (with Regex Quadrat Extraction):

```{r}
quadrat_id  = as.character(str_extract(str_extract(sample_label, "(?i)(quadrat|q)-?\\s*\\d+"), "\\d+"))

position    = as.character(str_extract(str_extract(sample_label, "(?i)point\\s*\\d+\\.?\\d*|at point\\s*\\d+\\.?\\d*"), "\\d+\\.?\\d*"))
```

- Dynamic Stack-Multiplier Percent Cover Normalization:

```{r}
normalized_analysis_data <- master_output_cleaned %>%
  group_by(date, site_key, transect_id, quadrat_id, position) %>%
  mutate(
    total_rows_at_point  = n(),
    unique_species_found = n_distinct(taxon_raw),
    stack_multiplier     = total_rows_at_point / unique_species_found,
    scaled_count         = count / stack_multiplier,
    quadrat_total_pts    = sum(count, na.rm = TRUE) / stack_multiplier,
    percent_cover        = (scaled_count / quadrat_total_pts) * 100
  ) %>%
  ungroup() %>%
  select(-total_rows_at_point, -unique_species_found, -stack_multiplier,
         -scaled_count)
```

### 2B. Concrete AI Mistake & Questionable Assumption

- **The Assumption:** When data point sums for the 2025-2026 data frames began scaling past the 25-point baseline (inflating to `75` and `112`), the AI assumed this was a row-duplication artifact introduced solely by the horizontal metadata `left_join()`. It implemented static `case_when(raw_sum == 75 ~25)` division overrides to compress the figures.
- **The Reality:** The underlying historical biological files contained unflattened row structures and duplicate row fragments *before the metadata join was ever evaluated*. Applying static overrides failed completely on irregular row sets like `112`.
- **Rigorous Verification Check:** Manual review of the console output and file logs confirmed that the data frame contained split rows where different species entries sat on identical spatial points. If a species had a count of 3 in a quadrat summing to 112, the static override left the unscaled count intact, throwing off density metrics and underestimating actual percent abundance.

### 2C. Debugging Steps & Manual Checks

We systematically worked through R console errors using specific debugging techniques:

- **Tidyselect Mutation Crash:** The wide-sheet parser failed with `any_of() must be used within a selecting function`. We diagnosed that `any_of()` cannot run directly inside a `mutate()` text statement. We fixed this by introducing a robust base R `intersect()` string matcher to find the positional metric variables safely.
- **Object Collision in Validation Script:** The validation code crashed when trying to write out debugging records because `duplicate_count` was assigned as a single row-count integer value on one line, and then immediately passed down to `write_csv()`. We refactored this block to maintain the detailed data frame (`duplicate_rows_df`) and the total count tracker as two separate entities.
- **Integration of `quadrat_id`:** We traced how leaving `quadrat_id` out of the master `distinct()` passes caused R to flag valid quadrat sub-samples as duplicates. We tracked this metric from regex collection all the way down into the final 25-point threshold validation script:

```{r}
quadrat_validation <- master_output_cleaned %>%
  group_by(date, site_key, transect_id, quadrat_id, position) %>%
  summarize(
    total_rows_at_point = n(),
    unique_species_found = n_distinct(taxon_raw),
    stack_multiplier = total_rows_at_point / unique_species_found,
    total_points_counted = sum(count, na.rm = TRUE) / stack_multiplier,
    .groups = "drop"
  )
```

### 2D. Disclosure Statement

- **Models Utilized:** Google Gemini
- **Execution Verification:** Code constructs were cross-checked directly against `tidyverse v2.0.0` syntax parameters to guarantee stability with the project structure.
