# Print a Topic-Count Comparison

Shows one row per candidate with its quality measures, and the call that
pulls the best-scoring fitted model back out.

## Usage

``` r
# S3 method for class 'sbert_topic_sweep'
print(x, ...)
```

## Arguments

- x:

  An \`sbert_topic_sweep\` object.

- ...:

  Ignored.

## Value

The sweep object, invisibly.

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
print(comparison)
#> <sbert_topic_sweep> 2 candidates, coherence measure: npmi
#>  n_topics  coherence topic_diversity explained
#>         2 -0.4562038               1 0.9954323
#>         3  0.1817530               1 0.9972006
#> 
#> Fitted models retained: fitted(x, n_topics = 3)
```
