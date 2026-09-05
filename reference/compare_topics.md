# Compare Topic Counts Before Committing to One

Fits \[topics()\] once per candidate topic count — deterministically, on
one shared set of embeddings — and returns the quality metrics that
justify a granularity choice: mean topic coherence, topic diversity, and
the share of embedding variance separated between topics. The verb
compares; it never chooses for you. Take the count you want out of the
comparison with \[fitted()\].

## Usage

``` r
compare_topics(
  text,
  n_topics = c(5L, 10L, 15L, 20L, 25L, 30L),
  column = NULL,
  model = NULL,
  embeddings = NULL,
  measure = c("npmi", "umass"),
  n_terms = 10L,
  n_representatives = 1L,
  keep_models = TRUE,
  batch_size = 32L,
  cores = 1L,
  segment = c("document", "sentence", "clause", "phrase"),
  max_tokens = NULL,
  merge_below = 0L,
  min_content = 0,
  ...
)
```

## Arguments

- text:

  A character vector of documents, a data frame together with
  \`column\`, or a prepared \[topic_corpus()\]. Passing a corpus (or
  letting \`compare_topics()\` build one internally) segments, embeds,
  and tokenizes the documents once and reuses that work across every
  candidate, instead of re-tokenizing per candidate.

- n_topics:

  Integer vector of candidate topic counts, each at least 2 and below
  the number of modelled units. Default \`c(5, 10, 15, 20, 25, 30)\`.

- column:

  When \`text\` is a data frame, the name of the column holding the
  documents to model. Every other column is carried into
  \`\$documents\`, and rows whose text is missing, blank, or a
  bibliographic placeholder are dropped. Leave \`NULL\` for a character
  vector.

- model:

  A loaded sbert model, a pinned model name, or \`NULL\` for the session
  default. Ignored when \`embeddings\` is supplied.

- embeddings:

  Optional precomputed embedding matrix, one row per document (or per
  segment when \`segment\` is not \`"document"\`); supply it to avoid
  re-encoding.

- measure:

  Coherence measure, \`"npmi"\` (default) or \`"umass"\`.

- n_terms:

  Top terms per topic used for coherence and topic_diversity. Default
  \`10\`.

- n_representatives:

  Representative documents kept per topic in each retained model.
  Default \`1\`; raise it when the stored models are meant to be
  inspected rather than only compared.

- keep_models:

  Whether to retain every fitted model so the chosen granularity needs
  no refitting. Default \`TRUE\`; set \`FALSE\` to return only the
  comparison table when memory matters.

- batch_size:

  Number of texts encoded per model call when encoding is needed.
  Default \`32\`.

- cores:

  Number of forked worker processes. Default \`1\` (serial). Above one,
  the shared corpus is tokenized in parallel and the candidates — which
  are independent and deterministic — are fitted in parallel, on
  Unix-alikes (serial fallback on Windows). Results are identical for
  any core count.

- segment:

  The unit the candidates are fitted on, as in \[topics()\]:
  \`"document"\` (default), \`"sentence"\`, \`"clause"\`, or
  \`"phrase"\`. Give several levels — for example \`c("document",
  "sentence", "clause")\` — to compare the segmentations as well as the
  counts: every level is fitted across every candidate, the table gains
  a leading \`segment\` column, the plot draws one line per level, and
  \[fitted()\] takes \`segment =\` alongside \`n_topics\`.
  \`max_tokens\`, \`merge_below\`, and \`min_content\` then apply to the
  segmented levels only. With several levels, precomputed \`embeddings\`
  are a list of matrices named by level.

- max_tokens:

  Optional cap on segment length, passed to \[segment()\]. When a
  \`model\` is used, the budget counts that model's exact tokens; with
  precomputed \`embeddings\` it counts words. Only with a segmented fit.

- merge_below:

  Re-join segments shorter than this many words into their neighbour,
  passed to \[segment()\]. Only with a segmented fit.

- min_content:

  Minimum alphabetic-content ratio for a segment to be kept, passed to
  \[segment()\]. Only with a segmented fit.

- ...:

  Further arguments passed to \[topics()\] (for example \`stop_words\`
  or \`weighting\`).

## Value

A base data frame with one row per candidate and columns \`n_topics\`,
\`coherence\` (corpus mean), \`topic_diversity\`, and \`explained\`
(between-topic share of total variance), preceded by \`segment\` when
several levels were compared. The coherence measure is recorded in the
\`measure\` attribute. When \`keep_models = TRUE\` the result also
carries class \`sbert_topic_sweep\` and the fitted models, which
\[fitted()\] extracts and \[plot.sbert_topic_sweep()\] draws.

## Details

There is no single correct topic count; this verb replaces the habit of
picking one by feel with a table you can defend. Coherence typically
falls as counts grow while separation rises, so look for the count after
which coherence stops improving (or starts degrading) rather than a
global maximum.

## See also

\[fitted()\] to pull one fitted model out of the comparison.

## Examples

``` r
text <- c(
  "Cats chase mice", "Dogs chase balls", "Kittens nap in sunshine",
  "Stocks and bonds trade", "Markets price shares", "Banks report profit"
)
embeddings <- rbind(
  c(1, 0), c(0.95, 0.05), c(0.9, 0.1),
  c(0, 1), c(0.05, 0.95), c(0.1, 0.9)
)
comparison <- compare_topics(text, n_topics = 2:3, embeddings = embeddings)
comparison
#> <sbert_topic_sweep> 2 candidates, coherence measure: npmi
#>  n_topics  coherence topic_diversity explained
#>         2 -0.4562038               1 0.9954323
#>         3  0.1817530               1 0.9972006
#> 
#> Fitted models retained: fitted(x, n_topics = 3)
fitted(comparison, n_topics = 2)
#> <sbert_topic_model>
#>   documents: 6 
#>   topics: 2
#>   model: precomputed embeddings
#>   algorithm: deterministic k-means (Lloyd)
#>   topic sizes: 3, 3
#>   between/total SS: 99.5%

# Documents against sentences, in one table and one plot (offline: one
# embedding matrix per level, one row per unit of that level).
documents <- c(
  "Cats chase mice. Stocks and bonds trade.",
  "Dogs chase balls. Markets price shares.",
  "Kittens nap in sunshine. Banks report profit."
)
levels <- compare_topics(
  documents,
  n_topics = 2,
  segment = c("document", "sentence"),
  embeddings = list(
    document = rbind(c(0.7, 0.7), c(0.6, 0.8), c(0.8, 0.6)),
    sentence = rbind(
      c(1, 0), c(0, 1), c(0.9, 0.1),
      c(0.1, 0.9), c(0.95, 0.05), c(0.05, 0.95)
    )
  ),
  n_terms = 2
)
levels
#> <sbert_topic_sweep> 2 candidates, coherence measure: npmi
#>   segment n_topics  coherence topic_diversity explained
#>  document        2  0.6845351               1 0.7491596
#>  sentence        2 -0.1934264               1 0.9954323
#> 
#> Fitted models retained: fitted(x, n_topics = 2, segment = "document")
fitted(levels, n_topics = 2, segment = "sentence")
#> <sbert_topic_model>
#>   documents: 3 
#>   segments: 6 (sentence level) 
#>   topics: 2
#>   model: precomputed embeddings
#>   algorithm: deterministic k-means (Lloyd)
#>   topic sizes: 3, 3
#>   between/total SS: 99.5%
```
