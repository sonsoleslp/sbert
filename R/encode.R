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

#' Pool token embeddings into sentence embeddings
#'
#' @description
#' `pool()` reduces the token embeddings of each text to one sentence embedding,
#' by mean or CLS pooling. A transformer encoder returns one vector per word
#' piece of a text, whereas a sentence embedding is one vector per text, and the
#' pooling rule is part of the model's definition: Sentence-BERT models average
#' the token vectors over the positions that hold real tokens (mean pooling;
#' Reimers and Gurevych, 2019), while the BGE and mxbai families take the vector
#' of the first, classification token (CLS pooling).
#'
#' It applies either rule to an array of token embeddings and its attention
#' mask, and by default scales each pooled vector to unit Euclidean (L2) length,
#' the form in which cosine similarity is a dot product. It returns a matrix
#' with one row per text. It is the step [encode()] runs after the ONNX model,
#' exposed for checking the arithmetic or for pooling token embeddings computed
#' elsewhere.
#'
#' To embed text, use [encode()], which tokenizes, runs the model, and pools
#' with the rule pinned for that model; `models(detail = TRUE)` lists each
#' model's rule.
#'
#' @param token_embeddings Numeric array of token embeddings, shaped texts x
#'   tokens x hidden dimensions.
#' @param attention_mask Numeric matrix shaped texts x tokens: 1 for a real
#'   token, 0 for padding.
#' @param normalize Scale each pooled vector to unit L2 length (default
#'   `TRUE`).
#' @param method `"mean"` (default), the average over positions with mask 1,
#'   or `"cls"`, the first token.
#' @return A numeric matrix with one row per text and one column per hidden
#'   dimension, without dimnames.
#' @seealso [encode()] for embeddings of text; [models()] for the pooling
#'   rule of each pinned model.
#' @references Reimers, N., & Gurevych, I. (2019). Sentence-BERT: Sentence
#'   embeddings using Siamese BERT-networks. *Proceedings of the 2019
#'   Conference on Empirical Methods in Natural Language Processing and the
#'   9th International Joint Conference on Natural Language Processing
#'   (EMNLP-IJCNLP)*, 3982-3992. \doi{10.18653/v1/D19-1410}
#' @export
#' @examples
#' # Two texts, three token positions, two hidden dimensions; the first text
#' # has two real tokens, the second one.
#' hidden <- array(1:12, dim = c(2, 3, 2))
#' mask <- matrix(c(1, 1, 0, 1, 0, 0), nrow = 2, byrow = TRUE)
#' pool(hidden, mask)
#' pool(hidden, mask, method = "cls")
#' pool(hidden, mask, normalize = FALSE)
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
      sbert_abort(
        sprintf("ONNX inference failed: %s", conditionMessage(error_condition)),
        class = "sbert_model_error"
      )
    }
  )

  token_embeddings <- model_output[["last_hidden_state"]]
  if (is.null(token_embeddings)) {
    sbert_abort(
      "The ONNX model did not return 'last_hidden_state'.",
      class = "sbert_model_error"
    )
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
    sbert_abort(
      "ONNX inference produced missing or non-finite values.",
      class = "sbert_model_error"
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
  # Fill one pre-allocated result matrix batch by batch, rather than collecting
  # every batch in a list and `rbind`-ing at the end — that held the whole
  # corpus of embeddings twice (the list of batches and the concatenated copy) at
  # peak. Writing into a freshly allocated matrix modifies it in place, so the
  # result is byte-identical while only one batch lives alongside it.
  embeddings <- NULL
  for (index in batch_groups) {
    batch <- encode_sbert_batch(model, ordered_text[index], normalize = normalize)
    if (is.null(embeddings)) {
      # Match the batch's storage mode so the assembled result is identical to a
      # single rbind (real embeddings are double; the tests use integer stubs).
      embeddings <- matrix(
        vector(typeof(batch), 1L),
        nrow = length(ordered_text), ncol = ncol(batch)
      )
    }
    embeddings[index, ] <- batch
  }
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

#' Encode texts as sentence embeddings
#'
#' @description
#' `encode()` returns one sentence embedding per text from a pinned model (see
#' [models()]): a point in a vector space learned so that texts with similar
#' meaning lie close together, whatever words they use. Sentence-BERT models
#' (Reimers and Gurevych, 2019) obtain such a vector by running a transformer
#' encoder over the text and pooling its token vectors; the cosine of the angle
#' between two embeddings then measures how close the two texts are in meaning.
#'
#' Each text is tokenized with the model's own tokenizer, truncated to the
#' model's maximum length, run through the ONNX graph, pooled with the model's
#' rule ([pool()]), and by default scaled to unit length. The static
#' `potion-base-8M` model instead averages looked-up token vectors and needs no
#' ONNX Runtime. With `cache`, embeddings are stored in a file keyed by text and
#' model, so encoding an edited corpus again computes only the new or changed
#' texts. The result is a numeric matrix with one row per text, in input order.
#'
#' Encoding is the expensive step of a workflow, and every analysis in the
#' package (topics, the assignment of new texts, similarity) starts from its
#' result: encode once and pass the matrix to the `embeddings` argument of
#' [topics()], [compare_topics()], [topic_corpus()],
#' [predict()][predict.sbert_topic_model], [representatives()] and
#' [topic_gamma()]. To split long documents into sentences or clauses first, use
#' [segment()]. The bundled [feedback_embeddings] matrix is the output of
#' `encode()` for 600 feedback messages and lets the examples run without a
#' model.
#'
#' @param text Character vector, one text per element. Empty strings are
#'   allowed; `NA` is not. Names become the row names of the result.
#' @param model A model from [load_model()] or [load_custom()], the name of a
#'   pinned model from [models()], or `NULL` (default) for
#'   `"all-MiniLM-L6-v2"`. A name is loaded once per session. A model that is
#'   not installed is downloaded only with consent: an interactive prompt, or
#'   `options(sbert.download = TRUE)` in a script.
#' @param batch_size Number of texts per model call (default 32).
#' @param normalize Scale each embedding to unit L2 length (default `TRUE`).
#' @param prefix Text prepended to every input. `NULL` (default) uses the
#'   model's pinned prefix (for example `"query: "` for E5 models); `""` uses
#'   none.
#' @param sort_by_length Batch texts of similar length together, which reduces
#'   computation over padding, most of all for segments of varying length
#'   (default `FALSE`). The rows keep input order, but the values can differ
#'   from an unsorted run by floating-point rounding, enough to change the
#'   assignment of a rare unit on a topic boundary.
#' @param cache `NULL` (default), or the path of an `.rds` file of stored
#'   embeddings. Texts already stored for the same model and settings are read
#'   from the file; the others are encoded once each (repeats within the call
#'   included) and added to it. A file that cannot be read, or was written for
#'   another embedding dimension, is rebuilt with a warning.
#' @return A numeric matrix with one row per text, in input order, and one
#'   column per embedding dimension of the model (the `dimensions` column of
#'   [models()]). Row names are `names(text)`. An empty `text` gives a matrix
#'   with no rows.
#' @section Conditions:
#'   `sbert_unknown_model` when `model` names no pinned model;
#'   `sbert_model_not_installed` when the model is not installed and its
#'   download is declined or not permitted; `sbert_download_failed` or
#'   `sbert_cache_invalid` when a permitted download fails or does not verify;
#'   `sbert_cache_invalid` when installed files fail verification;
#'   `sbert_runtime_missing` when ONNX Runtime is not installed;
#'   `sbert_missing_package` when the static model is loaded without
#'   jsonlite; `sbert_model_error` when the model cannot be loaded, or
#'   inference fails or returns non-finite values. Warning
#'   `sbert_cache_rebuilt` when the `cache` file is unusable.
#' @seealso [load_model()] and [models()] for the models; [segment()] to
#'   split documents first; [topic_similarity()] to compare embeddings;
#'   [topics()] to fit topics on them.
#' @references Reimers, N., & Gurevych, I. (2019). Sentence-BERT: Sentence
#'   embeddings using Siamese BERT-networks. *Proceedings of the 2019
#'   Conference on Empirical Methods in Natural Language Processing and the
#'   9th International Joint Conference on Natural Language Processing
#'   (EMNLP-IJCNLP)*, 3982-3992. \doi{10.18653/v1/D19-1410}
#' @export
#' @examples
#' # The bundled embeddings are what encode() returns for 600 feedback
#' # messages: one row per text, one column per model dimension.
#' dim(feedback_embeddings)
#' topic_similarity(head(feedback_embeddings, 3))
#'
#' \donttest{
#' if (interactive()) {
#'   model <- load_model()
#'   embeddings <- encode(c("A short sentence.", "Another sentence."), model)
#'
#'   # Segment-level work benefits most, because segment lengths vary widely.
#'   segments <- with(head(covid, 50), segment(Abstract, level = "clause"))
#'   embeddings <- with(segments, encode(text, model, sort_by_length = TRUE))
#'
#'   # Encode once, then re-run after editing the corpus: only changed rows cost
#'   # anything the second time.
#'   store <- file.path(tempdir(), "covid-embeddings.rds")
#'   embeddings <- with(covid, encode(Abstract, model, cache = store))
#'   embeddings <- with(covid, encode(Abstract, model, cache = store))
#'   unlink(store)
#' }
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
