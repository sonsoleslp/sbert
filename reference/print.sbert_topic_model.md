# Print a Semantic Topic Model

Shows the fit at a glance: how many documents and topics, the variance
explained, and each topic with its size and its most distinctive terms.

## Usage

``` r
# S3 method for class 'sbert_topic_model'
print(x, ...)
```

## Arguments

- x:

  An \`sbert_topic_model\` object.

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
