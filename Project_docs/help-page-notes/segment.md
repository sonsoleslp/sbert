# Implementation notes removed from `?segment` and `?abbreviations` (2026-11-17)

Still true of R/segment.R; kept for maintainers.

- **gazetteer** (`.sbert_segment_abbreviations`): matched case-insensitively
  and anchored at a word boundary. "ETC." is deliberately absent: a boundary
  fires only at "period space word", and mid-sentence etc. is written
  "ETC.," or "ETC.)", so protecting it could only glue true sentence ends.
- **clause hinges** (`.sbert_segment_hinges`): IN TERMS OF, IN ORDER TO,
  SUCH THAT, AS WELL AS, RATHER THAN, WHEREAS, WHEREBY, WHICH, WHERE, WHILE,
  BECAUSE, ALTHOUGH, THOUGH; multi-word hinges first. Bare AND/OR are
  excluded so enumerations stay whole at clause level.
- **normalization**: curly quotes -> straight; en/em dashes -> spaced
  hyphen; whitespace runs -> one space. Sentinels `@@B@@`, `@@P@@`, `@@C@@`
  mark boundaries and protected periods/commas.
- **max_tokens**: over-long segments are re-split at clause hinges, `;`,
  `:`, `" - "` and commas, except a comma that would sever a name from its
  initials ("Tomlinson, C. A."); pieces are packed greedily back up to the
  budget. A run with no such boundary is chopped before a function word
  (`.sbert_segment_break_before`: coordinators, prepositions, articles,
  relative pronouns) near the budget edge, falling back to the raw edge.
  Word counting is whitespace words; the old help suggested ~200 words for a
  256-token model (not re-measured). With a model, its tokenizer counts
  tokens (special tokens included) in batches of 10,000, after
  `no_padding()`/`no_truncation()` (encode() re-enables both on each call).
- **cores**: `resolve_cores()` returns 1 on Windows, for `cores <= 1`, or for
  fewer than 2,000 documents; otherwise `min(cores, detectCores(), n)`.
  Forked chunks via `parallel::splitIndices()` + `mclapply()`; if any chunk
  returns a `try-error` the whole input is silently re-run serially. With a
  `model`, always serial.
- **min_content**: applied after the `max_tokens` cap; uses
  `content_ratio()`. The old help suggested ~0.5 for removing reference
  noise (not re-measured).
- **merge_below**: a short segment is joined to the next; a short first
  segment is joined to the second.
