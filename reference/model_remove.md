# Remove an Installed Model from the Cache

Deletes the cached files of one pinned model. Other models and the rest
of the cache are left untouched; a model that is not installed is not an
error.

## Usage

``` r
model_remove(cache_dir = default_cache_dir(), model = "all-MiniLM-L6-v2")
```

## Arguments

- cache_dir:

  Cache root returned by
  [`cache_dir()`](https://sonsoles.me/sbert/reference/cache_dir.md).

- model:

  Name of a pinned model listed by
  [`models()`](https://sonsoles.me/sbert/reference/models.md).

## Value

Invisibly, whether the model directory no longer exists.

## Examples

``` r
cache <- file.path(tempdir(), "sbert-example-cache")
model_remove(cache)
```
