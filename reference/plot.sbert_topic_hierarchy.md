# Plot a Topic Hierarchy Dendrogram

Draws the merge tree as a dendrogram labeled with topic labels, with
cosine distance on the height axis. Early merges at small heights are
near-duplicate topics.

## Usage

``` r
# S3 method for class 'sbert_topic_hierarchy'
plot(x, main = "Topic hierarchy", cex = 0.8, ...)
```

## Arguments

- x:

  An \`sbert_topic_hierarchy\` object.

- main:

  Plot title.

- cex:

  Character expansion factor for labels.

- ...:

  Passed to \[plot.dendrogram()\].

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
plot(tree)
```
