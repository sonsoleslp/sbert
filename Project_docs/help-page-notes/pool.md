# Implementation notes removed from `?pool` (2026-11-17)

Still true of R/encode.R; kept for maintainers.

- `pool()` validates (finite array, 0/1 mask, matching first two dims,
  logical `normalize`) and calls `pool_impl()`; `encode()` calls
  `pool_impl()` directly and keeps only O(1) shape checks on the hot path.
- Mean pooling re-dimensions the array to (texts * tokens) x hidden,
  multiplies by the flattened mask, and sums per text with `rowsum()`
  (`reorder = FALSE`); the comment records a 6.3x speed-up over
  `sweep()` + `apply()` with bit-identical output.
- Token counts are floored at `1e-9`, so an all-zero mask gives a zero
  vector, not NaN. Row norms are floored at `1e-12` before division.
- A zero-length token dimension returns a texts x hidden zero matrix.
- dimnames are always dropped.
