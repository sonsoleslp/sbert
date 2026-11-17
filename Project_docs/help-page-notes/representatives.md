# Implementation notes removed from `?representatives` (2026-11-17)

Still true of R/inference.R and R/topics.R; kept for maintainers.

- **ranking**: margin = (min cosine distance to any other centre) - (own
  distance); order by `-margin` (or `distance`), then `nchar(text)`, then
  `text` alphabetically.
- **filters**: duplicated texts (after ordering) and texts without
  `\p{L}{2}` (PCRE, UTF) are dropped before `head(n)`.
- **rationale** (old help): raw closeness favours long units because
  centres are averages of whole-document embeddings; margin rewards units
  unambiguously about one topic.
- **assignment**: units are re-assigned by cosine to normalized centres, not
  taken from the fitted `documents$topic`, so a few boundary units can be
  listed under another topic than the one they were fitted to.
- **stored representatives** (`topic_representatives()` in R/topics.R, used
  by `topics()`): within the fitted k-means topic, ordered by `distance`
  (cosine to normalized centre) then `document_id`, same duplicate/no-word
  filters. `plot()` recomputes with `representatives(rank = "distance")`
  when more are requested than stored.
