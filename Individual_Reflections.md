## Individual Reflections

Project: AI-Assisted Community Data Sprint\
Created: November 4, 2026

------------------------------------------------------------------------

## Wei Shen Lim

For this project, I was responsible for figuring out the R data pipeline to synthesize over two decades of OPIHI intertidal survey data (2004-2026) from irregular, legacy sheets into a clean, relational master sheet. The overall structure of my workflow was hugely based on <u>**Fabi's**</u> workflow when she first joined the two copies of the 2024 data sheets together. This included:

- the initial function (`clean_hawaiian_text()`) to clean up Hawaiian names,
- exporting csv files of unique site and taxon names for review, and
- checking for true duplicate rows with an exported csv files containing these duplicate observations for review.

My core contributions from the entire pipeline included:

- the 3 different functions to clean up the 3 chunks of data files ([2004-2020; `parse_transposed_block()` & `process_transposed_file()`], [2024-2026; `process_wide_year()`], [metadata; `process_metadata_sheet()`]) into clean long format before joining them into one master sheet,
- implementing a way to easily review and edit site and taxon names manually to correct for duplicates and misspellings,
- creating a dynamic scaling equation to check the true total points for each quadrat,
- building a normalization layer to convert raw quadrat counts into true percent cover, and
- implementing a rigorous Base R validation pipeline to enforce data integrity.

AI was essential in summarizing massive amount of info and codes. When I lose track of what I've done or lost track of all the different versions of outputs I've created whenever I make little edits to parts of my script, I was able to use AI to look through my script and flagged places that are mismatched if I made edits to one chunk but forgot to do the same for previous related code chunks. AI was also essential in giving me the base structural format for my codes. This gave me a starting point where I can just easily edit within this framework, rather than having to figure out how to start from zero.

Where AI specifically failed was included in my `AI Developer Log` with output examples and debugging steps, but the overall problem that AI had was that it gets stuck in its previous ways of doing things. If it has created a function that worked for a much complicated problem, it will continue to use the same structure for a much simpler problem later on, leading to over-engineered steps. For example, once AI was able to correctly clean and format the 2024-2020 chunks, it could not understand that the 2024-2026 chunk was already in wide format that just needs to be pivoted long until you explicitly called them out on their over-engineered steps. It attempted to still try to identify "column headers" by rows, which was necessary for 2004-2020 data, but would not work for 2024-2026 data.

I manually verified all the outputs, specifically the `duplicate.counts.csv`, the `quadrats_needing_review.csv` and both the master sheets output (`final_clean_master_sheet.csv` and `clean_master_sheet_percent_cover.csv`). This was how I discovered that observations that were not true duplicates were being flagged as duplicates due to the 2025-2026 metadata issue. This metadata issue was also causing the total points per quadrats to be calculated incorrectly, leading to incorrect percent cover data, until the dynamic scaling equation was built to properly scale counts and totals based on the true replication factor. These manual checks also led me to discover issues that would be solved more easily by manually editing the data files (mentioned in Quarto Document). This included shifting `Location` rows to match other metadata for 2004-2020 data files, removing extra rows that calculated the sum for each quadrat in 2004-2020 data files, causing actual counts do doubled, and matching the `date` in 2026 Mauliola metadata to the actual dates in 2026 Mauliola dataset.

This experience taught me to not trust any AI-generated code until you have personally tested every single one of them and manually checked the outputs even after running validation scripts. Even after doing all this, you have to fundamentally understand what each line of code does, so you can easily make little edits to them when you discover more errors after checking. If you ask AI to input these edits seamlessly into the whole code chunk, most of the time it will do it wrongly, or change something else entirely too. AI is useful in providing a starting point, suggestions, and answering quick questions, but the user must have fundamental knowledge to be able to check their work and make necessary edits to fit their goals.

## Fabiola Gonzalez Zamora

For our `AI Data Sprint` I was responsible primarily for creating the heat maps and associated functions to visualize how the contribution to quadrat cover from each taxa or functional group changed over time. Early in the cleanup, I created an introductory function to join the two copies of the 2024 datasheet, which Wei Shen then extended beautifully across the full pipeline.

My later contributions were:

- Classifying all 207 taxa into functional groups using an ordered `case_when()`, with the draft exported alongside total abundance so review effort went to the taxa that actually move the figures,
- 2 reusable functions (`group_summary()` and `group_heatmap()`) so the static and interactive figures are rendered from one calculation rather than two that happen to agree,
- Static taxon-by-year heat map and an interactive plotly version with a functional-group dropdown

Though initially hesitant, I was pleasantly surprised not only in the model's ability to correct basic syntax errors, but also in the thoughtful manner the framework was designed so that it could be later modified even as datasheets, visualizations, cleanups were being changed. I learned that providing the AI with descriptive, iterative prompts was crucial in the output achieving the desired result. Plotly’s `updatemenus` syntax and the matrix reshape it requires would have taken me far longer to work out from documentation alone. Claude also provided descriptions explaining *why* a given approach was wrong when I questioned structural or aesthetic decisions.

Besides minor errors warranting manual modifications, the more prolematic errors were when the AI failed in a silent manner (which often took careful parsing through each code chunk to catch). It predicted what `janitor::clean_names()` would produce instead of checking, giving `t` where the real name was `number_t`; because the pivot used `any_of()`, which ignores names that don’t exist, both key columns were swallowed into `taxon_raw` as though they were species, with no error raised. Its regex patterns lacked word boundaries, so `sand` matched inside *Cellana sandwicensis* and filed the ʻopihi under Substrate, and `crust` matched *Grapsus tenuicrustatus* and filed a crab under Unresolved. It left `source_file` inside a `distinct()` call, which inflated the 2024 conflict count from 3 to 2,393. None of these threw an error; all of them produced a plausible-looking wrong answer. Since careful vetting was a component of this assignment, they were caught. I can certainly imagine a user without a background in R nor the guidance of a course like OCN 682 overlooking these errors, which may (or may not?) have consequences for further analysis.

What strikes me looking back is that the errors I caught by knowing the organisms and the structure of the datasheets. I questioned the *Cellana* misclassification because an ʻopihi is a limpet, and I questioned why substrate appeared only from 2024 because the older datasheets recorded nothing but organisms. That second question exposed a denominator change between years that a validation script in our pipeline might not have flagged, because a script only tests the assumptions you already thought to write down. AI closed the gap between knowing what I wanted and knowing how to write it in R, but contributed little towards the gap between having an output and knowing whether that output is true, and that is where the actual science sits.

## Natalie Goeler-Slough

For this OPIHI Data Sprint, I primarily focused on generating a few high-quality figures visualizing change over time in our intertidal taxa data. I wrote (with the help of AI) the code and quarto documentation for an NMDS plot, pooled richness across time, island-specific richness across time, and "winners and losers" plot of individual taxa. (I also played around with wrangling the master datasheet but Wei Shen beat me to the output so we used her immaculate version instead!)

In generating my plots, the AI model also prompted me to use 3 different functions throughout the workflow, which could be used outside of this project:

- `nearest_island`, which used latitude and longitude points for each island to assign sites to nearest island (allowing me to plot trends by island instead of by individual site)
- `dedupe_keep_fullest`, which separated actual observations from defined key metadata columns to identify observation duplicate entries, and keep the version with fullest metadata
- `plot_rich_island`, which plots taxon richness across an inputted number of years. Slightly less generalizable, but helpful to use to investigate trends over specific target years

AI models (especially Claude) were extremely valuable in my work for this project, and helped me make some super awesome figures that would've taken me *forever* to figure out on my own. Not every plot / suggestion it made was a good one, but through me hand-selecting which plots and which chunks of code were valuable to me, AI was instrumental in generating some really cool figures.

The biggest issues I ran into while using AI were problems that I noticed myself, where visualizing these issues on the plots given the project parameters we knew was helpful for initial identification *(i.e. richness values of 20+ per quadrat when there's a max of 25 possible points per quadrat, as described in my `AI Developer Log`)*. After I identified an issue, the AI models were helpful in generating diagnostic code to identify where the issue stemmed from, how to fix it, and which verification checks make sense to run. I also never uploaded the full dataset to the AI model, which is definitely best-practice (especially when working with someone else's data), but I think this also contributed to some of the AI errors. I only gave it the `glimpse()` of the csv file, so it wouldn't have been able to see some of the duplicates and issues in later years.

I think AI is an extremely powerful tool that can be used to help code efficiently, but I think a lot of manual checking and verification has to be done to ensure that the code that's written is actually doing what you think it is, and to ensure that any data wrangling is ouputting what you actually want it to for the context of your project. AI often won't know the project parameters and/or nuances of your data, so as a researcher, taking the sufficient time to verify that any code and output is representative of your actual data is key.

## Ellie S Jones

For our group OPIHI Data Sprint, my primary responsibility was compiling all scripts and AI developer logs into single Quarto and ReadMe documents for our group project.  

Later, I also wanted to play with the data to learn from the AI portion of the project, so I decided to test out using AI to help me run some statistics. I was slightly apprehensive; I was raised on the understanding that you should put your best work into your own work 100% of the time, and somehow that translated in my head to an idea that if you use AI to do your work, then it is not entirely "yours," and therefore not your best effort. I really appreciated this assignment as an opportunity to challenge that personal perception and use AI as a tool rather than being afraid of it.  

A few key things I learned:
- Creating tibbles to test the AI prompts prior to using your own data ensures you will not be blindly running code on datasets  
- I liked to let AI help suggest code, and then type it into my scripts myself to test each piece one by one  
- AI will sometimes code itself into a corner. By this I mean that when debugging, I noticed that the AI had a tendency to add on multiple lines of code to manipulate the data into the arguments it wanted to make, but sometimes the best option was to retrace your steps and clean it from the beginning rather than doing backflips to make it fit the AI's code. This is where I felt my brain come in the most handy, instead of just plugging and chugging with whatever the AI suggested  
- Marine ecologists still have no need to fear AI taking our jobs - Google Gemini had a really challenging time figuring out what a sea anemone was  

I appreciated this assignment a lot. I feel as though I am less scared to use AI, and have the foundational coding language knowledge to understand what I am asking it to do and what output it is providing me. Mahalo for assigning this!
