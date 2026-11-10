## Ellie AI Developer Log

### Summary
I used AI to perform statistical analysis on our cleaned dataframe to identify trends in the OPIHI data. I also utilized AI to tinker with our group photo, at Fabi's request. 

### Data analysis
#### AI prompts used to perform a PERMANOVA analysis
I utilized the following prompt: I have a dataframe with columns on year, taxonomic group, and percent cover for intertidal species in Hawaiʻi. I want to analyze these using a PERMANOVA to determine whether the percentage of intertidal taxon changed significantly over the years. How would I code this in R? 

#### AI output
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
    
#### Debugging
I needed to manually set a sample identification row names in order for the program to run. I was able to give the error code to AI to determine where to do this in the code.

#### What the AI did right, wrong, and what my fixes were
The AI originally helped me see that I had cleaned the data down a little _too_ well and needed to add sample identification columns back in.  
However, it then had to be coached through a couple of error messages in order to format the dataframe correctly for use in a PERMANOVA.

### Photo edits
#### AI prompts used to place us in our group photo in the Hawaiian intertidal
Can you edit us in this photo to make it look like we are meeting in the Hawaiʻi intertidal zone?

#### Debugging
That is fine, but please remove the green sea anemones in the tide pools, those species are not local to Hawaiʻi.

#### What the AI did right, wrong, and what my fixes are
The AI was able to place our group selfie on a fictional Hawaiʻi tidal flat (complete with a stone bench for Natalie, Fabi, and Wei Shen,) but no matter how many iterations of the question I asked...  
It was unable to remove the sea anemones from the tide pools.  
Apparently, no matter how advanced an AI is, it still doesn't know what _Anthropleura xanthogrammica_ look like, and that they don't belong in Hawaiian tide pools.

### Disclosure statement

- Models utilized: Google Gemini through UH Agreement
- Execution verification: Data frames were viewed and inspected before being utilized in code. 
