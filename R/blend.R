# Context-blended segment embeddings: each unit keeps what it says beyond its
# parent document (the context-orthogonal residual) and inherits the rest from
# the document vector. Blending the residual rather than the raw unit vector
# avoids near-collinearity: a segment and its parent are already highly
# aligned, so a plain convex combination mostly re-adds shared direction and
# lets the document term wash out unit-level nuance.

#' Blend segment embeddings with their document context
#'
#' @description
#' `blend()` computes context-aware embeddings of segments: it combines what
#' each segment says beyond its parent document with the direction of the
#' document itself. A short segment is often ambiguous on its own ("It was too
#' hard."), and identical segments can occur in different documents with
#' different meanings; the parent document supplies the missing context.
#'
#' Each segment vector `u` is split into the part along its unit-length
#' document vector `d` and the residual orthogonal to it; the blend keeps
#' `alpha` of the residual and `1 - alpha` of the document direction, scaled
#' to unit length:
#' \deqn{m = \mathrm{normalize}\left(\alpha \left(u - (u \cdot d)\, d\right) +
#' (1 - \alpha)\, d\right)}{m = normalize(alpha (u - (u . d) d) + (1 - alpha) d)}
#' with `u` and `d` normalized first. `alpha = 0` returns the document vector,
#' `alpha = 1` only what the segment adds to it. Identical segments from
#' different documents therefore receive different vectors. A segment that
#' points exactly along its document receives the document vector.
#'
#' The result, a matrix with one unit-length row per segment, replaces the
#' segment embeddings in the `embeddings` argument of [topics()],
#' [representatives()] and [predict()][predict.sbert_topic_model]. To cluster
#' segments by their own meaning alone, pass the plain segment embeddings from
#' [encode()] instead.
#'
#' @param segments A data frame from [segment()], or any data frame with a
#'   numeric `document_id` and a `text` column, one row per segment.
#' @param documents The character vector of documents that was segmented;
#'   `document_id` indexes it. Needed unless both embedding matrices are given.
#' @param model A model from [load_model()], a pinned model name, or `NULL`
#'   (default) for the default model; ignored when embeddings are given.
#' @param alpha Weight of the segment's residual, in `[0, 1]` (default 0.5).
#' @param embeddings Segment embeddings, one row per row of `segments`, or
#'   `NULL` (default) to encode them. Give together with
#'   `document_embeddings`.
#' @param document_embeddings Document embeddings, one row per document, or
#'   `NULL` (default) to encode `documents`.
#' @param batch_size Texts per model call when encoding (default 32).
#' @return A numeric matrix with one unit-length row per row of `segments`
#'   and the columns of the embeddings.
#' @section Conditions:
#'   `sbert_bad_input` when only one of `embeddings` and
#'   `document_embeddings` is given, or neither they nor `documents`; when
#'   encoding, the conditions of [encode()].
#' @seealso [segment()] for the segments; [encode()] for the embeddings;
#'   [topics()] to fit topics on the blended vectors.
#' @export
#' @examples
#' segments <- segment("The model works. It is fast.", level = "sentence")
#' segment_vectors <- matrix(c(1, 0, 0.6, 0.8), nrow = 2, byrow = TRUE)
#' document_vector <- matrix(c(0, 1), nrow = 1)
#' blend(segments, embeddings = segment_vectors,
#'       document_embeddings = document_vector)
#'
#' # alpha = 0 returns the document vector for every segment.
#' blend(segments, alpha = 0, embeddings = segment_vectors,
#'       document_embeddings = document_vector)
blend <- function(
  segments,
  documents = NULL,
  model = NULL,
  alpha = 0.5,
  embeddings = NULL,
  document_embeddings = NULL,
  batch_size = 32L
) {
  stopifnot(
    is.data.frame(segments),
    all(c("document_id", "text") %in% names(segments)),
    nrow(segments) >= 1L,
    is.numeric(segments$document_id),
    !anyNA(segments$document_id),
    is.numeric(alpha),
    length(alpha) == 1L,
    is.finite(alpha),
    alpha >= 0,
    alpha <= 1
  )
  if (is.null(embeddings) != is.null(document_embeddings)) {
    sbert_abort(
      "blend: supply both 'embeddings' and 'document_embeddings', ",
      "or neither.",
      class = "sbert_bad_input"
    )
  }
  if (is.null(embeddings)) {
    if (is.null(documents)) {
      sbert_abort(
        "blend: supply 'documents' (with an optional 'model') or ",
        "both 'embeddings' and 'document_embeddings'.",
        class = "sbert_bad_input"
      )
    }
    stopifnot(is.character(documents), !anyNA(documents))
    model <- resolve_sbert_model(model)
    embeddings <- encode(
      segments$text,
      model = model,
      batch_size = batch_size
    )
    document_embeddings <- encode(
      documents,
      model = model,
      batch_size = batch_size
    )
  }
  stopifnot(
    is.matrix(embeddings),
    is.matrix(document_embeddings),
    is.numeric(embeddings),
    is.numeric(document_embeddings),
    nrow(embeddings) == nrow(segments),
    ncol(embeddings) == ncol(document_embeddings),
    max(segments$document_id) <= nrow(document_embeddings),
    min(segments$document_id) >= 1
  )

  unit_matrix <- normalize_rows(embeddings)
  parent_matrix <- normalize_rows(
    document_embeddings[segments$document_id, , drop = FALSE]
  )
  # Elementwise vector-matrix products recycle column-major, i.e. per row.
  alignment <- rowSums(unit_matrix * parent_matrix)
  residual <- unit_matrix - alignment * parent_matrix
  blended <- alpha * residual + (1 - alpha) * parent_matrix
  blended_norms <- sqrt(rowSums(blended^2))
  degenerate <- blended_norms < 1e-8
  blended[degenerate, ] <- parent_matrix[degenerate, , drop = FALSE]
  blended_norms[degenerate] <- 1
  blended / blended_norms
}

normalize_rows <- function(m) {
  norms <- sqrt(rowSums(m^2))
  norms[norms < 1e-12] <- 1
  m / norms
}
