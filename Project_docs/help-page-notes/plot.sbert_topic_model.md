# Implementation notes removed from `?plot.sbert_topic_model` (2026-11-17)

Still true of R/plots.R; kept for maintainers.

- **sizes**: horizontal `barplot()` of `topics$n_documents` (units, i.e.
  segments for a segmented model, although the axis says "Documents");
  labels truncated to 45 characters; left margin `min(24, 1 + 0.42 *
  longest label)`.
- **representatives**: two-column grid (one column for a single topic),
  `max_chars = 96 / columns`; panel texts laid out by measured height, two
  lines when they fit, else one, "(k of n shown)" when the panel is short.
- **fit**: `layout()` with four cells per topic row, documents first (width
  1.9) then count, TF-IDF, beta. Wrapped in `with_panel_size_guard()`, which
  rethrows "figure margins too large" / "invalid graphics state" as
  `sbert_plot_too_small`; on exit `par(mfrow = c(1, 1))` then the old par.
- **map**: thinning by `thin_map_documents()`: per topic quota
  `max(2, round(max_points * share))`, evenly spaced indices, no RNG; a
  message reports the sample. Distances `1 - x %*% t(x)` on the stored
  embeddings (assumed unit-norm), clamped at 0, `cmdscale(k = 2)`.
- **few representatives**: when more are requested than stored and no
  embeddings were kept, warning `sbert_few_representatives` and the stored
  set is drawn.
- **known warning**: texts with curly quotes (e.g. `feedback_translations`)
  give "mbcsToSbcs" warnings on the `pdf()` device, which is why the
  examples use the ASCII toy model.
