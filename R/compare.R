# Topic-count comparison: fit the deterministic topic model across candidate
# counts and report coherence, topic_diversity, and cluster separation side by
# side, so the chosen granularity is justified by numbers rather than habit.

#' Compare numbers of topics and segmentation levels
#'
#' @description
#' `compare_topics()` fits [topics()] for every candidate number of topics, and
#' for every segmentation level in `segment`, on one shared set of embeddings,
#' and reports measures of the quality of each fit. The number of topics, like
#' the unit of analysis (the whole document or its sentences, clauses, or
#' phrases), sets the granularity of a topic model and has no single correct
#' value: fewer topics give broad themes, more topics give narrower ones, until
#' some of them split a theme into near-duplicates.
#'
#' Three measures are reported per candidate: the mean coherence of the topics'
#' terms ([coherence()]), the diversity of the terms across topics
#' ([topic_diversity()]), and the share of the embedding variance that lies
#' between topics. Coherence tends to fall and between-topic variance to rise as
#' the number of topics grows, so a useful candidate is often the count after
#' which coherence stops improving rather than the count with the highest
#' coherence. Comparing candidates on such measures is a better basis for the
#' choice than fixing a number in advance. The function compares; it does not
#' choose.
#'
#' The result is a table of class `sbert_topic_sweep` with one row per
#' candidate. The fitted candidates are kept, so a chosen one is taken out with
#' [fitted()][fitted.sbert_topic_sweep] without refitting.
#'
#' The measures are a guide; the choice should also rest on reading the
#' representative texts of the candidate models.
#'
#' @param text Documents: a character vector, a data frame together with
#'   `column`, or a corpus prepared by [topic_corpus()].
#' @param n_topics Candidate numbers of topics: distinct integers of at least
#'   2 and below the number of modeled units. Default
#'   `c(5, 10, 15, 20, 25, 30)`.
#' @param model The encoder: a model from [load_model()], a pinned model name,
#'   or `NULL` (default) for the default model. Not used when `embeddings` are
#'   given.
#' @param embeddings Optional precomputed embedding matrix, one row per
#'   modeled unit. When several `segment` levels are compared, a list of
#'   matrices named by level. Default `NULL`.
#' @param measure Coherence measure: `"npmi"` (default) or `"umass"`.
#' @param n_terms Top terms per topic used for coherence and diversity
#'   (default 10).
#' @param coherence_weight How the coherences of a candidate's topics are
#'   averaged: `"none"` (default), every topic equally, or `"size"`, each
#'   topic in proportion to its number of units, so a very small topic cannot
#'   decide the comparison.
#' @param n_representatives Representative units stored per topic in each
#'   candidate (default 1).
#' @param keep_models Whether to keep the fitted candidates (default `TRUE`).
#'   With `FALSE`, only the table is kept and [fitted()][fitted.sbert_topic_sweep]
#'   is not available.
#' @param batch_size Texts encoded per model call (default 32).
#' @param cores Number of forked worker processes for tokenization and for
#'   fitting the candidates (default 1; Unix-alikes only). Results do not
#'   depend on it.
#' @param segment Unit or units of analysis, as in [topics()]: one or more of
#'   `"document"` (default), `"sentence"`, `"clause"`, and `"phrase"`. With
#'   several levels, every level is fitted for every candidate.
#' @param ... Further arguments to [topics()], for example `stop_words` or
#'   `weighting`.
#' @inheritParams topics
#' @return An object of class `sbert_topic_sweep`: a data frame with one row
#'   per candidate and columns `n_topics`, `coherence` (the mean over the
#'   topics that can be scored, averaged as `coherence_weight` says; `NA` when
#'   no topic can be scored), `topic_diversity`, `explained` (the
#'   between-topic share of the variance), and `converged`, preceded by
#'   `segment` when several levels are compared. The coherence measure and the
#'   weighting are kept as the attributes `measure` and `coherence_weight`.
#'   [summary()][summary.sbert_topic_sweep] gives the most coherent candidate
#'   per level, [plot()][plot.sbert_topic_sweep] draws the measures, and
#'   [fitted()][fitted.sbert_topic_sweep] returns a fitted candidate.
#' @section Conditions:
#'   Errors of class `sbert_bad_input` when fewer than three units are
#'   modeled, a candidate is not below the number of units, a list of
#'   embeddings is given for a single level, several levels are given with a
#'   prepared corpus or with embeddings that are not a list named by level;
#'   and the conditions of [topics()] for each candidate.
#'   Non-convergence of a candidate is recorded in the `converged` column.
#' @seealso [topics()] to fit one model; [coherence()] and
#'   [topic_diversity()] for the measures; [topic_hierarchy()] and
#'   [reduce_topics()] to merge the topics of a fit.
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' comparison <- compare_topics(corpus, n_topics = c(4, 6, 8),
#'                              column = "translation",
#'                              embeddings = feedback_embeddings)
#' comparison
#' summary(comparison)
#' fitted(comparison, n_topics = 6)
#'
#' # Documents against sentences (one embedding matrix per level)
#' documents <- c(
#'   "Cats chase mice. Stocks and bonds trade.",
#'   "Dogs chase balls. Markets price shares.",
#'   "Kittens nap in sunshine. Banks report profit."
#' )
#' levels <- compare_topics(
#'   documents,
#'   n_topics = 2,
#'   segment = c("document", "sentence"),
#'   embeddings = list(
#'     document = rbind(c(0.7, 0.7), c(0.6, 0.8), c(0.8, 0.6)),
#'     sentence = rbind(
#'       c(1, 0), c(0, 1), c(0.9, 0.1),
#'       c(0.1, 0.9), c(0.95, 0.05), c(0.05, 0.95)
#'     )
#'   ),
#'   n_terms = 2
#' )
#' levels
compare_topics <- function(
  text,
  n_topics = c(5L, 10L, 15L, 20L, 25L, 30L),
  column = NULL,
  model = NULL,
  embeddings = NULL,
  measure = c("npmi", "umass"),
  n_terms = 10L,
  n_representatives = 1L,
  keep_models = TRUE,
  batch_size = 32L,
  cores = 1L,
  segment = c("document", "sentence", "clause", "phrase"),
  max_tokens = NULL,
  merge_below = 0L,
  min_content = 0,
  coherence_weight = c("none", "size"),
  ...
) {
  measure <- match.arg(measure)
  coherence_weight <- match.arg(coherence_weight)
  # The default is one level, but an explicit vector compares several.
  segment <- if (missing(segment)) {
    "document"
  } else {
    match.arg(segment, several.ok = TRUE)
  }
  stopifnot(
    is.numeric(n_topics),
    length(n_topics) >= 1L,
    all(is.finite(n_topics)),
    all(n_topics == as.integer(n_topics)),
    all(n_topics >= 2L),
    !anyDuplicated(n_topics)
  )
  if (length(segment) > 1L) {
    return(compare_topic_segments(
      text,
      n_topics = n_topics,
      segments = segment,
      column = column,
      model = model,
      embeddings = embeddings,
      measure = measure,
      n_terms = n_terms,
      n_representatives = n_representatives,
      keep_models = keep_models,
      batch_size = batch_size,
      cores = cores,
      max_tokens = max_tokens,
      merge_below = merge_below,
      min_content = min_content,
      coherence_weight = coherence_weight,
      dots = list(...)
    ))
  }
  if (is.list(embeddings) && !is.data.frame(embeddings)) {
    sbert_abort(
      "A list of embedding matrices is only for comparing several segment ",
      "levels; supply one matrix for a single level.",
      class = "sbert_bad_input"
    )
  }
  # The upper bound is the number of modeled units. At document level it is
  # known before any encoding; a segmented fit only knows it once the corpus
  # exists, so that case is checked below.
  if (segment == "document") {
    n_units <- if (inherits(text, "sbert_topic_corpus")) {
      length(text$text)
    } else if (is.data.frame(text)) {
      NA_integer_
    } else {
      stopifnot(is.character(text), !anyNA(text))
      length(text)
    }
    if (!is.na(n_units)) {
      validate_candidate_counts(n_topics, n_units)
    }
  }

  # Prepare the corpus once — segment, embed, and tokenize a single time — then
  # fit every candidate against it. topic_corpus() returns an existing corpus
  # unchanged, so a prepared corpus can also be passed in directly.
  dots <- list(...)
  corpus_arg_names <- intersect(
    names(dots),
    c(
      "stop_words", "min_token_length", "stem",
      "numbers", "roman_numerals", "section_numbers"
    )
  )
  corpus <- do.call(
    topic_corpus,
    c(
      list(
        text,
        column = column,
        model = model,
        embeddings = embeddings,
        batch_size = batch_size,
        cores = cores,
        segment = segment,
        max_tokens = max_tokens,
        merge_below = merge_below,
        min_content = min_content
      ),
      dots[corpus_arg_names]
    )
  )
  validate_candidate_counts(n_topics, length(corpus$text))
  model_dots <- dots[setdiff(names(dots), corpus_arg_names)]

  candidates <- sort(as.integer(n_topics))
  fit_candidate <- function(candidate) {
    do.call(
      topics,
      c(
        list(
          corpus,
          n_topics = candidate,
          n_terms = n_terms,
          n_representatives = n_representatives
        ),
        model_dots
      )
    )
  }
  # Candidates are independent and deterministic, so fitting them across forks
  # gives identical models in any order. The corpus is already prepared, so no
  # tokenization or encoding happens inside the parallel section.
  candidate_cores <- resolve_cores(cores, .Machine$integer.max)
  candidate_cores <- min(candidate_cores, length(candidates))
  models <- if (candidate_cores > 1L) {
    parallel::mclapply(candidates, fit_candidate, mc.cores = candidate_cores)
  } else {
    lapply(candidates, fit_candidate)
  }
  if (any(vapply(models, inherits, logical(1), "try-error"))) {
    models <- lapply(candidates, fit_candidate)
  }
  names(models) <- as.character(candidates)

  rows <- Map(
    function(candidate, fitted) {
      # Every candidate shares the corpus, so coherence reuses the corpus tokens
      # instead of re-tokenizing per candidate (its dominant cost otherwise).
      coherence <- coherence(
        fitted,
        measure = measure,
        n_terms = n_terms,
        token_lists = corpus$token_lists,
        weight = coherence_weight
      )
      explained <- if (fitted$diagnostics$totss > 0) {
        fitted$diagnostics$betweenss / fitted$diagnostics$totss
      } else {
        0
      }
      data.frame(
        n_topics = candidate,
        # The corpus mean over scored topics, the same number summary() prints;
        # one unscorable topic (fewer than two terms) must not void the row.
        coherence = attr(coherence, "mean_coherence"),
        topic_diversity = topic_diversity(fitted, n_terms = n_terms),
        explained = explained,
        # Forked candidates cannot pass warnings back, so non-convergence is
        # carried in the table itself.
        converged = !isFALSE(fitted$diagnostics$converged),
        stringsAsFactors = FALSE
      )
    },
    candidates,
    models
  )
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  attr(result, "measure") <- measure
  attr(result, "coherence_weight") <- coherence_weight
  # The class is always applied so fitted() keeps dispatching here and can
  # explain itself; keep_models only controls whether the models are carried.
  if (keep_models) {
    attr(result, "models") <- models
  }
  class(result) <- c("sbert_topic_sweep", class(result))
  result
}

# Several segmentation levels side by side: one single-level comparison per
# level, stacked into one table with a leading `segment` column. Models are
# kept per level so fitted(n_topics =, segment =) can pick any of them. The
# segment-only options are dropped for the document level, where they cannot
# apply.
compare_topic_segments <- function(
  text,
  n_topics,
  segments,
  column,
  model,
  embeddings,
  measure,
  n_terms,
  n_representatives,
  keep_models,
  batch_size,
  cores,
  max_tokens,
  merge_below,
  min_content,
  coherence_weight,
  dots
) {
  if (inherits(text, "sbert_topic_corpus")) {
    sbert_abort(
      "A prepared topic_corpus fixes one segmentation; pass the raw text to ",
      "compare several segment levels.",
      class = "sbert_bad_input"
    )
  }
  per_level <- is.null(embeddings) ||
    (
      is.list(embeddings) && !is.data.frame(embeddings) &&
        all(segments %in% names(embeddings))
    )
  if (!per_level) {
    sbert_abort(
      "With several segment levels, `embeddings` must be a list of matrices ",
      "named by level.",
      class = "sbert_bad_input"
    )
  }
  comparisons <- lapply(
    segments,
    function(level) {
      segmented <- level != "document"
      do.call(
        compare_topics,
        c(
          list(
            text,
            n_topics = n_topics,
            column = column,
            model = model,
            embeddings = embeddings[[level]],
            measure = measure,
            n_terms = n_terms,
            n_representatives = n_representatives,
            keep_models = keep_models,
            batch_size = batch_size,
            cores = cores,
            segment = level,
            max_tokens = if (segmented) max_tokens else NULL,
            merge_below = if (segmented) merge_below else 0L,
            min_content = if (segmented) min_content else 0,
            coherence_weight = coherence_weight
          ),
          dots
        )
      )
    }
  )
  names(comparisons) <- segments
  rows <- Map(
    function(level, comparison) {
      cbind(
        data.frame(segment = level, stringsAsFactors = FALSE),
        as.data.frame(comparison)
      )
    },
    segments,
    comparisons
  )
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  attr(result, "measure") <- measure
  attr(result, "coherence_weight") <- coherence_weight
  if (keep_models) {
    attr(result, "models") <- lapply(comparisons, attr, "models")
  }
  class(result) <- c("sbert_topic_sweep", "data.frame")
  result
}

# The segment levels a comparison spans: NULL for a single-level table.
comparison_levels <- function(x) {
  if ("segment" %in% names(x)) unique(x$segment) else NULL
}

# One fit report per segment level for the same topic count, each titled by
# its level so the figures read as a set.
plot_comparison_fit <- function(x, n_topics, segment, n_terms, n_representatives, ...) {
  candidates <- unique(x$n_topics)
  if (is.null(n_topics)) {
    if (length(candidates) > 1L) {
      sbert_abort(
        sprintf(
          "plot(type = \"fit\"): pass n_topics = one of %s.",
          paste(candidates, collapse = ", ")
        ),
        class = "sbert_bad_input"
      )
    }
    n_topics <- candidates
  }
  levels <- comparison_levels(x)
  if (is.null(levels)) {
    plot(
      stats::fitted(x, n_topics = n_topics),
      type = "fit",
      n_terms = n_terms,
      n_representatives = n_representatives,
      ...
    )
    return(invisible(x))
  }
  segment <- if (is.null(segment)) levels else match.arg(segment, levels, several.ok = TRUE)
  lapply(
    segment,
    function(level) {
      plot(
        stats::fitted(x, n_topics = n_topics, segment = level),
        type = "fit",
        n_terms = n_terms,
        n_representatives = n_representatives,
        main = sprintf(
          "%s level, %d topics. Term columns: count, TF-IDF, beta. Last column: representatives.",
          level,
          as.integer(n_topics)
        ),
        ...
      )
    }
  )
  invisible(x)
}

# Every candidate needs at least three units and must leave at least one unit
# unassigned to a topic of its own.
validate_candidate_counts <- function(n_topics, n_units) {
  if (n_units < 3L) {
    sbert_abort(
      sprintf(
        "compare_topics needs at least three units; %d supplied.",
        n_units
      ),
      class = "sbert_bad_input"
    )
  }
  if (any(n_topics >= n_units)) {
    sbert_abort(
      sprintf(
        paste0(
          "Every candidate n_topics must be below the number of units ",
          "(%d); got %s."
        ),
        n_units,
        paste(n_topics[n_topics >= n_units], collapse = ", ")
      ),
      class = "sbert_bad_input"
    )
  }
  invisible(n_topics)
}

#' Compare numbers of topics (deprecated)
#'
#' @description
#' `select_topics()` is the former name of [compare_topics()], renamed in
#' sbert 0.5.4 because the function compares candidate numbers of topics and
#' does not select one. It passes every argument to [compare_topics()] and
#' warns that it is deprecated.
#'
#' @param ... Arguments passed to [compare_topics()].
#' @return The result of [compare_topics()].
#' @section Conditions:
#'   A deprecation warning (class `deprecatedWarning`) on every call.
#' @seealso [compare_topics()].
#' @aliases sbert-deprecated
#' @examples
#' text <- c(
#'   "Cats chase mice", "Dogs chase balls", "Kittens nap in sunshine",
#'   "Stocks and bonds trade", "Markets price shares", "Banks report profit"
#' )
#' embeddings <- rbind(
#'   c(1, 0), c(0.95, 0.05), c(0.9, 0.1),
#'   c(0, 1), c(0.05, 0.95), c(0.1, 0.9)
#' )
#' # Warns, then forwards to compare_topics()
#' select_topics(text, n_topics = 2:3, embeddings = embeddings)
#' @keywords internal
#' @export
select_topics <- function(...) {
  .Deprecated("compare_topics", package = "sbert")
  compare_topics(...)
}

#' Extract a fitted model from a topic-count comparison
#'
#' @description
#' `fitted()` returns one candidate model from a [compare_topics()] comparison,
#' identical to a [topics()] fit with the same settings, without fitting it
#' again. [compare_topics()] fits a model for every candidate number of topics
#' and, by default, keeps them, so once a candidate has been chosen from the
#' comparison its model can be taken out directly.
#'
#' @param object A comparison returned by [compare_topics()] with
#'   `keep_models = TRUE` (the default).
#' @param n_topics The number of topics of the model to return; one of the
#'   candidates.
#' @param segment The segment level of the model to return, when the
#'   comparison spans several levels; `NULL` (default) for a single-level
#'   comparison.
#' @param ... Ignored.
#' @return A topic model of class `sbert_topic_model`, as returned by
#'   [topics()].
#' @section Conditions:
#'   Errors of class `sbert_no_fitted_model` when the comparison kept no
#'   models or holds no model for `n_topics`, and `sbert_bad_input` when
#'   `segment` is given for a single-level comparison or missing for a
#'   comparison of several levels.
#' @seealso [compare_topics()]; [summary()][summary.sbert_topic_sweep] for
#'   the most coherent candidate.
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' comparison <- compare_topics(corpus, n_topics = c(4, 6),
#'                              column = "translation",
#'                              embeddings = feedback_embeddings)
#' topic_model <- fitted(comparison, n_topics = 6)
#' topic_sizes(topic_model, weights = "n")
fitted.sbert_topic_sweep <- function(object, n_topics, segment = NULL, ...) {
  sweep <- object
  models <- attr(sweep, "models")
  if (is.null(models)) {
    sbert_abort(
      "fitted: this comparison kept no models. Refit with ",
      "compare_topics(..., keep_models = TRUE).",
      class = "sbert_no_fitted_model"
    )
  }
  levels <- comparison_levels(sweep)
  if (is.null(levels)) {
    if (!is.null(segment)) {
      sbert_abort(
        "fitted: this comparison has a single segment level; leave ",
        "`segment` NULL.",
        class = "sbert_bad_input"
      )
    }
  } else {
    if (is.null(segment)) {
      sbert_abort(
        sprintf(
          paste0(
            "fitted: this comparison spans several segment levels (%s); ",
            "pass segment = to pick one."
          ),
          paste(levels, collapse = ", ")
        ),
        class = "sbert_bad_input"
      )
    }
    segment <- match.arg(segment, levels)
    models <- models[[segment]]
  }
  stopifnot(
    is.numeric(n_topics),
    length(n_topics) == 1L,
    is.finite(n_topics),
    n_topics == as.integer(n_topics)
  )
  key <- as.character(as.integer(n_topics))
  if (!key %in% names(models)) {
    sbert_abort(
      sprintf(
        "fitted: no model for n_topics = %s. Available: %s.",
        key,
        paste(names(models), collapse = ", ")
      ),
      class = "sbert_no_fitted_model"
    )
  }
  models[[key]]
}

#' Print a topic-count comparison
#'
#' @description
#' `print()` shows a topic-count comparison: the coherence measure, one row per
#' candidate with its measures, and, when the fitted models are kept, the
#' [fitted()][fitted.sbert_topic_sweep] call that returns the most coherent
#' candidate.
#'
#' @param x A comparison returned by [compare_topics()].
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @seealso [compare_topics()]; [summary()][summary.sbert_topic_sweep];
#'   [as.data.frame()][as.data.frame.sbert_topic_sweep].
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' print(compare_topics(corpus, n_topics = c(4, 6), column = "translation",
#'                      embeddings = feedback_embeddings))
print.sbert_topic_sweep <- function(x, ...) {
  measure <- attr(x, "measure")
  models <- attr(x, "models")
  cat(sprintf(
    "<sbert_topic_sweep> %d candidates, coherence measure: %s%s\n",
    nrow(x),
    if (is.null(measure)) "unknown" else measure,
    if (identical(attr(x, "coherence_weight"), "size")) ", weighted by topic size" else ""
  ))
  print(as.data.frame(x), row.names = FALSE)
  if (!is.null(models)) {
    # The hint names the most coherent candidate, or the first when none has
    # a coherence score.
    best <- which.max(x$coherence)
    if (length(best) == 0L) {
      best <- 1L
    }
    level_hint <- if (is.null(comparison_levels(x))) {
      ""
    } else {
      sprintf(", segment = \"%s\"", x$segment[best])
    }
    cat(sprintf(
      "\nFitted models retained: fitted(x, n_topics = %d%s)\n",
      x$n_topics[best],
      level_hint
    ))
  }
  invisible(x)
}

#' Convert a topic-count comparison to a data frame
#'
#' @description
#' `as.data.frame()` returns the table of a comparison of candidate numbers of
#' topics as a plain data frame, without the fitted models, for reporting or for
#' joining with other results.
#'
#' @param x A comparison returned by [compare_topics()].
#' @param ... Ignored.
#' @return A base data frame with one row per candidate and columns
#'   `n_topics`, `coherence`, `topic_diversity`, `explained`, and `converged`,
#'   preceded by `segment` when several levels were compared. The attributes
#'   `measure` and `coherence_weight` are kept.
#' @seealso [compare_topics()]; [summary()][summary.sbert_topic_sweep].
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' comparison <- compare_topics(corpus, n_topics = c(4, 6),
#'                              column = "translation",
#'                              embeddings = feedback_embeddings)
#' as.data.frame(comparison)
as.data.frame.sbert_topic_sweep <- function(x, ...) {
  plain <- x
  attr(plain, "models") <- NULL
  class(plain) <- "data.frame"
  plain
}

#' Plot a topic-count comparison
#'
#' @description
#' `plot()` draws the measures of a topic-count comparison, or the fit report of
#' one of its candidates. With `type = "metrics"` (default) it draws three
#' panels against the number of topics: mean coherence, topic diversity, and the
#' share of the variance between topics, with a dotted line at the most coherent
#' candidate. A comparison of several segment levels draws one line per level,
#' told apart by color, point shape, and line type. The useful signal is usually
#' the count after which coherence stops improving, not the highest value.
#'
#' `type = "fit"` draws the fit report of [plot()][plot.sbert_topic_model]
#' for the kept model with `n_topics` topics, one figure per segment level, so
#' that one number of topics can be read across segmentations.
#'
#' @param x A comparison returned by [compare_topics()].
#' @param type `"metrics"` (default) or `"fit"`.
#' @param main Overall title for `type = "metrics"` (default
#'   `"Topic-count comparison"`).
#' @param n_topics For `type = "fit"`, the number of topics of the models to
#'   draw; required when the comparison holds several candidates. Default
#'   `NULL`.
#' @param segment For `type = "fit"`, the segment levels to draw; `NULL`
#'   (default) for every level.
#' @param n_terms,n_representatives For `type = "fit"`, terms and
#'   representatives per topic (defaults 8 and 5), passed to
#'   [plot()][plot.sbert_topic_model].
#' @param ... Passed to the underlying plotting calls.
#' @return `x`, invisibly. Called for the plot.
#' @section Conditions:
#'   An error of class `sbert_bad_input` when `type = "fit"` and `n_topics`
#'   is missing for a comparison of several candidates.
#' @seealso [compare_topics()]; [summary()][summary.sbert_topic_sweep].
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' comparison <- compare_topics(corpus, n_topics = c(4, 6, 8),
#'                              column = "translation",
#'                              embeddings = feedback_embeddings)
#' plot(comparison)
#' @export
plot.sbert_topic_sweep <- function(
  x,
  type = c("metrics", "fit"),
  main = "Topic-count comparison",
  n_topics = NULL,
  segment = NULL,
  n_terms = 8L,
  n_representatives = 5L,
  ...
) {
  type <- match.arg(type)
  if (type == "fit") {
    return(plot_comparison_fit(
      x,
      n_topics = n_topics,
      segment = segment,
      n_terms = n_terms,
      n_representatives = n_representatives,
      ...
    ))
  }
  panels <- list(
    list(column = "coherence", ylab = sprintf(
      "Coherence (%s%s)",
      if (is.null(attr(x, "measure"))) "npmi" else attr(x, "measure"),
      if (identical(attr(x, "coherence_weight"), "size")) ", size-weighted" else ""
    )),
    list(column = "topic_diversity", ylab = "Topic diversity"),
    list(column = "explained", ylab = "Variance between topics")
  )
  # One series per segment level; a single-level comparison is one series.
  levels <- comparison_levels(x)
  series <- if (is.null(levels)) {
    list(x)
  } else {
    split(as.data.frame(x), factor(x$segment, levels = levels))
  }
  colors <- topic_palette(length(series))
  shapes <- rep_len(c(19L, 17L, 15L, 18L), length(series))
  line_types <- rep_len(c(1L, 2L, 3L, 4L), length(series))

  previous <- graphics::par(
    mfrow = c(1, 3),
    mar = c(4.2, 4.4, 3.2, 1.0),
    oma = c(0, 0, 2.4, 0),
    mgp = c(2.5, 0.7, 0)
  )
  on.exit(graphics::par(previous), add = TRUE)

  # which.max() skips NA; with no coherence at all there is no best count.
  best <- which.max(x$coherence)
  draw_panel <- function(panel, index) {
    column <- panel$column
    values <- x[[column]]
    finite <- values[is.finite(values)]
    plot(
      range(x$n_topics),
      if (length(finite) > 0L) range(finite) else c(0, 1),
      type = "n",
      xlab = "Number of topics",
      ylab = panel$ylab,
      main = column,
      ...
    )
    graphics::grid(col = "grey90", lty = 1)
    if (length(finite) == 0L) {
      graphics::text(
        mean(range(x$n_topics)),
        0.5,
        "not available",
        col = "grey40"
      )
    }
    if (length(best) > 0L) {
      graphics::abline(v = x$n_topics[best], lty = 3, col = "grey40")
    }
    Map(
      function(one, position) {
        graphics::lines(
          one$n_topics,
          one[[column]],
          type = "b",
          pch = shapes[position],
          lty = line_types[position],
          lwd = 2,
          col = colors[position]
        )
      },
      series,
      seq_along(series)
    )
    if (index == 1L && !is.null(levels)) {
      graphics::legend(
        "bottomleft",
        legend = levels,
        col = colors,
        pch = shapes,
        lty = line_types,
        lwd = 2,
        bty = "n",
        cex = 0.85
      )
    }
    invisible(NULL)
  }
  Map(draw_panel, panels, seq_along(panels))

  graphics::mtext(
    if (length(best) > 0L) {
      sprintf(
        "%s  (highest coherence at %d topics%s)",
        main,
        x$n_topics[best],
        if (is.null(levels)) "" else sprintf(", %s level", x$segment[best])
      )
    } else {
      sprintf("%s  (coherence not available)", main)
    },
    outer = TRUE,
    cex = 0.95,
    font = 2
  )
  invisible(x)
}
