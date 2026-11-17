# Print a topic hierarchy summary

[`print()`](https://rdrr.io/r/base/print.html) shows the nearest
neighbor of every topic, as computed by
[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_hierarchy.md),
as a table.

## Usage

``` r
# S3 method for class 'summary.sbert_topic_hierarchy'
print(x, digits = 3L, ...)
```

## Arguments

- x:

  A summary returned by
  [summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_hierarchy.md).

- digits:

  Significant digits for the distances (default 3).

- ...:

  Ignored.

## Value

`x`, invisibly.

## See also

[`summary.sbert_topic_hierarchy()`](https://sonsoles.me/sbert/reference/summary.sbert_topic_hierarchy.md).

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
tree <- topic_hierarchy(topics(text, n_topics = 3, embeddings = embeddings,
                               n_terms = 3))
print(summary(tree), digits = 2)
#> Nearest topic of each topic (cosine distance between centers)
#> 
#>  topic                   label nearest_topic           nearest_label distance
#>      1    Markets price shares             3 Kittens nap in sunshine   0.8357
#>      2        Dogs chase balls             3 Kittens nap in sunshine   0.0036
#>      3 Kittens nap in sunshine             2        Dogs chase balls   0.0036
#>  merge_step merge_height
#>           2       0.8775
#>           1       0.0036
#>           1       0.0036
```
