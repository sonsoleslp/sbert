# Print a Topic Hierarchy

Shows the merge table: one row per merge, with its height and the two
branches that fused.

## Usage

``` r
# S3 method for class 'sbert_topic_hierarchy'
print(x, ...)
```

## Arguments

- x:

  An \`sbert_topic_hierarchy\` object.

- ...:

  Ignored.

## Value

The hierarchy object, invisibly.

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
tree <- topic_hierarchy(topics(text, 3, embeddings = embeddings, n_terms = 3))
print(tree)
#> <sbert_topic_hierarchy> 3 topics, 2 merges (cosine distance)
#> 
#>  step      height                              left
#>     1 0.003556675    topic 2 (chase / balls / cats)
#>     2 0.877531228 topic 1 (banks / bonds / markets)
#>                               right
#>  topic 3 (kittens / nap / sunshine)
#>                             merge 1
```
