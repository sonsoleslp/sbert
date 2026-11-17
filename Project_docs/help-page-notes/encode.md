# Implementation notes removed from `?encode` (2026-11-17)

Still true of R/encode.R and R/embeddings_cache.R; kept for maintainers.

- **pipeline**: `encode()` -> `encode_in_batches()` -> `encode_sbert_batch()`
  -> `prepare_sbert_inputs()` (tokenizer truncation to `max_length`, right
  padding with the model's `pad_id`/`pad_token`, `token_type_ids` all zero)
  -> `run_sbert_onnx()` -> `pool_impl()` -> optional L2 normalization. The
  static model branches to `encode_static_batch()` (no special tokens, token
  lookup + mean; unknown-only texts embed as zero vectors before
  normalization).
- **prefix**: pasted onto the text before tokenization (and before the cache
  key is computed), so a prefix change is a cache miss.
- **ONNX errors**: any error from `onnxr::onnx_run()` is rethrown as
  `sbert_model_error`; a missing `last_hidden_state` output and non-finite
  pooled values also raise `sbert_model_error`. Finiteness is checked on the
  pooled output, not the token array (cheaper; an unmasked Inf sums to Inf
  and a masked one becomes NaN, so both surface).
- **batching**: results are written into one preallocated matrix batch by
  batch (avoids holding the list of batches and the rbind copy at once).
  Storage mode follows the first batch (tests use integer stubs).
- **sort_by_length**: orders inputs by `nchar(type = "bytes")` (radix) and
  inverts the permutation at the end. Old help quoted, from an earlier
  benchmark: on clause-level segments 60.1% of token work was padding in
  input order vs 1.6% sorted, 1.9x faster end to end; whole documents 1.1x.
  Regrouping moves values by about 1e-7 (CLAUDE.md), which can flip a
  borderline topic assignment. These figures were not re-measured on
  2026-11-17.
- **cache key** (`embedding_cache_keys()`): SHA-256 of (SHA-256 of model
  `id`, `revision`, `dimension`, `max_length`, `pooling`, `normalize`) +
  the exact input text. `batch_size` and `sort_by_length` are deliberately
  excluded, so cached values are stable to whatever computed them first,
  not bit-identical to a fresh encode under other batching.
- **cache file**: an `.rds` list `version = 1L`, `key`, `embeddings`; written
  uncompressed to `<path>.tmp<pid>` then renamed. Unreadable, wrong-version,
  wrong-dimension, or duplicate-key files are discarded with warning
  `sbert_cache_rebuilt`. Distinct missing keys are encoded once each, so
  duplicates within a call are encoded once (only on the cache path).
- **old figures** (not re-measured): changing 38 of 3,847 documents cost
  0.59 s vs 57 s to re-encode; encoding ~97% of a topic workflow. The old
  help said 177 of the 3,847 `covid` abstracts repeat an earlier one; the
  comment in `encode_with_cache()` says 295. One of the two is wrong.
- **empty input**: `character(0)` returns a 0 x `dimension` matrix (the model
  is still resolved first, so this needs a model).
