# Segment Text into Sentences, Clauses, or Phrases

Splits each document into units at a selectable granularity using
deterministic sentence-boundary rules: a word-boundary-anchored,
case-insensitive abbreviation gazetteer (see \[abbreviations()\]), a
decimal-number guard, and a parenthetical guard, plus shallow clause
chunking at discourse connectives. No model call is involved, so
segmentation works offline and is fully reproducible.

## Usage

``` r
segment(
  text,
  level = c("clause", "sentence", "phrase"),
  merge_below = 0L,
  abbreviations = default_abbreviations(),
  cores = 1L,
  max_tokens = NULL,
  model = NULL,
  min_content = 0
)
```

## Arguments

- text:

  A character vector of documents. Names, when present, are carried into
  the \`document_name\` column.

- level:

  \`"clause"\` (default), \`"sentence"\`, or \`"phrase"\`.

- merge_below:

  Re-join segments shorter than this many words into their neighbor.
  \`0\` (default) disables merging and returns the pure segmentation.

- abbreviations:

  Character vector of abbreviations (each ending in a period) whose
  periods never end a sentence. Defaults to the built-in gazetteer from
  \[abbreviations()\]; matching is case-insensitive.

- cores:

  Number of forked worker processes used to split documents. Default
  \`1\` (serial). Values above one use \`parallel::mclapply\` on
  Unix-alikes and fall back to serial on Windows or for small inputs;
  the segmentation is identical regardless of the count.

- max_tokens:

  Optional cap on segment length, so no segment overruns an encoder's
  context window and is silently truncated. \`NULL\` (default) leaves
  segments uncapped. When set, any segment over the budget is re-split
  at the finest logical boundaries — clause hinges, \`";"\`, \`":"\`,
  \`" - "\`, and commas (though a comma that would sever a name from its
  initials, as in \`"Tomlinson, C. A."\`, does not split) — and the
  pieces are packed back up to the budget, so a split lands on
  punctuation wherever possible. A run with no such boundary is chopped
  further, but even then the break is placed just before a function word
  (a coordinator, preposition, article, or relative pronoun) near the
  budget edge rather than mid-phrase, falling back to the raw edge only
  when the run has no function word either. With \`model = NULL\` the
  budget counts whitespace-delimited words, a deterministic offline
  proxy; set it below the model's true token limit (for example around
  200 for a 256-token model), since a tokenizer emits somewhat more
  tokens than words.

- model:

  Optional loaded \[sbert_model\]\[load_model()\]. When supplied with
  \`max_tokens\`, the budget counts that model's exact sub-word tokens
  instead of words, so \`max_tokens\` can be the model's real limit.
  Token-counted segmentation runs serially (the tokenizer is not
  forked), so \`cores\` is ignored in that case.

- min_content:

  Minimum alphabetic-content ratio, in \`\[0, 1\]\`, for a segment to be
  kept (see \[content_ratio()\]). Segments below the floor — citation
  fragments, page and reference bits, number lists — are dropped. Prose
  scores near 1 and reference noise far below, so a value around \`0.5\`
  removes the noise while keeping real clauses. \`0\` (default) keeps
  every segment.

## Value

A base data frame with one row per segment and columns \`document_id\`
(integer position in \`text\`), \`document_name\` (name of the input
element, or \`""\`), \`segment\` (integer position within the document),
and \`text\` (the segment). Blank documents contribute no rows.

## Details

Each finer level adds separators:

- \`"sentence"\`:

  splits at \`.\`, \`?\`, and \`!\` only.

- \`"clause"\`:

  additionally splits at \`;\`, \`:\`, spaced dashes, and subordinating
  hinges (for example "which", "where", "in terms of"). Comma-separated
  enumerations stay whole. This is the default.

- \`"phrase"\`:

  additionally splits at commas, for maximal granularity.

Before segmentation, each document is normalized: curly quotes become
straight quotes, en and em dashes become spaced hyphens, and runs of
whitespace collapse to single spaces. Letter case is preserved.

## Examples

``` r
segment(
  "We propose a simulator which runs alongside the processor."
)
#>   document_id document_name segment                                text
#> 1           1                     1              We propose a simulator
#> 2           1                     2 which runs alongside the processor.

segment(
  c(intro = "See Fig. 3 for details. The next part follows."),
  level = "sentence"
)
#>   document_id document_name segment                    text
#> 1           1         intro       1 See Fig. 3 for details.
#> 2           1         intro       2  The next part follows.
```
