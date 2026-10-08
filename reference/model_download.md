# Download a Pinned Sentence-BERT Model

Downloads the official ONNX graph and tokenizer of a pinned model only
after this function is called. Files are locked to an immutable
repository revision and checked against package-controlled SHA-256
values. See \[models()\] for the available models; the default remains
\`all-MiniLM-L6-v2\`.

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

  Name of a pinned model listed by \[models()\].

- cache_dir:

  Cache root returned by \[cache_dir()\].

- quiet:

  Whether to suppress download progress.

- timeout:

  Minimum download timeout in seconds.

## Value

Invisibly, the model directory.

## Examples

``` r
# Report what is already cached; nothing is downloaded here.
model_status(tempdir())
#>             file
#> 1     model.onnx
#> 2 tokenizer.json
#>                                                                                       path
#> 1     /tmp/RtmpzkWGLt/all-MiniLM-L6-v2/1110a243fdf4706b3f48f1d95db1a4f5529b4d41/model.onnx
#> 2 /tmp/RtmpzkWGLt/all-MiniLM-L6-v2/1110a243fdf4706b3f48f1d95db1a4f5529b4d41/tokenizer.json
#>   exists valid expected_bytes actual_bytes
#> 1  FALSE FALSE       90405214           NA
#> 2  FALSE FALSE         466247           NA

# \donttest{
if (interactive()) {
  model_download()
}
# }
```
