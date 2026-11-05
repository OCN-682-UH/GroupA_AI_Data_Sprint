## Individual Reflections

Project: AI-Assisted Community Data Sprint\
Created: November 4, 2026

------------------------------------------------------------------------

## Wei Shen Lim

For this project, I was responsible for figuring out the R data pipeline to synthesize over two decades of OPIHI intertidal survey data (2004-2026) from irregular, legacy sheets into a clean, relational master sheet. The overall structure of my workflow was hugely based on [**Fabi's**]{.underline} workflow when she first joined the two copies of the 2024 data sheets together. This included:

- the initial function to clean up Hawaiian names,
- exporting csv files of unique site and taxon names for review, and
- checking for true duplicate rows with an exported csv files containing these duplicate observations for review.

My core contributions from the entire pipeline included:

- the 3 different functions to clean up the 3 chunks of data files ([2004-2020], [2024-2026], [metadata]) into clean long format before joining them into one master sheet,
- implementing a way to easily review and edit site and taxon names manually to correct for duplicates and misspellings,
- creating a dynamic scaling equation to check the true total points for each quadrat,
- building a normalization layer to convert raw quadrat counts into true percent cover, and
- implementing a rigorous Base R validation pipeline to enforce data integrity.

AI was essential in summarizing massive amount of info and codes. When I lose track of what I've done or lost track of all the different versions of outputs I've created whenever I make little edits to parts of my script, I was able to use AI to look through my script and flagged places that are mismatched if I made edits to one chunk but forgot to do the same for previous related code chunks. AI was also essential in giving me the base structural format for my codes. This gave me a starting point where I can just easily edit within this framework, rather than having to figure out how to start from zero.

Where AI specifically failed was included in my AI Developer Log with output examples and debugging steps, but the overall problem that AI had was that it gets stuck in its previous ways of doing things. If it has created a function that worked for a much complicated problem, it will continue to use the same structure for a much simpler problem later on, leading to over-engineered steps. For example, once AI was able to correctly clean and format the 2024-2020 chunks, it could not understand that the 2024-2026 chunk was already in wide format that just needs to be pivoted long until you explicitly called them out on their over-engineered steps. It attempted to still try to identify "column headers" by rows, which was necessary for 2004-2020 data, but would not work for 2024-2026 data.

I manually verified all the outputs, specifically the `duplicate.counts.csv`, the `quadrats_needing_review.csv` and both the master sheets output (`final_clean_master_sheet.csv` and `clean_master_sheet_percent_cover.csv`). This was how I discovered that observations that were not true duplicates were being flagged as duplicates due to the 2025-2026 metadata issue. This metadata issue was also causing the total points per quadrats to be calculated incorrectly, leading to incorrect percent cover data, until the dynamic scaling equation was built to properly scale counts and totals based on the true replication factor. These manual checks also led me to discover issues that would be solved more easily by manually editing the data files (mentioned in Quarto Document). This included shifting `Location` rows to match other metadata for 2004-2020 data files, removing extra rows that calculated the sum for each quadrat in 2004-2020 data files, causing actual counts do doubled, and matching the `date` in 2026 Mauliola metadata to the actual dates in 2026 Mauliola dataset.

This experience taught me to not trust any AI-generated code until you have personally tested every single one of them and manually checked the outputs even after running validation scripts. Even after doing all this, you have to fundamentally understand what each line of code does, so you can easily make little edits to them when you discover more errors after checking. If you ask AI to input these edits seamlessly into the whole code chunk, most of the time it will do it wrongly, or change something else entirely too. AI is useful in providing a starting point, suggestions, and answering quick questions, but the user must have fundamental knowledge to be able to check their work and make necessary edits to fit their goals.
