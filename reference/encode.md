# Encode Text with Sentence-BERT

Encode Text with Sentence-BERT

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

  A loaded \[sbert_model\]\[load_model()\], the name of a pinned model
  from \[models()\], or \`NULL\` for the default \`all-MiniLM-L6-v2\`.
  Names are loaded lazily and kept in a session cache; the first use of
  a not-yet-installed model offers a one-time verified download
  (interactive prompt, or \`options(sbert.download = TRUE)\` in
  scripts).

- batch_size:

  Positive number of sentences processed per ONNX call.

- normalize:

  Whether to return row-wise L2-normalized embeddings.

- prefix:

  Text prepended to every input before tokenization. \`NULL\` (default)
  uses the model's pinned prefix (for example \`"query: "\` for E5
  models, which require one); \`""\` disables prefixing.

- sort_by_length:

  When \`TRUE\`, group inputs of similar length into the same batch
  before encoding and restore the original order afterwards. Sequences
  in a batch are padded to the longest member, so mixed-length input
  makes the model compute over padding: on clause-level segments 60.1
  measured at 1.9x faster end to end. Whole documents of similar length
  gain little (1.1x). Off by default because regrouping changes batch
  composition, which moves embeddings by around 1e-7 — enough to flip a
  rare borderline topic assignment, the same trade-off as
  \`dedupe_segments\` in \[topic_gamma()\]. Row order of the result is
  unaffected.

- cache:

  Optional path to an embedding cache file. When supplied, every
  document is looked up by a SHA-256 digest of its own text together
  with the model identity, revision, dimension, maximum length, pooling
  method and \`normalize\` setting; only documents with no matching
  entry are encoded, and the file is updated with whatever was newly
  computed. Corpora are usually edited rather than replaced — a few
  records corrected, a year appended, rows reordered — and encoding is
  about 97 reuse dominates. Changing 38 documents of 3,847 cost 0.59 s
  against 57 s to re-encode the corpus. Repeated documents within a
  single call are also encoded once (295 of the 3,847 bundled \`covid\`
  abstracts are duplicates).

  The key deliberately excludes \`batch_size\` and \`sort_by_length\`,
  which shift embeddings by around 1e-7 through batch composition alone.
  Cached values are therefore stable to whatever computed them first
  rather than bit-identical to a fresh encode under different batching —
  the same trade-off as \`sort_by_length\` itself. A cache that cannot
  be read, or that was written for a different embedding dimension, is
  discarded with a warning and rebuilt rather than trusted.

## Value

A numeric matrix with one row per input and one column per embedding
dimension of the loaded model.

## Examples

``` r
if (FALSE) { # \dontrun{
model <- load_model()
embeddings <- encode(c("A short sentence.", "Another sentence."), model)

# Segment-level work benefits most, because segment lengths vary widely.
segments <- segment(covid$Abstract[1:50], level = "clause")
embeddings <- encode(segments$text, model, sort_by_length = TRUE)

# Encode once, then re-run after editing the corpus: only changed rows cost
# anything the second time.
store <- file.path(tempdir(), "covid-embeddings.rds")
embeddings <- encode(covid$Abstract, model, cache = store)
embeddings <- encode(covid$Abstract, model, cache = store)
} # }
```
