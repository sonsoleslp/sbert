# Remove list and enumeration markers from text

`strip_list_markers()` removes the markers of numbered and lettered
lists, such as `"1."`, `"(ii)"`, `"(a)"` and `"IV."`, from the text
itself, before segmentation and encoding. Such markers, common in texts
taken from documents, forms, or reports, carry no meaning, but they
split sentences where there is no sentence boundary, shift the
embeddings, and appear in the representative texts.

It removes a one- or two-digit number with a period where a list can be
(at the start of the text or of a sentence, or continuing a list); a
parenthesized number, single letter, or Roman numeral; and an upper-case
Roman numeral with a period. A marker must stand alone, so a number that
ends a sentence (`"in the top 20."`), years, decimals, and words in
parentheses are kept. The result is `text` with the markers removed and
white space collapsed.

The `numbers`, `roman_numerals`, and `section_numbers` arguments of
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) filter the
terms only.
[`clean_corpus()`](https://sonsoles.me/sbert/reference/clean_corpus.md)
applies this function together with other cleaning steps.

## Usage

``` r
strip_list_markers(text)
```

## Arguments

- text:

  A character vector without missing values.

## Value

`text` with the markers removed, runs of white space collapsed to one
space, and each element trimmed.

## See also

[`clean_corpus()`](https://sonsoles.me/sbert/reference/clean_corpus.md),
which includes this step;
[`dedupe()`](https://sonsoles.me/sbert/reference/dedupe.md);
[`segment()`](https://sonsoles.me/sbert/reference/segment.md).

## Examples

``` r
strip_list_markers(c("1. background 2. methods", "(i) first (ii) second"))
#> [1] "background methods" "first second"      
strip_list_markers("the concept of (civil) society in (2020)")
#> [1] "the concept of (civil) society in (2020)"
strip_list_markers("The student ranks in the top 20. Good work.")
#> [1] "The student ranks in the top 20. Good work."
```
