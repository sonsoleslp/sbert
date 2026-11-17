# Install ONNX Runtime

`install_runtime()` downloads and installs ONNX Runtime, the native
inference library on which transformer models run, through
[`onnxr::onnx_install()`](http://corymccartan.com/onnxr/reference/onnx_install.md):
the portable CPU build, a CUDA build where supported, or the build
chosen by automatic detection. The CRAN package onnxr provides the R
interface but leaves the library itself, a large platform-specific
binary that is not part of R, to be installed on request.

Nothing is installed when the package is installed or loaded; this
function is the only path. Run it once per R library before
[`load_model()`](https://sonsoles.me/sbert/reference/load_model.md) or
[`load_custom()`](https://sonsoles.me/sbert/reference/load_custom.md).
The static `potion-base-8M` model does not need it. Model files are
installed separately with
[`model_download()`](https://sonsoles.me/sbert/reference/model_download.md).

## Usage

``` r
install_runtime(cuda = NULL)
```

## Arguments

- cuda:

  `FALSE` for the CPU runtime, `TRUE` to request CUDA on supported
  systems, or `NULL` (default) for automatic detection; passed to
  [`onnxr::onnx_install()`](http://corymccartan.com/onnxr/reference/onnx_install.md).

## Value

The value of
[`onnxr::onnx_install()`](http://corymccartan.com/onnxr/reference/onnx_install.md),
invisibly.

## See also

[`load_model()`](https://sonsoles.me/sbert/reference/load_model.md),
which needs the runtime;
[`model_download()`](https://sonsoles.me/sbert/reference/model_download.md)
for the model files;
[`onnxr::onnx_is_installed()`](http://corymccartan.com/onnxr/reference/onnx_is_installed.md)
to check the installation.

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
