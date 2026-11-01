# Measure the sbert Cache

Reports how much disk space the files under a cache root take, for
example the downloaded models, so the cache can be pruned with
[`model_remove()`](https://sonsoles.me/sbert/reference/model_remove.md).

## Usage

``` r
cache_size(cache_dir = cache_dir())
```

## Arguments

- cache_dir:

  Cache root returned by
  [`cache_dir()`](https://sonsoles.me/sbert/reference/cache_dir.md).

## Value

A single number: the total bytes used by regular files beneath the cache
root, or `0` when it does not exist.

## Examples

``` r
cache_size(tempdir())
#> [1] 3503285
```
