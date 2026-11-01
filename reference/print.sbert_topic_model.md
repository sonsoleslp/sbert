# Print a Semantic Topic Model

Shows the fit at a glance: the number of documents and topics, the
embedding source, the clustering algorithm, the size of every topic, and
the share of the embedding variance that lies between topics. Use
[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_model.md)
for coherence per topic and
[`topic_sizes()`](https://sonsoles.me/sbert/reference/topic_sizes.md)
for the labeled size table.

## Usage

``` r
# S3 method for class 'sbert_topic_model'
print(x, ...)
```

## Arguments

- x:

  An `sbert_topic_model` object.

- ...:

  Ignored.

## Value

The topic model object, invisibly.

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
print(topics(text, n_topics = 2, embeddings = embeddings, n_terms = 3))
#> <sbert_topic_model>
#>   documents: 6 
#>   topics: 2
#>   model: precomputed embeddings
#>   algorithm: deterministic k-means (Lloyd)
#>   topic sizes: 3, 3
#>   between/total SS: 99.5%
```
