prepare_sbert_inputs <- function(
  text,
  tokenizer_instance,
  max_length,
  pad_id = 0L,
  pad_token = "[PAD]"
) {
  stopifnot(
    is.character(text),
    length(text) >= 1L,
    !anyNA(text),
    is.environment(tokenizer_instance),
    is.numeric(max_length),
    length(max_length) == 1L,
    is.finite(max_length),
    max_length >= 2,
    max_length == as.integer(max_length),
    is.numeric(pad_id),
    length(pad_id) == 1L,
    pad_id >= 0,
    pad_id == as.integer(pad_id),
    is.character(pad_token),
    length(pad_token) == 1L,
    nzchar(pad_token)
  )

  tokenizer_instance$enable_truncation(max_length = as.integer(max_length))
  tokenizer_instance$enable_padding(
    direction = "right",
    pad_id = as.integer(pad_id),
    pad_type_id = 0L,
    pad_token = pad_token
  )
  encoded <- tokenizer_instance$encode_batch(
    text,
    is_pretokenized = FALSE,
    add_special_tokens = TRUE
  )

  input_ids <- do.call(
    rbind,
    lapply(encoded, function(item) as.integer(item$ids))
  )
  attention_mask <- do.call(
    rbind,
    lapply(encoded, function(item) as.integer(item$attention_mask))
  )
  token_type_ids <- matrix(
    0L,
    nrow = nrow(input_ids),
    ncol = ncol(input_ids)
  )

  stopifnot(
    is.matrix(input_ids),
    is.matrix(attention_mask),
    identical(dim(input_ids), dim(attention_mask)),
    identical(dim(input_ids), dim(token_type_ids)),
    !anyNA(input_ids),
    !anyNA(attention_mask),
    all(attention_mask %in% c(0L, 1L))
  )

  list(
    input_ids = input_ids,
    attention_mask = attention_mask,
    token_type_ids = token_type_ids
  )
}

#' Pool Token Embeddings into Sentence Embeddings
#'
#' Applies the pooling strategy of the loaded model — attention-mask-aware
#' mean pooling (the Sentence-BERT default) or CLS-token pooling (used by the
#' BGE and mxbai families) — and optional row-wise L2 normalization.
#'
#' @param token_embeddings Numeric array shaped batch by sequence by hidden.
#' @param attention_mask Numeric matrix shaped batch by sequence, containing
#'   only zero and one.
#' @param normalize Whether to L2-normalize every sentence vector.
#' @param method `"mean"` (default) or `"cls"` (first token).
#' @return A numeric matrix shaped batch by hidden.
#' @export
#' @examples
#' hidden <- array(1:12, dim = c(2, 3, 2))
#' mask <- matrix(c(1, 1, 0, 1, 0, 0), nrow = 2, byrow = TRUE)
#' pool(hidden, mask)
#' pool(hidden, mask, method = "cls")
pool <- function(
  token_embeddings,
  attention_mask,
  normalize = TRUE,
  method = c("mean", "cls")
) {
  method <- match.arg(method)
  stopifnot(
    is.numeric(token_embeddings),
    length(dim(token_embeddings)) == 3L,
    is.matrix(attention_mask),
    is.numeric(attention_mask),
    !anyNA(token_embeddings),
    !anyNA(attention_mask),
    all(is.finite(token_embeddings)),
    all(attention_mask %in% c(0, 1)),
    identical(dim(token_embeddings)[1:2], dim(attention_mask)),
    is.logical(normalize),
    length(normalize) == 1L,
    !is.na(normalize)
  )

  pool_impl(token_embeddings, attention_mask, normalize = normalize, method = method)
}

# The arithmetic behind pool(), without the input validation. Called directly on
# the encoding hot path, where prepare_sbert_inputs() has already validated the
# mask and the array comes straight from the ONNX session. Validating there costs
# more than the pooling itself: a full all(is.finite()) scan of a 32x256x384
# batch measured 0.0042 s against 0.0087 s for the whole computation.
pool_impl <- function(token_embeddings, attention_mask, normalize, method) {
  # Structural checks only. These are O(1) — comparing dimensions, not scanning
  # values — so the hot path keeps them. Skipping them let a wrongly shaped ONNX
  # output through, which recycled silently and returned the wrong number of
  # rows: a correspondence bug between inputs and embeddings, not a crash.
  stopifnot(
    length(dim(token_embeddings)) == 3L,
    is.matrix(attention_mask),
    identical(dim(token_embeddings)[1:2], dim(attention_mask))
  )

  batch_size <- dim(token_embeddings)[[1L]]
  sequence_length <- dim(token_embeddings)[[2L]]
  hidden_size <- dim(token_embeddings)[[3L]]

  if (sequence_length == 0L) {
    # rowsum() sees no groups at all when there are no sequence positions and
    # drops every batch row; the sweep()/apply() formulation summed an empty set
    # to zero and kept them. Preserve the original shape and values.
    pooled <- matrix(0, nrow = batch_size, ncol = hidden_size)
    if (normalize) {
      pooled <- pooled / pmax(sqrt(rowSums(pooled^2)), 1e-12)
    }
    dimnames(pooled) <- NULL
    return(pooled)
  }

  if (method == "cls") {
    pooled <- matrix(
      token_embeddings[, 1L, ],
      nrow = batch_size,
      ncol = hidden_size
    )
  } else {
    # token_embeddings is [batch, sequence, hidden]. Its first two margins are
    # adjacent in column-major order, so re-dimensioning to
    # (batch * sequence) x hidden reinterprets the buffer without permuting it.
    # Masking is then one recycled vector multiply, and the per-document sum is a
    # single C-level grouped add. This replaces sweep() + apply(., c(1,3), sum) —
    # apply() over a 3-D array is an R-level loop that also materialized a second
    # 24 MB copy — and is 6.3x faster with bit-identical output.
    flat <- token_embeddings
    dim(flat) <- c(batch_size * sequence_length, hidden_size)
    flat <- flat * as.vector(attention_mask)
    pooled <- rowsum(
      flat,
      group = rep.int(seq_len(batch_size), sequence_length),
      reorder = FALSE
    )
    dimnames(pooled) <- NULL
    token_counts <- pmax(rowSums(attention_mask), 1e-9)
    pooled <- pooled / token_counts
  }

  if (normalize) {
    row_norms <- pmax(sqrt(rowSums(pooled^2)), 1e-12)
    pooled <- pooled / row_norms
  }

  dimnames(pooled) <- NULL
  pooled
}

encode_sbert_batch <- function(model, text, normalize) {
  stopifnot(
    inherits(model, "sbert_model"),
    is.character(text),
    length(text) >= 1L,
    !anyNA(text),
    is.logical(normalize),
    length(normalize) == 1L,
    !is.na(normalize)
  )

  if (inherits(model, "sbert_static_model")) {
    pooled <- encode_static_batch(model, text)
    if (normalize) {
      pooled <- normalize_rows(pooled)
    }
    return(pooled)
  }

  inputs <- prepare_sbert_inputs(
    text,
    model$tokenizer,
    model$max_length,
    pad_id = if (is.null(model$pad_id)) 0L else model$pad_id,
    pad_token = if (is.null(model$pad_token)) "[PAD]" else model$pad_token
  )
  send_token_type_ids <- is.null(model$token_type_ids) || model$token_type_ids
  model_output <- tryCatch(
    run_sbert_onnx(model$onnx, inputs, token_type_ids = send_token_type_ids),
    error = function(error_condition) {
      stop(
        sprintf("ONNX inference failed: %s", conditionMessage(error_condition)),
        call. = FALSE
      )
    }
  )

  token_embeddings <- model_output[["last_hidden_state"]]
  if (is.null(token_embeddings)) {
    stop("The ONNX model did not return 'last_hidden_state'.", call. = FALSE)
  }
  pooled <- pool_impl(
    token_embeddings,
    inputs$attention_mask,
    normalize = normalize,
    method = if (is.null(model$pooling)) "mean" else model$pooling
  )

  # Check the pooled OUTPUT for finiteness rather than the raw batch. It is the
  # same guarantee for a fraction of the cost — a 32x384 result against a
  # 32x256x384 input, some 256x fewer elements — because any non-finite token
  # value must surface here: an unmasked Inf sums to Inf, and a masked one
  # becomes Inf * 0 = NaN. anyNA() alone missed both, which let infinities reach
  # the caller as finite-looking embeddings.
  if (!all(is.finite(pooled))) {
    stop(
      "ONNX inference produced missing or non-finite values.",
      call. = FALSE
    )
  }
  pooled
}

# The batching loop, shared by the plain and cached paths of encode().
encode_in_batches <- function(
  model,
  input_text,
  batch_size,
  normalize,
  sort_by_length
) {
  # Every sequence in a batch is padded to the longest member, so a batch costs
  # the model its maximum length, not its mean. Grouping similar lengths together
  # shrinks that padding: on clause-level segments 60.1% of all token work is
  # padding in input order against 1.6% when sorted. The permutation is inverted
  # before returning, so row order always matches the input.
  order_index <- if (sort_by_length) {
    order(nchar(input_text, type = "bytes"), method = "radix")
  } else {
    seq_along(input_text)
  }
  ordered_text <- input_text[order_index]

  positions <- seq_along(ordered_text)
  batch_groups <- split(
    positions,
    ceiling(positions / as.integer(batch_size))
  )
  embedding_batches <- lapply(
    batch_groups,
    function(index) {
      encode_sbert_batch(model, ordered_text[index], normalize = normalize)
    }
  )
  embeddings <- do.call(rbind, embedding_batches)
  if (sort_by_length) {
    embeddings <- embeddings[order(order_index), , drop = FALSE]
  }
  embeddings
}

run_sbert_onnx <- function(onnx_model, inputs, token_type_ids = TRUE) {
  stopifnot(
    is.list(inputs),
    identical(
      names(inputs),
      c("input_ids", "attention_mask", "token_type_ids")
    ),
    is.logical(token_type_ids),
    length(token_type_ids) == 1L,
    !is.na(token_type_ids)
  )

  if (token_type_ids) {
    onnxr::onnx_run(
      onnx_model,
      input_ids = inputs$input_ids,
      attention_mask = inputs$attention_mask,
      token_type_ids = inputs$token_type_ids
    )
  } else {
    onnxr::onnx_run(
      onnx_model,
      input_ids = inputs$input_ids,
      attention_mask = inputs$attention_mask
    )
  }
}

#' Encode Text with Sentence-BERT
#'
#' @param text Character vector of sentences. Empty strings are supported;
#'   missing values are rejected.
#' @param model A loaded [sbert_model][load_model()], the name of a
#'   pinned model from [models()], or `NULL` for the default
#'   `all-MiniLM-L6-v2`. Names are loaded lazily and kept in a session
#'   cache; the first use of a not-yet-installed model offers a one-time
#'   verified download (interactive prompt, or
#'   `options(sbert.download = TRUE)` in scripts).
#' @param batch_size Positive number of sentences processed per ONNX call.
#' @param normalize Whether to return row-wise L2-normalized embeddings.
#' @param prefix Text prepended to every input before tokenization. `NULL`
#'   (default) uses the model's pinned prefix (for example `"query: "` for
#'   E5 models, which require one); `""` disables prefixing.
#' @param sort_by_length When `TRUE`, group inputs of similar length into the
#'   same batch before encoding and restore the original order afterwards.
#'   Sequences in a batch are padded to the longest member, so mixed-length
#'   input makes the model compute over padding: on clause-level segments
#'   60.1% of token work is padding in input order against 1.6% when sorted,
#'   measured at 1.9x faster end to end. Whole documents of similar length gain
#'   little (1.1x). Off by default because regrouping changes batch composition,
#'   which moves embeddings by around 1e-7 — enough to flip a rare borderline
#'   topic assignment, the same trade-off as `dedupe_segments` in
#'   [topic_gamma()]. Row order of the result is unaffected.
#' @param cache Optional path to an embedding cache file. When supplied, every
#'   document is looked up by a SHA-256 digest of its own text together with the
#'   model identity, revision, dimension, maximum length, pooling method and
#'   `normalize` setting; only documents with no matching entry are encoded, and
#'   the file is updated with whatever was newly computed. Corpora are usually
#'   edited rather than replaced — a few records corrected, a year appended, rows
#'   reordered — and encoding is about 97% of the cost of a topic workflow, so
#'   reuse dominates. Changing 38 documents of 3,847 cost 0.59 s against 57 s to
#'   re-encode the corpus. Repeated documents within a single call are also
#'   encoded once (295 of the 3,847 bundled `covid` abstracts are duplicates).
#'
#'   The key deliberately excludes `batch_size` and `sort_by_length`, which shift
#'   embeddings by around 1e-7 through batch composition alone. Cached values are
#'   therefore stable to whatever computed them first rather than bit-identical
#'   to a fresh encode under different batching — the same trade-off as
#'   `sort_by_length` itself. A cache that cannot be read, or that was written
#'   for a different embedding dimension, is discarded with a warning and rebuilt
#'   rather than trusted.
#' @return A numeric matrix with one row per input and one column per
#'   embedding dimension of the loaded model.
#' @export
#' @examples
#' \dontrun{
#' model <- load_model()
#' embeddings <- encode(c("A short sentence.", "Another sentence."), model)
#'
#' # Segment-level work benefits most, because segment lengths vary widely.
#' segments <- segment(covid$Abstract[1:50], level = "clause")
#' embeddings <- encode(segments$text, model, sort_by_length = TRUE)
#'
#' # Encode once, then re-run after editing the corpus: only changed rows cost
#' # anything the second time.
#' store <- file.path(tempdir(), "covid-embeddings.rds")
#' embeddings <- encode(covid$Abstract, model, cache = store)
#' embeddings <- encode(covid$Abstract, model, cache = store)
#' }
encode <- function(
  text,
  model = NULL,
  batch_size = 32L,
  normalize = TRUE,
  prefix = NULL,
  sort_by_length = FALSE,
  cache = NULL
) {
  model <- resolve_sbert_model(model)
  stopifnot(
    is.character(text),
    !anyNA(text),
    is.numeric(batch_size),
    length(batch_size) == 1L,
    is.finite(batch_size),
    batch_size >= 1,
    batch_size == as.integer(batch_size),
    is.logical(normalize),
    length(normalize) == 1L,
    !is.na(normalize),
    is.null(prefix) ||
      (is.character(prefix) && length(prefix) == 1L && !is.na(prefix)),
    is.logical(sort_by_length),
    length(sort_by_length) == 1L,
    !is.na(sort_by_length),
    is.null(cache) ||
      (is.character(cache) && length(cache) == 1L && !is.na(cache) && nzchar(cache))
  )

  if (length(text) == 0L) {
    return(matrix(numeric(), nrow = 0L, ncol = model$dimension))
  }

  if (is.null(prefix)) {
    prefix <- if (is.null(model$prefix)) "" else model$prefix
  }
  input_text <- if (nzchar(prefix)) paste0(prefix, text) else unname(text)

  embeddings <- if (is.null(cache)) {
    encode_in_batches(
      model,
      input_text,
      batch_size = batch_size,
      normalize = normalize,
      sort_by_length = sort_by_length
    )
  } else {
    encode_with_cache(
      model,
      input_text,
      batch_size = batch_size,
      normalize = normalize,
      sort_by_length = sort_by_length,
      cache = cache
    )
  }
  rownames(embeddings) <- names(text)
  embeddings
}
