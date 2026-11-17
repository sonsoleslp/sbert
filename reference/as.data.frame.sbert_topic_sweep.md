# Convert a topic-count comparison to a data frame

[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) returns
the table of a comparison of candidate numbers of topics as a plain data
frame, without the fitted models, for reporting or for joining with
other results.

## Usage

``` r
# S3 method for class 'sbert_topic_sweep'
as.data.frame(x, ...)
```

## Arguments

- x:

  A comparison returned by
  [`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md).

- ...:

  Ignored.

## Value

A base data frame with one row per candidate and columns `n_topics`,
`coherence`, `topic_diversity`, `explained`, and `converged`, preceded
by `segment` when several levels were compared. The attributes `measure`
and `coherence_weight` are kept.

## See also

[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md);
[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_sweep.md).

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
comparison <- compare_topics(corpus, n_topics = c(4, 6),
                             column = "translation",
                             embeddings = feedback_embeddings)
as.data.frame(comparison)
#>   n_topics  coherence topic_diversity explained converged
#> 1        4 -0.2070855       0.9250000 0.1229819      TRUE
#> 2        6 -0.1044246       0.9166667 0.2255144      TRUE
```
