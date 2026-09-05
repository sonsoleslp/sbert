# Topic-count comparison: fit the deterministic topic model across candidate
# counts and report coherence, topic_diversity, and cluster separation side by
# side, so the chosen granularity is justified by numbers rather than habit.

#' Compare Topic Counts Before Committing to One
#'
#' Fits [topics()] once per candidate topic count — deterministically,
#' on one shared set of embeddings — and returns the quality metrics that
#' justify a granularity choice: mean topic coherence, topic diversity, and
#' the share of embedding variance separated between topics. The verb
#' compares; it never chooses for you. Take the count you want out of the
#' comparison with [fitted()].
#'
#' There is no single correct topic count; this verb replaces the habit of
#' picking one by feel with a table you can defend. Coherence typically falls
#' as counts grow while separation rises, so look for the count after which
#' coherence stops improving (or starts degrading) rather than a global
#' maximum.
#'
#' @param text A character vector of documents, a data frame together with
#'   `column`, or a prepared [topic_corpus()]. Passing a corpus (or letting
#'   `compare_topics()` build one internally) segments, embeds, and tokenizes
#'   the documents once and reuses that work across every candidate, instead
#'   of re-tokenizing per candidate.
#' @param n_topics Integer vector of candidate topic counts, each at least 2
#'   and below the number of modelled units. Default `c(5, 10, 15, 20, 25, 30)`.
#' @param model A loaded sbert model, a pinned model name, or `NULL` for the
#'   session default. Ignored when `embeddings` is supplied.
#' @param embeddings Optional precomputed embedding matrix, one row per
#'   document (or per segment when `segment` is not `"document"`); supply it
#'   to avoid re-encoding.
#' @param measure Coherence measure, `"npmi"` (default) or `"umass"`.
#' @param n_terms Top terms per topic used for coherence and topic_diversity.
#'   Default `10`.
#' @param n_representatives Representative documents kept per topic in each
#'   retained model. Default `1`; raise it when the stored models are meant
#'   to be inspected rather than only compared.
#' @param keep_models Whether to retain every fitted model so the chosen
#'   granularity needs no refitting. Default `TRUE`; set `FALSE` to return
#'   only the comparison table when memory matters.
#' @param batch_size Number of texts encoded per model call when encoding is
#'   needed. Default `32`.
#' @param cores Number of forked worker processes. Default `1` (serial). Above
#'   one, the shared corpus is tokenized in parallel and the candidates — which
#'   are independent and deterministic — are fitted in parallel, on Unix-alikes
#'   (serial fallback on Windows). Results are identical for any core count.
#' @param ... Further arguments passed to [topics()] (for example
#'   `stop_words` or `weighting`).
#' @param segment The unit the candidates are fitted on, as in [topics()]:
#'   `"document"` (default), `"sentence"`, `"clause"`, or `"phrase"`. Give
#'   several levels — for example `c("document", "sentence", "clause")` — to
#'   compare the segmentations as well as the counts: every level is fitted
#'   across every candidate, the table gains a leading `segment` column, the
#'   plot draws one line per level, and [fitted()] takes `segment =` alongside
#'   `n_topics`. `max_tokens`, `merge_below`, and `min_content` then apply to
#'   the segmented levels only. With several levels, precomputed `embeddings`
#'   are a list of matrices named by level.
#' @inheritParams topics
#' @return A base data frame with one row per candidate and columns
#'   `n_topics`, `coherence` (corpus mean), `topic_diversity`, and `explained`
#'   (between-topic share of total variance), preceded by `segment` when
#'   several levels were compared. The coherence measure is recorded in the
#'   `measure` attribute. When `keep_models = TRUE` the result also carries
#'   class `sbert_topic_sweep` and the fitted models, which [fitted()]
#'   extracts and [plot.sbert_topic_sweep()] draws.
#' @seealso [fitted()] to pull one fitted model out of the comparison.
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
#' comparison <- compare_topics(text, n_topics = 2:3, embeddings = embeddings)
#' comparison
#' fitted(comparison, n_topics = 2)
#'
#' # Documents against sentences, in one table and one plot (offline: one
#' # embedding matrix per level, one row per unit of that level).
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
#' fitted(levels, n_topics = 2, segment = "sentence")
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
  ...
) {
  measure <- match.arg(measure)
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
      dots = list(...)
    ))
  }
  if (is.list(embeddings) && !is.data.frame(embeddings)) {
    stop(
      "A list of embedding matrices is only for comparing several segment ",
      "levels; supply one matrix for a single level.",
      call. = FALSE
    )
  }
  # The upper bound is the number of modelled units. At document level it is
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
        token_lists = corpus$token_lists
      )
      explained <- if (fitted$diagnostics$totss > 0) {
        fitted$diagnostics$betweenss / fitted$diagnostics$totss
      } else {
        0
      }
      data.frame(
        n_topics = candidate,
        coherence = mean(coherence$coherence),
        topic_diversity = topic_diversity(fitted, n_terms = n_terms),
        explained = explained,
        stringsAsFactors = FALSE
      )
    },
    candidates,
    models
  )
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  attr(result, "measure") <- measure
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
  dots
) {
  if (inherits(text, "sbert_topic_corpus")) {
    stop(
      "A prepared topic_corpus fixes one segmentation; pass the raw text to ",
      "compare several segment levels.",
      call. = FALSE
    )
  }
  per_level <- is.null(embeddings) ||
    (
      is.list(embeddings) && !is.data.frame(embeddings) &&
        all(segments %in% names(embeddings))
    )
  if (!per_level) {
    stop(
      "With several segment levels, `embeddings` must be a list of matrices ",
      "named by level.",
      call. = FALSE
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
            min_content = if (segmented) min_content else 0
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
      stop(
        sprintf(
          "plot(type = \"fit\"): pass n_topics = one of %s.",
          paste(candidates, collapse = ", ")
        ),
        call. = FALSE
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
    stop(
      sprintf(
        "compare_topics needs at least three units; %d supplied.",
        n_units
      ),
      call. = FALSE
    )
  }
  if (any(n_topics >= n_units)) {
    stop(
      sprintf(
        paste0(
          "Every candidate n_topics must be below the number of units ",
          "(%d); got %s."
        ),
        n_units,
        paste(n_topics[n_topics >= n_units], collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(n_topics)
}

#' Deprecated: Compare Topic Counts
#'
#' `select_topics()` is the former name of [compare_topics()]. It never
#' selected a count, it compared them, so it was renamed in sbert 0.5.4. This
#' alias forwards every argument and warns once per session.
#'
#' @param ... Passed to [compare_topics()].
#' @return See [compare_topics()].
#' @keywords internal
#' @export
select_topics <- function(...) {
  .Deprecated("compare_topics", package = "sbert")
  compare_topics(...)
}

#' Extract One Fitted Model from a Topic-Count Comparison
#'
#' Returns the model [compare_topics()] already fitted for a given topic
#' count, so choosing a granularity from the comparison table costs no
#' refitting.
#'
#' @param object A comparison returned by [compare_topics()] with
#'   `keep_models = TRUE` (the default).
#' @param ... Unused, present for generic consistency.
#' @param n_topics The topic count to extract. Must be one of the candidates
#'   in the comparison.
#' @param segment The segment level to extract when the comparison spans
#'   several (`compare_topics(segment = c(...))`); one of its levels. Leave
#'   `NULL` for a single-level comparison.
#' @return The `sbert_topic_model` fitted for that candidate.
#' @export
#' @examples
#' text <- c(
#'   "Cats chase mice", "Kittens chase mice too", "Cats nap daily",
#'   "Stocks and bonds trade", "Markets price shares", "Banks report profit"
#' )
#' embeddings <- rbind(
#'   c(1, 0, 0), c(0.98, 0.02, 0), c(0.96, 0, 0.04),
#'   c(0, 1, 0), c(0.02, 0.98, 0), c(0, 0.96, 0.04)
#' )
#' comparison <- compare_topics(
#'   text, n_topics = 2:3, embeddings = embeddings, n_terms = 3
#' )
#' fitted(comparison, n_topics = 2)
fitted.sbert_topic_sweep <- function(object, n_topics, segment = NULL, ...) {
  sweep <- object
  models <- attr(sweep, "models")
  if (is.null(models)) {
    stop(
      "fitted: this comparison kept no models. Refit with ",
      "compare_topics(..., keep_models = TRUE).",
      call. = FALSE
    )
  }
  levels <- comparison_levels(sweep)
  if (is.null(levels)) {
    if (!is.null(segment)) {
      stop(
        "fitted: this comparison has a single segment level; leave ",
        "`segment` NULL.",
        call. = FALSE
      )
    }
  } else {
    if (is.null(segment)) {
      stop(
        sprintf(
          paste0(
            "fitted: this comparison spans several segment levels (%s); ",
            "pass segment = to pick one."
          ),
          paste(levels, collapse = ", ")
        ),
        call. = FALSE
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
    stop(
      sprintf(
        "fitted: no model for n_topics = %s. Available: %s.",
        key,
        paste(names(models), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  models[[key]]
}

#' @export
print.sbert_topic_sweep <- function(x, ...) {
  measure <- attr(x, "measure")
  models <- attr(x, "models")
  cat(sprintf(
    "<sbert_topic_sweep> %d candidates, coherence measure: %s\n",
    nrow(x),
    if (is.null(measure)) "unknown" else measure
  ))
  print(as.data.frame(x), row.names = FALSE)
  if (!is.null(models)) {
    best <- which.max(x$coherence)
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

#' @export
as.data.frame.sbert_topic_sweep <- function(x, ...) {
  plain <- x
  attr(plain, "models") <- NULL
  class(plain) <- "data.frame"
  plain
}

#' Plot a Topic-Count Comparison
#'
#' `type = "metrics"` (the default) draws coherence, topic diversity, and
#' between-topic variance against the candidate topic counts, marking the
#' count with the highest coherence. A comparison over several segment levels
#' draws one line per level in each panel, told apart by colour, point shape,
#' and line type, with a legend. There is no single correct topic count; the
#' useful signal is the count after which coherence stops improving, not a
#' global maximum.
#'
#' `type = "fit"` draws the per-topic fit report of
#' [plot.sbert_topic_model()] for the retained model at `n_topics`, one
#' figure per segment level, so the same topic count can be read across
#' segmentations side by side.
#'
#' @param x A comparison returned by [compare_topics()].
#' @param type `"metrics"` (default) or `"fit"`.
#' @param main Overall title for `type = "metrics"`.
#' @param n_topics For `type = "fit"`, the candidate count whose models are
#'   drawn. Required when the comparison holds several candidates.
#' @param segment For `type = "fit"`, the segment levels to draw; defaults to
#'   every level in the comparison.
#' @param n_terms,n_representatives For `type = "fit"`, passed to
#'   [plot.sbert_topic_model()].
#' @param ... Passed to the underlying plotting calls.
#' @return `x`, invisibly.
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
      "Coherence (%s)",
      if (is.null(attr(x, "measure"))) "npmi" else attr(x, "measure")
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

  best <- which.max(x$coherence)
  draw_panel <- function(panel, index) {
    column <- panel$column
    plot(
      range(x$n_topics),
      range(x[[column]]),
      type = "n",
      xlab = "Number of topics",
      ylab = panel$ylab,
      main = column,
      ...
    )
    graphics::grid(col = "grey90", lty = 1)
    graphics::abline(v = x$n_topics[best], lty = 3, col = "grey40")
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
    sprintf(
      "%s  (highest coherence at %d topics%s)",
      main,
      x$n_topics[best],
      if (is.null(levels)) "" else sprintf(", %s level", x$segment[best])
    ),
    outer = TRUE,
    cex = 0.95,
    font = 2
  )
  invisible(x)
}
