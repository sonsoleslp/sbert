# Split documents into sentences, clauses, or phrases

`segment()` splits documents into sentences, clauses, or phrases by
deterministic rules, with no model involved, so the result is
reproducible and needs no download. A long document usually discusses
several things, and one embedding of the whole document averages them;
shorter units can each be embedded and assigned to a topic on their own,
so that a document can be described as a mixture of topics, and each
unit stays within the input length of the model.

The `"sentence"` level splits at `.`, `?` and `!`, protecting the
periods of abbreviations (see
[`abbreviations()`](https://sonsoles.me/sbert/reference/abbreviations.md)),
decimal numbers and parenthetical remarks. The `"clause"` level, the
default, also splits at `;`, `:`, spaced dashes, and subordinating words
such as "which", "where" or "in terms of", while comma-separated lists
stay whole. The `"phrase"` level also splits at commas. Quotes, dashes
and whitespace are normalized first; letter case is kept. Optional steps
merge very short segments into their neighbors, cap segment length at a
number of words or model tokens, and drop segments with little
alphabetic content, such as citation fragments. The result is a data
frame with one row per segment.

The topic verbs segment documents themselves through their `segment`
argument (see
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) and
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md));
call `segment()` directly to inspect the units, or to reuse one
segmentation and its embeddings in
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
and [`blend()`](https://sonsoles.me/sbert/reference/blend.md).

## Usage

``` r
segment(
  text,
  level = c("clause", "sentence", "phrase"),
  merge_below = 0L,
  abbreviations = default_abbreviations(),
  cores = 1L,
  max_tokens = NULL,
  model = NULL,
  min_content = 0
)
```

## Arguments

- text:

  Character vector of documents. Names are carried into the
  `document_name` column.

- level:

  `"clause"` (default), `"sentence"`, or `"phrase"`.

- merge_below:

  Join segments shorter than this many words to a neighbor; `0`
  (default) keeps every segment as split.

- abbreviations:

  Abbreviations, each ending in a period, whose period never ends a
  sentence (default
  [`abbreviations()`](https://sonsoles.me/sbert/reference/abbreviations.md));
  matched ignoring case.

- cores:

  Number of forked processes used to split documents (default 1).
  Ignored on Windows and for small inputs; the result does not depend on
  it.

- max_tokens:

  Maximum length of a segment, or `NULL` (default) for no limit. A
  longer segment is split again at clause words, `;`, `:`, dashes or
  commas, or, failing those, before a function word near the limit.
  Length is counted in words, or in the tokens of `model` when one is
  given; a tokenizer yields more tokens than words, so a word limit
  should sit below the model's token limit.

- model:

  `NULL` (default), or a model from
  [`load_model()`](https://sonsoles.me/sbert/reference/load_model.md)
  whose tokenizer counts the length for `max_tokens`. Requires
  `max_tokens`; splitting then runs in one process.

- min_content:

  Minimum share of alphabetic content, between 0 and 1, for a segment to
  be kept (see
  [`content_ratio()`](https://sonsoles.me/sbert/reference/content_ratio.md));
  `0` (default) keeps every segment.

## Value

A base data frame with one row per segment and columns `document_id`
(position of the document in `text`), `document_name` (its name, or
`""`), `segment` (position within the document), and `text`. Blank
documents contribute no rows.

## Conditions

`sbert_bad_input` when `model` is given without `max_tokens`.

## See also

[`abbreviations()`](https://sonsoles.me/sbert/reference/abbreviations.md)
for the protected abbreviations;
[`content_ratio()`](https://sonsoles.me/sbert/reference/content_ratio.md)
for `min_content`;
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) and
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md),
which segment through their `segment` argument;
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
and [`blend()`](https://sonsoles.me/sbert/reference/blend.md), which
take this data frame.

## Examples

``` r
feedback <- c(
  first = paste("The task was clear. I liked the colors, the sounds",
                "and the pictures, which were funny."),
  second = "Too hard; I did not understand the question."
)
segment(feedback)
#>   document_id document_name segment
#> 1           1         first       1
#> 2           1         first       2
#> 3           1         first       3
#> 4           2        second       1
#> 5           2        second       2
#>                                               text
#> 1                              The task was clear.
#> 2 I liked the colors, the sounds and the pictures,
#> 3                                which were funny.
#> 4                                        Too hard;
#> 5               I did not understand the question.
segment(feedback, level = "sentence")
#>   document_id document_name segment
#> 1           1         first       1
#> 2           1         first       2
#> 3           2        second       1
#>                                                                 text
#> 1                                                The task was clear.
#> 2 I liked the colors, the sounds and the pictures, which were funny.
#> 3                       Too hard; I did not understand the question.
segment(feedback, level = "phrase")
#>   document_id document_name segment                               text
#> 1           1         first       1                The task was clear.
#> 2           1         first       2                I liked the colors,
#> 3           1         first       3       the sounds and the pictures,
#> 4           1         first       4                  which were funny.
#> 5           2        second       1                          Too hard;
#> 6           2        second       2 I did not understand the question.

# Abbreviation and decimal periods do not end a sentence.
segment("See Fig. 3 for details. The mean was 2.5 points.",
        level = "sentence")
#>   document_id document_name segment                     text
#> 1           1                     1  See Fig. 3 for details.
#> 2           1                     2 The mean was 2.5 points.
```
