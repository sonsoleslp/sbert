# Implementation notes removed from `?load_custom` (2026-11-17)

Still true of R/custom.R; kept for maintainers.

- **layout**: `<cache_dir>/custom/<id with / -> __>/<revision>/` holding
  `model.onnx`, `tokenizer.json` and `sbert-manifest.json`.
- **revision**: `NULL` resolves the current `sha` from
  `https://huggingface.co/api/models/<id>` on every call (network needed
  even when a copy is cached, because the directory depends on it). Only an
  explicit `revision` reuses a cached manifest without the network.
- **ONNX path**: the repository tree is listed; `onnx/model.onnx` is
  preferred over `model.onnx`; with neither, the error names up to five
  other `.onnx` files.
- **pooling**: `1_Pooling/config.json` (`pooling_mode_cls_token` ->
  `"cls"`, `pooling_mode_mean_tokens` -> `"mean"`); absent -> error.
- **max_length**: `sentence_bert_config.json` `max_seq_length`, else 512.
- **padding token**: first added token named `[pad]` / `<pad>` (any case) in
  `tokenizer.json`, else `[PAD]`/0.
- **silent fallbacks**: `read_optional_hf_json()` and `detect_custom_pad()`
  turn every error into `NULL` (bare `tryCatch(..., error = NULL)`), so a
  network failure while reading an optional config looks like "file absent".
- **files** already present in the directory are not re-downloaded on the
  first-use path, and are hashed as found (no verification before the
  manifest is written).
- **dimension**: last dim of the graph's `last_hidden_state` shape; when
  dynamic, one probe encode of `"a"` sets it.
- **arguments** `pooling`, `prefix`, `max_length` given on a later call
  override the recorded manifest for that call only (manifest not rewritten).
- `backend` and `threads` are not validated here (passed to onnxr).
