# Implementation notes removed from other topic-layer pages (2026-11-17)

Covers `?stop_words`, `?topic_corpus`, `?terms.sbert_topic_model`,
`?topic_sizes`, `?dedupe`, `?reduce_topics`, `?topic_hierarchy`,
`?plot.sbert_topic_hierarchy`, `?keywords`, `?name_topics`, `?content_ratio`.

- `stop_words()`: `unique(c(.sbert_english_stopwords, tolower(add)))`, then
  `sort(setdiff(words, tolower(remove)))`. `language != "en"` is
  `sbert_bad_input`.
- `topic_corpus()`: returns an existing corpus unchanged (error if a
  non-document `segment` is passed with it). The object holds `text`,
  `metadata`, `units` (`document_id`, `document_name`, `segment`; `NULL` at
  document level), `embeddings`, `token_lists`, `model`, `settings`. Metadata
  is expanded to one row per segment. Document level needs >= 2 texts,
  segmented >= 1 text (then >= 2 segments).
- `terms()`: scores the whole vocabulary first, orders within topic by `-key`
  then term (alphabetical tie-break), renumbers `rank`, then cuts at `n`.
  `beta = (count + smoothing) / (topic_total + smoothing * V)` over the
  vocabulary `V` that passed `min_term_frequency`; only terms with a non-zero
  count in the topic are returned.
- `topic_sizes()`: `by = "document"` counts unique (document_id, topic) pairs;
  proportion over distinct documents. A character `weights` reads a carried
  column; with `by = "document"` the first segment's value per document is
  used. Weight checks are `stopifnot()` (unclassed).
- `dedupe()`: vector path uses `table(factor(kept, levels = unique(kept)))`;
  data-frame path keeps the first-occurrence row and asserts
  `sum(n) == number of non-blank rows`.
- `reduce_topics()`: `cutree(hclust(as.dist(1 - cos(centers))), k)` maps old
  topics to groups; groups renumbered by size (`order(-size, index)`);
  centers = normalized `colMeans` of member normalized embeddings (unit
  length, unlike `topics()`); distances `max(0, 1 - cos)`; `iterations` and
  `converged` copied from the original fit; algorithm string
  "hierarchical merge of deterministic k-means topics".
  `settings$topic_names` is dropped.
- `topic_hierarchy()`: cosine distance between normalized centers, negative
  values clipped to 0; leaf labels `topic_title(topic, label, 40)`. Stores
  `merges`, `tree` (`hclust`), `n_topics`, `topics`, `distance`.
- `plot.sbert_topic_hierarchy()`: draws `plot(<hclust>, hang = -1)`; the old
  page said `...` went to `plot.dendrogram()`, which was wrong. Bottom margin
  grows with the longest label (`1 + 0.45 * cex * max(nchar)`).
- `keywords()`: candidates are 1..`ngrams` consecutive tokens after stop-word
  removal, so a phrase can join words that a removed stop word separated
  ("analysis of networks" yields "analysis networks"). Candidates per document
  are sorted before MMR; MMR score `(1 - diversity) * relevance - diversity *
  max similarity to chosen`.
- `name_topics()`: raises `errorCondition(class = "sbert_bad_topic_names")`
  WITHOUT the parent class `sbert_error` (every other sbert error has it).
- `content_ratio()`: `nchar` of `\p{L}` characters over `nchar` of non-space
  characters, after `enc2utf8()`.
