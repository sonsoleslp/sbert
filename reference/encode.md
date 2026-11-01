# Encode Text with Sentence-BERT

Turns each text into one embedding: a vector in which texts with similar
meaning lie close together. Encoding is the step every topic workflow
starts from and by far its most expensive one, so encode once and pass
the matrix to the `embeddings` argument of
[`topics()`](https://sonsoles.me/sbert/reference/topics.md),
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md),
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md),
and the inference verbs. Each text is tokenized with the model's own
tokenizer, truncated to the model's maximum length, run through the ONNX
graph, pooled with
[`pool()`](https://sonsoles.me/sbert/reference/pool.md), and by default
L2-normalized. The static `potion-base-8M` model instead averages
looked-up token vectors, with no ONNX Runtime involved.

## Usage

``` r
encode(
  text,
  model = NULL,
  batch_size = 32L,
  normalize = TRUE,
  prefix = NULL,
  sort_by_length = FALSE,
  cache = NULL
)
```

## Arguments

- text:

  Character vector of sentences. Empty strings are supported; missing
  values are rejected.

- model:

  A loaded
  [sbert_model](https://sonsoles.me/sbert/reference/load_model.md), the
  name of a pinned model from
  [`models()`](https://sonsoles.me/sbert/reference/models.md), or `NULL`
  for the default `all-MiniLM-L6-v2`. Names are loaded lazily and kept
  in a session cache; the first use of a not-yet-installed model offers
  a one-time verified download (interactive prompt, or
  `options(sbert.download = TRUE)` in scripts).

- batch_size:

  Positive number of sentences processed per ONNX call.

- normalize:

  Whether to return row-wise L2-normalized embeddings.

- prefix:

  Text prepended to every input before tokenization. `NULL` (default)
  uses the model's pinned prefix (for example `"query: "` for E5 models,
  which require one); `""` disables prefixing.

- sort_by_length:

  When `TRUE`, group inputs of similar length into the same batch before
  encoding and restore the original order afterwards. Sequences in a
  batch are padded to the longest member, so mixed-length input makes
  the model compute over padding: on clause-level segments 60.1% of
  token work is padding in input order against 1.6% when sorted,
  measured at 1.9x faster end to end. Whole documents of similar length
  gain little (1.1x). Off by default because regrouping changes batch
  composition, which moves embeddings by around 1e-7 — enough to flip a
  rare borderline topic assignment, the same trade-off as
  `dedupe_segments` in
  [`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md).
  Row order of the result is unaffected.

- cache:

  Optional path to an embedding cache file. When supplied, every
  document is looked up by a SHA-256 digest of its own text together
  with the model identity, revision, dimension, maximum length, pooling
  method and `normalize` setting; only documents with no matching entry
  are encoded, and the file is updated with whatever was newly computed.
  Corpora are usually edited rather than replaced — a few records
  corrected, a year appended, rows reordered — and encoding is about 97%
  of the cost of a topic workflow, so reuse dominates. Changing 38
  documents of 3,847 cost 0.59 s against 57 s to re-encode the corpus.
  Repeated documents within a single call are also encoded once (177 of
  the 3,847 bundled `covid` abstracts repeat an earlier one).

  The key deliberately excludes `batch_size` and `sort_by_length`, which
  shift embeddings by around 1e-7 through batch composition alone.
  Cached values are therefore stable to whatever computed them first
  rather than bit-identical to a fresh encode under different batching —
  the same trade-off as `sort_by_length` itself. A cache that cannot be
  read, or that was written for a different embedding dimension, is
  discarded with a warning and rebuilt rather than trusted.

## Value

A numeric matrix with one row per input, in input order, and one column
per embedding dimension of the model (for example 384 for
`all-MiniLM-L6-v2`; see
[`models()`](https://sonsoles.me/sbert/reference/models.md)).

## Examples

``` r
# Embeddings need a downloaded model, so the full workflow is in the
# interactive block below. Segmenting needs none.
segment("One sentence. Another sentence.", level = "sentence")
#>   document_id document_name segment              text
#> 1           1                     1     One sentence.
#> 2           1                     2 Another sentence.

# \donttest{
if (interactive()) {
  model <- load_model()
  embeddings <- encode(c("A short sentence.", "Another sentence."), model)

  # Segment-level work benefits most, because segment lengths vary widely.
  segments <- with(head(covid, 50), segment(Abstract, level = "clause"))
  embeddings <- with(segments, encode(text, model, sort_by_length = TRUE))

  # Encode once, then re-run after editing the corpus: only changed rows cost
  # anything the second time.
  store <- file.path(tempdir(), "covid-embeddings.rds")
  embeddings <- with(covid, encode(Abstract, model, cache = store))
  embeddings <- with(covid, encode(Abstract, model, cache = store))
  unlink(store)
}
# }
```
