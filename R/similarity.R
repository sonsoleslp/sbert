normalize_embedding_rows <- function(embeddings) {
  stopifnot(
    is.matrix(embeddings),
    is.numeric(embeddings),
    !anyNA(embeddings),
    # `range()` is an O(n) scan returning two values, so this catches Inf and
    # NaN without allocating a full logical copy of the matrix the way
    # `all(is.finite(embeddings))` would.
    all(is.finite(range(embeddings)))
  )

  n <- nrow(embeddings)
  # Compute the row norms in blocks so squaring never materializes a whole
  # `embeddings^2` copy, then divide once. The single `embeddings / norms` result
  # is unavoidable (it is the return value); the point is to avoid a *second*
  # corpus-sized transient alongside it. Byte-identical row by row.
  chunk <- 8192L
  if (n <= chunk) {
    norms <- sqrt(rowSums(embeddings^2))
  } else {
    norms <- numeric(n)
    for (start in seq.int(1L, n, chunk)) {
      idx <- start:min(start + chunk - 1L, n)
      norms[idx] <- sqrt(rowSums(embeddings[idx, , drop = FALSE]^2))
    }
  }
  if (any(norms <= 0)) {
    sbert_abort(
      "Embedding rows must have non-zero norms.",
      class = "sbert_bad_input"
    )
  }
  embeddings / norms
}

#' Compute cosine similarity between embeddings
#'
#' @description
#' `topic_similarity()` computes the cosine similarity between every row of `x`
#' and every row of `y`, or between all pairs of rows of `x` when `y` is
#' omitted. In a sentence-embedding space, the closeness of two texts in meaning
#' is measured by the cosine of the angle between their embeddings: 1 for the
#' same direction, 0 for unrelated directions, and negative values for opposed
#' ones; cosine similarity ignores vector length, so it compares texts of
#' different lengths on an equal footing.
#'
#' Rows are scaled to unit length first, so embeddings need not be normalized.
#' The result is a matrix, or with `tidy = TRUE` a long data frame with one row
#' per pair. With `top`, the data frame keeps only the nearest neighbors of each
#' row of `x`: its `top` most similar rows of `y`, most similar first, where a
#' row is not its own neighbor when `y` is omitted.
#'
#' Any embeddings can be compared: texts from [encode()], the bundled
#' [feedback_embeddings], or rows of another embedding matrix with the same
#' number of columns. To assign texts to fitted topics use
#' [predict()][predict.sbert_topic_model]; to relate the topics of a model to
#' one another use [topic_hierarchy()].
#'
#' @param x Numeric embedding matrix, or a numeric vector (one embedding).
#' @param y Numeric embedding matrix or vector, or `NULL` (default) to
#'   compare the rows of `x` with each other.
#' @param tidy `FALSE` (default) for a matrix; `TRUE` for a data frame.
#' @param top `NULL` (default) for every pair, or a whole number: with
#'   `tidy = TRUE`, the `top` most similar rows of `y` for each row of `x`.
#' @return With `tidy = FALSE`, a numeric matrix of similarities in `[-1, 1]`
#'   with one row per row of `x` and one column per row of `y` (or of `x`);
#'   a vector counts as one row. With `tidy = TRUE`, a base data frame with
#'   one row per pair and columns `from` (row of `x`), `to` (row of `y`), and
#'   `similarity`; `from` and `to` are row names when the matrices have them,
#'   else row numbers. With `top`, at most `top` rows per row of `x`, ordered
#'   by `from` and decreasing similarity (ties by position in `y`), with a
#'   `rank` column (1 for the most similar).
#' @section Conditions:
#'   `sbert_dimension_mismatch` when `x` and `y` have different numbers of
#'   columns; `sbert_bad_input` when a row is zero, or when `top` is given
#'   without `tidy = TRUE`.
#' @seealso [encode()] for embeddings; [predict()][predict.sbert_topic_model]
#'   to assign texts to topics; [topic_hierarchy()] for similarity between
#'   topics.
#' @export
#' @examples
#' # Three feedback messages compared with each other.
#' topic_similarity(head(feedback_embeddings, 3))
#' topic_similarity(head(feedback_embeddings, 3), tidy = TRUE)
#'
#' # The three nearest neighbors of each of the 600 messages.
#' neighbors <- topic_similarity(feedback_embeddings, tidy = TRUE, top = 3)
#' head(neighbors)
#'
#' # Toy vectors: rows of x against one vector y.
#' x <- rbind(c(1, 0), c(0, 1), c(1, 1))
#' topic_similarity(x, c(1, 1))
topic_similarity <- function(x, y = NULL, tidy = FALSE, top = NULL) {
  stopifnot(
    is.numeric(x),
    is.null(y) || is.numeric(y),
    "`tidy` must be TRUE or FALSE" = isTRUE(tidy) || isFALSE(tidy),
    "`top` must be NULL or a single positive whole number" =
      is.null(top) ||
        (is.numeric(top) && length(top) == 1L && is.finite(top) &&
          top >= 1 && top == as.integer(top))
  )
  if (!is.null(top) && !tidy) {
    sbert_abort("`top` applies only when `tidy = TRUE`.", class = "sbert_bad_input")
  }
  self_pairs <- is.null(y)

  if (is.null(dim(x))) {
    x <- matrix(x, nrow = 1L)
  }
  if (!is.null(y) && is.null(dim(y))) {
    y <- matrix(y, nrow = 1L)
  }
  stopifnot(is.matrix(x), is.null(y) || is.matrix(y))

  if (is.null(y)) {
    y <- x
  }
  if (ncol(x) != ncol(y)) {
    sbert_abort(
      "x and y must have the same number of columns.",
      class = "sbert_dimension_mismatch"
    )
  }

  similarity <- normalize_embedding_rows(x) %*% t(normalize_embedding_rows(y))
  if (!tidy) {
    return(similarity)
  }
  from <- rownames(x) %||% seq_len(nrow(x))
  to <- rownames(y) %||% seq_len(nrow(y))
  pairs <- data.frame(
    from = rep(from, times = length(to)),
    to = rep(to, each = length(from)),
    similarity = as.vector(unname(similarity)),
    stringsAsFactors = FALSE
  )
  if (is.null(top)) {
    return(pairs)
  }
  # Nearest neighbors: for each row of `x`, its `top` most similar rows of `y`,
  # most similar first (ties by position in `y`). Without `y`, a row is not
  # its own neighbor.
  from_index <- rep(seq_len(nrow(x)), times = nrow(y))
  to_index <- rep(seq_len(nrow(y)), each = nrow(x))
  keep <- if (self_pairs) from_index != to_index else rep(TRUE, nrow(pairs))
  pairs <- pairs[keep, , drop = FALSE]
  from_index <- from_index[keep]
  to_index <- to_index[keep]
  ordering <- order(from_index, -pairs$similarity, to_index)
  pairs <- pairs[ordering, , drop = FALSE]
  from_index <- from_index[ordering]
  pairs$rank <- stats::ave(from_index, from_index, FUN = seq_along)
  pairs <- pairs[pairs$rank <= top, , drop = FALSE]
  rownames(pairs) <- NULL
  pairs
}
