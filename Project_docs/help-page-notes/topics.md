# Implementation notes removed from `?topics` (2026-11-17)

Still true of R/topics.R, R/corpus.R and R/hierarchy.R; kept for maintainers.

- **Clustering** (`fit_embedding_topics()`): rows are L2-normalized, then
  `stats::kmeans(algorithm = "Lloyd", iter.max = iter_max)` from the starting
  centers. kmeans warnings are collected in `diagnostics$warnings`; a "did not
  converge" warning is muffled and re-raised as classed `sbert_no_converge`
  (`converged <- fit$iter <= iter_max && !identical(fit$ifault, 2L)`). A kmeans
  error, or a topic with size 0, becomes `sbert_clustering_failed`.
  `diagnostics$iterations` is `min(fit$iter, iter_max)`.
- **Initialization** (`deterministic_topic_centers()`): first center = the
  point farthest (squared Euclidean) from the global mean of the normalized
  embeddings; each next center = the point farthest from its nearest chosen
  center (`which.max`, so ties go to the first row). Distances are computed
  in row blocks of 8192 (memory only; identical arithmetic). If the next
  farthest distance is 0 the corpus has fewer distinct embeddings than
  `n_topics`: `sbert_bad_input`. With seeds, the free centers start from the
  point least covered by the seeds.
- **Topic order**: `order(-size, original index)`, so topic 1 is the largest
  and ties keep k-means order. Seeded fits are not reordered (topic i = seed i).
- **centers**: `fit$centers` reordered, NOT normalized (norms < 1; on the
  600-message feedback fit with 6 topics they ranged 0.53 to 0.73). `distance`
  in `documents` is `pmax(0, 1 - cosine)` to the normalized center, computed in
  8192-row blocks. Note: `reduce_topics()` stores *normalized* centers
  (unit length), unlike `topics()`.
- **fixed_seeds**: nearest-center assignment with `max.col(..., ties.method =
  "first")`; `iter = 0`, `converged = TRUE`, empty topics allowed (withinss 0).
- **seeds** given as a list are collapsed with `paste(collapse = " ")`.
  Seeds are encoded with the document model; for a segmented fit the model is
  resolved separately for the seeds. `seed_embeddings` are normalized.
- **Input handling** (`prepare_topic_input()`): data-frame rows with NA,
  blank, or `"[No abstract available]"` text are dropped; the surviving row
  indices subset a document-level `embeddings` matrix. Blank documents in a
  character vector are an error (`sbert_bad_input`).
- **Labels** (`topic_labels_for()`): `"representative"` = rank-1
  representative shortened to 60 characters at a word boundary
  (`shorten_topic_label()`); `"terms"` = top three terms joined with `" / "`.
  Named seeds override per topic.
- **Tokenizer** (`tokenize_topic_documents()`): lower-case, U+2019 to `'`,
  split on runs of `[^[:alnum:]']` with `(*UTF)(*UCP)`; edge apostrophes
  stripped, `''+` splits; keep tokens with `nchar >= min_token_length` not in
  the stop words. No word segmentation for unspaced CJK text. `numbers =
  "remove"` drops tokens with no character outside `[0-9']`;
  `roman_numerals = "remove"` drops canonical numerals 1-100
  (`.sbert_roman_numerals`; `ml`, `mm`, `cc`, `ci`, `cv` exceed 100 and are
  kept; `iv`, `vi`, `xl` are removed). `section_numbers = "remove"` deletes
  `[0-9]+(\.[0-9]+){2,}` and ANY standalone one- or two-digit number with a
  period (`(^|\s)[0-9]{1,2}\.(?=\s|$)`) before tokenizing. This is broader
  than `strip_list_markers()`, which since 0.5.12 removes such numbers only in
  a list position; "top 20." loses "20" from the terms but not from the text.
- **cores**: forked `parallel::mclapply` over `splitIndices`; stemming runs on
  the combined result; a failed fork falls back to serial. `resolve_cores()`
  forces serial on Windows and for small inputs.
- **Stemming** (`collapse_inflections()`): SnowballC Porter stems; each stem is
  displayed as its most frequent surface form.
- **c-TF-IDF** (`topic_term_scores()`): one count row per topic over the
  sorted vocabulary of terms with corpus frequency >= `min_term_frequency`.
  `tf` = count / `pmax(topic total, 1)`, then square-rooted with
  `reduce_frequent_words` (Eq. 3); `A` = mean topic length (a real number, Mendonca
  and Figueira 2025, Eq. 1); `f_x` = `pmax(colSums, 1)`. `"ctfidf"`:
  `tf * log(1 + A / f_x)`; `"bm25"`: `tf * log1p((A - f_x + 0.5) / (f_x +
  0.5))` (Eq. 2). Errors `sbert_no_terms` when no token survives, none meets
  `min_term_frequency`, or `A < 1`.
- **Segmented fits** go through `topic_corpus()` so both routes share one
  implementation. `max_tokens`, `merge_below`, `min_content` with
  `segment = "document"` is `sbert_bad_input`. A segmentation yielding fewer
  than 2 segments is `sbert_bad_input`.
- **Type checks** are bare `stopifnot()` (unclassed `simpleError`), e.g.
  non-integer `n_topics`, `n_topics > length(text)`.
- Previous page also documented the `documents$distance` as cosine distance to
  the "assigned centroid" and listed `@section Errors`; replaced by
  `@section Conditions` with the classes above.
