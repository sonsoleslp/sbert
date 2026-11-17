# Convert a topic hierarchy to a data frame

[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) returns
the merge table of a topic hierarchy: one row per merge of the
hierarchical clustering of the topic centers, in the order in which the
merges happen. Merges at a small height join topics whose centers are
nearly parallel; such topics are candidates for
[`reduce_topics()`](https://sonsoles.me/sbert/reference/reduce_topics.md).

## Usage

``` r
# S3 method for class 'sbert_topic_hierarchy'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)
```

## Arguments

- x:

  A hierarchy built by
  [`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md).

- row.names, optional:

  Ignored; present for compatibility with the generic.

- ...:

  Ignored.

## Value

A base data frame with one row per merge and columns `step`, `height`
(the cosine distance at which the two branches join), `left`, and
`right` (the branches, as `"topic <id> (<label>)"` or `"merge <step>"`).

## See also

[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_hierarchy.md)
for the nearest neighbor of each topic;
[plot()](https://sonsoles.me/sbert/reference/plot.sbert_topic_hierarchy.md)
for the dendrogram.

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings, label = "terms")
as.data.frame(topic_hierarchy(topic_model))
#>   step    height                                  left
#> 1    1 0.2972668    topic 3 (mean / ones / strawberry)
#> 2    2 0.3199983 topic 1 (picture / pictures / choose)
#> 3    3 0.5163521                               merge 1
#> 4    4 0.6351317            topic 4 (box / red / blue)
#> 5    5 0.7383564      topic 6 (it's / person / animal)
#>                               right
#> 1  topic 5 (means / middle / right)
#> 2 topic 2 (ones / broccoli / candy)
#> 3                           merge 2
#> 4                           merge 3
#> 5                           merge 4
```
