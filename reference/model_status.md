# Inspect an Installed Model

Reports whether each required artifact exists and passes its pinned
byte-size and SHA-256 checks.

## Usage

``` r
model_status(cache_dir = default_cache_dir(), model = "all-MiniLM-L6-v2")
```

## Arguments

- cache_dir:

  Cache root returned by
  [`cache_dir()`](https://sonsoles.me/sbert/reference/cache_dir.md).

- model:

  Name of a pinned model listed by
  [`models()`](https://sonsoles.me/sbert/reference/models.md).

## Value

A base data frame with one row per required artifact and columns `file`,
`path` (where it is expected in the cache), `exists`, `valid` (size and
hash both match), `expected_bytes`, and `actual_bytes` (`NA` when the
file is missing).

## Examples

``` r
model_status(tempdir())
#>             file
#> 1     model.onnx
#> 2 tokenizer.json
#>                                                                                       path
#> 1     /tmp/RtmpfQXKr3/all-MiniLM-L6-v2/1110a243fdf4706b3f48f1d95db1a4f5529b4d41/model.onnx
#> 2 /tmp/RtmpfQXKr3/all-MiniLM-L6-v2/1110a243fdf4706b3f48f1d95db1a4f5529b4d41/tokenizer.json
#>   exists valid expected_bytes actual_bytes
#> 1  FALSE FALSE       90405214           NA
#> 2  FALSE FALSE         466247           NA
```
