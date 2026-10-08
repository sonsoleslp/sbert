# Install ONNX Runtime

Explicitly downloads the native ONNX Runtime used by the CRAN package
\`onnxr\`. This is never called during package installation or loading.

## Usage

``` r
install_runtime(cuda = NULL)
```

## Arguments

- cuda:

  Passed to \[onnxr::onnx_install()\]. Use \`FALSE\` for the portable
  CPU runtime, \`TRUE\` to request CUDA on supported systems, or
  \`NULL\` for automatic detection.

## Value

The result returned by \[onnxr::onnx_install()\], invisibly.

## Examples

``` r
# Whether the ONNX Runtime is already available; nothing is installed here.
onnxr::onnx_is_installed()
#> [1] FALSE

# \donttest{
if (interactive()) {
  install_runtime()
}
# }
```
