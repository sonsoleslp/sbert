# Summarize a topic hierarchy

[`summary()`](https://rdrr.io/r/base/summary.html) lists every topic of
a hierarchy with its nearest neighbor among the other topics, the topic
whose center has the smallest cosine distance to its own, and the step
and height at which the topic first merges in the hierarchy. A topic at
a small distance from its neighbor is a near-duplicate of it; a topic
that merges only late is distinct from all others.

## Usage

``` r
# S3 method for class 'sbert_topic_hierarchy'
summary(object, ...)
```

## Arguments

- object:

  A hierarchy built by
  [`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md).

- ...:

  Ignored.

## Value

A data frame of class `summary.sbert_topic_hierarchy` with one row per
topic and columns `topic`, `label`, `nearest_topic`, `nearest_label`,
`distance` (cosine distance between the two topic centers),
`merge_step`, and `merge_height` (the first merge that includes the
topic). It prints as a table.

## Conditions

An error of class `sbert_bad_input` for a hierarchy built by an sbert
version that did not store the topic distances; rebuild it with
[`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md).

## See also

[`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md),
[`reduce_topics()`](https://sonsoles.me/sbert/reference/reduce_topics.md),
[as.data.frame()](https://sonsoles.me/sbert/reference/as.data.frame.sbert_topic_hierarchy.md).

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings, label = "terms")
summary(topic_hierarchy(topic_model))
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
