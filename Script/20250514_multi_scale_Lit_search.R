# Workspace set up -------------------------------------------------------------

# We will be using two packages in this script: litsearchr, and igraph
# igraph is a litsearchr dependency, so does not require separate installation

# litsearchr is not on CRAN, so it must be installed with the remotes package
# If you do not have the remotes package, install it with:
#install.packages("remotes")

# If you do not have litsearchr installed, it can be installed with:
#remotes::install_github("elizagrames/litsearchr")

#load the library
#library(litsearchr)
#library(here)

# Defining the scope of the question -------------------------------------------

# As with any review, before we begin we need to define the scope of the 
# question. Let's say we want to do a systematic review on location choice 
# studies in crime

# other options 
# We can use the 'PICO' format to define the question as:
# Population: law enforcement officers
# Intervention: de-escalation
# Comparator: officers who have not undergone training
# Outcome: police violence

# Function to create a folder with a date argument---------
make_folder <- function(date = Sys.Date()) {
  # Convert the provided date to "YYYYMMDD" format
  folder_name <- format(as.Date(date), "%Y%m%d")
  
  # Define the full folder name with additional text
  full_folder_name <- paste0(folder_name, "_output_spatial_scale")
  
  # Check if the folder exists, and create it if it doesn't
  if (!dir.exists(here::here(full_folder_name))) {
    dir.create(here::here(full_folder_name))
    message("Folder created: ", full_folder_name)
  } else {
    message("Folder already exists: ", full_folder_name)
  }
  
  return(full_folder_name)  # Return the folder name to use later
}

# Create the folder
folder_name <- make_folder()


# create a function to save output with data-------
custom_save <- function(data, folder_name, file_description, save_function, file_extension = ".csv", ...) {
  # Current date in YYYYMMDD format
  current_date <- format(Sys.Date(), "%Y%m%d")
  
  # Create the file name
  file_name <- paste0(current_date, "_", file_description)
  
  # Add extension if needed
  if (!grepl(file_extension, file_name)) {
    file_name <- paste0(file_name, file_extension)
  }
  
  # Define the file path
  file_path <- file.path(folder_name, file_name)
  
  # Call the provided save_function with additional arguments
  save_function(data, file = file_path, fileEncoding = "UTF-8", ...)
  
  message("File saved: ", file_path)
}


# Automatically locate today's naive search folder
naive_search_folder <- here::here("Data", "20250117_Lit_search_results", "naive_search")


# Generating the naive search --------------------------------------------------
# WOS (n = 97, 17.01.2025): TS=(((offend* OR crim* OR burglar* OR robb* OR co-offend* OR dealer*)     AND   ("discret* choic*"     OR "choic* model*"     OR "rational choice"     OR "awareness space"     OR "journey to crime"    OR "mobility"    OR "opportunity"    OR "accessibility"    OR "attractiveness"    OR "crime pattern*" )     AND   ("crime locat* choic*"    OR "offend* locat* choic*"    OR "robber* locat* choic*"    OR "burglar* locat* choic*"    OR "target area*"    OR "target selection"    OR "crime site selection"    OR "spatial choic* model*" )))
# Scopus (n= 105, 17.01.2025): TITLE-ABS-KEY ( ( offender* OR crime OR criminal* OR burglar* OR robber* ) AND ( "discrete choice*" OR "choice model*" OR "discrete spatial choice" OR "awareness space" OR "opportunity" OR "journey two crime" OR "mobility" OR accessibility OR attractiveness OR crime AND pattern ) AND ( "location choice*" OR "offending location choice" OR "crime location choice" OR "target selection" OR "crime site selection" ) )
# proquest (n= 47, 17.01.2025): noft(((offend* OR crim* OR burglar* OR robb* OR co-offend* OR dealer*) AND ("discret* choic*" OR "choic* model*" OR "rational choice" OR "awareness space" OR "journey to crime" OR "mobility" OR "opportunity" OR "accessibility" OR "attractiveness" OR "crime pattern*") AND ("crime locat* choic*" OR "offend* locat* choic*" OR "robber* locat* choic*" OR "burglar* locat* choic*" OR "target area*" OR "target selection" OR "crime site selection" OR "spatial choic* model*"))) 
# save search results as RIS file in navie search folder 

# read the RIS files 
dat.all <- litsearchr::import_results(directory = naive_search_folder)

# remove the duplicate articles based on its title
dat <- litsearchr::remove_duplicates(dat.all, field="title", method="exact")

# we can get no of duplicates removed 
nrow(dat.all)-nrow(dat) 

# To identify possible keywords, we use a knock-off version of the rapid automatic 
# keyword extraction algorithm (RAKE) which is called 'fakerake' in litsearchr 
# (the logic is the same but it doesn't require java)

all_keywords <-
  litsearchr::extract_terms(
    text = paste(dat$title, dat$abstract, dat$keywords),
    method = "fakerake",
    min_freq = 2,
    ngrams = TRUE,
    min_n = 2,
    language = "English"
  )

# We can look at some of these to get a sense of what they look like with
head(all_keywords, 50)

# Ignore these lines for now, we will come back to them later with explanation
terms_ignored <- c("article examines","academic press", "database record", "psycinfo database", "publication abstract",
                   "psycinfo database record", "rights reserved", "based simulation",
                   "copyright holder", "copyright applies", "email articles",
                   "express written", "express written permission", "binomial regression",
                   "original published", "original published version", "business media",
                   "published version", "written permission", "study examines", "correlation coefficient",
                   "current study","control group", "findings suggest", "outcome measures",
                   "future research", "forward searches", "criminological theory", "environmental criminology")

all_keywords <- all_keywords[!all_keywords%in%terms_ignored]

# We now create a document-feature matrix (DFM) out of the articles and the keywords
# In the DFM, each row is an article and each column is one of the potential
# keywords identified in the previous step. If a keyword/phrase appears in
# an article, it is a 1 in the DFM, else it is a 0

naivedfm <-
  litsearchr::create_dfm(
    elements = paste(dat$title, dat$abstract, dat$keywords),
    features = all_keywords
  )

# We can use the DFM to create a keyword co-occurrence network because we know
# which terms appear in the same articles together (i.e. co-occur). 
naivegraph <-
  litsearchr::create_network(
    search_dfm = naivedfm,
    min_studies = 2,
    min_occ = 2
  )

# The advantage of using a co-occurrence network for keyword selection is that
# we can use properties of networks to identify the most 'important' terms because
# they will have stronger co-occurrence relationships with other terms that
# are also important, whereas relatively  unimportant terms that occur infrequently
# and not in the right context (i.e. not with other good terms) will have low
# scores for importance in the network

# To see what I mean by that, let's plot the network
# This is a big network with a lot of potential terms, so it may take some time
igraph::plot.igraph(naivegraph, 
                    vertex.label.color = "#00000000", # make labels invisible
                    vertex.label.cex = 0.7, # size of labels
                    vertex.size = sqrt(igraph::strength(naivegraph)), # size of nodes
                    vertex.color = "white", # color of nodes
                    vertex.frame.color = "black", 
                    edge.width = 0.25, 
                    edge.color = "black", 
                    
                    edge.arrow.size = 0.25)

# Select a cutoff and finalize search terms ------------------------------------

# What we want to get out of the network are those big nodes in the center that
# are relatively important based on their node strength, which is a measure 
# of the weighted degrees of a node (i.e. how many connections does it have to
# other nodes, and how well connected are those nodes?)

node.strengths <- sort(igraph::strength(naivegraph), decreasing = T)
head(node.strengths, 50)

# Let's plot the node strengths so we get a sense of the shape of the distribution
# and can see which ones are towards the top
par(pty="s", las=1)
plot(sort(node.strengths), ylab="Node strength", pch=19, cex=0.5, axes=F)
axis(1); axis(2) # add axes
labels <- names(sort(node.strengths)) # pull out labels to add
labels[1:(length(labels)-20)] <- "" # we don't want to add all the labels!
text(sort(node.strengths), labels, pos=4, cex=0.5)

# We can now find a cutoff in node strength above which we will manually consider
# terms to use for the systematic review. We certainly don't want to consider
# all  terms, but we also don't want to miss some that may be useful in
# finding relevant literature. We want a cutoff that ignores the long tail of
# unimportant keywords but keeps the best ones

# Sometimes using 80/20 is a nice cutoff because of the Pareto principle
cutoff <-
  litsearchr::find_cutoff(
    naivegraph,
    method = "cumulative",
    percent = .20,
    imp_method = "strength"
  )

reducedgraph <-
  litsearchr::reduce_graph(naivegraph, cutoff_strength = cutoff[1])

# This gave us 196 terms to consider using for the search
# If we were cautious about missing terms, we could increase the percent
# in the code above
searchterms <- litsearchr::get_keywords(reducedgraph)
head(searchterms, 50)

# Call with row.names argument through ...
custom_save(searchterms, folder_name, "search_term", write.csv, row.names = FALSE, quote = TRUE)


# Mannually read searchterms and group it based on pupulation, intrest and outcome 
grouped_terms <- read.csv(here::here("./20250513_output_spatial_scale/20250513_grouped_search_term.csv"))
grouped_terms

pop <- grouped_terms$term[grep("pop", grouped_terms$group)]
int <- grouped_terms$term[grep("int", grouped_terms$group)]
out <- grouped_terms$term[grep("out", grouped_terms$group)]


# At this point, we can revisit our naive terms and see if we want to add
# any of them back into our full search (generally recommended)

pop <- append(pop, c("offend", "crim", "burglar", "robber", "co-offend", "dealer"))
int <- append(int, c("mobility"))



# Write Boolean search from the terms ------------------------------------------

# First we need to set up a list that contains all our strings of terms
mysearchterms <- list(pop, int, out)

# litsearchr will separate terms within a concept category (i.e. an element of
# PICO) by 'OR' and then link categories with 'AND' so that the search logic is 
# to have at least one term from each category, but in any combination
my_search <-
  litsearchr::write_search(
    groupdata = mysearchterms,
    languages = "English",
    stemming = TRUE,
    closure = "none",
    exactphrase = TRUE,
    writesearch = FALSE,
    verbose = TRUE
  )

# When writing to a plain text file, the extra \ are required to render the 
# * and " properly on some unix-based systems; if copying straight from the 
# console, simply find and replace them in a text editor
# search in the database using the "my_search", save results and RIS and CSV or excel in different folders
my_search

# this is the serach term we created after the using litsearch R 
# ((offend* OR crim* OR burglar* OR robber* OR dealer*) AND ("choic* model*" OR "discret* choic*" OR "ration* choic*" OR "spatial* choic*" OR mobil*) AND (pattern* OR "locat* choic*" OR "target* select*"))

# use the search term in data bases and save it as RIS file 

# WOS (n = 681, 17.01.2025): TS=(((offend* OR crim* OR burglar* OR robber* OR dealer*) AND ("choic* model*" OR "discret* choic*" OR "ration* choic*" OR "spatial* choic*" OR mobil*) AND (pattern* OR "locat* choic*" OR "target* select*")))
# Scopus (n= 1169, 17.01.2025): TITLE-ABS-KEY ( ( ( offend* OR crim* OR burglar* OR robber* OR dealer* ) AND ( "choic* model*" OR "discret* choic*" OR "ration* choic*" OR "spatial* choic*" OR mobil* ) AND ( "locat* choic*" OR "target* select*" OR pattern* ) ) )
# Proquest (n= 189, 17.01.2025): noft(((offend* OR crim* OR burglar* OR robber* OR dealer*) AND ("choic* model*" OR "discret* choic*" OR "ration* choic*" OR "spatial* choic*" OR mobil*) AND (pattern* OR "locat* choic*" OR "target* select*")))
# Google scholar (first 15 pages, 20 items per page)  (n= 286 #should 300 but not sure why), 17.01.2025) ("offender" OR "offenders" OR "crime" OR "criminal" OR "criminals" OR "burglar" OR "burglars" OR "robber" OR "robbers" OR "dealer" OR "dealers")  ("choice model" OR "discrete choice" OR "discrete choice model" OR "rational choice" OR "spatial choice" OR "mobility") ("pattern" OR "location choice" OR "target selection" OR "behavior pattern" )

# save search results as RIS file in navie search folder 

# Checking search against benchmark articles -----------------------------------

# If there has been a previous review on a topic, we may have some idea of what
# articles we expect should be retrieved. Or, we could do some ad-hoc searching
# to find articles that we know are relevant (which was what we did in this case)

# There are probably lots more relevant article, but we will use these three
# as an example of how this process works in litsearchr
gold_standard <- c(
  "a discrete spatial choice model of burglary target selection at the house-level",
  "a sentimental journey to crime: effects of residential history on crime location choice",
  "a time for a crime: temporal aspects of repeat offenders’ crime location choices",
  "adolescent offenders’ current whereabouts predict locations of their future crimes",
  "ambient population and surveillance cameras: the guardianship role in street robbers’ crime location choice",
  "assessing the influence of prior on subsequent street robbery location choices: a case study in zg city, china",
  "awarenessXopportunity: testing interactions between activity nodes and criminal opportunity in predicting crime location choice",
  "biting once, twice: the influence of prior on subsequent crime location choice",
  "burglar target selection: a cross-national comparison",
  "burglars blocked by barriers? the impact of physical and social barriers on residential burglars’ target location choices in china",
  "co‐offending and the choice of target areas in burglary",
  "co-offenders crime location choice: do co-offending groups commit crimes in their shared awareness space?",
  "crime feeds on legal activities: daily mobility flows help to explain thieves’ target location choices",
  "do juvenile, young adult, and adult offenders target different places in the chinese context?",
  "do migrant and native robbers target different places?",
  "do street robbery location choices vary over time of day or day of week? a test in chicago",
  "effects of attractiveness, opportunity and accessibility to burglars on residential burglary rates of urban neighborhoods",
  "effects of residential history on commercial robbers’ crime location choices",
  "family matters: effects of family members’ residential areas on crime location choice",
  "formal evaluation of the impact of barriers and connectors on residential burglars’ macro-level offending location choices",
  "go where the money is: modeling street robbers’ location choices",
  "how do residential burglars select target areas? a new approach to the analysis of criminal location choice",
  "investigating the effect of people on the street and streetscape physical environment on the location choice of street theft crime offenders using street view images and a discrete spatial choice model",
  "learning where to offend: effects of past on future burglary locations",
  "location choice of snatching offenders in chennai city",
  "location, location, location: effects of neighborhood and house attributes on burglars’ target selection",
  "modeling micro-level crime location choice: application of the discrete choice framework to crime at places",
  "modelling taste heterogeneity regarding offence location choices",
  "modelling the spatial decision making of terrorists: the discrete choice approach",
  "relative difference and burglary location: can ecological characteristics of a burglar’s home neighborhood predict offense location?",
  "relationships between offenders’ crime locations and different prior activity locations as recorded in police data",
  "right place, right time? making crime pattern theory time-specific",
  "role of the street network in burglars’ spatial decision-making",
  "target choice during extreme events: a discrete spatial choice model of the 2011 london riots",
  "target selection models with preference variation between offenders",
  "the importance of importance sampling: exploring methods of sampling from alternatives in discrete choice models of crime location choice",
  "the influence of activity space and visiting frequency on crime location choice: findings from an online self-report survey",
  "the usefulness of past crime data as an attractiveness index for residential burglars",
  "traveling alone or together? neighborhood context on individual and group juvenile and adult burglary decisions",
  "where do dealers solicit customers and sell them drugs? a micro-level multiple method study",
  "where offenders choose to attack: a discrete choice model of robberies in chicago",
  "Graffiti writers choose locations that optimize exposure"
)

# Normalize titles
gold_standard <- gold_standard |>
  stringr::str_to_lower() |>                  # Convert to lowercase
  stringr::str_replace_all("[^a-z0-9 ]", "") |>  # Remove non-alphanumeric characters
  stringr::str_squish()                       # Remove extra spaces

# We have litsearchr write a title-only search out of the benchmark articles
title_search <- litsearchr::write_title_search(titles=gold_standard)
title_search

# We then run that search in a few databases to check if the articles are 
# indexed and we would expect our search to retrieve them (if they aren't in a
# database, it would of course not be reasonable to retrieve them). 

# We then run our full search terms in databases we are using for benchmarking
# and export those results, which we can read back in
retrieved_articles <-  litsearchr::import_results(directory="./Data/20250117_Lit_search_results/results_litsearch")

retrieved_articles <- retrieved_articles |>
  dplyr::mutate(
    title = title |>
      stringr::str_to_lower() |>                 # Lowercase
      stringr::str_replace_all("[^a-z0-9 ]", "") |>  # Remove non-alphanumeric
      stringr::str_squish()                      # Remove extra spaces
  ) 

retrieved_articles <- retrieved_articles |>
  dplyr::select(-database) |>
  dplyr::mutate(database = dplyr::case_when(
    grepl("Google_scholar", filename, ignore.case = TRUE) ~ "Google Scholar",
    grepl("ProQuest", filename, ignore.case = TRUE) ~ "ProQuest",
    grepl("Scopus", filename, ignore.case = TRUE) ~ "Scopus",
    grepl("WOS", filename, ignore.case = TRUE) ~ "Web of Science",
    TRUE ~ "Other"  # Default for unidentified sources
  ))

# And then check the results against our benchmark list to see if they were found
articles_found <- litsearchr::check_recall(true_hits = gold_standard,
                                           retrieved = retrieved_articles$title)


custom_save(articles_found, folder_name, "articles_found.csv", write.csv, row.names = FALSE, quote = TRUE)


df_articles_found <- as.data.frame(articles_found) 

Unique_retrieved_articles <- litsearchr::remove_duplicates(retrieved_articles, field="title", method="exact")
nrow(retrieved_articles)-nrow(Unique_retrieved_articles)

Unique_retrieved_articles <- Unique_retrieved_articles |> 
  dplyr::mutate(ID = dplyr::row_number()) |>
  dplyr::select(ID, source_type, year, title, abstract, database,
                journal, volume, issue, start_page, end_page,
                source_type, doi, issn) |>
  dplyr::mutate(`select_reject_by (Wim/Christophe)` = " ", 
                `notes (Wim/Christophe)` = " ",
                `select_reject_by (Kural)` = " ",
                `notes kural` = " ",)|>
  # rearrange the column order 
  dplyr::select(ID, `select_reject_by (Wim/Christophe)`, `notes (Wim/Christophe)`,
                `select_reject_by (Kural)`,`notes kural`, title, 
                abstract, everything())

# Abstract of row 1605 as > 4000 words, which is causing the problem. so reduced it to 1000 
Unique_retrieved_articles$abstract[1605] <- substr(Unique_retrieved_articles$abstract[1605], 1, 1000)


# Save the new dataset with instructions as a CSV
custom_save(Unique_retrieved_articles, folder_name, "Unique_retrieved_articles.csv", write.csv, row.names = FALSE, quote = TRUE)




