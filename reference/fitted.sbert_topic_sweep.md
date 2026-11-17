# Extract a fitted model from a topic-count comparison

[`fitted()`](https://rdrr.io/r/stats/fitted.values.html) returns one
candidate model from a
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
comparison, identical to a
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) fit with the
same settings, without fitting it again.
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
fits a model for every candidate number of topics and, by default, keeps
them, so once a candidate has been chosen from the comparison its model
can be taken out directly.

## Usage

``` r
# S3 method for class 'sbert_topic_sweep'
fitted(object, n_topics, segment = NULL, ...)
```

## Arguments

- object:

  A comparison returned by
  [`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
  with `keep_models = TRUE` (the default).

- n_topics:

  The number of topics of the model to return; one of the candidates.

- segment:

  The segment level of the model to return, when the comparison spans
  several levels; `NULL` (default) for a single-level comparison.

- ...:

  Ignored.

## Value

A topic model of class `sbert_topic_model`, as returned by
[`topics()`](https://sonsoles.me/sbert/reference/topics.md).

## Conditions

Errors of class `sbert_no_fitted_model` when the comparison kept no
models or holds no model for `n_topics`, and `sbert_bad_input` when
`segment` is given for a single-level comparison or missing for a
comparison of several levels.

## See also

[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md);
[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_sweep.md)
for the most coherent candidate.

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
comparison <- compare_topics(corpus, n_topics = c(4, 6),
                             column = "translation",
                             embeddings = feedback_embeddings)
topic_model <- fitted(comparison, n_topics = 6)
topic_sizes(topic_model, weights = "n")
#>   topic                                                       label n_documents
#> 1     1   Where is the cow and the cake? Choose all the pictures...         223
#> 2     2            All the ones between the cat and the strawberry.         133
#> 3     3         What does “all the ones between the leaf and the...         131
#> 4     4 Are you sure you have fewer pictures in the red box than...          49
#> 5     5      In the top middle box, it means something is in the...          37
#> 6     6    It is not a person, does not have a hat, and is sitting.          27
#>   proportion n_weighted weighted_share
#> 1 0.37166667        267     0.36081081
#> 2 0.22166667        162     0.21891892
#> 3 0.21833333        138     0.18648649
#> 4 0.08166667         76     0.10270270
#> 5 0.06166667         57     0.07702703
#> 6 0.04500000         40     0.05405405
```
