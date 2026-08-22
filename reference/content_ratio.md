# Alphabetic Content Ratio of Text

The fraction of a string's non-space characters that are letters. A
domain-agnostic measure of how much of a unit is prose rather than
numbers, punctuation, or symbols: real sentences score near 1, while
citation fragments, reference lists, number tables, and identifiers
(\`"OJ No L 297, 24.11.1979, p. 1."\`, \`"doi:10.1007/..."\`) score low.
Used by the \`min_content\` filters of \[segment()\] and \[topics()\].

## Usage

``` r
content_ratio(text)
```

## Arguments

- text:

  A character vector.

## Value

A numeric vector in \`\[0, 1\]\`; empty or space-only elements score
\`0\`.

## Examples

``` r
content_ratio(c("A real sentence here.", "OJ No L 297, 24.11.1979, p. 1."))
#> [1] 0.9444444 0.2500000
```
