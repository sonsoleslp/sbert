#' Install ONNX Runtime
#'
#' @description
#' `install_runtime()` downloads and installs ONNX Runtime, the native inference
#' library on which transformer models run, through [onnxr::onnx_install()]: the
#' portable CPU build, a CUDA build where supported, or the build chosen by
#' automatic detection. The CRAN package onnxr provides the R interface but
#' leaves the library itself, a large platform-specific binary that is not part
#' of R, to be installed on request.
#'
#' Nothing is installed when the package is installed or loaded; this function
#' is the only path. Run it once per R library before [load_model()] or
#' [load_custom()]. The static `potion-base-8M` model does not need it. Model
#' files are installed separately with [model_download()].
#'
#' @param cuda `FALSE` for the CPU runtime, `TRUE` to request CUDA on
#'   supported systems, or `NULL` (default) for automatic detection; passed
#'   to [onnxr::onnx_install()].
#' @return The value of [onnxr::onnx_install()], invisibly.
#' @seealso [load_model()], which needs the runtime; [model_download()] for
#'   the model files; [onnxr::onnx_is_installed()] to check the installation.
#' @export
#' @examples
#' # Whether the ONNX Runtime is already available; nothing is installed here.
#' onnxr::onnx_is_installed()
#'
#' \donttest{
#' if (interactive()) {
#'   install_runtime()
#' }
#' }
install_runtime <- function(cuda = NULL) {
  stopifnot(
    is.null(cuda) ||
      (is.logical(cuda) && length(cuda) == 1L && !is.na(cuda))
  )
  invisible(install_sbert_onnx_runtime(cuda = cuda))
}

install_sbert_onnx_runtime <- function(cuda = NULL) {
  stopifnot(
    is.null(cuda) ||
      (is.logical(cuda) && length(cuda) == 1L && !is.na(cuda))
  )
  onnxr::onnx_install(cuda = cuda)
}
