# Download a pinned model

`model_download()` downloads the files of one pinned model into the
cache. A pinned model is a fixed set of files (an ONNX graph and a
tokenizer, or an embedding table for the static model) at an immutable
Hugging Face revision; installing it locally once makes encoding work
offline and keeps the model identical across machines and over time.

Only files that are missing or fail verification are fetched, and each
is checked against its pinned size and SHA-256 hash before it is kept.
The function runs only when called; the package never downloads during
installation, loading, examples or tests. It returns the model's
directory in the cache, invisibly.

Verbs given a model name that is not installed offer this download
themselves (see
[`encode()`](https://sonsoles.me/sbert/reference/encode.md)). ONNX
Runtime, needed by transformer models, is installed separately with
[`install_runtime()`](https://sonsoles.me/sbert/reference/install_runtime.md).
For models outside the pinned list, see
[`load_custom()`](https://sonsoles.me/sbert/reference/load_custom.md).

## Usage

``` r
model_download(
  model = "all-MiniLM-L6-v2",
  cache_dir = default_cache_dir(),
  quiet = FALSE,
  timeout = 600
)
```

## Arguments

- model:

  Name of a pinned model, as listed by
  [`models()`](https://sonsoles.me/sbert/reference/models.md) (default
  `"all-MiniLM-L6-v2"`).

- cache_dir:

  Cache root (default
  [`cache_dir()`](https://sonsoles.me/sbert/reference/cache_dir.md)).

- quiet:

  Suppress the start message and download progress (default `FALSE`).

- timeout:

  Minimum download timeout in seconds (default 600); a larger
  `getOption("timeout")` is kept.

## Value

The model's directory in the cache, invisibly.

## Conditions

`sbert_unknown_model` when `model` names no pinned model;
`sbert_download_failed` when a file cannot be downloaded or moved into
the cache; `sbert_cache_invalid` when a downloaded file fails size or
hash verification.

## See also

[`models()`](https://sonsoles.me/sbert/reference/models.md) for the
pinned models;
[`model_status()`](https://sonsoles.me/sbert/reference/model_status.md)
to check an installation;
[`load_model()`](https://sonsoles.me/sbert/reference/load_model.md) to
load it;
[`model_remove()`](https://sonsoles.me/sbert/reference/model_remove.md)
to delete it;
[`install_runtime()`](https://sonsoles.me/sbert/reference/install_runtime.md)
for ONNX Runtime.

## Examples

``` r
# Report what is already cached; nothing is downloaded here.
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

# \donttest{
if (interactive()) {
  model_download()
}
# }
```
