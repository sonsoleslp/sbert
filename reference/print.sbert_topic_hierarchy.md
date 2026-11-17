# Print a topic hierarchy

[`print()`](https://rdrr.io/r/base/print.html) shows a topic hierarchy:
the number of topics and merges, and the merge table: one row per merge,
with the cosine distance at which it happens and the two branches it
joins.

## Usage

``` r
# S3 method for class 'sbert_topic_hierarchy'
print(x, ...)
```

## Arguments

- x:

  A hierarchy built by
  [`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md).

- ...:

  Ignored.

## Value

`x`, invisibly.

## See also

[`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md);
[as.data.frame()](https://sonsoles.me/sbert/reference/as.data.frame.sbert_topic_hierarchy.md);
[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_hierarchy.md).

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
print(tree)
#> <sbert_topic_hierarchy> 3 topics, 2 merges (cosine distance)
#> 
#>  step      height                           left
#>     1 0.003556675     topic 2 (Dogs chase balls)
#>     2 0.877531228 topic 1 (Markets price shares)
#>                              right
#>  topic 3 (Kittens nap in sunshine)
#>                            merge 1
```
