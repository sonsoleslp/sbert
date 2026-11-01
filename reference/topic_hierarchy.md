# Build the Topic Hierarchy of a Fitted Model

Agglomeratively clusters the topic centroids by cosine distance and
returns the merge tree: which topics are semantic neighbors, in what
order they would fuse, and how far apart they are. Use it to judge
whether a topic count is too fine (early merges at small heights are
near-duplicate topics) and to choose a target count for
[`reduce_topics()`](https://sonsoles.me/sbert/reference/reduce_topics.md).
Deterministic — no sampling, no seed.

## Usage

``` r
topic_hierarchy(object, method = "average")
```

## Arguments

- object:

  An `sbert_topic_model` returned by
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md).

- method:

  Agglomeration method passed to
  [`stats::hclust()`](https://rdrr.io/r/stats/hclust.html). Default
  `"average"`.

## Value

An `sbert_topic_hierarchy`: a list with `merges` (a tidy data frame with
one row per merge — `step`, `height`, and the human-readable `left` and
`right` branch descriptions) and `tree` (the underlying `hclust` object,
labeled with topic labels).
[`print()`](https://rdrr.io/r/base/print.html) shows the merge table;
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws the
labeled dendrogram.

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
topic_model <- topics(text, 3, embeddings = embeddings, n_terms = 3)
topic_hierarchy(topic_model)
#> <sbert_topic_hierarchy> 3 topics, 2 merges (cosine distance)
#> 
#>  step      height                           left
#>     1 0.003556675     topic 2 (Dogs chase balls)
#>     2 0.877531228 topic 1 (Markets price shares)
#>                              right
#>  topic 3 (Kittens nap in sunshine)
#>                            merge 1
```
