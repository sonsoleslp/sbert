# Plot a topic hierarchy as a dendrogram

[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws the
hierarchy of the topics as a dendrogram with the topic labels as leaves
and the cosine distance between topic centers on the vertical axis.
Topics joined low in the tree are near-duplicates; topics joined only
near the top are distinct from the rest.

## Usage

``` r
# S3 method for class 'sbert_topic_hierarchy'
plot(x, main = "Topic hierarchy", cex = 0.8, ...)
```

## Arguments

- x:

  A hierarchy built by
  [`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md).

- main:

  Plot title (default `"Topic hierarchy"`).

- cex:

  Size of the leaf labels (default 0.8).

- ...:

  Passed to the [`plot()`](https://rdrr.io/r/graphics/plot.default.html)
  method of [`stats::hclust()`](https://rdrr.io/r/stats/hclust.html).

## Value

`x`, invisibly. Called for the plot.

## See also

[`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md);
[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_hierarchy.md);
[`reduce_topics()`](https://sonsoles.me/sbert/reference/reduce_topics.md).

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings, label = "terms")
plot(topic_hierarchy(topic_model))
```
