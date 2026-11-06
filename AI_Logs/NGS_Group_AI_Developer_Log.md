## Natalie Goeler-Slough

## AI Developer Log for OPIHI Data Sprint


### Summary

I used Claude as a coding and debugging assistant to help brainstorm plot ideas, draft R code, and diagnose data problems. The AI wrote first drafts of the code and I ran, edited, and checked everything myself. The most important mistake that happened is that the AI's first version of the quadrat ID was wrong for 2024-2026, which produced impossible richness values. I noticed the symptom, the AI proposed diagnostics, I ran them and pasted the output, and the data pointed to the real cause (see section below).

In previous scripts, when working to wrangle the entire dataset and in preliminary plotting, I used Google Gemini, but Claude ultimately did a better job here at creating code for higher quality plots.

### Selected prompts and outputs

| My prompt (abridged) | What the AI produced | Outcome |
|---|---|---|
| pasted `glimpse()` of the data; help me think through and draft code for plots showing change over time | Sampling-effort heatmap, diversity metrics through time, top-species area/heatmap, rank-abundance curves, NMDS trajectories, per-taxon trends | Used parts as the base for my final document; I kept 4 of the plots |
| NMDS plot across years with color by island instead of by site | Assigned each site to an island from lat/long (nearest island center), then colors the NMDS by island | Used, but one site needed a manual fix |
| community richness across time by island | Richness per quadrat by island, small multiples, and rarefied richness | Kept the per-quadrat version |
| i think there are a bunch of duplicates in the recent data because the metadata wasn't included such that each observation / taxon has 2 row entries... help fix | Diagnostic for duplicates by year plus a `dedupe_keep_fullest()` function | Used (I extended `dup_years` to 2024:2026) |
| richness spikes from ~3 to ~20 species per quadrat when there are only 25 possible points per quadrat. help me find the error | Diagnostics with checks for ID problems vs. leftover duplicates | Ran it; led to the actual cause |
| the legend key for size of circle isn't working | Diagnosis (size legend keys were white-on-white) and a `guides(size = guide_legend(override.aes = ...))` fix | Added to my plot code |

---

### Biggest AI mistake: quadrats were identified using a column that was empty in 2024-2026

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

### Checks, fixes, & debugging steps

1. **Impossible richness** (~20 species per quadrat). I spotted the impossible richness values, ran the diagnostic script, found that `quadrat_id` was all NA in 2024-2026, switched to `position`, reran and compared the before/after tables in Section 4.
2. **Size legend not showing.** I noticed the size legend wasn't showing up on the plots. AI diagnosed it from the code (white keys on a white background) and correctly suggested `override.aes`.
3. **Manually checking island assignments.** Had to check island assignments and manually correct Mamala Bay (as it was missing latitude/longitude coordinates).
4. **Added Hawaiian names with ʻokina and kahakō to island labels.** Had to add/prompt to add correct spelling of Hawaiian islands.

