# Implementation notes removed from `?clean_corpus` (2026-11-17)

Still true of R/corpus.R; kept for maintainers.

Order of operations in `clean_corpus()`:

1. NA becomes "" (and the row is dropped at the end).
2. `clean_characters()`: HTML entities (`&amp; &nbsp; &lt; &gt; &quot;` and
   apostrophe entities), tags (`</?[[:alpha:]][^>]*>`), URLs / `www.` / `doi:`
   tokens, e-mail addresses, bracketed numeric citations (`[12]`, `[1,2]`,
   `[1-3]`), page references (`p. 1`, `pp. 15-30`, digit required), curly
   quotes to straight, en/em dash to " - ", bullets to space, control /
   zero-width / BOM / soft hyphen / U+FFFD removed, NBSP to space, whitespace
   collapsed.
3. `min_content` is judged HERE, on the repaired text, before number and
   marker removal (stripping a reference's numbers would otherwise raise its
   letter ratio).
4. Each `remove` pattern: `gsub(paste0("(?i)", pattern), " ", perl = TRUE)`.
5. `section_numbers`: `[0-9]+(\.[0-9]+){2,}`, `\b[A-Z]{2,3}\.[0-9]+\b`
   ("II.2", "AA.2"; single letters such as "B.12" kept), then list-position
   enumeration markers (`strip_enumeration_markers()`).
6. `list_markers`: `strip_list_markers()`.
7. `numbers`: `\b[0-9]+\b` (so "covid19" survives).
8. `roman_numerals`: canonical numerals of two or more characters up to 100,
   case-insensitive, whole words.
9. Punctuation tidy: space before `,.;:` removed, separator runs collapsed to
   ", ", ",." to ".", leading punctuation trimmed.
10. Kept: not NA, non-empty, and content ok. A data frame keeps the rows
    whole, row names reset.

- A data-frame `column` is checked by bare `stopifnot()` (unclassed); `column`
  with a character vector is `sbert_bad_input`.
- Zero-length input is returned unchanged.
