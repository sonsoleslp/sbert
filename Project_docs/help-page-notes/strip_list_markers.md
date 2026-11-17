# Implementation notes removed from `?strip_list_markers` (2026-11-17)

Still true of R/corpus.R; kept for maintainers.

- Numbered markers (`strip_enumeration_markers()`), pattern
  `(^|\s)([0-9]{1,2})\s*\.(?=\s|$)` (tolerates "2 ."). A candidate is removed
  when it is (a) at a boundary: nothing before it, or the preceding text (after
  dropping spaces, quotes, an opening parenthesis) ends in `. : ; ! ?`;
  (b) a "1." directly followed by a "2." candidate; or (c) the previous
  marker number + 1 (carried forward with `Reduce(accumulate = TRUE)`).
  Otherwise kept ("in the top 20.", "for student 10."). Since 0.5.12; before,
  every such number was removed.
- Parenthesized markers: `(^|\s)\(\s*(?i:[0-9]{1,3}|[a-z]|roman)\s*\)(?=\s|$)`
  where `roman` is a non-empty numeral 1-39 (`(?=[ivxlcdm])x{0,3}(?:ix|iv|v?i{0,3})`).
  One to three digits, so "(109)" goes and "(2020)" stays.
- Bare Roman section markers with a period, upper case only: multi-letter
  numerals from `.sbert_roman_numerals` (longest first) anywhere; single
  letters `[VXLCDM].` only at the very start of the text ("by V. Nabokov",
  "5 V.", "Smith v. Jones" kept).
- Finally whitespace runs collapse to one space and each element is trimmed.
- `stopifnot(is.character(text), !anyNA(text))`; zero-length input returned
  unchanged.
