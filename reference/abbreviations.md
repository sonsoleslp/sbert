# List the abbreviations protected from sentence splitting

`abbreviations()` returns the built-in list of abbreviations whose
period does not end a sentence, which
[`segment()`](https://sonsoles.me/sbert/reference/segment.md) uses by
default. A period ends a sentence far more often than not, but
abbreviations such as "e.g.", "Fig." or "et al." also end in one, so
rule-based sentence splitting needs such a list.

Matching in
[`segment()`](https://sonsoles.me/sbert/reference/segment.md) ignores
case and starts at a word boundary, so `"ST."` protects
`"St. Petersburg"` but not the end of `"cost."`.

To protect further abbreviations, pass an extended vector to the
`abbreviations` argument of
[`segment()`](https://sonsoles.me/sbert/reference/segment.md).

## Usage

``` r
abbreviations()
```

## Value

A sorted character vector of abbreviations in upper case, each ending in
a period.

## See also

[`segment()`](https://sonsoles.me/sbert/reference/segment.md), which
uses the list.

## Examples

``` r
abbreviations()
#>  [1] "APPROX." "B.SC."   "CF."     "DR."     "E.G."    "EQ."     "EQS."   
#>  [8] "ET AL."  "FIG."    "FIGS."   "I.E."    "M.SC."   "NO."     "NOS."   
#> [15] "PH.D."   "PP."     "PROF."   "REF."    "REFS."   "ST."     "U.K."   
#> [22] "U.S."    "VOL."    "VS."    

# "App." is not in the list, so its period ends a sentence ...
segment("See App. B for the items. Then stop.", level = "sentence")
#>   document_id document_name segment             text
#> 1           1                     1         See App.
#> 2           1                     2 B for the items.
#> 3           1                     3       Then stop.

# ... unless it is added.
segment("See App. B for the items. Then stop.", level = "sentence",
        abbreviations = c(abbreviations(), "APP."))
#>   document_id document_name segment                      text
#> 1           1                     1 See App. B for the items.
#> 2           1                     2                Then stop.
```
