#' Load a Pinned Sentence-BERT Model
#'
#' Loads already-downloaded model artifacts. The function never downloads
#' model files or native libraries. See [models()] for the available
#' pinned models.
#'
#' @param model Name of a pinned model listed by [models()].
#' @param cache_dir Cache root returned by [cache_dir()].
#' @param backend ONNX execution backend accepted by [onnxr::onnx_model()].
#' @param threads Positive number of inference threads, or `"auto"` to use the
#'   machine's performance-core count. Inference is the dominant cost of
#'   [encode()] — about 88% of a batch — and it is the only part of the package
#'   that threads. The default `1` is deliberate: it keeps runs reproducible
#'   across machines and keeps the package within the two-core limit that check
#'   environments impose.
#'
#'   Raising it is free of numerical consequence — output was `identical()` at
#'   1, 2, 4, 6 and 8 threads across all 45 measured runs — but expect a modest
#'   gain, bounded by *performance* cores rather than logical ones. Over three
#'   repetitions at 200, 600 and 1,500 documents on an Apple M4 (4 performance +
#'   6 efficiency), median speedups against a single thread were 1.22x at two
#'   threads, 1.29x at four, 1.22x at six and 1.18x at eight. Four threads was
#'   fastest at the two larger sizes (1.34x at 1,500 documents); beyond that the
#'   efficiency cores add contention rather than throughput. Threaded timings are
#'   also noisy — run-to-run spread reached 26% at the smallest size against
#'   under 3% single-threaded — so benchmark with repetition before tuning.
#'   Set `threads = "auto"` for the knee of that curve, or an integer to pin it.
#' @param verify Whether to verify file sizes and SHA-256 hashes before loading.
#' @return An object of class `sbert_model`.
#' @export
#' @examples
#' \dontrun{
#' model <- load_model()
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
    stop(
      "Model files are missing. Run model_download() explicitly first.",
      call. = FALSE
    )
  }
  if (verify && !all(status$valid)) {
    stop(
      "Model files failed size or SHA-256 validation. Remove and download them again.",
      call. = FALSE
    )
  }
  if (identical(manifest$type, "static")) {
    static_paths <- status$path
    names(static_paths) <- status$file
    return(load_sbert_static_model(manifest, static_paths))
  }
  if (!sbert_onnx_is_installed()) {
    stop(
      "ONNX Runtime is not installed. Run install_runtime() explicitly first.",
      call. = FALSE
    )
  }

  paths <- status$path
  names(paths) <- status$file
  tokenizer_instance <- tryCatch(
    load_sbert_tokenizer(paths[["tokenizer.json"]]),
    error = function(error_condition) {
      stop(
        sprintf("Could not load tokenizer.json: %s", conditionMessage(error_condition)),
        call. = FALSE
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
      stop(
        sprintf("Could not load the ONNX model: %s", conditionMessage(error_condition)),
        call. = FALSE
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

#' @export
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
