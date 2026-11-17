# Print a topic-count comparison summary

[`print()`](https://rdrr.io/r/base/print.html) shows the coherence
measure and weighting of a comparison summary made by
[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_sweep.md),
followed by its table of one row per segment level.

## Usage

``` r
# S3 method for class 'summary.sbert_topic_sweep'
print(x, digits = 3L, ...)
```

## Arguments

- x:

  A summary returned by
  [summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_sweep.md).

- digits:

  Significant digits for the measures (default 3).

- ...:

  Ignored.

## Value

`x`, invisibly.

## See also

[`summary.sbert_topic_sweep()`](https://sonsoles.me/sbert/reference/summary.sbert_topic_sweep.md).

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
comparison <- compare_topics(corpus, n_topics = c(4, 6),
                             column = "translation",
                             embeddings = feedback_embeddings)
print(summary(comparison), digits = 2)
#> Topic-count comparison: highest mean npmi coherence per level
#> 
#>   segment n_candidates min_topics max_topics best_n_topics coherence
#>  document            2          4          6             6      -0.1
#>  topic_diversity explained all_converged
#>             0.92      0.23          TRUE
```
