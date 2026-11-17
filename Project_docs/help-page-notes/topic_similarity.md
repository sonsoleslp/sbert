# Implementation notes for `?topic_similarity` (2026-11-17)

Still true of R/similarity.R; kept for maintainers.

- `normalize_embedding_rows()` checks finiteness with `range()` (O(n), no
  full logical copy) and computes norms in blocks of 8,192 rows (a `for`
  loop, to avoid a corpus-sized `embeddings^2` transient); zero norm ->
  `sbert_bad_input`.
- `tidy = TRUE` is column-major: `from` varies fastest.
- The name says "topic" but the function compares any embeddings.
- `top` (added 2026-11-17): pairs ordered by `from`, descending similarity,
  then position in `y`; self-pairs dropped when `y` is omitted; `rank` via
  `ave(seq_along)`. The tidy table is built in full before filtering, so
  memory is n_x * n_y rows.
