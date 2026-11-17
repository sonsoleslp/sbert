# Collapse repeated texts and count them

`dedupe()` collapses repeated texts: it keeps the first occurrence of
every distinct non-blank text, in order of first appearance, and adds
its number of occurrences as `n`. Many corpora repeat texts (templates,
standard replies, and copied messages); repeated texts carry no new
information about the topics, but in a clustering they pull the topic
centers toward themselves and inflate the size of the topics they fall
in.

Modeling each distinct text once, and carrying how often it occurred,
separates what kinds of text there are from how often each kind is used.
The result is a data frame with one row per distinct text. The counts
can be used as weights after fitting, for example with
`topic_sizes(weights = "n")`.

## Usage

``` r
dedupe(text, column = NULL)
```

## Arguments

- text:

  A character vector, or a data frame together with `column`. Missing
  and blank texts are dropped.

- column:

  Name of the text column when `text` is a data frame; `NULL` (default)
  for a character vector.

## Value

A base data frame with one row per distinct text, in order of first
appearance. For a character vector, the columns are `text` and `n`; for
a data frame, all its columns, with the values of the row where the text
first occurs, followed by `n`.

## Conditions

An error of class `sbert_bad_input` when no non-blank text remains, when
`column` is missing, not found, or given for a character vector, or when
the data frame already has a column `n`.

## See also

[`topic_sizes()`](https://sonsoles.me/sbert/reference/topic_sizes.md) to
weight topic sizes by the counts;
[`clean_corpus()`](https://sonsoles.me/sbert/reference/clean_corpus.md)
to clean the texts first.

## Examples

``` r
dedupe(c("Very good!", "Try again.", "Very good!", NA, "  "))
#>         text n
#> 1 Very good! 2
#> 2 Try again. 1

corpus <- dedupe(feedback_translations, column = "translation")
head(corpus)
#>                                                       feedback
#> 1                                Víš, co znamená o jeden více?
#> 2                   V červeném má být o dva více než v modrém.
#> 3                     Když to není člověk, tak co to může být?
#> 4                                Co znamená všechny za prvním?
#> 5 V šedém rámečku je pět obrázků. Kde je o jeden obrázek méně?
#> 6                              Podle čeho se obrázky střídají?
#>                                                                 translation n
#> 1                                        Do you know what “one more” means? 2
#> 2                     There should be two more in the red than in the blue. 3
#> 3                                   If it’s not a person, what could it be? 2
#> 4                            What does “everyone after the first one” mean? 1
#> 5 There are five pictures in the gray box. Where is there one picture less? 2
#> 6                                            How do the pictures alternate? 1
```
