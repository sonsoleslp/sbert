# Get and adjust the stop-word list

`stop_words()` returns the built-in English list of stop words, extended
with `add` or reduced with `remove`. Stop words are frequent function
words, such as articles, pronouns, and prepositions, that occur in texts
of every topic and so say little about what distinguishes one topic from
another; excluding them lets the terms that describe a topic be its
content words.

Adding words that every text of a corpus shares, such as the name of the
course or the disease a corpus is about, removes them from the topic
terms as well. The list filters only the terms and keyword candidates;
the text that is embedded is unchanged.

The result is passed as `stop_words =` to
[`topics()`](https://sonsoles.me/sbert/reference/topics.md),
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md),
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md),
[terms()](https://sonsoles.me/sbert/reference/terms.sbert_topic_model.md),
or [`keywords()`](https://sonsoles.me/sbert/reference/keywords.md). A
character vector of one's own replaces the list, and
[`character()`](https://rdrr.io/r/base/character.html) turns the filter
off.

## Usage

``` r
stop_words(language = "en", add = NULL, remove = NULL)
```

## Arguments

- language:

  Language of the list. Only `"en"` (default) is available.

- add:

  Words to add to the list, matched case-insensitively. Default `NULL`.

- remove:

  Words to remove from the list. Default `NULL`.

## Value

A character vector of lower-case stop words, sorted.

## Conditions

An error of class `sbert_bad_input` when `language` is not `"en"`.

## See also

[`topics()`](https://sonsoles.me/sbert/reference/topics.md) and
[terms()](https://sonsoles.me/sbert/reference/terms.sbert_topic_model.md),
which use the list;
[`clean_corpus()`](https://sonsoles.me/sbert/reference/clean_corpus.md)
to clean the text itself.

## Examples

``` r
head(stop_words())
#> [1] "a"       "about"   "after"   "again"   "against" "all"    

# Keep the defaults, add two domain words, and drop one entry
custom <- stop_words(add = c("try", "again"), remove = "against")

corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings, stop_words = custom)
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
#> 1     1 0.15819045        99 0.10185185
#> 2     2 0.15739251       130 0.13374486
#> 3     3 0.15714708        89 0.09156379
#> 4     1 0.30943987        82 0.21025641
#> 5     2 0.07418199         9 0.02307692
#> 6     3 0.06593954         8 0.02051282
#> 7     1 0.34335717       130 0.26104418
#> 8     2 0.11230039        38 0.07630522
#> 9     3 0.05444551         9 0.01807229
#> 10    1 0.27315124        32 0.10666667
#> 11    2 0.24977571        27 0.09000000
#> 12    3 0.24052476        26 0.08666667
#> 13    1 0.31826329        19 0.11176471
#> 14    2 0.18282602        10 0.05882353
#> 15    3 0.15393314        10 0.05882353
#> 16    1 0.57790397        22 0.20560748
#> 17    2 0.55189536        19 0.17757009
#> 18    3 0.42821832        14 0.13084112
```
