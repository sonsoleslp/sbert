# Implementation notes removed from `?topic_membership` (2026-11-17)

Still true of R/inference.R; kept for maintainers.

- Distances are cosine distances to the L2-normalized centres, floored at
  1e-12. Weights computed in log space: `w = -(2 / (m - 1)) * log(d)`,
  row-max subtracted, exponentiated, normalized.
- Output sorted by `document_id`, then descending probability, then topic.
- The rank-1 topic equals `predict()`'s topic (same similarity matrix,
  first-index tie-break both ways), and can differ from the fitted k-means
  topic for a few boundary units; on `feedback_embeddings` with 6 topics,
  5 of 600 (checked 2026-11-17).
- Old help: "In high-dimensional embedding spaces distances concentrate, so
  the textbook fuzzifier 2 collapses memberships toward 1/k" (kept, reworded).
