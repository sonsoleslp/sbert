# Blend segment embeddings with their document context

`blend()` computes context-aware embeddings of segments: it combines
what each segment says beyond its parent document with the direction of
the document itself. A short segment is often ambiguous on its own ("It
was too hard."), and identical segments can occur in different documents
with different meanings; the parent document supplies the missing
context.

Each segment vector `u` is split into the part along its unit-length
document vector `d` and the residual orthogonal to it; the blend keeps
`alpha` of the residual and `1 - alpha` of the document direction,
scaled to unit length: \$\$m = \mathrm{normalize}\left(\alpha \left(u -
(u \cdot d)\\ d\right) + (1 - \alpha)\\ d\right)\$\$ with `u` and `d`
normalized first. `alpha = 0` returns the document vector, `alpha = 1`
only what the segment adds to it. Identical segments from different
documents therefore receive different vectors. A segment that points
exactly along its document receives the document vector.

The result, a matrix with one unit-length row per segment, replaces the
segment embeddings in the `embeddings` argument of
[`topics()`](https://sonsoles.me/sbert/reference/topics.md),
[`representatives()`](https://sonsoles.me/sbert/reference/representatives.md)
and
[predict()](https://sonsoles.me/sbert/reference/predict.sbert_topic_model.md).
To cluster segments by their own meaning alone, pass the plain segment
embeddings from
[`encode()`](https://sonsoles.me/sbert/reference/encode.md) instead.

## Usage

``` r
blend(
  segments,
  documents = NULL,
  model = NULL,
  alpha = 0.5,
  embeddings = NULL,
  document_embeddings = NULL,
  batch_size = 32L
)
```

## Arguments

- segments:

  A data frame from
  [`segment()`](https://sonsoles.me/sbert/reference/segment.md), or any
  data frame with a numeric `document_id` and a `text` column, one row
  per segment.

- documents:

  The character vector of documents that was segmented; `document_id`
  indexes it. Needed unless both embedding matrices are given.

- model:

  A model from
  [`load_model()`](https://sonsoles.me/sbert/reference/load_model.md), a
  pinned model name, or `NULL` (default) for the default model; ignored
  when embeddings are given.

- alpha:

  Weight of the segment's residual, in `[0, 1]` (default 0.5).

- embeddings:

  Segment embeddings, one row per row of `segments`, or `NULL` (default)
  to encode them. Give together with `document_embeddings`.

- document_embeddings:

  Document embeddings, one row per document, or `NULL` (default) to
  encode `documents`.

- batch_size:

  Texts per model call when encoding (default 32).

## Value

A numeric matrix with one unit-length row per row of `segments` and the
columns of the embeddings.

## Conditions

`sbert_bad_input` when only one of `embeddings` and
`document_embeddings` is given, or neither they nor `documents`; when
encoding, the conditions of
[`encode()`](https://sonsoles.me/sbert/reference/encode.md).

## See also

[`segment()`](https://sonsoles.me/sbert/reference/segment.md) for the
segments; [`encode()`](https://sonsoles.me/sbert/reference/encode.md)
for the embeddings;
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) to fit
topics on the blended vectors.

## Examples

``` r
segments <- segment("The model works. It is fast.", level = "sentence")
segment_vectors <- matrix(c(1, 0, 0.6, 0.8), nrow = 2, byrow = TRUE)
document_vector <- matrix(c(0, 1), nrow = 1)
blend(segments, embeddings = segment_vectors,
      document_embeddings = document_vector)
#>           [,1]      [,2]
#> [1,] 0.7071068 0.7071068
#> [2,] 0.5144958 0.8574929

# alpha = 0 returns the document vector for every segment.
blend(segments, alpha = 0, embeddings = segment_vectors,
      document_embeddings = document_vector)
#>      [,1] [,2]
#> [1,]    0    1
#> [2,]    0    1
```
