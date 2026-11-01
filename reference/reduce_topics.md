# Reduce a Fitted Topic Model to Fewer Topics

Cuts the topic hierarchy (see
[`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md))
at the requested count and rebuilds the model: documents keep their
cluster memberships (merged, never re-clustered), centroids are
recomputed from the member documents, and terms, labels, sizes, and
representatives are derived afresh for the merged topics. The result is
a full `sbert_topic_model` — every downstream verb
([`summary()`](https://rdrr.io/r/base/summary.html),
[`coherence()`](https://sonsoles.me/sbert/reference/coherence.md),
[`predict()`](https://rdrr.io/r/stats/predict.html),
[`representatives()`](https://sonsoles.me/sbert/reference/representatives.md),
plots) works unchanged.

## Usage

``` r
reduce_topics(object, n_topics, embeddings = NULL, method = "average")
```

## Arguments

- object:

  An `sbert_topic_model` returned by
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md).

- n_topics:

  Target number of topics, at least 2 and below the current count.

- embeddings:

  The document embedding matrix used to fit `object`. Only needed when
  the model was fitted with `keep_embeddings = FALSE`; models fitted
  with `keep_embeddings = TRUE` carry their embeddings.

- method:

  Agglomeration method passed to
  [`stats::hclust()`](https://rdrr.io/r/stats/hclust.html). Default
  `"average"`.

## Value

An `sbert_topic_model` with `n_topics` topics and the same structure as
a [`topics()`](https://sonsoles.me/sbert/reference/topics.md) fit. Names
given with
[`name_topics()`](https://sonsoles.me/sbert/reference/name_topics.md)
are dropped, because the merged topics need new ones.

## Examples

``` r
text <- c(
  "Cats chase mice", "Dogs chase balls", "Kittens nap in sunshine",
  "Stocks and bonds trade", "Markets price shares", "Banks report profit"
)
embeddings <- rbind(
  c(1, 0), c(0.95, 0.05), c(0.9, 0.1),
  c(0, 1), c(0.05, 0.95), c(0.1, 0.9)
)
topic_model <- topics(
  text, 3,
  embeddings = embeddings, n_terms = 3, keep_embeddings = TRUE
)
reduce_topics(topic_model, 2)
#> <sbert_topic_model>
#>   documents: 6 
#>   topics: 2
#>   model: precomputed embeddings
#>   algorithm: hierarchical merge of deterministic k-means topics
#>   topic sizes: 3, 3
#>   between/total SS: 99.5%
```
