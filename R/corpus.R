#' Deduplicate a Text Corpus with Frequencies
#'
#' Collapses a character vector to its distinct non-blank texts, keeping the
#' order of first appearance and counting how often each text occurred.
#' Embedding and clustering operate on the distinct texts (so repeated
#' templates cannot drag the cluster geometry), while the returned counts
#' carry the original frequencies back into reporting, for example through
#' [topic_sizes()].
#'
#' @param text A character vector. `NA` and blank (whitespace-only) elements
#'   are dropped before deduplication.
#' @return A base data frame with one row per distinct text and columns
#'   `text` (in order of first appearance) and `n` (number of occurrences).
#' @export
#' @examples
#' dedupe(c("Very good!", "Try again.", "Very good!", NA, "  "))
dedupe <- function(text) {
  stopifnot(is.character(text), length(text) >= 1L)

  kept <- text[!is.na(text) & nzchar(trimws(text))]
  if (length(kept) == 0L) {
    stop("text contains no non-blank elements.", call. = FALSE)
  }
  counts <- table(factor(kept, levels = unique(kept)))
  data.frame(
    text = names(counts),
    n = as.integer(counts),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

#' Strip Enumeration and List Markers from Text
#'
#' Removes list and enumeration markers — `"1."`, `"2."`, `"(i)"`, `"(a)"`,
#' `"(iv)"` — from each document. The `numbers`, `roman_numerals`, and
#' `section_numbers` arguments of [topics()] clean only the extracted *terms*;
#' this cleans the source *text*, so markers no longer over-fragment
#' [segment()], skew the embeddings, or surface in
#' [representatives()][representatives]. Run it once, before embedding or
#' segmentation, as a companion to [dedupe()].
#'
#' A marker must stand alone — whitespace or a string boundary on both sides —
#' so real words in parentheses (`"(civil)"`), four-digit years (`"(2020)"`),
#' counts (`"(n=100)"`), multi-word parentheticals (`"(see Fig 1)"`), and
#' decimals (`"1.5"`) are left untouched. Removed forms are a standalone
#' one- or two-digit number followed by a period (`"1."`, `"12."`), and a
#' parenthesized one- or two-digit number, single letter, or Roman numeral up to
#' 39 (`"(1)"`, `"(a)"`, `"(iv)"`).
#'
#' @param text A character vector.
#' @return `text` with markers removed and runs of whitespace collapsed to a
#'   single space; each element trimmed.
#' @seealso [dedupe()], and the `numbers` / `roman_numerals` / `section_numbers`
#'   arguments of [topics()] for cleaning the terms rather than the text.
#' @export
#' @examples
#' strip_list_markers(c("1. background 2. methods", "(i) first (ii) second"))
#' strip_list_markers("the concept of (civil) society in (2020)")
strip_list_markers <- function(text) {
  stopifnot(is.character(text), !anyNA(text))
  if (length(text) == 0L) {
    return(text)
  }
  # A Roman numeral from 1 to 39, non-empty (the lookahead forbids the empty
  # match that the otherwise-all-optional pattern would allow).
  roman <- "(?=[ivxlcdm])x{0,3}(?:ix|iv|v?i{0,3})"
  parenthesized <- paste0("(?i:[0-9]{1,2}|[a-z]|", roman, ")")
  text <- gsub("(^|\\s)[0-9]{1,2}\\.(?=\\s|$)", " ", text, perl = TRUE)
  text <- gsub(
    paste0("(^|\\s)\\(", parenthesized, "\\)(?=\\s|$)"),
    " ", text,
    perl = TRUE
  )
  trimws(gsub("[[:space:]]+", " ", text, perl = TRUE))
}

#' Topic Sizes on the Distinct and Weighted Scales
#'
#' Returns the size of every topic as fitted (distinct documents) and,
#' when `weights` are supplied, on the weighted scale — for example the
#' original row frequencies from [dedupe()]. The gap between
#' `proportion` and `weighted_share` measures how template-driven a topic
#' is: a topic whose weighted share far exceeds its distinct share is a
#' small repertoire of heavily repeated texts.
#'
#' @param object A fitted [topics()] model.
#' @param weights Optional numeric vector with one non-negative weight per
#'   fitted document (in document order), typically the `n` column of
#'   [dedupe()].
#' @return A base data frame with one row per topic and columns `topic`,
#'   `label`, `n_documents`, and `proportion`, plus `n_weighted` and
#'   `weighted_share` when `weights` are supplied.
#' @export
#' @examples
#' text <- c(
#'   "Cats chase mice", "Dogs chase balls",
#'   "Stocks and bonds trade", "Markets price shares"
#' )
#' embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
#' fitted <- topics(text, 2, embeddings = embeddings)
#' topic_sizes(fitted, weights = c(10, 1, 1, 1))
topic_sizes <- function(object, weights = NULL) {
  stopifnot(
    inherits(object, "sbert_topic_model"),
    is.null(weights) ||
      (
        is.numeric(weights) &&
          length(weights) == nrow(object$documents) &&
          !anyNA(weights) &&
          all(is.finite(weights)) &&
          all(weights >= 0)
      )
  )

  sizes <- data.frame(
    topic = object$topics$topic,
    label = object$topics$label,
    n_documents = object$topics$n_documents,
    proportion = object$topics$proportion,
    stringsAsFactors = FALSE
  )
  if (is.null(weights)) {
    return(sizes)
  }

  weighted_totals <- vapply(
    sizes$topic,
    function(topic_id) sum(weights[object$documents$topic == topic_id]),
    numeric(1)
  )
  sizes$n_weighted <- weighted_totals
  sizes$weighted_share <- weighted_totals / sum(weighted_totals)
  sizes
}

# Accepts either a character vector (the historical input) or a data frame
# together with `column`, the name of the text column. Rows whose text is
# missing, blank, or a bibliographic placeholder cannot be modelled, so they
# are dropped once here instead of by every caller; the surviving row indices
# come back so precomputed embeddings can be subset the same way.
prepare_topic_input <- function(text, column = NULL) {
  if (!is.data.frame(text)) {
    if (!is.null(column)) {
      stop(
        "topics: 'column' applies only when the first argument is a ",
        "data frame.",
        call. = FALSE
      )
    }
    return(list(
      text = text,
      metadata = NULL,
      kept = seq_along(text),
      n_supplied = length(text)
    ))
  }

  if (is.null(column)) {
    stop(
      "topics: supply 'column' naming the text column of the data ",
      "frame, for example column = \"abstract\".",
      call. = FALSE
    )
  }
  stopifnot(is.character(column), length(column) == 1L, !is.na(column))
  if (!column %in% names(text)) {
    stop(
      sprintf(
        "topics: column '%s' not found. Available: %s.",
        column,
        paste(utils::head(names(text), 12L), collapse = ", ")
      ),
      call. = FALSE
    )
  }

  values <- text[[column]]
  if (!is.character(values)) {
    values <- as.character(values)
  }
  n_supplied <- length(values)
  kept <- which(usable_document_text(values))
  if (length(kept) < 2L) {
    stop(
      "topics: fewer than two usable documents after dropping missing, ",
      "blank, and placeholder text.",
      call. = FALSE
    )
  }
  metadata <- text[kept, setdiff(names(text), column), drop = FALSE]
  rownames(metadata) <- NULL
  list(
    text = values[kept],
    metadata = metadata,
    kept = kept,
    n_supplied = n_supplied
  )
}

# Bibliographic exports mark absent abstracts with a literal placeholder that
# would otherwise be embedded as if it were content.
usable_document_text <- function(values) {
  trimmed <- trimws(values)
  !is.na(trimmed) &
    nzchar(trimmed) &
    !toupper(trimmed) %in% c(
      "[NO ABSTRACT AVAILABLE]", "NO ABSTRACT AVAILABLE", "NA", "NULL"
    )
}

# Puts `label` directly after `topic` in any table keyed by topic id.
insert_topic_label <- function(table, labels) {
  if (is.null(table) || nrow(table) == 0L || !"topic" %in% names(table)) {
    return(table)
  }
  table$label <- labels[table$topic]
  position <- match("topic", names(table))
  reordered <- append(
    setdiff(names(table), "label"),
    "label",
    after = position
  )
  table[, reordered, drop = FALSE]
}

# The exported verb is now `stop_words()`, which collides with the argument of
# the same name; a default of `stop_words()` inside a function whose parameter
# is `stop_words` is a self-reference. Callers get the same list either way.
default_stop_words <- function() stop_words()

# Same shadowing problem as default_stop_words(): a parameter named `cache_dir`
# or `abbreviations` hides the verb of that name from its own default. These
# wrappers resolve the verb in a scope where nothing shadows it.
default_cache_dir <- function() cache_dir()

default_abbreviations <- function() abbreviations()
