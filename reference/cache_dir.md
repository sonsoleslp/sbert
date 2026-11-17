# Locate the model cache

`cache_dir()` returns the path of the model cache: the user cache
directory that R designates for the package, where downloaded models are
stored once per user, outside any project. Every function that installs,
verifies, loads, measures or removes a model uses this location unless
given another `cache_dir`.

The path is the one given by
`tools::R_user_dir("sbert", which = "cache")`. `cache_dir()` only
computes it: it creates no directory and does not check whether one
exists.

To see what the cache holds, use
[`model_status()`](https://sonsoles.me/sbert/reference/model_status.md)
for one model and
[`cache_size()`](https://sonsoles.me/sbert/reference/cache_size.md) for
the disk space used.

## Usage

``` r
cache_dir()
```

## Value

A character string: the path of the cache directory.

## See also

[`model_status()`](https://sonsoles.me/sbert/reference/model_status.md),
[`cache_size()`](https://sonsoles.me/sbert/reference/cache_size.md),
[`model_download()`](https://sonsoles.me/sbert/reference/model_download.md)
and
[`model_remove()`](https://sonsoles.me/sbert/reference/model_remove.md),
which take this path as `cache_dir`.

## Examples

``` r
cache_dir()
#> [1] "/home/runner/.cache/R/sbert"
```
