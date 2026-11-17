# Build the hierarchy of the topics of a model

`topic_hierarchy()` clusters the topic centers of a model
hierarchically, showing which topics are nearest neighbors, in what
order they would merge, and at what distance. The topics of a model are
not equally distinct: some lie close together in the embedding space and
describe facets of one broader theme, while others stand apart. Topics
that merge early, at a small distance, are near-duplicates, which
suggests that the number of topics is finer than the data support.

It computes the cosine distances between the topic centers and clusters
them with [`stats::hclust()`](https://rdrr.io/r/stats/hclust.html). The
result, an object of class `sbert_topic_hierarchy`, is deterministic.
Use it to choose a smaller number of topics for
[`reduce_topics()`](https://sonsoles.me/sbert/reference/reduce_topics.md),
or to report how the topics group into themes.

## Usage

``` r
topic_hierarchy(object, method = "average")
```

## Arguments

- object:

  A topic model fitted by
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md).

- method:

  Agglomeration method passed to
  [`stats::hclust()`](https://rdrr.io/r/stats/hclust.html) (default
  `"average"`).

## Value

An object of class `sbert_topic_hierarchy`.
[as.data.frame()](https://sonsoles.me/sbert/reference/as.data.frame.sbert_topic_hierarchy.md)
gives the merge table, one row per merge;
[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_hierarchy.md)
gives the nearest neighbor of every topic;
[plot()](https://sonsoles.me/sbert/reference/plot.sbert_topic_hierarchy.md)
draws the dendrogram.

## Conditions

An error of class `sbert_bad_input` when the model has fewer than two
topics.

## See also

[`reduce_topics()`](https://sonsoles.me/sbert/reference/reduce_topics.md)
to merge topics;
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
to compare numbers of topics;
[`topic_similarity()`](https://sonsoles.me/sbert/reference/topic_similarity.md)
for cosine similarities between embeddings.

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings, label = "terms")
tree <- topic_hierarchy(topic_model)
tree
#> <sbert_topic_hierarchy> 6 topics, 5 merges (cosine distance)
#> 
#>  step    height                                  left
#>     1 0.2972668    topic 3 (mean / ones / strawberry)
#>     2 0.3199983 topic 1 (picture / pictures / choose)
#>     3 0.5163521                               merge 1
#>     4 0.6351317            topic 4 (box / red / blue)
#>     5 0.7383564      topic 6 (it's / person / animal)
#>                              right
#>   topic 5 (means / middle / right)
#>  topic 2 (ones / broccoli / candy)
#>                            merge 2
#>                            merge 3
#>                            merge 4
summary(tree)
#> Nearest topic of each topic (cosine distance between centers)
#> 
#>  topic                       label nearest_topic               nearest_label
#>      1 picture / pictures / choose             2     ones / broccoli / candy
#>      2     ones / broccoli / candy             1 picture / pictures / choose
#>      3    mean / ones / strawberry             5      means / middle / right
#>      4            box / red / blue             1 picture / pictures / choose
#>      5      means / middle / right             3    mean / ones / strawberry
#>      6      it's / person / animal             5      means / middle / right
#>  distance merge_step merge_height
#>     0.320          2        0.320
#>     0.320          2        0.320
#>     0.297          1        0.297
#>     0.461          4        0.635
#>     0.297          1        0.297
#>     0.538          5        0.738
```
