#' Load an installed pinned model
#'
#' @description
#' `load_model()` reads an installed pinned model from the cache, verifies its
#' files against the pinned sizes and hashes, and returns the model ready for
#' inference: the tokenizer and the ONNX session (or, for the static
#' `potion-base-8M`, its embedding table). An embedding model is defined by its
#' network weights, its tokenizer, and the rules applied around them (pooling,
#' input prefix, maximum input length); the package pins each supported model to
#' an immutable Hugging Face revision with known file sizes and SHA-256 hashes,
#' so that the same name always means the same model and the same text always
#' receives the same embedding.
#'
#' It never downloads anything; the files must first be installed with
#' [model_download()], and transformer models also need ONNX Runtime from
#' [install_runtime()]. The result is an object of class `sbert_model`.
#'
#' Most verbs accept a model name and load it themselves, keeping it for the
#' rest of the session, so an explicit `load_model()` is needed mainly to set
#' `backend` or `threads`. For a model outside the pinned list, use
#' [load_custom()].
#'
#' @param model Name of a pinned model, as listed by [models()] (default
#'   `"all-MiniLM-L6-v2"`).
#' @param cache_dir Cache root (default [cache_dir()]).
#' @param backend ONNX execution backend: `"cpu"` (default), `"coreml"`,
#'   `"cuda"`, `"xnnpack"` or `"openvino"`, as accepted by
#'   [onnxr::onnx_model()].
#' @param threads Number of inference threads, or `"auto"` for the machine's
#'   performance-core count (default 1). Results do not depend on the thread
#'   count; the gain in speed is modest and bounded by the number of
#'   performance cores. The default of one keeps runs within the two-core
#'   limit of check environments.
#' @param verify Check file sizes and SHA-256 hashes before loading (default
#'   `TRUE`).
#' @return An object of class `sbert_model` (class
#'   `c("sbert_static_model", "sbert_model")` for `potion-base-8M`): a list
#'   holding the model's identity (`id`, `short_name`, `revision`), its
#'   encoding settings (`dimension`, `max_length`, `pooling`, `prefix`), the
#'   `backend` and `threads` it runs with, and the loaded tokenizer and model.
#'   Pass it to the `model` argument of [encode()] and of the topic verbs;
#'   its print method shows the identity.
#' @section Conditions:
#'   `sbert_unknown_model` when `model` names no pinned model;
#'   `sbert_model_not_installed` when its files are missing;
#'   `sbert_cache_invalid` when they fail size or hash verification;
#'   `sbert_runtime_missing` when ONNX Runtime is not installed (transformer
#'   models only); `sbert_missing_package` when the static model is loaded
#'   without jsonlite; `sbert_model_error` when the tokenizer or model cannot
#'   be loaded.
#' @seealso [models()] for the pinned models; [model_download()] and
#'   [install_runtime()] to install them; [model_status()] to check an
#'   installation; [load_custom()] for other Hugging Face models; [encode()]
#'   to use the model.
#' @export
#' @examples
#' # The pinned models that load_model() accepts.
#' models()
#'
#' \donttest{
#' if (interactive()) {
#'   model <- load_model()
#'   model
#' }
#' }
load_model <- function(
  model = "all-MiniLM-L6-v2",
  cache_dir = default_cache_dir(),
  backend = "cpu",
  threads = 1L,
  verify = TRUE
) {
  stopifnot(
    is.character(cache_dir),
    length(cache_dir) == 1L,
    !is.na(cache_dir),
    nzchar(cache_dir),
    is.character(backend),
    length(backend) == 1L,
    backend %in% c("cpu", "coreml", "cuda", "xnnpack", "openvino"),
    identical(threads, "auto") ||
      (is.numeric(threads) &&
        length(threads) == 1L &&
        is.finite(threads) &&
        threads >= 1 &&
        threads == as.integer(threads)),
    is.logical(verify),
    length(verify) == 1L,
    !is.na(verify)
  )
  threads <- resolve_inference_threads(threads)

  manifest <- resolve_sbert_manifest(model)

  status <- model_status(cache_dir, model = manifest$short_name)
  if (!all(status$exists)) {
    sbert_abort(
      "Model files are missing. Run model_download() explicitly first.",
      class = "sbert_model_not_installed"
    )
  }
  if (verify && !all(status$valid)) {
    sbert_abort(
      "Model files failed size or SHA-256 validation. Remove and download them again.",
      class = "sbert_cache_invalid"
    )
  }
  if (identical(manifest$type, "static")) {
    static_paths <- status$path
    names(static_paths) <- status$file
    return(load_sbert_static_model(manifest, static_paths))
  }
  if (!sbert_onnx_is_installed()) {
    sbert_abort(
      "ONNX Runtime is not installed. Run install_runtime() explicitly first.",
      class = "sbert_runtime_missing"
    )
  }

  paths <- status$path
  names(paths) <- status$file
  tokenizer_instance <- tryCatch(
    load_sbert_tokenizer(paths[["tokenizer.json"]]),
    error = function(error_condition) {
      sbert_abort(
        sprintf("Could not load tokenizer.json: %s", conditionMessage(error_condition)),
        class = "sbert_model_error"
      )
    }
  )
  onnx_instance <- tryCatch(
    load_sbert_onnx_model(
      path = paths[["model.onnx"]],
      backend = backend,
      threads = as.integer(threads)
    ),
    error = function(error_condition) {
      sbert_abort(
        sprintf("Could not load the ONNX model: %s", conditionMessage(error_condition)),
        class = "sbert_model_error"
      )
    }
  )

  structure(
    list(
      id = manifest$id,
      short_name = manifest$short_name,
      revision = manifest$revision,
      dimension = manifest$dimension,
      max_length = manifest$max_length,
      pad_token = manifest$pad_token,
      pad_id = manifest$pad_id,
      token_type_ids = manifest$token_type_ids,
      pooling = manifest$pooling,
      prefix = manifest$prefix,
      backend = backend,
      threads = as.integer(threads),
      tokenizer = tokenizer_instance,
      onnx = onnx_instance
    ),
    class = "sbert_model"
  )
}

sbert_onnx_is_installed <- function() {
  onnxr::onnx_is_installed()
}

# Inference threads scale only with the machine's PERFORMANCE cores, not with
# its logical core count. Measured on an Apple M4 (4 performance + 6 efficiency)
# encoding 640 abstracts: 1.00x, 1.31x, 1.43x, 1.50x at one to four threads,
# then falling back to 1.25x at six and eight as the efficiency cores add
# contention rather than throughput — user time rose from 9 s to 51 s across
# that range for no wall-clock gain. "auto" therefore asks the platform for its
# performance-core count and falls back to half the logical cores elsewhere.
resolve_inference_threads <- function(threads) {
  if (!identical(threads, "auto")) {
    return(as.integer(threads))
  }
  detect_performance_cores()
}

detect_performance_cores <- function() {
  reported <- NA_integer_
  if (identical(Sys.info()[["sysname"]], "Darwin")) {
    reported <- tryCatch(
      {
        value <- system2(
          "sysctl",
          c("-n", "hw.perflevel0.logicalcpu"),
          stdout = TRUE,
          stderr = FALSE
        )
        if (length(value) == 1L) suppressWarnings(as.integer(value)) else NA_integer_
      },
      error = function(error_condition) NA_integer_,
      warning = function(warning_condition) NA_integer_
    )
  }
  if (is.na(reported) || reported < 1L) {
    logical_cores <- parallel::detectCores(logical = TRUE)
    reported <- if (is.na(logical_cores)) {
      1L
    } else {
      max(1L, as.integer(logical_cores) %/% 2L)
    }
  }
  # Capped because the measured curve turns over well before large core counts,
  # and because a library should not seize a whole machine uninvited.
  max(1L, min(reported, 8L))
}

load_sbert_tokenizer <- function(path) {
  stopifnot(is.character(path), length(path) == 1L, file.exists(path))
  tok::tokenizer$from_file(path)
}

load_sbert_onnx_model <- function(path, backend, threads) {
  stopifnot(
    is.character(path),
    length(path) == 1L,
    file.exists(path),
    is.character(backend),
    length(backend) == 1L,
    is.numeric(threads),
    length(threads) == 1L
  )
  onnxr::onnx_model(
    path = path,
    backend = backend,
    threads = as.integer(threads)
  )
}

#' Print a loaded model
#'
#' @description
#' `print()` shows a loaded model: the repository id, the pinned revision, the
#' number of embedding dimensions, and the backend. A loaded model is identified
#' by its Hugging Face repository and the revision it is pinned to; together
#' with the embedding dimension and the execution backend, these are what a
#' report needs to state which model produced a set of embeddings.
#'
#' For the full list of settings of every pinned model, including pooling and
#' prefix, use `models(detail = TRUE)`.
#'
#' @param x An `sbert_model` from [load_model()] or [load_custom()].
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @seealso [load_model()]; [models()] for the settings of all pinned models.
#' @export
#' @examples
#' # Repository ids and revisions of the pinned models, without loading one.
#' models(detail = TRUE)
#'
#' \donttest{
#' if (interactive()) {
#'   print(load_model())
#' }
#' }
print.sbert_model <- function(x, ...) {
  stopifnot(inherits(x, "sbert_model"))
  cat(sprintf(
    "<sbert_model>\n  model: %s\n  revision: %s\n  dimensions: %d\n  backend: %s\n",
    x$id,
    x$revision,
    x$dimension,
    x$backend
  ))
  invisible(x)
}
