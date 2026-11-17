# Merge the topics of a model into fewer topics

`reduce_topics()` merges the closest topics of a fitted model into
`n_topics` topics, giving a coarser model in which every document keeps
its place: documents that shared a topic still share one. A model with
more topics than the data support has near-duplicate topics that divide
one theme between them; merging them differs from fitting a new model
with fewer topics, in which documents may be regrouped.

It cuts the hierarchy of
[`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md)
into `n_topics` groups and merges the topics within each group. The new
topic centers are the normalized means of their members' embeddings, and
the terms, labels, sizes, representatives, and sums of squares are
computed again for the merged topics. The result is a topic model like
any other, so every verb applies to it. Names given with
[`name_topics()`](https://sonsoles.me/sbert/reference/name_topics.md)
are dropped, because the merged topics need new ones.

## Usage

``` r
reduce_topics(object, n_topics, embeddings = NULL, method = "average")
```

## Arguments

- object:

  A topic model fitted by
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md).

- n_topics:

  Number of topics after merging: at least 2 and below the current
  number.

- embeddings:

  The embedding matrix the model was fitted on. Needed only for a model
  fitted with `keep_embeddings = FALSE`. Default `NULL`.

- method:

  Agglomeration method passed to
  [`stats::hclust()`](https://rdrr.io/r/stats/hclust.html) (default
  `"average"`).

## Value

A topic model of class `sbert_topic_model` with `n_topics` topics,
structured as a
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) fit.

## Conditions

Errors of class `sbert_bad_input` when `n_topics` is not below the
current number of topics, and `sbert_no_embeddings` when the model holds
no embeddings and none are given.

## See also

[`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md)
to see which topics would merge;
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
to compare fits with different numbers of topics.

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings)
reduced <- reduce_topics(topic_model, n_topics = 4)
topic_sizes(reduced, weights = "n")
#>   topic                                                       label n_documents
#> 1     1   Where is the cow and the cake? Choose all the pictures...         356
#> 2     2         What does “all the ones between the leaf and the...         168
#> 3     3 Are you sure you have fewer pictures in the red box than...          49
#> 4     4    It is not a person, does not have a hat, and is sitting.          27
#>   proportion n_weighted weighted_share
#> 1 0.59333333        429     0.57972973
#> 2 0.28000000        195     0.26351351
#> 3 0.08166667         76     0.10270270
#> 4 0.04500000         40     0.05405405
```
