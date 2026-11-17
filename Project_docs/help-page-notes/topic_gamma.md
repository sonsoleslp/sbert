# Implementation notes removed from `?topic_gamma` (2026-11-17)

Still true of R/inference.R; kept for maintainers.

- `text = NULL` on a segmented model counts `documents$topic` per
  `document_id` (the k-means assignments), with no re-assignment.
- Otherwise segments are assigned with `assign_topic_embeddings()` (cosine
  to normalized centres), the same rule as `predict()`.
- **dedupe_segments**: `unique(segments$text)` is encoded and expanded back
  with `match()`. Old help: "real corpora are often close to half duplicate
  segments, so this can roughly halve encoding time"; differences ~1e-7 from
  batch composition; identical for the static model (no batch effect). Not
  re-measured.
- **sort_by_length**: old help quoted 60.1% vs 1.6% padding at clause level
  and 1.9x (see encode.md). Not re-measured.
- **cores**: old help noted that segmenting dominates the non-encoding cost;
  encoding threads are set via `load_model(threads =)`.
- **top**: zero shares dropped; ordered by document, descending gamma, topic
  number (ties by topic); `rank` via `ave(seq_along)`.
- `gamma_from_assignments()` builds a document x topic `table()`; documents
  with no segments are absent.
