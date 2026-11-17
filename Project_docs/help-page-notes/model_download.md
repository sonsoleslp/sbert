# Implementation notes removed from `?model_download`, `?model_status`, `?model_remove` (2026-11-17)

Still true of R/cache.R and R/manifest.R; kept for maintainers.

- **layout**: `<cache_dir>/<short_name>/<revision>/<file>`; URLs are
  `https://huggingface.co/<id>/resolve/<revision>/<remote_path>`.
- **download**: each missing or invalid file is fetched to a temporary file
  in the destination directory, verified (byte size, then SHA-256 via
  `digest`), then renamed over the destination. The whole set is verified
  again at the end. `options(timeout = max(current, timeout))` is set and
  restored.
- **start message**: names id, revision, license (always printed as
  Apache-2.0 in the message text, regardless of the model's license field)
  and total MB. 4 of the 14 pinned models are MIT-licensed (checked
  2026-11-17), so the message is wrong for them.
- **interactive consent** lives in `ensure_sbert_model_installed()`
  (R/session.R): `utils::askYesNo()` (default no); declining raises
  `sbert_model_not_installed`; non-interactive needs
  `options(sbert.download = TRUE)`.
- **model_status**: `valid` recomputes SHA-256 of every present file on each
  call (slow for the large models).
- **model_remove** deletes only `<short_name>/<revision>`; an older revision
  directory or the empty `<short_name>/` parent is left.
