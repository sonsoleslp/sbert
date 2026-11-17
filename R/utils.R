# Internal helpers shared across the package.

# Base R gained `%||%` only in R 4.4.0, and DESCRIPTION supports R >= 4.1.0,
# so the package defines its own. Same semantics as the base operator.
`%||%` <- function(x, y) if (is.null(x)) y else x

# Raise a classed error. Every user-facing error carries a specific class plus
# the parent class `sbert_error`, so callers and tests can catch precisely
# (`tryCatch(..., sbert_no_embeddings = ...)`) without matching message text.
# The message pieces are pasted with no separator, as stop() does.
sbert_abort <- function(..., class = "sbert_bad_input") {
  stop(errorCondition(
    paste0(...),
    class = unique(c(class, "sbert_error")),
    call = NULL
  ))
}

# Raise a classed warning, mirroring sbert_abort().
sbert_warn <- function(..., class) {
  warning(warningCondition(
    paste0(...),
    class = unique(c(class, "sbert_warning")),
    call = NULL
  ))
}
