# Measure the disk space of the model cache

`cache_size()` measures the disk space of the model cache: it sums the
sizes of all regular files beneath a cache root, including downloaded
models and the files of custom models. A pinned model takes from about
31 MB to 1.3 GB of disk (the `size_mb` column of
[`models()`](https://sonsoles.me/sbert/reference/models.md)), and the
cache keeps every model and custom model downloaded until it is removed,
so this total is the basis for deciding what to remove.

It returns the total size in bytes. To list the files of one model, use
[`model_status()`](https://sonsoles.me/sbert/reference/model_status.md);
to delete one, use
[`model_remove()`](https://sonsoles.me/sbert/reference/model_remove.md).

## Usage

``` r
cache_size(cache_dir = default_cache_dir())
```

## Arguments

- cache_dir:

  Cache root (default the package cache directory,
  [`cache_dir()`](https://sonsoles.me/sbert/reference/cache_dir.md)).

## Value

A number: the total size in bytes, or `0` when the directory does not
exist or is empty.

## See also

[`cache_dir()`](https://sonsoles.me/sbert/reference/cache_dir.md) for
the location;
[`model_status()`](https://sonsoles.me/sbert/reference/model_status.md)
for one model's files;
[`model_remove()`](https://sonsoles.me/sbert/reference/model_remove.md)
to free space.

## Examples

``` r
cache_size(tempdir())
#> [1] 3503241
cache_size(file.path(tempdir(), "no-such-cache"))
#> [1] 0
```
