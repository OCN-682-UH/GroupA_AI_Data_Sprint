# AI Developer Logs - Group A
## Wei Shen Lim, Fabi Zamora, Natalie Goeler-Slough, Ellie S Jones

### Lim

#### 1A. Selected Prompts & Outputs

Our sessions focused on transitioning raw, multi-year files into an analytical master sheet. The workflow utilized the `tidyverse (dplyr, tidyr, readr, purrr)` and `janitor` packages in R.

##### Key Implementation Snippets

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

#### 1B. Concrete AI Mistake & Questionable Assumption

- **The Assumption:** When the AI was asked to read in three new metadata files, it assumed they followed the same tall/long design architecture as the previous biological data sheets (`Parser A` and `Parser B`). It generated a long-pivot function mapping the headers to `taxon_raw` and `count`.
- **The Reality:** The new files were purely horizontal environmental metadata tracking conditions (e.g., weather, low tide height, wave heights). Pivoting them long corrupted the structure of the data matrix, and vertically stacking them using `bind_rows()` left all environmental observations completely detached from their corresponding biological observations.
- **Rigorous Verification Check:** A validation test checking for the existence of values in columns like `weather` on rows containing biological data returned 100% `NA` values. This confirmed that environmental metrics were sitting underneath the main observations instead of beside them.

#### 1C. Debugging Steps & Manual Checks

We systematically resolved four major console execution bottlenecks:

- **File Pathing Resolution:** Code execution crashed initially because the metadata parser could not locate files in the root path. We diagnosed that `process_wide_year()` had project pathing hardcoded within it. We updated `process_metadata_sheet()` to use `here("Data_Clean", file_name)` internally to achieve parity.
- **Header Sanitization (`rename()` vs `rename_with()`):** Strict renaming failed because headers varied across years (e.g., `# T lines` vs `t_lines`). We replaced explicit renaming with `rename_with()` and a `case_when(grepl())` configuration to clean columns dynamically based on fuzzy keyword matches.
- **Data Type Collisions:** `bind_row()` crashed because some files imported numeric values as characters due to mixed input strings (e.g., `"34m"`, `"N/A"`). We resolved this by forcing all initial raw imports to character text using `col_types = cols(.default = "c")`.
- **Downstream Regex Corrections:** Standard numeric conversions stripped the negative sign out of tidal fluctuation. We added manual checks and updated the text extraction regex from `"[^9-0.]"` to `"[^0-9.-]"` to preserve negative low tide metrics (e.g., `-0.3`).

#### 1D. Taxonomy Harmonization Feature Addition

In our final optimization block, we corrected how the pipeline handles taxonomic updates. Instead of overwriting the historical field records directly inside the `taxon_raw` column, we created a localized `taxon_key` tracking index. This approach maps validated nomenclature cleanly while keeping the raw fieldwork fields untouched fro tracking purposes.

```{r}
master_output_cleaned <- master_output %>%
  left_join(taxon_lookup, by = "taxon_raw") %>%
  mutate(taxon_key = if_else(!is.na(clean_taxon_name) & clean_taxon_name != "",
                             clean_taxon_name, taxon_raw)) %>%
  select(-clean_taxon_name) %>%
  relocate(taxon_key, .after = taxon_raw)
```

#### 1E. Disclosure Statement

- **Models utilized:** Google Gemini
- **Execution Verification:** Code snippets were checked against `dplyr 1.1.4` and `stringr 1.5.1` structural rules to ensure compatibility with the existing parsing modules.

------------------------------------------------------------------------

#### 2A. Selected Prompts & Outputs

Our workflow focused on shifting an intertidal survey dataset from disparate, seasonal wide matrices into a unified horizontal and vertical master relational structure using `tidyverse (dplyr, tidyr, readr, purrr)` and `janitor` packages in R.

##### Key Implementation Snippets

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

#### 2B. Concrete AI Mistake & Questionable Assumption

- **The Assumption:** When data point sums for the 2025-2026 data frames began scaling past the 25-point baseline (inflating to `75` and `112`), the AI assumed this was a row-duplication artifact introduced solely by the horizontal metadata `left_join()`. It implemented static `case_when(raw_sum == 75 ~25)` division overrides to compress the figures.
- **The Reality:** The underlying historical biological files contained unflattened row structures and duplicate row fragments *before the metadata join was ever evaluated*. Applying static overrides failed completely on irregular row sets like `112`.
- **Rigorous Verification Check:** Manual review of the console output and file logs confirmed that the data frame contained split rows where different species entries sat on identical spatial points. If a species had a count of 3 in a quadrat summing to 112, the static override left the unscaled count intact, throwing off density metrics and underestimating actual percent abundance.

#### 2C. Debugging Steps & Manual Checks

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

#### 2D. Disclosure Statement

- **Models Utilized:** Google Gemini
- **Execution Verification:** Code constructs were cross-checked directly against `tidyverse v2.0.0` syntax parameters to guarantee stability with the project structure.

### Zamora

#### Prompts Used for Each Sections

3A. Taxon Heat Map

1.  *“I would like to build a heat map from `sample_clean_master_sheet.csv`, which is a truncated version of the full datasheet I will be analyzing, but retains all columns. What parameters would be appropriate to map (percent cover, region, and so on) and please annotate any code you propose.”*
    1.  *(Supplied `sample_clean_master_sheet.csv` so column names and structure could be verified rather than assumed.)*
2.  *“Why is substrate only present in 2024–2026?”* (raised after reviewing the functional group totals, which prompted an audit of whether `percent_cover` is comparable across survey eras)

4A. Reusable Group Functions

1.  *“Can you find a way to create a dropdown for the heat map that selects a functional group (algae, invertebrate and so on) with mean cover by abundance shown for the selected group?”*
2.  *“Turf should be its own category, and crustose coralline algae should be classified under Algae.”* (correcting the AI’s draft classification after reviewing the group shares)
3.  *“Why is Cellana sandwicensis classified under Substrate?”* (surfaced the unbounded `sand` regex collision)
4.  *“How do I change the palette to the `mako`colors?”* (to keep the interactive figure consistent with the static ones)

5A. Interactive Heatmap with Dropdown

1.  *“The Mollusc test plot renders correctly. Please help me build the dropdown version.”*
2.  *“How do I modify the color scale on the plotly and how do I lock the dropdown to the top-right corner so that it does not distort the plot area? I'd also like to move the dropdown to the bottom instead.”*
3.  *“The dropdown is no longer visible.”* (after the invalid `showarrow` and `name` keys were introduced into the `updatemenus` object)
4.  *“How do I anchor the mean cover legend so it does not move between selections?”*
5.  *“Please provide detailed annotations for this code block.”*

#### 3A. Static Taxon Heatmap

- Workflow focused on rendering a taxon × year abundance matrix from the cleaned master sheet, using tidyverse (dplyr, tidyr, forcats) and viridisLite.
- Key implementation snippet — explicit zero-completion before averaging:

```{r}
taxon_year <- master|>
  filter(taxon_key %in% top_taxa) |>
  select(all_of(quad_keys), year, taxon_key, percent_cover) |>
  complete(nesting(!!!syms(c(quad_keys, "year"))), taxon_key,
           fill = list(percent_cover = 0)) |>
  group_by(year, taxon_key) |>
  summarize(mean_cover = mean(percent_cover), n_quadrats = n(), .groups = "drop") %>%
  mutate(taxon_key = fct_reorder(taxon_key, mean_cover, .fun = mean))
```

#### 3B. AI Mistake and Questionable Assumption

- Assumption: The AI initially generated a master_complete object that completed the full taxon × quadrat grid before filtering to the top twelve taxa, and placed it at the top of the chunk as though downstream code depended on it
- Reality: nothing used it, was kinda just sitting there
- Check: Although no error occurred, after reading through the code, I noticed that no downstream items actually used the object, so I removed it

#### 3C. Debugging Steps and Manual Aesthetic Adjustments

- Assumption: The AI proposed grouping on four columns.
- Reality: Testing five candidate keys against the data showed only date + site_key + transect_id + quadrat_id + position yields quadrats summing to exactly 100% (7,108 of 7,108). The four-column version produced sums up to 1,300%, because quadrat_id repeats across positions
- Addition checks:
  - Proposed colors were not very eye pleasing, so I adjusted, using the `mako` colors
  - Had to manually adjust the caption positioning and the `hjust` for the years to make sure they were not cut off

#### 4A Reusable Group Functions

- Refactored repeated per-group summaries into two functions so the static and interactive figures share one calculation

```{r}
group_summary <- function(data, group, n_taxa = 12) {
  d <- data %>% filter(functional_group == group)
  keep <- d %>% group_by(taxon_key) %>%
    summarize(total = sum(percent_cover, na.rm = TRUE), .groups = "drop") %>%
    slice_max(total, n = n_taxa) %>% pull(taxon_key)
  d %>% filter(taxon_key %in% keep) %>% ...
}
```

#### 4B. AI Mistake and Questionable Assumption

- Assumption: Asked to name the key columns for `pivot_longer()`, AI predicted what `janitor::clean_names()` would produce, giving `t` and `position_on_transect_m`.
- Reality: `clean_names()` applies a default substitution of \# → number, so the actual names are number_t and position_number_on_transect_m.
  - Pivot used `any_of()`, silently ignores names that don’t exist, both key columns were swept into taxon_raw as though they were species. No error was raised.
- Check: `names(long_2024)` returned 9 columns instead of 11, with the transect and position keys missing; `filter(str_detect(taxon_raw, "number"))` confirmed they had become taxon rows.
  - Resolved by `running names()` after `clean_names()` and pasting the real output, rather than predicting it

#### 4C. Debugging Steps and Manual Aesthetic Adjustments

- Two taxa were misclassified by unbounded patterns:

  - `Cellana sandwicensis` (ʻopihi) matched `sand` and was filed as Substrate; `Grapsus tenuicrustatus` (a crab) matched `crust` and became Unresolved.

  - Fixed with `\\bsand\\b` and `\\bcrust\\b`, then verified by printing all 207 classifications by eye rather than trusting a second regex audit

#### 5A. Interactive Heatmap with Dropdown

- Built a plotly heat map with a functional-group selector, using one trace per group and visibility toggling, so the figure works as static HTML with no server

```{r}
to_colorscale <- function(cols) {
  cols <- substr(cols, 1, 7)          # strip alpha: plotly rejects 8-digit hex
  n <- length(cols)
  map(seq_len(n), \(i) list((i - 1) / (n - 1), cols[i]))
}

buttons <- map(groups, function(g) {
  list(method = "update", label = g,
       args = list(list(visible = groups == g),
                   list(title = list(text = paste0(g, ": mean percent cover")))))
})
```

#### 5B. Debugging Steps and Manual Aesthetic Adjustments

- Silent palette failure: `viridisLite::mako()` returns 8-digit hex with an alpha channel (`#0B0405FF`). plotly cannot parse it and falls back to its default without warning. Resolved with `substr(cols, 1, 7)`.

- Margin reservation: plotly does not auto-expand for colorbars or menus. The anchored colorbar at `x = 1.02` was clipped until the right margin was widened from 30 to 100; the menu squeezed the plot until the bottom margin reached 140.

- Expansion direction: With the menu placed below the plot, the default downward expansion ran the option list off the canvas. Set `direction = "up"` so it overlays the panel instead.

- Title: `"Mean\ncover (%)"` printed the `\n` literally, since plotly titles are HTML. Corrected to `<br>`

#### 5C. Disclosure Statement

- Models utilized: Anthropic Claude

- Execution verification: All plotting code was checked against `ggplot2 3.5.x`, `plotly 4.10.x` and `viridisLite 0.4.x`. Figures were rendered and inspected before acceptance; two AI-supplied constructs (`showarrow` in `updatemenus`, 8-digit hex colorscales) failed silently rather than erroring and were caught only by visual inspection

### Goeler-Slough

#### Summary

I used Claude as a coding and debugging assistant to help brainstorm plot ideas, draft R code, and diagnose data problems. The AI wrote first drafts of the code and I ran, edited, and checked everything myself. The most important mistake that happened is that the AI's first version of the quadrat ID was wrong for 2024-2026, which produced impossible richness values. I noticed the symptom, the AI proposed diagnostics, I ran them and pasted the output, and the data pointed to the real cause (see section below).

In previous scripts, when working to wrangle the entire dataset and in preliminary plotting, I used Google Gemini, but Claude ultimately did a better job here at creating code for higher quality plots.

#### Selected prompts and outputs

| My prompt (abridged) | What the AI produced | Outcome |
|---|---|---|
| pasted `glimpse()` of the data; help me think through and draft code for plots showing change over time | Sampling-effort heatmap, diversity metrics through time, top-species area/heatmap, rank-abundance curves, NMDS trajectories, per-taxon trends | Used parts as the base for my final document; I kept 4 of the plots |
| NMDS plot across years with color by island instead of by site | Assigned each site to an island from lat/long (nearest island center), then colors the NMDS by island | Used, but one site needed a manual fix |
| community richness across time by island | Richness per quadrat by island, small multiples, and rarefied richness | Kept the per-quadrat version |
| i think there are a bunch of duplicates in the recent data because the metadata wasn't included such that each observation / taxon has 2 row entries... help fix | Diagnostic for duplicates by year plus a `dedupe_keep_fullest()` function | Used (I extended `dup_years` to 2024:2026) |
| richness spikes from ~3 to ~20 species per quadrat when there are only 25 possible points per quadrat. help me find the error | Diagnostics with checks for ID problems vs. leftover duplicates | Ran it; led to the actual cause |
| the legend key for size of circle isn't working | Diagnosis (size legend keys were white-on-white) and a `guides(size = guide_legend(override.aes = ...))` fix | Added to my plot code |

---

#### Biggest AI mistake: quadrats were identified using a column that was empty in 2024-2026

**What the AI assumed.** In the first script, a quadrat was identified as `paste(site_key, date, transect_id, quadrat_id)`. The AI assumed `quadrat_id` was filled in for every year. The `glimpse()` I gave it only showed the first rows of the data, so it could not have seen the later years, but it also did not build in an NA check, which was the thing that would have caught the problem.

**False reassurance about duplicates.** When I reported the duplicates, the AI said richness would be unaffected. That was true for duplicate rows, but it missed the real problem, and I found the spike myself rather than the AI catching it.

**What went wrong.** `quadrat_id` was blank in 2024, 2025 and 2026, so every quadrat on a transect got the same ID (`...|NA`). Each "quadrat" was really a whole transect with up to 11 real quadrats pooled together. Consequences:

- Per-quadrat richness in 2024 was inflated to a median of 19 species (max 26), when a quadrat only has 25 points.
- The number of quadrats was far too low, so every density (count divided by number of quadrats) was inflated in 2024-2026. That affects the NMDS and the winners/losers trends, not just richness.

**How it was found.** I noticed the impossible richness values (knowing there was a max of 25 points per quadrat) and asked the AI for help fixing. The AI wrote a diagnostic script, and the results helped identify all the NAs in quadrat ID.

**The fix.** `position` was filled in every year, so quadrats are now identified by `site_key | date | transect_id | position`.

**Verification after the fix**:

| Year | Quadrats before → after | Median richness before → after | Max richness before → after |
|---|---|---|---|
| 2024 | 61 → 624 | 19 → 6 | 26 → 14 |
| 2025 | 12 → 82 | 10.5 → 4 | 17 → 8 |
| 2026 | 12 → 129 | 11 → 4 | 22 → 9 |

The earlier years also barely changed (for example 2016: 1,088 → 1,108 quadrats), suggesting the new ID is not distorting previous years that were already fine.

---

#### Checks, fixes, & debugging steps

1. **Impossible richness** (~20 species per quadrat). I spotted the impossible richness values, ran the diagnostic script, found that `quadrat_id` was all NA in 2024-2026, switched to `position`, reran and compared the before/after tables in Section 4.
2. **Size legend not showing.** I noticed the size legend wasn't showing up on the plots. AI diagnosed it from the code (white keys on a white background) and correctly suggested `override.aes`.
3. **Manually checking island assignments.** Had to check island assignments and manually correct Mamala Bay (as it was missing latitude/longitude coordinates).
4. **Added Hawaiian names with ʻokina and kahakō to island labels.** Had to add/prompt to add correct spelling of Hawaiian islands.


### Jones
#### Summary
I used AI to perform statistical analysis on our cleaned dataframe to identify trends in the OPIHI data. I also utilized AI to tinker with our group photo, at Fabi's request. 

#### Data analysis
##### AI prompts used to perform a PERMANOVA analysis
I utilized the following prompt: I have a dataframe with columns on year, taxonomic group, and percent cover for intertidal species in Hawaiʻi. I want to analyze these using a PERMANOVA to determine whether the percentage of intertidal taxon changed significantly over the years. How would I code this in R? 

##### AI output
`# Reshape dataframe from long to wide format (Samples x Taxa)
comm_wide <- df %>%
  pivot_wider(
    names_from = taxonomic_group,
    values_from = percent_cover,
    values_fill = 0  # Fill missing taxon entries with 0% cover)`

At this point, the AI did not understand the code because I had removed too many sample identifying columns, so it suggested I add a column back in with sample IDs for the PERMANOVA. 

I tested the AI with a tibble of the cleaned dataframe, and it seemed to work well, so I uploaded the cleaned dataframe and asked it to provide code to perform the PERMANOVA.
`# Aggregate duplicate entries per sample unit if any exist, then pivot
comm_wide <- tidal_data_clean %>%
  group_by(sample_id, year, site_key, taxon_key) %>%
  summarise(percent_cover = mean(percent_cover, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(
    names_from = taxon_key,
    values_from = percent_cover,
    values_fill = 0  # Fill absent taxa with 0% cover)`
    
##### Debugging
I needed to manually set a sample identification row names in order for the program to run. I was able to give the error code to AI to determine where to do this in the code.

##### What the AI did right, wrong, and what my fixes were
The AI originally helped me see that I had cleaned the data down a little _too_ well and needed to add sample identification columns back in.  
However, it then had to be coached through a couple of error messages in order to format the dataframe correctly for use in a PERMANOVA.

#### Photo edits
##### AI prompts used to place us in our group photo in the Hawaiian intertidal
Can you edit us in this photo to make it look like we are meeting in the Hawaiʻi intertidal zone?

##### Debugging
That is fine, but please remove the green sea anemones in the tide pools, those species are not local to Hawaiʻi.

##### What the AI did right, wrong, and what my fixes are
The AI was able to place our group selfie on a fictional Hawaiʻi tidal flat (complete with a stone bench for Natalie, Fabi, and Wei Shen,) but no matter how many iterations of the question I asked...  
It was unable to remove the sea anemones from the tide pools.  
Apparently, no matter how advanced an AI is, it still doesn't know what _Anthropleura xanthogrammica_ look like, and that they don't belong in Hawaiian tide pools.

#### Disclosure statement

- Models utilized: Google Gemini through UH Agreement
- Execution verification: Data frames were viewed and inspected before being utilized in code. 

