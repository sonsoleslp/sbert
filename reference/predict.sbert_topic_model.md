# Assign new documents to fitted topics

[`predict()`](https://rdrr.io/r/stats/predict.html) assigns new
documents to the topics of a fitted model without fitting again: it
embeds the new texts (or takes their embeddings) and assigns each to the
topic whose center has the highest cosine similarity with it, after
scaling the centers to unit length. A fitted topic model defines its
topics by their centers in the embedding space, so new texts (later
responses, a held-out sample, another cohort) can be placed in the same
topics, which keeps the topics and their labels fixed and makes the
counts comparable across samples.

`distance` is one minus that similarity. A model fitted on segments
splits the new texts with the same segmentation settings first and
assigns each segment. The fitted model is not changed. The result is a
data frame with one row per document, or per segment for a segmented
model.

This rule differs from the one that formed the topics:
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) fits Lloyd's
k-means, which assigns each unit to the nearest raw mean of the
normalized embeddings by squared Euclidean distance, and those means are
shorter than unit length by different amounts. On the units a model was
fitted on, the two rules agree for almost every unit but can differ for
a few units on topic boundaries, so
[`predict()`](https://rdrr.io/r/stats/predict.html) on the training
texts need not reproduce the fitted topics exactly; read the fitted
assignment with `as.data.frame(fit, what = "documents")`. For graded
rather than single assignments use
[`topic_membership()`](https://sonsoles.me/sbert/reference/topic_membership.md);
for the topic mixture of long documents,
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md).

## Usage

``` r
# S3 method for class 'sbert_topic_model'
predict(object, text, model = NULL, embeddings = NULL, batch_size = 32L, ...)
```

## Arguments

- object:

  A fitted model from
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md).

- text:

  Character vector of new documents.

- model:

  A model from
  [`load_model()`](https://sonsoles.me/sbert/reference/load_model.md), a
  pinned model name, or `NULL` (default) for the default model, used to
  embed `text`; ignored when `embeddings` are given. Its dimension must
  match the fitted model.

- embeddings:

  Numeric matrix with one row per document (one per segment for a
  segmented model), or `NULL` (default) to encode `text`.

- batch_size:

  Texts per model call when encoding (default 32).

- ...:

  Unused.

## Value

A base data frame with one row per document and columns `document_id`,
`document_name`, `text`, `topic`, `label` (the fitted topic label), and
`distance` (cosine distance to the assigned center). For a segmented
model, one row per segment, with `segment` (position in the document)
after `document_name`.

## Conditions

`sbert_dimension_mismatch` when the embeddings have a different number
of columns from the fitted model; `sbert_bad_input` when both `model`
and `embeddings` are given, when `embeddings` has the wrong number of
rows or non-finite values or a zero row, or when segmentation yields no
segment; when encoding, the conditions of
[`encode()`](https://sonsoles.me/sbert/reference/encode.md).

## See also

[`topics()`](https://sonsoles.me/sbert/reference/topics.md) for the fit;
[`topic_membership()`](https://sonsoles.me/sbert/reference/topic_membership.md)
for graded membership;
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
for document mixtures;
[`representatives()`](https://sonsoles.me/sbert/reference/representatives.md)
for the clearest examples of each topic.

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings)

# Assign three messages, giving their precomputed embeddings.
new_messages <- head(corpus, 3)
with(new_messages,
     predict(topic_model, translation,
             embeddings = head(feedback_embeddings, 3)))
#>   document_id document_name
#> 1           1              
#> 2           2              
#> 3           3              
#>                                                    text topic
#> 1                    Do you know what “one more” means?     3
#> 2 There should be two more in the red than in the blue.     4
#> 3               If it’s not a person, what could it be?     6
#>                                                         label  distance
#> 1         What does “all the ones between the leaf and the... 0.5466974
#> 2 Are you sure you have fewer pictures in the red box than... 0.2167227
#> 3    It is not a person, does not have a hat, and is sitting. 0.2611759

# A small model on toy two-dimensional embeddings.
text <- c(
  "Cats chase mice", "Dogs chase balls",
  "Stocks and bonds trade", "Markets price shares"
)
embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
toy_model <- topics(text, 2, embeddings = embeddings)
predict(toy_model, "Bulls and bears move markets",
        embeddings = rbind(c(0.2, 0.8)))
#>   document_id document_name                         text topic
#> 1           1               Bulls and bears move markets     2
#>                    label   distance
#> 1 Stocks and bonds trade 0.01792973

# \donttest{
if (interactive()) {
  predict(topic_model, c("The pictures were too small.",
                         "I liked the counting game."))
}
# }
```
