# Tidy accessors for the result objects. Every result class reads out as a
# base data frame through as.data.frame(), with `what =` choosing among its
# tables, so no caller ever reaches into a result with `$`.

#' Convert a topic model to a data frame
#'
#' @description
#' `as.data.frame()` returns one of the tables of a fitted topic model as a base
#' data frame. The default, `what = "documents"`, gives one row per modeled unit
#' with its topic, so that the topic of every document (or segment) can be
#' joined to other data, filtered with [subset()], or tabulated.
#'
#' The other tables are the topic sizes (`"topics"`), the stored terms
#' (`"terms"`), and the stored representative units (`"representatives"`),
#' as kept when the model was fitted. To compute terms under other settings,
#' use [terms()][terms.sbert_topic_model]; to rank representatives in another
#' way, use [representatives()].
#'
#' @param x A topic model fitted by [topics()].
#' @param row.names,optional Ignored; present for compatibility with the
#'   generic.
#' @param what Which table: `"documents"` (default), `"topics"`, `"terms"`,
#'   or `"representatives"`.
#' @param ... Ignored.
#' @return A base data frame:
#'   * `"documents"`: one row per modeled unit, with `document_id`,
#'     `document_name`, `segment` (segmented fits only), `text`, `topic`,
#'     `label`, `distance` (cosine distance to the topic center), and the
#'     columns carried from a data frame input.
#'   * `"topics"`: one row per topic, with `topic`, `label`, `n_documents`,
#'     `proportion`, and `withinss` (within-topic sum of squares).
#'   * `"terms"`: one row per topic and term, with `topic`, `label`, `term`,
#'     `rank`, `score`, and `frequency`.
#'   * `"representatives"`: one row per topic and representative unit, with
#'     `topic`, `label`, `rank`, `document_id`, `document_name`, `segment`
#'     (segmented fits only), `text`, and `distance`.
#' @seealso [topic_sizes()], [terms()][terms.sbert_topic_model],
#'   [representatives()], [predict()][predict.sbert_topic_model].
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings)
#' head(as.data.frame(topic_model))
#' as.data.frame(topic_model, what = "topics")
#' subset(as.data.frame(topic_model), topic == 6 & n > 2)
as.data.frame.sbert_topic_model <- function(
  x,
  row.names = NULL,
  optional = FALSE,
  ...,
  what = c("documents", "topics", "terms", "representatives")
) {
  what <- match.arg(what)
  table <- switch(
    what,
    documents = x$documents,
    topics = x$topics,
    terms = x$terms,
    representatives = x$representatives
  )
  table <- as.data.frame(table, stringsAsFactors = FALSE)
  rownames(table) <- NULL
  table
}

#' Convert a topic hierarchy to a data frame
#'
#' @description
#' `as.data.frame()` returns the merge table of a topic hierarchy: one row per
#' merge of the hierarchical clustering of the topic centers, in the order in
#' which the merges happen. Merges at a small height join topics whose centers
#' are nearly parallel; such topics are candidates for [reduce_topics()].
#'
#' @param x A hierarchy built by [topic_hierarchy()].
#' @param row.names,optional Ignored; present for compatibility with the
#'   generic.
#' @param ... Ignored.
#' @return A base data frame with one row per merge and columns `step`,
#'   `height` (the cosine distance at which the two branches join), `left`,
#'   and `right` (the branches, as `"topic <id> (<label>)"` or
#'   `"merge <step>"`).
#' @seealso [summary()][summary.sbert_topic_hierarchy] for the nearest
#'   neighbor of each topic; [plot()][plot.sbert_topic_hierarchy] for the
#'   dendrogram.
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings, label = "terms")
#' as.data.frame(topic_hierarchy(topic_model))
as.data.frame.sbert_topic_hierarchy <- function(
  x,
  row.names = NULL,
  optional = FALSE,
  ...
) {
  merges <- as.data.frame(x$merges, stringsAsFactors = FALSE)
  rownames(merges) <- NULL
  merges
}

#' Convert a prepared topic corpus to a data frame
#'
#' @description
#' `as.data.frame()` returns the units of a prepared corpus, one row per unit to
#' be clustered: each document, or each sentence, clause, or phrase when the
#' corpus is segmented. The table shows what [topics()] and [compare_topics()]
#' will model, including the segments a segmentation produced and the columns
#' carried from a data frame input.
#'
#' @param x A corpus prepared by [topic_corpus()].
#' @param row.names,optional Ignored; present for compatibility with the
#'   generic.
#' @param ... Ignored.
#' @return A base data frame with one row per unit and columns
#'   `document_id`, `document_name`, `segment` (segmented corpora only), and
#'   `text`, followed by the columns carried from a data frame input.
#' @seealso [topic_corpus()], [segment()].
#' @export
#' @examples
#' documents <- data.frame(
#'   id = c("a", "b"),
#'   text = c("Cats chase mice. Stocks and bonds trade.",
#'            "Dogs chase balls. Markets price shares.")
#' )
#' prepared <- topic_corpus(
#'   documents, column = "text", segment = "sentence",
#'   embeddings = rbind(c(1, 0), c(0, 1), c(0.9, 0.1), c(0.1, 0.9))
#' )
#' as.data.frame(prepared)
as.data.frame.sbert_topic_corpus <- function(
  x,
  row.names = NULL,
  optional = FALSE,
  ...
) {
  if (is.null(x$units)) {
    document_names <- names(x$text) %||% rep.int("", length(x$text))
    units <- data.frame(
      document_id = seq_along(x$text),
      document_name = unname(document_names),
      stringsAsFactors = FALSE
    )
  } else {
    units <- as.data.frame(x$units, stringsAsFactors = FALSE)
  }
  units$text <- unname(x$text)
  if (!is.null(x$metadata) && ncol(x$metadata) > 0L) {
    units <- cbind(units, x$metadata)
  }
  rownames(units) <- NULL
  stopifnot(nrow(units) == length(x$text))
  units
}

#' Summarize a topic-count comparison
#'
#' @description
#' `summary()` reduces a comparison of candidate numbers of topics to one row
#' per segment level: the range of numbers compared, the number with the highest
#' mean coherence, that candidate's diversity and between-topic variance, and
#' whether every candidate converged. The full table of candidates is given by
#' [as.data.frame()][as.data.frame.sbert_topic_sweep].
#'
#' Coherence is one guide among several; the choice of a number of topics
#' should also rest on reading the representative texts of the candidates.
#'
#' @param object A comparison returned by [compare_topics()].
#' @param ... Ignored.
#' @return A data frame of class `summary.sbert_topic_sweep` with one row per
#'   segment level and columns `segment`, `n_candidates`, `min_topics`,
#'   `max_topics`, `best_n_topics` (highest coherence; `NA` when no candidate
#'   can be scored), `coherence`, `topic_diversity`, `explained`, and
#'   `all_converged`. It prints as a table.
#' @seealso [compare_topics()], [plot()][plot.sbert_topic_sweep],
#'   [fitted()][fitted.sbert_topic_sweep].
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' comparison <- compare_topics(corpus, n_topics = c(4, 6, 8),
#'                              column = "translation",
#'                              embeddings = feedback_embeddings)
#' summary(comparison)
summary.sbert_topic_sweep <- function(object, ...) {
  table <- as.data.frame(object)
  if (!"segment" %in% names(table)) {
    # A single-level comparison records its level in the fitted models.
    models <- attr(object, "models")
    table$segment <- if (is.null(models) || length(models) == 0L) {
      NA_character_
    } else {
      topic_segmentation(models[[1L]])$segment
    }
  }
  levels <- unique(table$segment)
  rows <- lapply(levels, function(level) {
    level_rows <- table[table$segment == level, , drop = FALSE]
    scored <- which(is.finite(level_rows$coherence))
    best <- if (length(scored) == 0L) {
      NA_integer_
    } else {
      scored[which.max(level_rows$coherence[scored])]
    }
    pick <- function(column) {
      if (is.na(best)) NA_real_ else level_rows[[column]][[best]]
    }
    data.frame(
      segment = level,
      n_candidates = nrow(level_rows),
      min_topics = as.integer(min(level_rows$n_topics)),
      max_topics = as.integer(max(level_rows$n_topics)),
      best_n_topics = if (is.na(best)) NA_integer_ else
        as.integer(level_rows$n_topics[[best]]),
      coherence = pick("coherence"),
      topic_diversity = pick("topic_diversity"),
      explained = pick("explained"),
      all_converged = all(level_rows$converged %||% TRUE),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  attr(out, "measure") <- attr(object, "measure")
  attr(out, "coherence_weight") <- attr(object, "coherence_weight")
  class(out) <- c("summary.sbert_topic_sweep", "data.frame")
  out
}

#' Print a topic-count comparison summary
#'
#' @description
#' `print()` shows the coherence measure and weighting of a comparison summary
#' made by [summary()][summary.sbert_topic_sweep], followed by its table of one
#' row per segment level.
#'
#' @param x A summary returned by [summary()][summary.sbert_topic_sweep].
#' @param digits Significant digits for the measures (default 3).
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @seealso [summary.sbert_topic_sweep()].
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' comparison <- compare_topics(corpus, n_topics = c(4, 6),
#'                              column = "translation",
#'                              embeddings = feedback_embeddings)
#' print(summary(comparison), digits = 2)
print.summary.sbert_topic_sweep <- function(x, digits = 3L, ...) {
  measure <- attr(x, "measure") %||% "unknown"
  weighted <- identical(attr(x, "coherence_weight"), "size")
  cat(sprintf(
    "Topic-count comparison: highest mean %s coherence%s per level\n\n",
    measure,
    if (weighted) " (weighted by topic size)" else ""
  ))
  plain <- x
  class(plain) <- "data.frame"
  print(plain, row.names = FALSE, digits = digits)
  invisible(x)
}

#' Summarize a topic hierarchy
#'
#' @description
#' `summary()` lists every topic of a hierarchy with its nearest neighbor among
#' the other topics, the topic whose center has the smallest cosine distance to
#' its own, and the step and height at which the topic first merges in the
#' hierarchy. A topic at a small distance from its neighbor is a near-duplicate
#' of it; a topic that merges only late is distinct from all others.
#'
#' @param object A hierarchy built by [topic_hierarchy()].
#' @param ... Ignored.
#' @return A data frame of class `summary.sbert_topic_hierarchy` with one row
#'   per topic and columns `topic`, `label`, `nearest_topic`,
#'   `nearest_label`, `distance` (cosine distance between the two topic
#'   centers), `merge_step`, and `merge_height` (the first merge that includes
#'   the topic). It prints as a table.
#' @section Conditions:
#'   An error of class `sbert_bad_input` for a hierarchy built by an sbert
#'   version that did not store the topic distances; rebuild it with
#'   [topic_hierarchy()].
#' @seealso [topic_hierarchy()], [reduce_topics()],
#'   [as.data.frame()][as.data.frame.sbert_topic_hierarchy].
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings, label = "terms")
#' summary(topic_hierarchy(topic_model))
summary.sbert_topic_hierarchy <- function(object, ...) {
  distance <- object$distance
  topics <- object$topics
  if (is.null(distance) || is.null(topics)) {
    sbert_abort(
      "summary: this hierarchy was built by an older sbert version; ",
      "rebuild it with topic_hierarchy().",
      class = "sbert_bad_input"
    )
  }
  n_topics <- nrow(topics)
  others <- distance
  diag(others) <- Inf
  nearest <- max.col(-others, ties.method = "first")
  merge_matrix <- object$tree$merge
  first_merge <- vapply(
    seq_len(n_topics),
    function(topic_id) {
      which(merge_matrix[, 1L] == -topic_id | merge_matrix[, 2L] == -topic_id)[[1L]]
    },
    integer(1)
  )
  out <- data.frame(
    topic = topics$topic,
    label = topics$label,
    nearest_topic = topics$topic[nearest],
    nearest_label = topics$label[nearest],
    distance = others[cbind(seq_len(n_topics), nearest)],
    merge_step = first_merge,
    merge_height = object$tree$height[first_merge],
    stringsAsFactors = FALSE
  )
  class(out) <- c("summary.sbert_topic_hierarchy", "data.frame")
  out
}

#' Print a topic hierarchy summary
#'
#' @description
#' `print()` shows the nearest neighbor of every topic, as computed by
#' [summary()][summary.sbert_topic_hierarchy], as a table.
#'
#' @param x A summary returned by [summary()][summary.sbert_topic_hierarchy].
#' @param digits Significant digits for the distances (default 3).
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @seealso [summary.sbert_topic_hierarchy()].
#' @export
#' @examples
#' text <- c(
#'   "Cats chase mice", "Dogs chase balls", "Kittens nap in sunshine",
#'   "Stocks and bonds trade", "Markets price shares", "Banks report profit"
#' )
#' embeddings <- rbind(
#'   c(1, 0), c(0.95, 0.05), c(0.9, 0.1),
#'   c(0, 1), c(0.05, 0.95), c(0.1, 0.9)
#' )
#' tree <- topic_hierarchy(topics(text, n_topics = 3, embeddings = embeddings,
#'                                n_terms = 3))
#' print(summary(tree), digits = 2)
print.summary.sbert_topic_hierarchy <- function(x, digits = 3L, ...) {
  cat("Nearest topic of each topic (cosine distance between centers)\n\n")
  plain <- x
  class(plain) <- "data.frame"
  print(plain, row.names = FALSE, digits = digits)
  invisible(x)
}
