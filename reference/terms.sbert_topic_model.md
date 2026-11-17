# Compute the terms of each topic

[`terms()`](https://rdrr.io/r/stats/terms.html) computes the ranked
terms of each topic of a fitted model: the words that distinguish its
texts from the texts of the other topics. Class-based TF-IDF
(Grootendorst 2022) treats all the texts of a topic as one document and
weights each term by its frequency in the topic against its frequency
across all topics, so that a word frequent everywhere ranks low and a
word frequent in one topic ranks high.

The terms describe a topic in words and complement its representative
texts. They depend only on the topic assignments and the text, so
[`terms()`](https://rdrr.io/r/stats/terms.html) recomputes them under
any term settings: changing the weighting, the stop words, the number
filters, or stemming does not refit the model or encode anything. Every
argument left `NULL` keeps the value the model was fitted with. Besides
the weight (`score`), each term has its frequency in the topic and its
probability within the topic (`beta`), and `sort_by = "beta"` ranks the
words a topic uses most rather than the most distinctive ones. The
result is a data frame with one row per topic and term.

## Usage

``` r
# S3 method for class 'sbert_topic_model'
terms(
  x,
  n = NULL,
  stop_words = NULL,
  min_term_frequency = NULL,
  min_token_length = NULL,
  weighting = NULL,
  reduce_frequent_words = NULL,
  stem = NULL,
  numbers = NULL,
  roman_numerals = NULL,
  section_numbers = NULL,
  smoothing = 0,
  sort_by = c("score", "beta"),
  ...
)
```

## Arguments

- x:

  A topic model fitted by
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md).

- n:

  Terms per topic; `NULL` (default) uses the model's `n_terms`.

- stop_words:

  Words excluded from the terms; `NULL` (default) uses the model's list.
  See
  [`stop_words()`](https://sonsoles.me/sbert/reference/stop_words.md).

- min_term_frequency:

  Minimum corpus-wide frequency of a term.

- min_token_length:

  Minimum length of a term, in characters.

- weighting:

  Term weighting: `"ctfidf"` or `"bm25"`.

- reduce_frequent_words:

  Whether to take the square root of within-topic frequencies before
  weighting.

- stem:

  Whether to merge inflected forms under one Porter stem (needs the
  SnowballC package).

- numbers, roman_numerals, section_numbers:

  Whether to `"keep"` or `"remove"` digit-only tokens, Roman-numeral
  tokens, and section or list numbering.

- smoothing:

  Additive smoothing of `beta` (default 0). With 0, each topic's `beta`
  over its terms sums to one; a positive value reserves probability for
  the terms a topic does not use.

- sort_by:

  Order of the terms within a topic: `"score"` (default), the
  class-based weight, or `"beta"`, the probability within the topic. `n`
  is applied after ordering.

- ...:

  Ignored.

## Value

A base data frame with one row per topic and term, and columns `topic`,
`label`, `term`, `rank`, `score` (the class-based weight), `frequency`
(count within the topic), and `beta` (the probability of the term within
the topic).

## Conditions

An error of class `sbert_no_terms` when no term passes the filters, and
`sbert_missing_package` for `stem = TRUE` without SnowballC.

## References

Grootendorst, M. (2022). BERTopic: Neural topic modeling with a
class-based TF-IDF procedure. arXiv:2203.05794.

Mendonca, M. and Figueira, A. (2025). Modeling political discourse with
Sentence-BERT and BERTopic. arXiv:2510.22904.

## See also

[`topics()`](https://sonsoles.me/sbert/reference/topics.md);
[`keywords()`](https://sonsoles.me/sbert/reference/keywords.md) for the
keywords of single documents;
[`coherence()`](https://sonsoles.me/sbert/reference/coherence.md) and
[`topic_diversity()`](https://sonsoles.me/sbert/reference/topic_diversity.md),
which evaluate the terms;
[plot()](https://sonsoles.me/sbert/reference/plot.sbert_topic_model.md)
with `type = "terms"`.

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings)
terms(topic_model, n = 3)
#>    topic                                                       label       term
#> 1      1   Where is the cow and the cake? Choose all the pictures...    picture
#> 2      1   Where is the cow and the cake? Choose all the pictures...   pictures
#> 3      1   Where is the cow and the cake? Choose all the pictures...     choose
#> 4      2            All the ones between the cat and the strawberry.       ones
#> 5      2            All the ones between the cat and the strawberry.   broccoli
#> 6      2            All the ones between the cat and the strawberry.      candy
#> 7      3         What does “all the ones between the leaf and the...       mean
#> 8      3         What does “all the ones between the leaf and the...       ones
#> 9      3         What does “all the ones between the leaf and the... strawberry
#> 10     4 Are you sure you have fewer pictures in the red box than...        box
#> 11     4 Are you sure you have fewer pictures in the red box than...        red
#> 12     4 Are you sure you have fewer pictures in the red box than...       blue
#> 13     5      In the top middle box, it means something is in the...      means
#> 14     5      In the top middle box, it means something is in the...     middle
#> 15     5      In the top middle box, it means something is in the...      right
#> 16     6    It is not a person, does not have a hat, and is sitting.       it's
#> 17     6    It is not a person, does not have a hat, and is sitting.     person
#> 18     6    It is not a person, does not have a hat, and is sitting.     animal
#>    rank      score frequency       beta
#> 1     1 0.15812657        99 0.10174717
#> 2     2 0.15734447       130 0.13360740
#> 3     3 0.15707789        89 0.09146968
#> 4     1 0.30963920        82 0.21025641
#> 5     2 0.07420924         9 0.02307692
#> 6     3 0.06596377         8 0.02051282
#> 7     1 0.34359216       130 0.26104418
#> 8     2 0.11237273        38 0.07630522
#> 9     3 0.05446666         9 0.01807229
#> 10    1 0.27236446        32 0.10631229
#> 11    2 0.24904937        27 0.08970100
#> 12    3 0.23982532        26 0.08637874
#> 13    1 0.31653087        19 0.11111111
#> 14    2 0.18182559        10 0.05847953
#> 15    3 0.15309964        10 0.05847953
#> 16    1 0.57814172        22 0.20560748
#> 17    2 0.55210406        19 0.17757009
#> 18    3 0.42837319        14 0.13084112
terms(topic_model, n = 3, weighting = "bm25", sort_by = "beta")
#>    topic                                                       label     term
#> 1      1   Where is the cow and the cake? Choose all the pictures... pictures
#> 2      1   Where is the cow and the cake? Choose all the pictures...  picture
#> 3      1   Where is the cow and the cake? Choose all the pictures...   choose
#> 4      2            All the ones between the cat and the strawberry.     ones
#> 5      2            All the ones between the cat and the strawberry. broccoli
#> 6      2            All the ones between the cat and the strawberry.    candy
#> 7      3         What does “all the ones between the leaf and the...     mean
#> 8      3         What does “all the ones between the leaf and the...     ones
#> 9      3         What does “all the ones between the leaf and the... pictures
#> 10     4 Are you sure you have fewer pictures in the red box than... pictures
#> 11     4 Are you sure you have fewer pictures in the red box than...      box
#> 12     4 Are you sure you have fewer pictures in the red box than...      one
#> 13     5      In the top middle box, it means something is in the...    means
#> 14     5      In the top middle box, it means something is in the...     mean
#> 15     5      In the top middle box, it means something is in the...   middle
#> 16     6    It is not a person, does not have a hat, and is sitting.     it's
#> 17     6    It is not a person, does not have a hat, and is sitting.   person
#> 18     6    It is not a person, does not have a hat, and is sitting.   animal
#>    rank      score frequency       beta
#> 1     1 0.10811433       130 0.13360740
#> 2     2 0.13374923        99 0.10174717
#> 3     3 0.13868736        89 0.09146968
#> 4     1 0.25452287        82 0.21025641
#> 5     2 0.07265190         9 0.02307692
#> 6     3 0.06457947         8 0.02051282
#> 7     1 0.26186737       130 0.26104418
#> 8     2 0.09237019        38 0.07630522
#> 9     3 0.02599821        16 0.03212851
#> 10    1 0.09409235        35 0.11627907
#> 11    2 0.26253720        32 0.10631229
#> 12    3 0.19874420        30 0.09966777
#> 13    1 0.30797460        19 0.11111111
#> 14    2 0.08799592        15 0.08771930
#> 15    3 0.17777985        10 0.05847953
#> 16    1 0.56198797        22 0.20560748
#> 17    2 0.53981937        19 0.17757009
#> 18    3 0.41961918        14 0.13084112
```
