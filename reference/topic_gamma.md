# Document-Topic Distributions from Segment Assignments

Computes \`gamma\`, the distribution of every document over the fitted
topics, by segmenting each document with \[segment()\], assigning each
segment to its nearest topic centroid, and normalizing the per-document
segment counts. This yields parameter-free mixed topic_membership: a
document that discusses two topics in different sentences receives
weight on both, which the single-embedding hard assignment cannot
express.

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
  sort_by_length = FALSE
)
```

## Arguments

- object:

  A fitted \[topics()\] model.

- text:

  Either \`NULL\`, a character vector of documents (segmented here at
  \`level\`), or the data frame returned by \[segment()\] (used as-is).
  \`NULL\` — the default — works for a model fitted with \`segment =
  "sentence"\`, \`"clause"\`, or \`"phrase"\`: its own segments and
  their topic assignments are already stored, so the mixture of every
  fitted document comes back with no encoding at all. Passing your own
  segmentation keeps every segment option in \[segment()\] and lets you
  reuse one set of segment embeddings across this and other verbs. A
  data frame must have \`document_id\` and \`text\` columns; \`gamma\`
  is then computed per \`document_id\`.

- model:

  A loaded \[sbert_model\]\[load_model()\], a pinned model name, or
  \`NULL\` for the default model, used to embed the segments; ignored
  when \`embeddings\` are supplied.

- embeddings:

  Optional precomputed numeric matrix of segment embeddings, one row per
  segment. When \`text\` is raw documents the rows must align with
  \`segment(text, level = level)\`; when \`text\` is a \[segment()\]
  data frame they must align with its rows — which is automatic, since
  no re-segmentation happens.

- level:

  Segmentation granularity passed to \[segment()\] when \`text\` is a
  character vector: \`"clause"\`, \`"sentence"\`, or \`"phrase"\`.
  \`NULL\` (the default) uses the fitted segmentation — level,
  \`max_tokens\`, \`merge_below\`, and \`min_content\` — for a segmented
  model, so new documents are cut exactly as the fitted ones were, and
  \`"clause"\` for a document-level model. Ignored when \`text\` is
  already a \[segment()\] data frame.

- batch_size:

  Batch size passed to \[encode()\] when \`model\` is used.

- cores:

  Number of forked worker processes used to split documents into
  segments (passed to \[segment()\]). Default \`1\`. Segmenting a large
  corpus dominates the non-encoding cost, so \`cores \> 1\` can
  noticeably speed up sentence- and clause-level gamma; the result is
  identical for any count. Encoding itself is parallelized separately,
  via \`load_model(threads =)\`. Ignored when \`text\` is already a
  \[segment()\] data frame.

- dedupe_segments:

  When \`TRUE\`, encode each distinct segment only once and expand the
  embeddings back by position, rather than encoding every occurrence.
  Real corpora are often close to half duplicate segments, so this can
  roughly halve encoding time (the dominant cost). Only applies when
  \`embeddings\` are not supplied. Assignments match encoding every
  occurrence up to the ~1e-7 floating-point effect of encoding a smaller
  batched set, which can flip a rare borderline segment; it is therefore
  opt-in and off by default. With the static \`potion-base-8M\` model,
  encoding has no batch effect and the result is identical.

- sort_by_length:

  Passed to \[encode()\]. Groups segments of similar length into the
  same batch so the model computes over less padding. Segment lengths
  vary far more than document lengths — at clause level 60.1 token work
  is padding in input order against 1.6 the single largest saving
  available on this verb, measured at 1.9x. Off by default for the same
  ~1e-7 reason as \`dedupe_segments\`.

## Value

A base data frame with one row per document-topic pair and columns
\`document_id\`, \`topic\`, \`gamma\`, and \`n_segments\`. \`gamma\`
sums to 1 within each document; documents with no segments contribute no
rows.

## Examples

``` r
text <- c(
  "Cats chase mice", "Dogs chase balls",
  "Stocks and bonds trade", "Markets price shares"
)
embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
fitted <- topics(text, 2, embeddings = embeddings)
mixed <- "Cats chase mice. Stocks and bonds trade."
segment_embeddings <- rbind(c(1, 0), c(0, 1))
topic_gamma(fitted, mixed, embeddings = segment_embeddings)
#>   document_id topic gamma n_segments
#> 1           1     1   0.5          2
#> 2           1     2   0.5          2

# Segment once (with any options), reuse the segments and their embeddings:
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
```
