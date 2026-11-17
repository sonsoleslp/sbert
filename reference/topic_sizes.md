# Compute the size of each topic

`topic_sizes()` returns the number and proportion of units in every
topic of a fitted model and, with `weights`, the weighted size and
share. The size of a topic can be counted in several ways: counted in
distinct texts, it says how varied the content of the topic is; weighted
by how often each text occurred, it says how much of the original corpus
the topic accounts for.

A topic whose weighted share far exceeds its share of distinct texts is
a small set of texts that are repeated many times. For a segmented
model, a topic can be counted in segments or, with `by = "document"`, in
the documents that have at least one segment in it; a document with
segments in several topics then counts in each of them, so the
proportions need not sum to one. For a model fitted to documents, the
two scales are the same.

## Usage

``` r
topic_sizes(object, weights = NULL, by = c("segment", "document"))
```

## Arguments

- object:

  A topic model fitted by
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md).

- weights:

  Optional weights: the name of a numeric column carried in the model
  (for example `"n"` from
  [`dedupe()`](https://sonsoles.me/sbert/reference/dedupe.md)), or a
  numeric vector of non-negative weights, one per unit on the chosen
  scale. Default `NULL`.

- by:

  Unit counted: `"segment"` (default), every modeled unit, or
  `"document"`, the source documents.

## Value

A base data frame with one row per topic and columns `topic`, `label`,
`n_documents`, and `proportion`, followed by `n_weighted` and
`weighted_share` when `weights` are given.

## Conditions

An error of class `sbert_bad_input` when `weights` names a column that
the model does not carry.

## See also

[`dedupe()`](https://sonsoles.me/sbert/reference/dedupe.md) for the
counts; [`topics()`](https://sonsoles.me/sbert/reference/topics.md);
[as.data.frame()](https://sonsoles.me/sbert/reference/as.data.frame.sbert_topic_model.md)
for the full tables;
[plot()](https://sonsoles.me/sbert/reference/plot.sbert_topic_model.md)
with `type = "sizes"`.

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings)
topic_sizes(topic_model)
#>   topic                                                       label n_documents
#> 1     1   Where is the cow and the cake? Choose all the pictures...         223
#> 2     2            All the ones between the cat and the strawberry.         133
#> 3     3         What does “all the ones between the leaf and the...         131
#> 4     4 Are you sure you have fewer pictures in the red box than...          49
#> 5     5      In the top middle box, it means something is in the...          37
#> 6     6    It is not a person, does not have a hat, and is sitting.          27
#>   proportion
#> 1 0.37166667
#> 2 0.22166667
#> 3 0.21833333
#> 4 0.08166667
#> 5 0.06166667
#> 6 0.04500000
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
