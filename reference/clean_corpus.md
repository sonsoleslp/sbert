# Clean a corpus before encoding

`clean_corpus()` removes material without topical meaning from a corpus
before encoding: markup, links, citation numbers, list markers, and
broken characters. Text exported from web pages, databases, and
documents carries such material; left in place, it shifts the
embeddings, appears among the topic terms, and can form topics of its
own. Cleaning the text once, before encoding, means that the encoder,
the topic terms, and the representative texts all see the same clean
text.

It always repairs broken characters and removes markup, links, e-mail
addresses, DOIs, and bracketed citation numbers. It removes list markers
and section numbering by default, and on request numbers, Roman
numerals, and the matches of patterns of one's own (`remove`). Words,
author citations, dates, decimals, and numbers within sentences are
kept. Documents left empty, or with a share of letters below
`min_content` (see
[`content_ratio()`](https://sonsoles.me/sbert/reference/content_ratio.md)),
are dropped. For a data frame, the dropped rows are removed whole, so
other columns stay aligned with the text. It returns the cleaned texts
that are kept or, for a data frame, the kept rows with `column` cleaned.

The `numbers`, `roman_numerals`, and `section_numbers` arguments of
[`topics()`](https://sonsoles.me/sbert/reference/topics.md), by
contrast, filter only the topic terms and leave the text unchanged.

## Usage

``` r
clean_corpus(
  text,
  column = NULL,
  list_markers = TRUE,
  section_numbers = TRUE,
  numbers = FALSE,
  roman_numerals = FALSE,
  remove = NULL,
  min_content = 0
)
```

## Arguments

- text:

  A character vector, or a data frame together with `column`.

- column:

  Name of the text column when `text` is a data frame; `NULL` (default)
  for a character vector.

- list_markers:

  Remove list and enumeration markers (default `TRUE`); see
  [`strip_list_markers()`](https://sonsoles.me/sbert/reference/strip_list_markers.md).

- section_numbers:

  Remove section numbering such as `1.2.3` and `II.2` (default `TRUE`).

- numbers:

  Remove stand-alone numbers such as years and counts, keeping words
  with digits such as `covid19` (default `FALSE`).

- roman_numerals:

  Remove stand-alone Roman numerals of two or more letters, such as `ii`
  and `xiv` (default `FALSE`).

- remove:

  Optional character vector of Perl-compatible regular expressions,
  matched case-insensitively; each match is replaced by a space. Default
  `NULL`.

- min_content:

  Minimum share of letters for a document to be kept, between 0 and 1
  (default 0, keep every non-empty document).

## Value

For a character vector, the cleaned texts that are kept. For a data
frame, the rows that are kept, with `column` cleaned.

## Conditions

An error of class `sbert_bad_input` when `column` is given for a
character vector.

## See also

[`strip_list_markers()`](https://sonsoles.me/sbert/reference/strip_list_markers.md)
and
[`content_ratio()`](https://sonsoles.me/sbert/reference/content_ratio.md),
which it uses;
[`dedupe()`](https://sonsoles.me/sbert/reference/dedupe.md) to collapse
repeated texts after cleaning.

## Examples

``` r
clean_corpus(c(
  "1. The directive entered into force in 2020.",
  "OJ No L 297, 24.11.1979, p. 1."
), min_content = 0.5)
#> [1] "The directive entered into force in 2020."

# Remove a reference form of one's own corpus
clean_corpus("as set out in OJ No L 313 it applies.",
             remove = "OJ No L?\\s*\\d+")
#> [1] "as set out in it applies."
```
