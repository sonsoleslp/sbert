# Implementation notes removed from `?load_model` (2026-11-17)

Still true of R/model.R, R/session.R and R/static.R; kept for maintainers.

- **threads benchmark** (from the old help, not re-measured): output was
  `identical()` at 1, 2, 4, 6 and 8 threads over 45 runs. On an Apple M4
  (4 performance + 6 efficiency cores), 200/600/1,500 documents, median
  speed-ups vs one thread: 1.22x (2), 1.29x (4), 1.22x (6), 1.18x (8); four
  threads fastest at the larger sizes (1.34x at 1,500). Run-to-run spread up
  to 26% threaded vs < 3% single-threaded. Inference was ~88% of a batch.
  The code comment on `resolve_inference_threads()` quotes a different run
  (640 abstracts: 1.00/1.31/1.43/1.50x at 1-4 threads, 1.25x at 6 and 8).
- **"auto"**: `detect_performance_cores()` reads
  `sysctl -n hw.perflevel0.logicalcpu` on macOS; elsewhere (or on failure)
  half the logical cores; capped at 8, floored at 1.
- **backend** is validated against `c("cpu", "coreml", "cuda", "xnnpack",
  "openvino")` with `stopifnot()` (unclassed error).
- **order of checks**: unknown name (`sbert_unknown_model`, from
  `resolve_sbert_manifest()`) -> missing files (`sbert_model_not_installed`)
  -> failed verification when `verify = TRUE` (`sbert_cache_invalid`) ->
  static model returned (no runtime check) -> runtime check
  (`sbert_runtime_missing`) -> tokenizer / ONNX load errors rethrown as
  `sbert_model_error`. Static models raise `sbert_missing_package` (no
  jsonlite) or `sbert_model_error` (dimension mismatch) from
  `load_sbert_static_model()`; a tokenizer error there is not wrapped.
- **session cache**: verbs given a name use `resolve_sbert_model()`, which
  caches loaded models by short name in `.sbert_session`; explicit
  `load_model()` calls are not cached.
