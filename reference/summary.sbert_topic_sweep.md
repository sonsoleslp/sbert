# Summarize a topic-count comparison

[`summary()`](https://rdrr.io/r/base/summary.html) reduces a comparison
of candidate numbers of topics to one row per segment level: the range
of numbers compared, the number with the highest mean coherence, that
candidate's diversity and between-topic variance, and whether every
candidate converged. The full table of candidates is given by
[as.data.frame()](https://sonsoles.me/sbert/reference/as.data.frame.sbert_topic_sweep.md).

Coherence is one guide among several; the choice of a number of topics
should also rest on reading the representative texts of the candidates.

## Usage

``` r
# S3 method for class 'sbert_topic_sweep'
summary(object, ...)
```

## Arguments

- object:

  A comparison returned by
  [`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md).

- ...:

  Ignored.

## Value

A data frame of class `summary.sbert_topic_sweep` with one row per
segment level and columns `segment`, `n_candidates`, `min_topics`,
`max_topics`, `best_n_topics` (highest coherence; `NA` when no candidate
can be scored), `coherence`, `topic_diversity`, `explained`, and
`all_converged`. It prints as a table.

## See also

[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md),
[plot()](https://sonsoles.me/sbert/reference/plot.sbert_topic_sweep.md),
[fitted()](https://sonsoles.me/sbert/reference/fitted.sbert_topic_sweep.md).

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
comparison <- compare_topics(corpus, n_topics = c(4, 6, 8),
                             column = "translation",
                             embeddings = feedback_embeddings)
summary(comparison)
#> Topic-count comparison: highest mean npmi coherence per level
#> 
#>   segment n_candidates min_topics max_topics best_n_topics coherence
#>  document            3          4          8             6    -0.104
#>  topic_diversity explained all_converged
#>            0.917     0.226          TRUE
```
