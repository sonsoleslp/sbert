# Implementation notes removed from `?coherence` (2026-11-17)

Still true of R/evaluate.R; kept for maintainers.

- Incidence: binary unit-by-term matrix over the unique stored terms of all
  topics (`topic_document_incidence()`), tokenized with the model's settings
  (or from `token_lists`). Document frequency = `colSums`, co-document
  frequency = `crossprod(incidence)`.
- Each topic uses its first `n_terms` stored terms by `rank`; scored over all
  `combn(n, 2)` pairs, "earlier" = higher-ranked term.
- UMass: `log((co + smoothing) / df[earlier])`, mean over pairs. With
  `smoothing = 1` a pair that always co-occurs scores `log((df + 1) / df) > 0`,
  so UMass is not bounded above by 0 here (the page says "usually negative").
- NPMI: `log(p_ij / (p_i p_j)) / -log(p_ij)`; pairs with `p_ij = 0` score -1,
  `p_ij = 1` score 1 exactly.
- Fewer than two terms: `NA`. `mean_coherence` is the mean over non-NA topics
  (`weighted.mean` by `topics$n_documents` with `weight = "size"`); `NA`, not
  `NaN`, when none is scored (0.5.12).
- `smoothing` must be > 0 (bare `stopifnot`).
- `topic_diversity()`: pooled first `n_terms` terms by rank per topic;
  `length(unique) / length`.
