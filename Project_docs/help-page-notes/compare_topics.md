# Implementation notes removed from `?compare_topics` (2026-11-17)

Still true of R/compare.R and R/accessors.R; kept for maintainers.

- A corpus is built once with `topic_corpus()` from `text`; `...` arguments
  named `stop_words`, `min_token_length`, `stem`, `numbers`,
  `roman_numerals`, `section_numbers` go to the corpus, the rest to
  `topics()`. Candidates are sorted ascending.
- Candidates are fitted with `parallel::mclapply()` when `cores > 1`
  (capped at the number of candidates). If any fork returns a `try-error`,
  all candidates are refitted serially.
- Coherence reuses `corpus$token_lists`; the row's `coherence` is
  `attr(coherence(...), "mean_coherence")`, i.e. the mean over scored topics
  (since 0.5.12; before, one `NA` topic made the row `NA`).
- `explained` = `betweenss / totss`, 0 when `totss` is 0.
- `converged` = `!isFALSE(diagnostics$converged)`; forked candidates cannot
  pass warnings back, so the column is the record.
- Bounds: at document level `validate_candidate_counts()` runs before
  encoding when the unit count is known (character vector or corpus); always
  again after the corpus exists. Needs >= 3 units and every candidate
  `< n_units`. `n_topics` itself is checked by bare `stopifnot()` (integer,
  >= 2, no duplicates).
- Several levels: `compare_topic_segments()` runs one single-level comparison
  per level, stacks them with a leading `segment` column, and keeps
  `attr(, "models")` as a list per level. Segment-only options are dropped for
  the document level. Precomputed embeddings must be a list named by level.
- The class `sbert_topic_sweep` is ALWAYS applied; `keep_models` only decides
  whether `attr(, "models")` is stored. (The old page said the class was added
  only with `keep_models = TRUE`; that was false.)
- `print()` hint names `which.max(coherence)` (first candidate when all NA).
- `plot(type = "metrics")`: `par(mfrow = c(1, 3))`, colors from
  `topic_palette()`, shapes 19/17/15/18, line types 1-4, vertical `lty = 3`
  line at `which.max(coherence)`; an all-NA panel says "not available".
- `summary()` picks `which.max` over finite coherence per level; a
  single-level sweep reads its level from the first stored model (NA without
  models).
