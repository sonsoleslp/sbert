# Strip Enumeration and List Markers from Text

Removes list and enumeration markers — \`"1."\`, \`"2."\`, \`"(i)"\`,
\`"(a)"\`, \`"(iv)"\` — from each document. The \`numbers\`,
\`roman_numerals\`, and \`section_numbers\` arguments of \[topics()\]
clean only the extracted \*terms\*; this cleans the source \*text\*, so
markers no longer over-fragment \[segment()\], skew the embeddings, or
surface in \[representatives()\]\[representatives\]. Run it once, before
embedding or segmentation, as a companion to \[dedupe()\].

## Usage

``` r
strip_list_markers(text)
```

## Arguments

- text:

  A character vector.

## Value

\`text\` with markers removed and runs of whitespace collapsed to a
single space; each element trimmed.

## Details

A marker must stand alone — whitespace or a string boundary on both
sides — so real words in parentheses (\`"(civil)"\`), four-digit years
(\`"(2020)"\`), counts (\`"(n=100)"\`), multi-word parentheticals
(\`"(see Fig 1)"\`), and decimals (\`"1.5"\`) are left untouched.
Removed forms are a standalone one- or two-digit number followed by a
period (\`"1."\`, \`"12."\`), and a parenthesized one- or two-digit
number, single letter, or Roman numeral up to 39 (\`"(1)"\`, \`"(a)"\`,
\`"(iv)"\`).

## See also

\[dedupe()\], and the \`numbers\` / \`roman_numerals\` /
\`section_numbers\` arguments of \[topics()\] for cleaning the terms
rather than the text.

## Examples

``` r
strip_list_markers(c("1. background 2. methods", "(i) first (ii) second"))
#> [1] "background methods" "first second"      
strip_list_markers("the concept of (civil) society in (2020)")
#> [1] "the concept of (civil) society in (2020)"
```
