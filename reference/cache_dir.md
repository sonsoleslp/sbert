# Locate the sbert Model Cache

The directory under which downloaded and custom models are stored, from
[`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html) with
`which = "cache"`. It is only a path: calling this function creates
nothing.

## Usage

``` r
cache_dir()
```

## Value

A length-one character vector containing the platform-appropriate user
cache directory.

## Examples

``` r
cache_dir()
#> [1] "/home/runner/.cache/R/sbert"
```
