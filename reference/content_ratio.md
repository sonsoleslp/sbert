# Compute the share of letters in text

`content_ratio()` computes the share of letters among the non-space
characters of each element of `text`. The share separates prose from
other units without relying on a language: sentences score close to one,
while reference lists, citations, tables of numbers, and identifiers,
which consist mostly of digits and punctuation and form spurious topics
of their own when they are clustered, score low.

It returns one value between 0 and 1 per element and is the measure
behind the `min_content` filters of
[`clean_corpus()`](https://sonsoles.me/sbert/reference/clean_corpus.md),
[`segment()`](https://sonsoles.me/sbert/reference/segment.md), and
[`topics()`](https://sonsoles.me/sbert/reference/topics.md).

## Usage

``` r
content_ratio(text)
```

## Arguments

- text:

  A character vector.

## Value

A numeric vector of the same length as `text`, with values between 0 and
1; an empty or all-space element scores 0.

## See also

[`clean_corpus()`](https://sonsoles.me/sbert/reference/clean_corpus.md)
and [`segment()`](https://sonsoles.me/sbert/reference/segment.md), which
filter on it.

## Examples

``` r
content_ratio(c("A real sentence here.", "OJ No L 297, 24.11.1979, p. 1."))
#> [1] 0.9444444 0.2500000
```
