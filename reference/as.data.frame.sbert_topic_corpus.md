# Convert a prepared topic corpus to a data frame

[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) returns
the units of a prepared corpus, one row per unit to be clustered: each
document, or each sentence, clause, or phrase when the corpus is
segmented. The table shows what
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) and
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
will model, including the segments a segmentation produced and the
columns carried from a data frame input.

## Usage

``` r
# S3 method for class 'sbert_topic_corpus'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)
```

## Arguments

- x:

  A corpus prepared by
  [`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md).

- row.names, optional:

  Ignored; present for compatibility with the generic.

- ...:

  Ignored.

## Value

A base data frame with one row per unit and columns `document_id`,
`document_name`, `segment` (segmented corpora only), and `text`,
followed by the columns carried from a data frame input.

## See also

[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md),
[`segment()`](https://sonsoles.me/sbert/reference/segment.md).

## Examples

``` r
documents <- data.frame(
  id = c("a", "b"),
  text = c("Cats chase mice. Stocks and bonds trade.",
           "Dogs chase balls. Markets price shares.")
)
prepared <- topic_corpus(
  documents, column = "text", segment = "sentence",
  embeddings = rbind(c(1, 0), c(0, 1), c(0.9, 0.1), c(0.1, 0.9))
)
as.data.frame(prepared)
#>   document_id document_name segment                    text id
#> 1           1                     1        Cats chase mice.  a
#> 2           1                     2 Stocks and bonds trade.  a
#> 3           2                     1       Dogs chase balls.  b
#> 4           2                     2   Markets price shares.  b
```
