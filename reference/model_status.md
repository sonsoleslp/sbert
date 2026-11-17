# Check the installed files of a model

`model_status()` checks the installed files of a pinned model: for each
file the model needs, it reports where the file is expected in the
cache, whether it exists, and whether its size and SHA-256 hash match
the pinned values. A pinned model is usable only when each of its files
is present and identical to the file the package was pinned to; size and
hash establish that identity, so a truncated download or a modified file
is detected before it can produce wrong embeddings.

It reads the cache only; nothing is downloaded or repaired. The result
is a data frame with one row per required file.

To install missing or invalid files, use
[`model_download()`](https://sonsoles.me/sbert/reference/model_download.md);
to delete a model,
[`model_remove()`](https://sonsoles.me/sbert/reference/model_remove.md).

## Usage

``` r
model_status(cache_dir = default_cache_dir(), model = "all-MiniLM-L6-v2")
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

A base data frame with one row per required file and columns `file`,
`path` (its expected location), `exists`, `valid` (size and hash both
match), `expected_bytes`, and `actual_bytes` (`NA` when the file is
missing).

## Conditions

`sbert_unknown_model` when `model` names no pinned model.

## See also

[`model_download()`](https://sonsoles.me/sbert/reference/model_download.md)
to install;
[`model_remove()`](https://sonsoles.me/sbert/reference/model_remove.md)
to delete;
[`cache_size()`](https://sonsoles.me/sbert/reference/cache_size.md) for
disk use;
[`load_model()`](https://sonsoles.me/sbert/reference/load_model.md),
which runs the same check.

## Examples

``` r
# An empty cache: every file is missing.
model_status(tempdir())
#>             file
#> 1     model.onnx
#> 2 tokenizer.json
#>                                                                                       path
#> 1     /tmp/RtmpZAWFHj/all-MiniLM-L6-v2/1110a243fdf4706b3f48f1d95db1a4f5529b4d41/model.onnx
#> 2 /tmp/RtmpZAWFHj/all-MiniLM-L6-v2/1110a243fdf4706b3f48f1d95db1a4f5529b4d41/tokenizer.json
#>   exists valid expected_bytes actual_bytes
#> 1  FALSE FALSE       90405214           NA
#> 2  FALSE FALSE         466247           NA
model_status(tempdir(), model = "potion-base-8M")
#>                file
#> 1 model.safetensors
#> 2    tokenizer.json
#> 3       config.json
#>                                                                                        path
#> 1 /tmp/RtmpZAWFHj/potion-base-8M/bf8b056651a2c21b8d2565580b8569da283cab23/model.safetensors
#> 2    /tmp/RtmpZAWFHj/potion-base-8M/bf8b056651a2c21b8d2565580b8569da283cab23/tokenizer.json
#> 3       /tmp/RtmpZAWFHj/potion-base-8M/bf8b056651a2c21b8d2565580b8569da283cab23/config.json
#>   exists valid expected_bytes actual_bytes
#> 1  FALSE FALSE       30236760           NA
#> 2  FALSE FALSE         683666           NA
#> 3  FALSE FALSE            202           NA
```
