# Topic Sizes on the Distinct and Weighted Scales

Returns the size of every topic as fitted (distinct units) and, when
\`weights\` are supplied, on the weighted scale — for example the
original row frequencies from \[dedupe()\]. The gap between
\`proportion\` and \`weighted_share\` measures how template-driven a
topic is: a topic whose weighted share far exceeds its distinct share is
a small repertoire of heavily repeated texts.

## Usage

``` r
topic_sizes(object, weights = NULL, by = c("segment", "document"))
```

## Arguments

- object:

  A fitted \[topics()\] model.

- weights:

  Optional numeric vector with one non-negative weight per unit on the
  chosen scale — per fitted document (in document order), typically the
  \`n\` column of \[dedupe()\], or per segment when \`by = "segment"\`
  on a segmented model.

- by:

  \`"segment"\` (default; every fitted unit) or \`"document"\` (the
  distinct source documents).

## Value

A base data frame with one row per topic and columns \`topic\`,
\`label\`, \`n_documents\`, and \`proportion\`, plus \`n_weighted\` and
\`weighted_share\` when \`weights\` are supplied.

## Details

For a model fitted with \`segment = "sentence"\`, \`"clause"\`, or
\`"phrase"\`, \`by\` picks the scale: \`"segment"\` counts the fitted
segments, \`"document"\` counts the source documents that have at least
one segment in the topic. A document that spans several topics is
counted in each, so document proportions need not sum to one. On a
document-level model the two scales coincide.

## Examples

``` r
text <- c(
  "Cats chase mice", "Dogs chase balls",
  "Stocks and bonds trade", "Markets price shares"
)
embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
fitted <- topics(text, 2, embeddings = embeddings)
topic_sizes(fitted, weights = c(10, 1, 1, 1))
#>   topic                   label n_documents proportion n_weighted
#> 1     1    chase / balls / cats           2        0.5         11
#> 2     2 bonds / markets / price           2        0.5          2
#>   weighted_share
#> 1      0.8461538
#> 2      0.1538462
```
