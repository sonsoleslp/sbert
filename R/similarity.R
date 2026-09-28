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
    stop("Embedding rows must have non-zero norms.", call. = FALSE)
  }
  embeddings / norms
}

#' Compute Cosine Similarity
#'
#' @param x Numeric embedding matrix, or one numeric vector.
#' @param y Optional second embedding matrix or vector. When omitted, computes
#'   all pairwise similarities among rows of `x`.
#' @return A numeric similarity matrix.
#' @export
#' @examples
#' x <- rbind(c(1, 0), c(0, 1), c(1, 1))
#' topic_similarity(x)
topic_similarity <- function(x, y = NULL) {
  stopifnot(is.numeric(x), is.null(y) || is.numeric(y))

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
    stop("x and y must have the same number of columns.", call. = FALSE)
  }

  normalize_embedding_rows(x) %*% t(normalize_embedding_rows(y))
}

