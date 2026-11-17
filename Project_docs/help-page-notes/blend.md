# Implementation notes removed from `?blend` (2026-11-17)

Still true of R/blend.R; kept for maintainers.

- The old help motivated mixing granularities per unit, not pooling units of
  different levels into one training set, with "length-induced embedding
  collapse, arXiv:2410.24200". The citation was removed from the help page
  because it was not verified on 2026-11-17; re-add with full details if
  confirmed.
- Rows are normalized with `normalize_rows()` (norm floor 1e-12, so a zero
  row stays zero). A blended row with norm < 1e-8 (only possible at
  `alpha = 1` with a segment collinear with its document) is replaced by the
  document vector.
- When encoding, segments and documents are encoded with the same model in
  two `encode()` calls; `documents` is required then.
- `document_id` must index rows of `document_embeddings` (checked with
  `stopifnot()`, unclassed).
