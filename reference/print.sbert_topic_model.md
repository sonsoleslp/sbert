# Print a topic model

[`print()`](https://rdrr.io/r/base/print.html) shows a fitted topic
model at a glance: the number of documents (and of segments, for a
segmented fit), the number of topics, the embedding model, the
clustering algorithm, the size of every topic, and the share of the
embedding variance that lies between topics.

## Usage

``` r
# S3 method for class 'sbert_topic_model'
print(x, ...)
```

## Arguments

- x:

  A topic model fitted by
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md).

- ...:

  Ignored.

## Value

`x`, invisibly.

## See also

[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_model.md)
for coherence and topic diversity;
[`topic_sizes()`](https://sonsoles.me/sbert/reference/topic_sizes.md)
for the labeled size table;
[as.data.frame()](https://sonsoles.me/sbert/reference/as.data.frame.sbert_topic_model.md)
for the tables.

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
print(topics(corpus, n_topics = 6, column = "translation",
             embeddings = feedback_embeddings))
#> <sbert_topic_model>
#>   documents: 600 
#>   topics: 6
#>   model: precomputed embeddings
#>   algorithm: deterministic k-means (Lloyd)
#>   topic sizes: 223, 133, 131, 49, 37, 27
#>   between/total SS: 22.6%
```
