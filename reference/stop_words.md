# Obtain and Adjust the Topic Stop-Word List

Returns the stop words excluded from term extraction and keyword
candidates. \`add\` extends the list — the standard way to remove a
corpus-wide vocabulary from topic labels (words every document shares
carry no discriminative information). \`remove\` un-lists built-in
entries whose surface form is meaningful in a specific corpus.

## Usage

``` r
stop_words(language = "en", add = NULL, remove = NULL)
```

## Arguments

- language:

  Currently only \`"en"\` is supported.

- add:

  Character vector of extra words to exclude (matched
  case-insensitively).

- remove:

  Character vector of words to drop from the list.

## Value

A sorted character vector of lowercase stop words.

## Details

For a fully custom list, pass any character vector straight to the
\`stop_words\` argument of \[topics()\], \[compare_topics()\],
\[topic_corpus()\], or \[keywords()\] — for example \`stop_words(add =
c("covid", "patient"))\` to keep the defaults plus domain terms, a bare
\`c("covid", "patient")\` to replace the list entirely, or
\`character()\` to disable stop-word filtering.

## Examples

``` r
head(stop_words())
#> [1] "a"       "about"   "after"   "again"   "against" "all"    
# keep the defaults and add domain terms
custom <- stop_words(add = c("students", "learning"), remove = "against")

# use a custom list when modeling
text <- c("students learning math", "markets and trading stocks")
embeddings <- rbind(c(1, 0), c(0, 1))
topics(text, n_topics = 2, embeddings = embeddings, stop_words = custom)
#> <sbert_topic_model>
#>   documents: 2 
#>   topics: 2
#>   model: precomputed embeddings
#>   algorithm: deterministic k-means (Lloyd)
#>   topic sizes: 1, 1
#>   between/total SS: 100.0%
```
