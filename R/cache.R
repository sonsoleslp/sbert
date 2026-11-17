#' Locate the model cache
#'
#' @description
#' `cache_dir()` returns the path of the model cache: the user cache directory
#' that R designates for the package, where downloaded models are stored once
#' per user, outside any project. Every function that installs, verifies, loads,
#' measures or removes a model uses this location unless given another
#' `cache_dir`.
#'
#' The path is the one given by `tools::R_user_dir("sbert", which = "cache")`.
#' `cache_dir()` only computes it: it creates no directory and does not check
#' whether one exists.
#'
#' To see what the cache holds, use [model_status()] for one model and
#' [cache_size()] for the disk space used.
#'
#' @return A character string: the path of the cache directory.
#' @seealso [model_status()], [cache_size()], [model_download()] and
#'   [model_remove()], which take this path as `cache_dir`.
#' @export
#' @examples
#' cache_dir()
cache_dir <- function() {
  tools::R_user_dir("sbert", which = "cache")
}

#' Check the installed files of a model
#'
#' @description
#' `model_status()` checks the installed files of a pinned model: for each file
#' the model needs, it reports where the file is expected in the cache, whether
#' it exists, and whether its size and SHA-256 hash match the pinned values. A
#' pinned model is usable only when each of its files is present and identical
#' to the file the package was pinned to; size and hash establish that identity,
#' so a truncated download or a modified file is detected before it can produce
#' wrong embeddings.
#'
#' It reads the cache only; nothing is downloaded or repaired. The result is a
#' data frame with one row per required file.
#'
#' To install missing or invalid files, use [model_download()]; to delete a
#' model, [model_remove()].
#'
#' @param cache_dir Cache root (default [cache_dir()]).
#' @param model Name of a pinned model, as listed by [models()] (default
#'   `"all-MiniLM-L6-v2"`).
#' @return A base data frame with one row per required file and columns
#'   `file`, `path` (its expected location), `exists`, `valid` (size and hash
#'   both match), `expected_bytes`, and `actual_bytes` (`NA` when the file is
#'   missing).
#' @section Conditions:
#'   `sbert_unknown_model` when `model` names no pinned model.
#' @seealso [model_download()] to install; [model_remove()] to delete;
#'   [cache_size()] for disk use; [load_model()], which runs the same check.
#' @export
#' @examples
#' # An empty cache: every file is missing.
#' model_status(tempdir())
#' model_status(tempdir(), model = "potion-base-8M")
model_status <- function(
  cache_dir = default_cache_dir(),
  model = "all-MiniLM-L6-v2"
) {
  stopifnot(
    is.character(cache_dir),
    length(cache_dir) == 1L,
    !is.na(cache_dir),
    nzchar(cache_dir)
  )
  manifest <- resolve_sbert_manifest(model)

  paths <- sbert_artifact_paths(cache_dir, manifest)
  exists <- file.exists(paths)
  actual_bytes <- vapply(
    paths,
    function(path) {
      if (file.exists(path)) unname(file.info(path)$size) else NA_real_
    },
    numeric(1)
  )

  data.frame(
    file = manifest$artifacts$file,
    path = paths,
    exists = exists,
    valid = validate_sbert_cache(cache_dir, manifest),
    expected_bytes = manifest$artifacts$bytes,
    actual_bytes = actual_bytes,
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

download_sbert_artifact <- function(
  url,
  destination,
  expected_bytes,
  expected_sha256,
  quiet
) {
  stopifnot(
    is.character(url),
    length(url) == 1L,
    is.character(destination),
    length(destination) == 1L,
    is.numeric(expected_bytes),
    length(expected_bytes) == 1L,
    is.character(expected_sha256),
    length(expected_sha256) == 1L,
    is.logical(quiet),
    length(quiet) == 1L,
    !is.na(quiet)
  )

  destination_directory <- dirname(destination)
  dir.create(destination_directory, recursive = TRUE, showWarnings = FALSE)
  temporary_path <- tempfile(
    pattern = paste0(basename(destination), "-"),
    tmpdir = destination_directory
  )
  on.exit(unlink(temporary_path, force = TRUE), add = TRUE)

  tryCatch(
    utils::download.file(
      url = url,
      destfile = temporary_path,
      mode = "wb",
      quiet = quiet
    ),
    error = function(error_condition) {
      sbert_abort(
        sprintf(
          "Could not download '%s': %s",
          basename(destination),
          conditionMessage(error_condition)
        ),
        class = "sbert_download_failed"
      )
    }
  )

  if (!validate_sbert_artifact(
    temporary_path,
    expected_bytes,
    expected_sha256
  )) {
    sbert_abort(
      sprintf(
        "Downloaded artifact '%s' failed size or SHA-256 validation.",
        basename(destination)
      ),
      class = "sbert_cache_invalid"
    )
  }

  if (file.exists(destination)) {
    unlink(destination, force = TRUE)
  }
  if (!file.rename(temporary_path, destination)) {
    sbert_abort(
      sprintf("Could not move '%s' into the model cache.", basename(destination)),
      class = "sbert_download_failed"
    )
  }

  invisible(destination)
}

#' Download a pinned model
#'
#' @description
#' `model_download()` downloads the files of one pinned model into the cache. A
#' pinned model is a fixed set of files (an ONNX graph and a tokenizer, or an
#' embedding table for the static model) at an immutable Hugging Face revision;
#' installing it locally once makes encoding work offline and keeps the model
#' identical across machines and over time.
#'
#' Only files that are missing or fail verification are fetched, and each is
#' checked against its pinned size and SHA-256 hash before it is kept. The
#' function runs only when called; the package never downloads during
#' installation, loading, examples or tests. It returns the model's directory in
#' the cache, invisibly.
#'
#' Verbs given a model name that is not installed offer this download
#' themselves (see [encode()]). ONNX Runtime, needed by transformer models, is
#' installed separately with [install_runtime()]. For models outside the
#' pinned list, see [load_custom()].
#'
#' @param model Name of a pinned model, as listed by [models()] (default
#'   `"all-MiniLM-L6-v2"`).
#' @param cache_dir Cache root (default [cache_dir()]).
#' @param quiet Suppress the start message and download progress (default
#'   `FALSE`).
#' @param timeout Minimum download timeout in seconds (default 600); a larger
#'   `getOption("timeout")` is kept.
#' @return The model's directory in the cache, invisibly.
#' @section Conditions:
#'   `sbert_unknown_model` when `model` names no pinned model;
#'   `sbert_download_failed` when a file cannot be downloaded or moved into
#'   the cache; `sbert_cache_invalid` when a downloaded file fails size or
#'   hash verification.
#' @seealso [models()] for the pinned models; [model_status()] to check an
#'   installation; [load_model()] to load it; [model_remove()] to delete it;
#'   [install_runtime()] for ONNX Runtime.
#' @export
#' @examples
#' # Report what is already cached; nothing is downloaded here.
#' model_status(tempdir())
#'
#' \donttest{
#' if (interactive()) {
#'   model_download()
#' }
#' }
model_download <- function(
  model = "all-MiniLM-L6-v2",
  cache_dir = default_cache_dir(),
  quiet = FALSE,
  timeout = 600
) {
  stopifnot(
    is.character(cache_dir),
    length(cache_dir) == 1L,
    !is.na(cache_dir),
    nzchar(cache_dir),
    is.logical(quiet),
    length(quiet) == 1L,
    !is.na(quiet),
    is.numeric(timeout),
    length(timeout) == 1L,
    is.finite(timeout),
    timeout > 0
  )
  manifest <- resolve_sbert_manifest(model)

  model_directory <- sbert_model_directory(cache_dir, manifest)
  dir.create(model_directory, recursive = TRUE, showWarnings = FALSE)

  if (!quiet) {
    message(sprintf(
      paste0(
        "Downloading %s at revision %s (%s; %.1f MB total) ",
        "to '%s'."
      ),
      manifest$id,
      manifest$revision,
      manifest$license %||% "license not recorded",
      sum(manifest$artifacts$bytes) / 1e6,
      model_directory
    ))
  }

  old_timeout <- getOption("timeout")
  options(timeout = max(as.numeric(old_timeout), timeout))
  on.exit(options(timeout = old_timeout), add = TRUE)

  artifacts <- manifest$artifacts
  paths <- sbert_artifact_paths(cache_dir, manifest)
  urls <- sbert_artifact_urls(manifest)
  valid <- validate_sbert_cache(cache_dir, manifest)
  missing_indices <- which(!valid)

  invisible(lapply(
    missing_indices,
    function(index) {
      download_sbert_artifact(
        url = urls[[index]],
        destination = paths[[index]],
        expected_bytes = artifacts$bytes[[index]],
        expected_sha256 = artifacts$sha256[[index]],
        quiet = quiet
      )
    }
  ))

  if (!all(validate_sbert_cache(cache_dir, manifest))) {
    sbert_abort(
      "The model cache is incomplete or invalid after download.",
      class = "sbert_cache_invalid"
    )
  }

  invisible(model_directory)
}

#' Measure the disk space of the model cache
#'
#' @description
#' `cache_size()` measures the disk space of the model cache: it sums the sizes
#' of all regular files beneath a cache root, including downloaded models and
#' the files of custom models. A pinned model takes from about 31 MB to 1.3 GB
#' of disk (the `size_mb` column of [models()]), and the cache keeps every model
#' and custom model downloaded until it is removed, so this total is the basis
#' for deciding what to remove.
#'
#' It returns the total size in bytes. To list the files of one model, use
#' [model_status()]; to delete one, use [model_remove()].
#'
#' @param cache_dir Cache root (default the package cache directory,
#'   [cache_dir()]).
#' @return A number: the total size in bytes, or `0` when the directory does
#'   not exist or is empty.
#' @seealso [cache_dir()] for the location; [model_status()] for one model's
#'   files; [model_remove()] to free space.
#' @export
#' @examples
#' cache_size(tempdir())
#' cache_size(file.path(tempdir(), "no-such-cache"))
cache_size <- function(cache_dir = default_cache_dir()) {
  stopifnot(
    is.character(cache_dir),
    length(cache_dir) == 1L,
    !is.na(cache_dir),
    nzchar(cache_dir)
  )

  if (!dir.exists(cache_dir)) {
    return(0)
  }

  cache_files <- list.files(
    cache_dir,
    recursive = TRUE,
    full.names = TRUE,
    all.files = TRUE,
    no.. = TRUE
  )
  if (length(cache_files) == 0L) {
    return(0)
  }

  file_information <- file.info(cache_files)
  sum(file_information$size[!file_information$isdir], na.rm = TRUE)
}

#' Remove a pinned model from the cache
#'
#' @description
#' `model_remove()` deletes the cached directory of one pinned model at its
#' pinned revision, freeing its disk space. Downloaded models stay in the user
#' cache until removed; a removed model can be installed again at the same
#' pinned revision with [model_download()], giving identical files.
#'
#' Other models and the rest of the cache are left in place, and a model that is
#' not installed is not an error. It returns `TRUE`, invisibly, when the model's
#' directory no longer exists.
#'
#' Custom models from [load_custom()] are stored under the `custom`
#' subdirectory of the cache and are not removed by this function.
#'
#' @param cache_dir Cache root (default [cache_dir()]).
#' @param model Name of a pinned model, as listed by [models()] (default
#'   `"all-MiniLM-L6-v2"`).
#' @return Invisibly, `TRUE` when the model's directory no longer exists.
#' @section Conditions:
#'   `sbert_unknown_model` when `model` names no pinned model.
#' @seealso [cache_size()] for disk use; [model_status()] to check a model;
#'   [model_download()] to install it again.
#' @export
#' @examples
#' cache <- file.path(tempdir(), "sbert-example-cache")
#' model_remove(cache)
model_remove <- function(
  cache_dir = default_cache_dir(),
  model = "all-MiniLM-L6-v2"
) {
  stopifnot(
    is.character(cache_dir),
    length(cache_dir) == 1L,
    !is.na(cache_dir),
    nzchar(cache_dir)
  )
  manifest <- resolve_sbert_manifest(model)

  model_directory <- sbert_model_directory(cache_dir, manifest)
  if (dir.exists(model_directory)) {
    unlink(model_directory, recursive = TRUE, force = TRUE)
  }

  invisible(!dir.exists(model_directory))
}
