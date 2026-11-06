## Fabiola Gonzalez Zamora

### AI Log for OPIHI Data Sprint

### Prompts Used for Each Sections

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

### 3A. Static Taxon Heatmap

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

### 3B. AI Mistake and Questionable Assumption

- Assumption: The AI initially generated a master_complete object that completed the full taxon × quadrat grid before filtering to the top twelve taxa, and placed it at the top of the chunk as though downstream code depended on it
- Reality: nothing used it, was kinda just sitting there
- Check: Although no error occurred, after reading through the code, I noticed that no downstream items actually used the object, so I removed it

### 3C. Debugging Steps and Manual Aesthetic Adjustments

- Assumption: The AI proposed grouping on four columns.
- Reality: Testing five candidate keys against the data showed only date + site_key + transect_id + quadrat_id + position yields quadrats summing to exactly 100% (7,108 of 7,108). The four-column version produced sums up to 1,300%, because quadrat_id repeats across positions
- Addition checks:
  - Proposed colors were not very eye pleasing, so I adjusted, using the `mako` colors
  - Had to manually adjust the caption positioning and the `hjust` for the years to make sure they were not cut off

### 4A Reusable Group Functions

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

### 4B. AI Mistake and Questionable Assumption

- Assumption: Asked to name the key columns for `pivot_longer()`, AI predicted what `janitor::clean_names()` would produce, giving `t` and `position_on_transect_m`.
- Reality: `clean_names()` applies a default substitution of \# → number, so the actual names are number_t and position_number_on_transect_m.
  - Pivot used `any_of()`, silently ignores names that don’t exist, both key columns were swept into taxon_raw as though they were species. No error was raised.
- Check: `names(long_2024)` returned 9 columns instead of 11, with the transect and position keys missing; `filter(str_detect(taxon_raw, "number"))` confirmed they had become taxon rows.
  - Resolved by `running names()` after `clean_names()` and pasting the real output, rather than predicting it

### 4C. Debugging Steps and Manual Aesthetic Adjustments

- Two taxa were misclassified by unbounded patterns:

  - `Cellana sandwicensis` (ʻopihi) matched `sand` and was filed as Substrate; `Grapsus tenuicrustatus` (a crab) matched `crust` and became Unresolved.

  - Fixed with `\\bsand\\b` and `\\bcrust\\b`, then verified by printing all 207 classifications by eye rather than trusting a second regex audit

### 5A. Interactive Heatmap with Dropdown

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

### 5B. Debugging Steps and Manual Aesthetic Adjustments

- Silent palette failure: `viridisLite::mako()` returns 8-digit hex with an alpha channel (`#0B0405FF`). plotly cannot parse it and falls back to its default without warning. Resolved with `substr(cols, 1, 7)`.

- Margin reservation: plotly does not auto-expand for colorbars or menus. The anchored colorbar at `x = 1.02` was clipped until the right margin was widened from 30 to 100; the menu squeezed the plot until the bottom margin reached 140.

- Expansion direction: With the menu placed below the plot, the default downward expansion ran the option list off the canvas. Set `direction = "up"` so it overlays the panel instead.

- Title: `"Mean\ncover (%)"` printed the `\n` literally, since plotly titles are HTML. Corrected to `<br>`

### 5C. Disclosure Statement

- Models utilized: Anthropic Claude

- Execution verification: All plotting code was checked against `ggplot2 3.5.x`, `plotly 4.10.x` and `viridisLite 0.4.x`. Figures were rendered and inspected before acceptance; two AI-supplied constructs (`showarrow` in `updatemenus`, 8-digit hex colorscales) failed silently rather than erroring and were caught only by visual inspection
