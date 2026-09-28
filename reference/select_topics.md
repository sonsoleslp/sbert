# Deprecated: Compare Topic Counts

\`select_topics()\` is the former name of \[compare_topics()\]. It never
selected a count, it compared them, so it was renamed in sbert 0.5.4.
This alias forwards every argument and warns once per session.

## Usage

``` r
select_topics(...)
```

## Arguments

- ...:

  Passed to \[compare_topics()\].

## Value

See \[compare_topics()\].

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
# Deprecated: prefer compare_topics(). This warns once, then forwards.
suppressWarnings(select_topics(text, n_topics = 2:3, embeddings = embeddings))
#> <sbert_topic_sweep> 2 candidates, coherence measure: npmi
#>  n_topics  coherence topic_diversity explained
#>         2 -0.4562038               1 0.9954323
#>         3  0.1817530               1 0.9972006
#> 
#> Fitted models retained: fitted(x, n_topics = 3)
```
