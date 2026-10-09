# Coerce a Topic-Count Comparison to a Data Frame

Drops the retained models and the sweep attributes, leaving the plain
table of candidates and their measures for further manipulation.

## Usage

``` r
# S3 method for class 'sbert_topic_sweep'
as.data.frame(x, ...)
```

## Arguments

- x:

  An \`sbert_topic_sweep\` object.

- ...:

  Ignored.

## Value

A plain data frame without the attached models or sweep attributes.

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
comparison <- compare_topics(text, n_topics = 2:3, embeddings = embeddings)
as.data.frame(comparison)
#>   n_topics  coherence topic_diversity explained
#> 1        2 -0.4562038               1 0.9954323
#> 2        3  0.1817530               1 0.9972006
```
