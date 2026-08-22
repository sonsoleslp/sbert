# Clean a Text Corpus Before Encoding

One place for the text-level cleaning that should happen \*before\*
embedding, so the same clean text feeds the encoder, the topic terms,
and the representative examples. Junk characters are always repaired;
the structured removals are opt-in. Because cleaning happens up front,
encode the result and pass those embeddings on — nothing downstream
needs to re-clean.

## Usage

``` r
clean_corpus(
  text,
  column = NULL,
  list_markers = TRUE,
  section_numbers = TRUE,
  numbers = FALSE,
  roman_numerals = FALSE,
  remove = NULL,
  min_content = 0
)
```

## Arguments

- text:

  A character vector, or a data frame together with \`column\`.

- column:

  When \`text\` is a data frame, the name of the text column to clean.
  Every other column rides along and is filtered in step.

- list_markers:

  Remove enumeration and list markers (\`1.\`, \`(i)\`, \`(a)\`);
  default \`TRUE\`. See \[strip_list_markers()\].

- section_numbers:

  Remove multi-level indices (\`1.2.3\`) and enumeration markers;
  default \`TRUE\`.

- numbers:

  Remove stand-alone numeric tokens (years, counts) while keeping
  alphanumerics such as \`covid19\`; default \`FALSE\`.

- roman_numerals:

  Remove stand-alone Roman-numeral tokens (\`ii\`, \`iv\`, up to 100);
  default \`FALSE\`. A few numerals that are also words (\`iv\`, \`vi\`)
  go too.

- remove:

  Optional character vector of custom Perl-compatible regular
  expressions. Each match is replaced with a space, before the other
  steps. The extension point for domain-specific noise the generic
  cleaners leave — for example \`remove = "OJ No L?\s\*\d+"\` for
  European Union Official Journal references, or a journal-citation
  pattern. Matching is case-insensitive.

- min_content:

  Minimum alphabetic-content ratio, in \`\[0, 1\]\`, for a document to
  be kept (see \[content_ratio()\]). Documents below the floor —
  citation lists, reference footnotes, number tables — are dropped.
  \`0\` (default) keeps every non-empty document.

## Value

If \`text\` is a character vector, the cleaned vector with dropped
documents removed. If a data frame, the surviving rows with the
\`column\` cleaned in place.

## Details

The operations, in order: repair junk and strip non-content markup
(decode HTML entities and tags; remove URLs, DOIs, emails, and bracketed
numeric citations such as \`\[12\]\`; normalize curly quotes, dashes,
and bullets; drop control, zero-width, BOM, and replacement characters;
normalize whitespace); strip list and section numbering; optionally
remove numeric and Roman-numeral tokens; then drop documents that fall
below \`min_content\` (see \[content_ratio()\]) or are left empty.
Content-bearing text — real words, author citations, dates, decimals,
inline numbers — is left intact. When \`text\` is a data frame the
surviving rows are returned whole, so metadata stays aligned.

## See also

\[strip_list_markers()\], \[content_ratio()\], \[dedupe()\].

## Examples

``` r
clean_corpus(c(
  "1. The directive entered into force in 2020.",
  "OJ No L 297, 24.11.1979, p. 1."
), min_content = 0.5)
#> [1] "The directive entered into force in 2020."

# strip a domain-specific reference form the generic cleaner leaves
clean_corpus("as set out in OJ No L 313 it applies.",
             remove = "OJ No L?\\s*\\d+")
#> [1] "as set out in it applies."
```
