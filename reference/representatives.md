# Select representative texts for each topic

`representatives()` selects representative texts for each topic of a
fitted model: it ranks the units of each topic and returns the first
`n`. A topic in an embedding model is a region of meaning, and it is
read most directly from the texts it contains.

Each unit is assigned to the topic whose unit-length center has the
highest cosine similarity with it. The texts closest to a topic's center
are typical of it but tend to be long, because long texts resemble the
average of many texts; texts that are clearly about one topic and no
other are usually more telling. With `rank = "margin"`, the default,
units are ranked by their margin: the cosine distance to the
second-nearest center minus the distance to their own. With
`rank = "distance"` they are ranked by closeness to their own center.
Ties go to the shorter text; repeated texts and texts without a word of
two or more letters are skipped. By default the units the model was
fitted on are ranked, from their stored embeddings; given `text`, any
candidate texts are. The result is a data frame with one row per
selected text, ordered by topic and rank.

Because the assignment uses cosine similarity to the unit-length
centers, while
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) fits Lloyd's
k-means (squared Euclidean distance to the raw means of the normalized
embeddings), a few fitted units on topic boundaries can be ranked under
a different topic from the one they were fitted to. The representatives
stored at fitting time, shown by
`as.data.frame(fit, what = "representatives")`, are the units of each
fitted topic closest to its center. For topic words use
[terms()](https://sonsoles.me/sbert/reference/terms.sbert_topic_model.md)
or [`keywords()`](https://sonsoles.me/sbert/reference/keywords.md).

## Usage

``` r
representatives(
  object,
  text = NULL,
  model = NULL,
  embeddings = NULL,
  n = 3L,
  rank = c("margin", "distance"),
  batch_size = 32L
)
```

## Arguments

- object:

  A fitted model from
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md).

- text:

  Character vector of candidate texts, or `NULL` (default) for the
  documents or segments the model was fitted on.

- model:

  A model from
  [`load_model()`](https://sonsoles.me/sbert/reference/load_model.md), a
  pinned model name, or `NULL` (default) for the default model, used to
  embed `text`; ignored when `embeddings` are given.

- embeddings:

  Numeric matrix with one row per candidate, or `NULL` (default): the
  stored embeddings when `text` is `NULL`, else encode `text`.

- n:

  Number of texts per topic (default 3).

- rank:

  `"margin"` (default) or `"distance"`.

- batch_size:

  Texts per model call when encoding (default 32).

## Value

A base data frame with one row per selected text and columns `topic`,
`rank`, `text`, `distance` (cosine distance to the unit's own center),
and `margin`, ordered by topic and rank. When the fitted units are
ranked, `document_id` (and `segment`, for a segmented model) follow
`rank`. Topics without units have no rows.

## Conditions

`sbert_no_embeddings` when `text` is `NULL` and the model stores no
embeddings; `sbert_dimension_mismatch` when the embeddings have a
different number of columns from the fitted model; `sbert_bad_input`
when both `model` and `embeddings` are given or `embeddings` has the
wrong number of rows; when encoding, the conditions of
[`encode()`](https://sonsoles.me/sbert/reference/encode.md).

## See also

[terms()](https://sonsoles.me/sbert/reference/terms.sbert_topic_model.md)
and [`keywords()`](https://sonsoles.me/sbert/reference/keywords.md) for
topic words;
[`name_topics()`](https://sonsoles.me/sbert/reference/name_topics.md) to
label topics; `plot(fit, type = "representatives")` to draw them;
[`topic_membership()`](https://sonsoles.me/sbert/reference/topic_membership.md)
for graded membership.

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings)
representatives(topic_model, n = 2)
#>    topic rank document_id
#> 1      1    1         169
#> 2      1    2         559
#> 3      2    1         246
#> 4      2    2         202
#> 5      3    1         482
#> 6      3    2         227
#> 7      4    1          10
#> 8      4    2         475
#> 9      5    1          72
#> 10     5    2         325
#> 11     6    1         380
#> 12     6    2         166
#>                                                                                         text
#> 1          Where is the cat and the princess? Choose all the pictures that are between them.
#> 2           Where is the cup and the balloon? Select all the pictures that are between them.
#> 3                                               All the ones between the grape and the tram.
#> 4                                                  All the ones between the fly and the cat.
#> 5                                   What does “all between the plant and the princess” mean?
#> 6                            What does “all the ones between the leaf and the unicorn” mean?
#> 7                             There should be two fewer in the red one than in the blue one.
#> 8                             There should be two fewer in the blue one than in the red one.
#> 9                                “Sitting” means your bottom is on the ground or on a chair.
#> 10 To be on the grass means to stand or lie down on the soft green ground where grass grows.
#> 11                          This is not a person, it doesn’t have a hat, and it is standing.
#> 12                                                If it’s an animal, then it’s not a person.
#>     distance    margin
#> 1  0.2342085 0.3007396
#> 2  0.2850857 0.2922610
#> 3  0.2641428 0.3146493
#> 4  0.2080425 0.3134329
#> 5  0.2518425 0.3209479
#> 6  0.1835523 0.2937963
#> 7  0.1805440 0.5532961
#> 8  0.1838668 0.5515990
#> 9  0.4359726 0.2885570
#> 10 0.4951715 0.2777950
#> 11 0.1748397 0.5275012
#> 12 0.2196640 0.5096887
representatives(topic_model, n = 2, rank = "distance")
#>    topic rank document_id
#> 1      1    1         118
#> 2      1    2         474
#> 3      2    1         277
#> 4      2    2         237
#> 5      3    1         227
#> 6      3    2          87
#> 7      4    1         218
#> 8      4    2          62
#> 9      5    1         364
#> 10     5    2          28
#> 11     6    1         366
#> 12     6    2          31
#>                                                                                                              text
#> 1                                   Where is the cow and the cake? Choose all the pictures that are between them.
#> 2                          Where is the second and the fourth picture? Choose the pictures that are between them.
#> 3                                                                All the ones between the cat and the strawberry.
#> 4                                                                    All the ones between the piglet and the dog.
#> 5                                                 What does “all the ones between the leaf and the unicorn” mean?
#> 6                                               What does “all the ones between the dog and the strawberry” mean?
#> 7                                       Are you sure you have fewer pictures in the red box than in the blue one?
#> 8  It’s not enough to just have more—there must be exactly two more pictures in the red box than in the blue box.
#> 9                                          In the top middle box, it means something is in the middle at the top.
#> 10                                                             Do you know what “at the top in the middle” means?
#> 11                                                       It is not a person, does not have a hat, and is sitting.
#> 12                                                             It’s not a person, it has a hat, and it’s sitting.
#>     distance    margin
#> 1  0.2023061 0.2775969
#> 2  0.2197193 0.1858180
#> 3  0.1748744 0.2755350
#> 4  0.1755226 0.3043248
#> 5  0.1835523 0.2937963
#> 6  0.1931901 0.2867852
#> 7  0.1413591 0.4557122
#> 8  0.1472757 0.4829235
#> 9  0.2878022 0.1639653
#> 10 0.3234709 0.1467469
#> 11 0.1564578 0.4992959
#> 12 0.1602140 0.4720671

# Rank new candidate texts, giving their embeddings.
text <- c(
  "Cats chase mice", "Dogs chase balls",
  "Stocks and bonds trade", "Markets price shares"
)
embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
toy_model <- topics(text, 2, embeddings = embeddings)
representatives(
  toy_model,
  c("kittens pounce", "bond yields", "pets and prices"),
  embeddings = rbind(c(1, 0.1), c(0.1, 1), c(0.7, 0.7)),
  n = 1
)
#>   topic rank           text     distance    margin
#> 1     1    1 kittens pounce 0.0009828586 0.8446397
#> 2     2    1    bond yields 0.0009828586 0.8446397
```
