# Implementation notes for `?predict.sbert_topic_model` (2026-11-17)

Still true of R/inference.R and R/topics.R; kept for maintainers.

- **assignment rule** (`assign_topic_embeddings()`): rows and centres are
  L2-normalized; topic = `max.col(similarity, ties.method = "first")`;
  distance = `pmax(0, 1 - similarity)`.
- **inconsistency with the fit** (owner decision pending): `topics()` runs
  `stats::kmeans(algorithm = "Lloyd")` on the normalized embeddings, so the
  fitted cluster minimizes squared Euclidean distance to the raw centre,
  whose norm is < 1 and differs between topics. For unit x,
  ||x - c||^2 = 1 - 2 x.c + ||c||^2, which is not equivalent to maximizing
  x.c / ||c||. On `feedback_embeddings` with 6 topics, `predict()` on the
  600 training texts disagreed with the fitted topic for 5 units (checked
  2026-11-17). The help page states the difference qualitatively.
- **segmented models**: new text is cut by `segment_topic_documents()` with
  the fitted `segment`, `max_tokens`, `merge_below`, `min_content`
  (minimum 1 segment). With `max_tokens` and no `embeddings`, the model is
  resolved to count tokens.
- `resolve_new_embeddings()` rejects `model` and `embeddings` together and
  non-finite or wrongly sized matrices (`sbert_bad_input`).
