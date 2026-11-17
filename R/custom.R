# Generic Hugging Face embedding-model loader with trust-on-first-use pinning.
# Unlike the curated registry (models()), configuration here is
# auto-detected where possible and recorded to a local manifest on first
# download; later loads verify files against that recorded manifest. The
# caller vouches for the pooling configuration; no parity certificate is
# implied.

custom_model_directory <- function(cache_dir, id, revision) {
  file.path(cache_dir, "custom", gsub("/", "__", id, fixed = TRUE), revision)
}

read_hf_json <- function(url) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    sbert_abort(
      "load_custom() requires the 'jsonlite' package. Install it first.",
      class = "sbert_missing_package"
    )
  }
  tryCatch(
    jsonlite::fromJSON(url, simplifyVector = TRUE),
    error = function(error_condition) {
      sbert_abort(
        sprintf("Could not read '%s': %s", url, conditionMessage(error_condition)),
        class = "sbert_download_failed"
      )
    }
  )
}

resolve_hf_revision <- function(id) {
  info <- read_hf_json(sprintf("https://huggingface.co/api/models/%s", utils::URLencode(id)))
  revision <- info$sha
  if (is.null(revision) || !nzchar(revision)) {
    sbert_abort(
      sprintf("Could not resolve the current revision of '%s'.", id),
      class = "sbert_download_failed"
    )
  }
  revision
}

find_hf_onnx_path <- function(id, revision) {
  tree <- read_hf_json(sprintf(
    "https://huggingface.co/api/models/%s/tree/%s?recursive=true",
    utils::URLencode(id),
    revision
  ))
  candidates <- intersect(c("onnx/model.onnx", "model.onnx"), tree$path)
  if (length(candidates) == 0L) {
    onnx_files <- grep("\\.onnx$", tree$path, value = TRUE)
    sbert_abort(
      sprintf(
        "No 'onnx/model.onnx' or 'model.onnx' in '%s' at revision %s.%s",
        id,
        revision,
        if (length(onnx_files) > 0L) {
          sprintf(
            " Other .onnx files present (%s); pass onnx_path explicitly.",
            paste(utils::head(onnx_files, 5L), collapse = ", ")
          )
        } else {
          " The repository ships no ONNX export."
        }
      ),
      class = "sbert_model_error"
    )
  }
  candidates[[1L]]
}

# Read optional Sentence-Transformers configuration files; each returns NULL
# when the file is absent so explicit arguments and probes can take over.
read_optional_hf_json <- function(id, revision, path) {
  url <- sprintf("https://huggingface.co/%s/resolve/%s/%s", id, revision, path)
  tryCatch(read_hf_json(url), error = function(error_condition) NULL)
}

detect_custom_pooling <- function(id, revision) {
  pooling_config <- read_optional_hf_json(id, revision, "1_Pooling/config.json")
  if (is.null(pooling_config)) {
    return(NULL)
  }
  if (isTRUE(pooling_config$pooling_mode_cls_token)) {
    return("cls")
  }
  if (isTRUE(pooling_config$pooling_mode_mean_tokens)) {
    return("mean")
  }
  NULL
}

detect_custom_pad <- function(tokenizer_json_path) {
  tokenizer_config <- tryCatch(
    jsonlite::fromJSON(tokenizer_json_path, simplifyVector = FALSE),
    error = function(error_condition) NULL
  )
  added <- tokenizer_config$added_tokens
  if (is.null(added)) {
    return(NULL)
  }
  contents <- vapply(added, function(token) as.character(token$content), character(1))
  ids <- vapply(added, function(token) as.integer(token$id), integer(1))
  index <- match(TRUE, tolower(contents) %in% c("[pad]", "<pad>"))
  if (is.na(index)) {
    return(NULL)
  }
  list(pad_token = contents[[index]], pad_id = ids[[index]])
}

download_custom_artifact <- function(url, destination, quiet) {
  destination_directory <- dirname(destination)
  dir.create(destination_directory, recursive = TRUE, showWarnings = FALSE)
  temporary_path <- tempfile(
    pattern = paste0(basename(destination), "-"),
    tmpdir = destination_directory
  )
  on.exit(unlink(temporary_path, force = TRUE), add = TRUE)
  tryCatch(
    utils::download.file(url, temporary_path, mode = "wb", quiet = quiet),
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
  if (!file.rename(temporary_path, destination)) {
    sbert_abort(
      sprintf("Could not move '%s' into the cache.", basename(destination)),
      class = "sbert_download_failed"
    )
  }
  invisible(destination)
}

custom_manifest_path <- function(model_directory) {
  file.path(model_directory, "sbert-manifest.json")
}

write_custom_manifest <- function(model_directory, manifest) {
  writeLines(
    jsonlite::toJSON(manifest, auto_unbox = TRUE, pretty = TRUE),
    custom_manifest_path(model_directory)
  )
}

read_custom_manifest <- function(model_directory) {
  path <- custom_manifest_path(model_directory)
  if (!file.exists(path)) {
    return(NULL)
  }
  read_hf_json(path)
}

verify_custom_files <- function(model_directory, manifest) {
  files <- manifest$files
  vapply(
    seq_along(files$file),
    function(index) {
      validate_sbert_artifact(
        file.path(model_directory, files$file[[index]]),
        files$bytes[[index]],
        files$sha256[[index]]
      )
    },
    logical(1)
  )
}

#' Load a Hugging Face embedding model outside the pinned list
#'
#' @description
#' `load_custom()` loads a Hugging Face embedding model that is not in the
#' pinned list, on a "trust on first use" basis. Many embedding models on
#' Hugging Face publish an ONNX export of their encoder and a `tokenizer.json`;
#' such a model can be used like a pinned one, but its configuration is not
#' vouched for by the package: there is no pinned revision, no
#' package-controlled hash, and no check that its embeddings match the reference
#' implementation. The caller is responsible for the pooling rule, prefix and
#' maximum length.
#'
#' On first use it resolves the current revision (unless `revision` is given),
#' downloads the ONNX graph and tokenizer, and records their sizes, hashes and
#' the model's configuration in a local manifest; later loads verify the files
#' against that manifest. A later load with the same `revision` given uses no
#' network; with `revision = NULL` every call first asks Hugging Face for the
#' current revision. Pooling and maximum length are read from the repository's
#' Sentence-Transformers configuration when it has one and must be given
#' otherwise; the embedding dimension is read from the ONNX graph.
#'
#' The result is an `sbert_model` like the one [load_model()] returns, so
#' [encode()], [topics()] and every other verb accept it. For the pinned,
#' verified models use [load_model()].
#'
#' @param id Hugging Face repository id, for example `"thenlper/gte-small"`.
#' @param revision Commit hash to pin, or `NULL` (default) to resolve the
#'   current revision online on every call. Pin it for offline reuse.
#' @param onnx_path Path of the ONNX graph in the repository, or `NULL`
#'   (default) to use `onnx/model.onnx` or `model.onnx`.
#' @param tokenizer_path Path of the tokenizer in the repository (default
#'   `"tokenizer.json"`).
#' @param pooling `"mean"` or `"cls"`, or `NULL` (default) to read it from
#'   the repository's `1_Pooling/config.json`.
#' @param prefix Text prepended to every input by [encode()]. `NULL` (default)
#'   keeps the recorded prefix (`""` on first use); `""` clears it.
#' @param max_length Maximum word pieces per input, or `NULL` (default) to
#'   read it from `sentence_bert_config.json`, else 512.
#' @param cache_dir Cache root (default [cache_dir()]).
#' @param backend ONNX execution backend, as accepted by
#'   [onnxr::onnx_model()] (default `"cpu"`).
#' @param threads Number of inference threads (default 1).
#' @param verify Check recorded sizes and SHA-256 hashes when loading from the
#'   cache (default `TRUE`).
#' @param quiet Suppress the download message and progress (default `FALSE`).
#' @return An object of class `sbert_model` with the same fields as
#'   [load_model()] returns; its `short_name` is `"custom:<id>"`.
#' @section Conditions:
#'   `sbert_runtime_missing` when ONNX Runtime is not installed;
#'   `sbert_missing_package` when jsonlite is not installed;
#'   `sbert_download_failed` when repository metadata or files cannot be
#'   downloaded or the revision cannot be resolved; `sbert_model_error` when
#'   the repository has no ONNX graph at the expected path, the pooling rule
#'   cannot be detected and was not given, or the graph lacks a
#'   `last_hidden_state` output or needs unsupported inputs;
#'   `sbert_cache_invalid` when cached files no longer match the recorded
#'   manifest.
#' @seealso [load_model()] for the pinned models; [install_runtime()] for
#'   ONNX Runtime; [encode()] to use the model; [cache_dir()] for where it is
#'   stored.
#' @export
#' @examples
#' # Custom models are stored under "custom" in this cache root.
#' cache_dir()
#'
#' \donttest{
#' if (interactive()) {
#'   model <- load_custom("thenlper/gte-small")
#'   encode(c("one sentence", "another sentence"), model)
#' }
#' }
load_custom <- function(
  id,
  revision = NULL,
  onnx_path = NULL,
  tokenizer_path = "tokenizer.json",
  pooling = NULL,
  prefix = NULL,
  max_length = NULL,
  cache_dir = default_cache_dir(),
  backend = "cpu",
  threads = 1L,
  verify = TRUE,
  quiet = FALSE
) {
  stopifnot(
    is.character(id),
    length(id) == 1L,
    !is.na(id),
    grepl("^[^/]+/[^/]+$", id),
    is.null(revision) ||
      (is.character(revision) && length(revision) == 1L && nzchar(revision)),
    is.null(onnx_path) ||
      (is.character(onnx_path) && length(onnx_path) == 1L && nzchar(onnx_path)),
    is.character(tokenizer_path),
    length(tokenizer_path) == 1L,
    nzchar(tokenizer_path),
    is.null(pooling) || pooling %in% c("mean", "cls"),
    is.null(prefix) ||
      (is.character(prefix) && length(prefix) == 1L && !is.na(prefix)),
    is.null(max_length) ||
      (is.numeric(max_length) && length(max_length) == 1L && max_length >= 2 &&
        max_length == as.integer(max_length)),
    is.character(cache_dir),
    length(cache_dir) == 1L,
    nzchar(cache_dir),
    is.logical(verify),
    length(verify) == 1L,
    !is.na(verify),
    is.logical(quiet),
    length(quiet) == 1L,
    !is.na(quiet)
  )
  if (!sbert_onnx_is_installed()) {
    sbert_abort(
      "ONNX Runtime is not installed. Run install_runtime() explicitly first.",
      class = "sbert_runtime_missing"
    )
  }

  # Reuse an already-pinned local copy when the revision is known.
  if (!is.null(revision)) {
    model_directory <- custom_model_directory(cache_dir, id, revision)
    manifest <- read_custom_manifest(model_directory)
  } else {
    manifest <- NULL
  }

  if (is.null(manifest)) {
    if (is.null(revision)) {
      revision <- resolve_hf_revision(id)
      model_directory <- custom_model_directory(cache_dir, id, revision)
      manifest <- read_custom_manifest(model_directory)
    }
  }

  if (is.null(manifest)) {
    if (is.null(onnx_path)) {
      onnx_path <- find_hf_onnx_path(id, revision)
    }
    if (is.null(pooling)) {
      pooling <- detect_custom_pooling(id, revision)
      if (is.null(pooling)) {
        sbert_abort(
          paste0(
            "Could not auto-detect the pooling mode (no Sentence-Transformers ",
            "1_Pooling config). Pass pooling = \"mean\" or \"cls\" explicitly."
          ),
          class = "sbert_model_error"
        )
      }
    }
    if (is.null(max_length)) {
      sbc <- read_optional_hf_json(id, revision, "sentence_bert_config.json")
      max_length <- if (!is.null(sbc$max_seq_length)) {
        as.integer(sbc$max_seq_length)
      } else {
        512L
      }
    }
    if (!quiet) {
      message(sprintf(
        "Downloading %s at revision %s to '%s'.",
        id,
        revision,
        model_directory
      ))
    }
    base_url <- sprintf("https://huggingface.co/%s/resolve/%s", id, revision)
    local_files <- c("model.onnx", "tokenizer.json")
    remote_files <- c(onnx_path, tokenizer_path)
    invisible(lapply(
      seq_along(local_files),
      function(index) {
        destination <- file.path(model_directory, local_files[[index]])
        if (!file.exists(destination)) {
          download_custom_artifact(
            paste(base_url, remote_files[[index]], sep = "/"),
            destination,
            quiet = quiet
          )
        }
      }
    ))
    paths <- file.path(model_directory, local_files)
    pad <- detect_custom_pad(paths[[2L]])
    if (is.null(pad)) {
      pad <- list(pad_token = "[PAD]", pad_id = 0L)
    }
    manifest <- list(
      id = id,
      revision = revision,
      pooling = pooling,
      prefix = if (is.null(prefix)) "" else prefix,
      max_length = as.integer(max_length),
      pad_token = pad$pad_token,
      pad_id = as.integer(pad$pad_id),
      files = list(
        file = as.list(local_files),
        remote_path = as.list(remote_files),
        bytes = as.list(unname(file.info(paths)$size)),
        sha256 = as.list(vapply(
          paths,
          digest::digest,
          character(1),
          algo = "sha256",
          file = TRUE
        ))
      )
    )
    write_custom_manifest(model_directory, manifest)
  } else {
    if (verify && !all(verify_custom_files(model_directory, manifest))) {
      sbert_abort(
        paste0(
          "Cached files no longer match the recorded manifest. Delete '",
          model_directory,
          "' and load again."
        ),
        class = "sbert_cache_invalid"
      )
    }
    # Explicit arguments override what was recorded on first use.
    if (!is.null(pooling)) {
      manifest$pooling <- pooling
    }
    if (!is.null(prefix)) {
      manifest$prefix <- prefix
    }
    if (!is.null(max_length)) {
      manifest$max_length <- as.integer(max_length)
    }
  }

  paths <- file.path(model_directory, c("model.onnx", "tokenizer.json"))
  tokenizer_instance <- load_sbert_tokenizer(paths[[2L]])
  onnx_instance <- load_sbert_onnx_model(
    paths[[1L]],
    backend = backend,
    threads = as.integer(threads)
  )
  input_names <- onnx_instance$input_names
  output_names <- onnx_instance$output_names
  if (!"last_hidden_state" %in% output_names) {
    sbert_abort(
      sprintf(
        paste0(
          "The ONNX graph outputs (%s) do not include 'last_hidden_state'. ",
          "Only encoder feature-extraction exports are supported."
        ),
        paste(output_names, collapse = ", ")
      ),
      class = "sbert_model_error"
    )
  }
  unsupported <- setdiff(
    input_names,
    c("input_ids", "attention_mask", "token_type_ids")
  )
  if (length(unsupported) > 0L) {
    sbert_abort(
      sprintf(
        "The ONNX graph requires unsupported inputs: %s.",
        paste(unsupported, collapse = ", ")
      ),
      class = "sbert_model_error"
    )
  }

  hidden <- onnx_instance$output_shapes[["last_hidden_state"]]
  dimension <- as.integer(hidden[[length(hidden)]])
  model <- structure(
    list(
      id = manifest$id,
      short_name = paste0("custom:", manifest$id),
      revision = manifest$revision,
      dimension = dimension,
      max_length = as.integer(manifest$max_length),
      pad_token = manifest$pad_token,
      pad_id = as.integer(manifest$pad_id),
      token_type_ids = "token_type_ids" %in% input_names,
      pooling = manifest$pooling,
      prefix = manifest$prefix,
      backend = backend,
      threads = as.integer(threads),
      tokenizer = tokenizer_instance,
      onnx = onnx_instance
    ),
    class = "sbert_model"
  )
  if (is.na(dimension) || dimension <= 0L) {
    # Dynamic output shape: probe the graph once to learn the dimension.
    probe <- encode_sbert_batch(model, "a", normalize = FALSE)
    model$dimension <- ncol(probe)
  }
  model
}
