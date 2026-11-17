# Remove a pinned model from the cache

`model_remove()` deletes the cached directory of one pinned model at its
pinned revision, freeing its disk space. Downloaded models stay in the
user cache until removed; a removed model can be installed again at the
same pinned revision with
[`model_download()`](https://sonsoles.me/sbert/reference/model_download.md),
giving identical files.

Other models and the rest of the cache are left in place, and a model
that is not installed is not an error. It returns `TRUE`, invisibly,
when the model's directory no longer exists.

Custom models from
[`load_custom()`](https://sonsoles.me/sbert/reference/load_custom.md)
are stored under the `custom` subdirectory of the cache and are not
removed by this function.

## Usage

``` r
model_remove(cache_dir = default_cache_dir(), model = "all-MiniLM-L6-v2")
```

## Arguments

- cache_dir:

  Cache root (default
  [`cache_dir()`](https://sonsoles.me/sbert/reference/cache_dir.md)).

- model:

  Name of a pinned model, as listed by
  [`models()`](https://sonsoles.me/sbert/reference/models.md) (default
  `"all-MiniLM-L6-v2"`).

## Value

Invisibly, `TRUE` when the model's directory no longer exists.

## Conditions

`sbert_unknown_model` when `model` names no pinned model.

## See also

[`cache_size()`](https://sonsoles.me/sbert/reference/cache_size.md) for
disk use;
[`model_status()`](https://sonsoles.me/sbert/reference/model_status.md)
to check a model;
[`model_download()`](https://sonsoles.me/sbert/reference/model_download.md)
to install it again.

## Examples

``` r
cache <- file.path(tempdir(), "sbert-example-cache")
model_remove(cache)
```
