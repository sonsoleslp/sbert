# Print a topic-count comparison

[`print()`](https://rdrr.io/r/base/print.html) shows a topic-count
comparison: the coherence measure, one row per candidate with its
measures, and, when the fitted models are kept, the
[fitted()](https://sonsoles.me/sbert/reference/fitted.sbert_topic_sweep.md)
call that returns the most coherent candidate.

## Usage

``` r
# S3 method for class 'sbert_topic_sweep'
print(x, ...)
```

## Arguments

- x:

  A comparison returned by
  [`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md).

- ...:

  Ignored.

## Value

`x`, invisibly.

## See also

[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md);
[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_sweep.md);
[as.data.frame()](https://sonsoles.me/sbert/reference/as.data.frame.sbert_topic_sweep.md).

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
print(compare_topics(corpus, n_topics = c(4, 6), column = "translation",
                     embeddings = feedback_embeddings))
#> <sbert_topic_sweep> 2 candidates, coherence measure: npmi
#>  n_topics  coherence topic_diversity explained converged
#>         4 -0.2070855       0.9250000 0.1229819      TRUE
#>         6 -0.1044246       0.9166667 0.2255144      TRUE
#> 
#> Fitted models retained: fitted(x, n_topics = 6)
```
