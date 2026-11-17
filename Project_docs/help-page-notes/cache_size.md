# Implementation notes for `?cache_size` (2026-11-17)

- **fixed bug**: until 2026-11-17 the signature was
  `cache_size(cache_dir = cache_dir())`, whose default referred to the
  argument itself, so `cache_size()` with no argument failed with "promise
  already under evaluation". The default is now `default_cache_dir()`
  (R/corpus.R), like the other cache verbs.
- Sums `file.info()$size` of all non-directory entries from
  `list.files(recursive = TRUE, all.files = TRUE)`; `na.rm = TRUE` hides
  unreadable files.
