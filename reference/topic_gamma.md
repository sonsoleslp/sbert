# Compute document-topic mixtures from segments

`topic_gamma()` returns, for each document, its mixture over topics: the
share of its segments assigned to each topic, the document-topic
distribution conventionally called gamma. A document that discusses two
subjects in different sentences belongs partly to two topics, which a
single embedding of the whole document cannot express; counting the
topics of its segments gives the mixture without any additional
parameter.

For a model fitted on segments (`segment =` in
[`topics()`](https://sonsoles.me/sbert/reference/topics.md)) and
`text = NULL`, it counts the fitted assignments, with no encoding.
Otherwise it segments the given documents (with the fitted segmentation,
or at `level`), or takes a
[`segment()`](https://sonsoles.me/sbert/reference/segment.md) data frame
as it is, embeds the segments, and assigns each to the topic whose
unit-length center has the highest cosine similarity, as
[predict()](https://sonsoles.me/sbert/reference/predict.sbert_topic_model.md)
does. The result is a data frame with one row per document-topic pair.

The fitted assignments come from Lloyd's k-means in
[`topics()`](https://sonsoles.me/sbert/reference/topics.md), which uses
squared Euclidean distance to the raw means of the normalized
embeddings; for a few segments on topic boundaries this can differ from
the cosine-similarity rule applied to new text. For graded membership of
single units, use
[`topic_membership()`](https://sonsoles.me/sbert/reference/topic_membership.md).

## Usage

``` r
topic_gamma(
  object,
  text = NULL,
  model = NULL,
  embeddings = NULL,
  level = NULL,
  batch_size = 32L,
  cores = 1L,
  dedupe_segments = FALSE,
  sort_by_length = FALSE,
  top = NULL
)
```

## Arguments

- object:

  A fitted model from
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md).

- text:

  `NULL` (default) for the fitted segments of a segmented model; a
  character vector of documents to segment; or a data frame from
  [`segment()`](https://sonsoles.me/sbert/reference/segment.md) (columns
  `document_id` and `text`), used as it is.

- model:

  A model from
  [`load_model()`](https://sonsoles.me/sbert/reference/load_model.md), a
  pinned model name, or `NULL` (default) for the default model, used to
  embed the segments; ignored when `embeddings` are given.

- embeddings:

  Numeric matrix of segment embeddings, one row per segment of `text`
  (in the order of
  [`segment()`](https://sonsoles.me/sbert/reference/segment.md)), or
  `NULL` (default) to encode them.

- level:

  `"clause"`, `"sentence"`, or `"phrase"` for segmenting a character
  `text`, or `NULL` (default) for the fitted segmentation of a segmented
  model and `"clause"` otherwise.

- batch_size:

  Texts per model call when encoding (default 32).

- cores:

  Number of forked processes for segmenting (default 1), passed to
  [`segment()`](https://sonsoles.me/sbert/reference/segment.md); the
  result does not depend on it.

- dedupe_segments:

  Encode each distinct segment once (default `FALSE`). Saves time on
  corpora with many repeated segments; the values can differ from
  encoding every occurrence by floating-point rounding.

- sort_by_length:

  Batch segments of similar length together when encoding (default
  `FALSE`); see
  [`encode()`](https://sonsoles.me/sbert/reference/encode.md).

- top:

  `NULL` (default) for every topic of every document, or a whole number:
  each document's `top` largest non-zero shares.

## Value

A base data frame with one row per document-topic pair and columns
`document_id`, `topic`, `gamma` (the share of the document's segments in
the topic), and `n_segments`. `gamma` sums to one within each document;
documents without segments have no rows. With `top`, only the largest
non-zero shares, ordered by document and share, with a `rank` column
after `document_id`.

## Conditions

`sbert_bad_input` when `text` is `NULL` for a model fitted on whole
documents, when `model`, `embeddings` or `level` is given without
`text`, when a data frame lacks `document_id` or `text`, when no segment
results, or when `embeddings` has the wrong number of rows;
`sbert_dimension_mismatch` when the embeddings have a different number
of columns from the fitted model; when encoding, the conditions of
[`encode()`](https://sonsoles.me/sbert/reference/encode.md).

## See also

[`segment()`](https://sonsoles.me/sbert/reference/segment.md) for the
segments;
[`topic_membership()`](https://sonsoles.me/sbert/reference/topic_membership.md)
for graded membership;
[predict()](https://sonsoles.me/sbert/reference/predict.sbert_topic_model.md)
for single assignments;
[`topic_sizes()`](https://sonsoles.me/sbert/reference/topic_sizes.md)
for topic totals.

## Examples

``` r
text <- c(
  "Cats chase mice", "Dogs chase balls",
  "Stocks and bonds trade", "Markets price shares"
)
embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
fitted <- topics(text, 2, embeddings = embeddings)

# A new document with one sentence on each topic.
mixed <- "Cats chase mice. Stocks and bonds trade."
segment_embeddings <- rbind(c(1, 0), c(0, 1))
topic_gamma(fitted, mixed, embeddings = segment_embeddings)
#>   document_id topic gamma n_segments
#> 1           1     1   0.5          2
#> 2           1     2   0.5          2

# Segment once, then reuse the segments and their embeddings.
segments <- segment(mixed, level = "sentence")
topic_gamma(fitted, segments, embeddings = segment_embeddings)
#>   document_id topic gamma n_segments
#> 1           1     1   0.5          2
#> 2           1     2   0.5          2

# A model fitted on sentences already holds its segments: no text needed.
sentence_model <- topics(
  c(mixed, "Dogs chase balls. Markets price shares."), 2,
  segment = "sentence",
  embeddings = rbind(c(1, 0), c(0, 1), c(0.9, 0.1), c(0.1, 0.9))
)
topic_gamma(sentence_model)
#>   document_id topic gamma n_segments
#> 1           1     1   0.5          2
#> 2           1     2   0.5          2
#> 3           2     1   0.5          2
#> 4           2     2   0.5          2
topic_gamma(sentence_model, top = 1)
#>   document_id rank topic gamma n_segments
#> 1           1    1     1   0.5          2
#> 2           2    1     1   0.5          2
```
