# Compare numbers of topics (deprecated)

`select_topics()` is the former name of
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md),
renamed in sbert 0.5.4 because the function compares candidate numbers
of topics and does not select one. It passes every argument to
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
and warns that it is deprecated.

## Usage

``` r
select_topics(...)
```

## Arguments

- ...:

  Arguments passed to
  [`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md).

## Value

The result of
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md).

## Conditions

A deprecation warning (class `deprecatedWarning`) on every call.

## See also

[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md).

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
# Warns, then forwards to compare_topics()
select_topics(text, n_topics = 2:3, embeddings = embeddings)
#> Warning: 'select_topics' is deprecated.
#> Use 'compare_topics' instead.
#> See help("Deprecated") and help("sbert-deprecated").
#> <sbert_topic_sweep> 2 candidates, coherence measure: npmi
#>  n_topics  coherence topic_diversity explained converged
#>         2 -0.4562038               1 0.9954323      TRUE
#>         3  0.1817530               1 0.9972006      TRUE
#> 
#> Fitted models retained: fitted(x, n_topics = 3)
```
