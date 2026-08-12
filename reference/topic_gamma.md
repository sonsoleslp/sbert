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
  text,
  model = NULL,
  embeddings = NULL,
  level = c("clause", "sentence", "phrase"),
  batch_size = 32L,
  cores = 1L,
  dedupe_segments = FALSE
)
```

## Arguments

- object:

  A fitted \[topics()\] model.

- text:

  Character vector of documents.

- model:

  A loaded \[sbert_model\]\[load_model()\], a pinned model name, or
  \`NULL\` for the default model, used to embed the segments; ignored
  when \`embeddings\` are supplied.

- embeddings:

  Optional precomputed numeric matrix of segment embeddings whose rows
  align with \`segment(text, level = level)\`.

- level:

  Segmentation granularity passed to \[segment()\].

- batch_size:

  Batch size passed to \[encode()\] when \`model\` is used.

- cores:

  Number of forked worker processes used to split documents into
  segments (passed to \[segment()\]). Default \`1\`. Segmenting a large
  corpus dominates the non-encoding cost, so \`cores \> 1\` can
  noticeably speed up sentence- and clause-level gamma; the result is
  identical for any count. Encoding itself is parallelized separately,
  via \`load_model(threads =)\`.

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
```
