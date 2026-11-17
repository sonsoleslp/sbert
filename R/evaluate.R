# Intrinsic evaluation of embedding-based topic models: term coherence and
# term topic_diversity. Both are computed on the input corpus itself (no external
# reference corpus is required), matching the standard protocol used to assess
# Sentence-BERT topic models (Mimno et al. 2011; Reimers and Gurevych 2019;
# Mendonca and Figueira 2025).

# Build a document-by-term presence matrix for a fixed set of reference terms.
# Rows are documents, columns are terms, entries are TRUE when the (unique)
# tokenization of a document contains the term. Document frequencies and
# co-document frequencies are then simple matrix reductions.
topic_document_incidence <- function(
  text,
  terms,
  min_token_length,
  stem = FALSE,
  stop_words = character(),
  token_lists = NULL,
  cores = 1L,
  numbers = "keep",
  roman_numerals = "keep",
  section_numbers = "keep"
) {
  stopifnot(
    is.character(text),
    !anyNA(text),
    is.character(terms),
    !anyNA(terms),
    length(terms) >= 1L,
    is.numeric(min_token_length),
    length(min_token_length) == 1L,
    min_token_length >= 1,
    is.character(stop_words),
    !anyNA(stop_words)
  )

  reference_terms <- unique(terms)
  # Reuse the fit-time stop_words so that, under stemming, each stem's chosen
  # display surface is identical to the one in the topic term table. When a
  # prepared corpus already tokenized these documents, reuse those token lists
  # instead of tokenizing again — the presence matrix is identical either way.
  if (is.null(token_lists)) {
    token_lists <- tokenize_topic_documents(
      text,
      stop_words = stop_words,
      min_token_length = as.integer(min_token_length),
      stem = stem,
      cores = cores,
      numbers = numbers,
      roman_numerals = roman_numerals,
      section_numbers = section_numbers
    )
  }
  presence <- vapply(
    token_lists,
    function(document_tokens) {
      reference_terms %in% document_tokens
    },
    logical(length(reference_terms))
  )
  presence <- matrix(
    presence,
    nrow = length(reference_terms),
    ncol = length(text),
    dimnames = list(reference_terms, NULL)
  )
  incidence <- t(presence)
  storage.mode(incidence) <- "double"
  incidence
}

# Coherence of a single ordered set of top terms (most probable first).
score_topic_coherence <- function(
  term_indices,
  document_frequency,
  co_document_frequency,
  n_documents,
  measure,
  smoothing
) {
  n_words <- length(term_indices)
  if (n_words < 2L) {
    return(NA_real_)
  }

  pairs <- utils::combn(n_words, 2L)
  earlier <- term_indices[pairs[1L, ]]
  later <- term_indices[pairs[2L, ]]
  co_counts <- co_document_frequency[cbind(earlier, later)]

  pair_scores <- if (measure == "umass") {
    # UMass coherence (Mimno et al. 2011): the more-probable word of each pair
    # supplies the denominator document frequency.
    log((co_counts + smoothing) / document_frequency[earlier])
  } else {
    # Normalized pointwise mutual information, bounded in [-1, 1]. The two
    # limiting cases are handled exactly: terms that never co-occur score -1,
    # terms that always co-occur score 1.
    probability_earlier <- document_frequency[earlier] / n_documents
    probability_later <- document_frequency[later] / n_documents
    joint_probability <- co_counts / n_documents
    interior <- joint_probability > 0 & joint_probability < 1
    npmi <- ifelse(joint_probability <= 0, -1, 1)
    npmi[interior] <- log(
      joint_probability[interior] /
        (probability_earlier[interior] * probability_later[interior])
    ) / -log(joint_probability[interior])
    npmi
  }
  mean(pair_scores)
}

#' Score the coherence of topics
#'
#' @description
#' `coherence()` scores the coherence of each topic of a fitted model: whether
#' the top terms of the topic tend to occur in the same texts. A topic whose
#' terms co-occur is more likely to be interpretable as one subject than a topic
#' whose terms rarely appear together, and coherence is the usual intrinsic
#' measure of topic quality, computed from the corpus itself without external
#' judgments.
#'
#' Each topic is scored from its top `n_terms` terms and the co-occurrence of
#' those terms in the modeled units (documents, or segments of a segmented
#' model). Two measures are available: normalized pointwise mutual information
#' (NPMI; Bouma 2009), the mean over term pairs of how much more often two terms
#' co-occur than expected, bounded between -1 and 1; and UMass coherence (Mimno
#' et al. 2011), the mean log ratio of the number of units holding both terms of
#' a pair to the number holding the higher-ranked one, usually negative. For
#' both, larger values are more coherent. The result is a table with one row per
#' topic; the mean over topics is kept with it, and is what [compare_topics()]
#' and [summary()][summary.sbert_topic_model] report.
#'
#' Coherence is computed from words, while the topics are formed from
#' embeddings, so a topic of short texts that share meaning but not vocabulary
#' can score low. It complements reading the representative texts and does
#' not replace it.
#'
#' @param object A topic model fitted by [topics()].
#' @param measure `"npmi"` (default) or `"umass"`.
#' @param n_terms Top terms per topic to score (default 10), capped at the
#'   terms a topic has.
#' @param smoothing Count added to each co-occurrence count for UMass
#'   (default 1).
#' @param token_lists Optional precomputed token lists, one per modeled unit,
#'   as held by a [topic_corpus()]; `NULL` (default) tokenizes the text. The
#'   scores are the same either way.
#' @param cores Number of forked worker processes for tokenization (default
#'   1; Unix-alikes only). Results do not depend on it.
#' @param weight How topic scores are averaged into the mean: `"none"`
#'   (default), every topic equally, or `"size"`, each topic in proportion to
#'   its number of units, so that a very small topic of near-identical texts
#'   cannot move the mean.
#' @return A base data frame with one row per topic and columns `topic`,
#'   `label`, `measure`, `n_terms` (terms scored), and `coherence` (`NA` for a
#'   topic with fewer than two terms). The mean over the scored topics is
#'   attached as the attribute `mean_coherence` (`NA` when no topic can be
#'   scored) and the averaging as `weight`; [summary()][summary.sbert_topic_model]
#'   prints the mean.
#' @seealso [topic_diversity()]; [summary()][summary.sbert_topic_model] for
#'   the model report; [compare_topics()] to compare numbers of topics.
#' @references
#' Bouma, G. (2009). Normalized (pointwise) mutual information in collocation
#' extraction. *Proceedings of GSCL*, 31--40.
#'
#' Mimno, D., Wallach, H. M., Talley, E., Leenders, M., and McCallum, A.
#' (2011). Optimizing semantic coherence in topic models. *Proceedings of
#' EMNLP 2011*, 262--272.
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings)
#' coherence(topic_model)
#' coherence(topic_model, measure = "umass", weight = "size")
coherence <- function(
  object,
  measure = c("npmi", "umass"),
  n_terms = 10L,
  smoothing = 1,
  token_lists = NULL,
  cores = 1L,
  weight = c("none", "size")
) {
  measure <- match.arg(measure)
  weight <- match.arg(weight)
  stopifnot(
    inherits(object, "sbert_topic_model"),
    is.numeric(n_terms),
    length(n_terms) == 1L,
    is.finite(n_terms),
    n_terms >= 1,
    n_terms == as.integer(n_terms),
    is.numeric(smoothing),
    length(smoothing) == 1L,
    is.finite(smoothing),
    smoothing > 0
  )

  topic_ids <- object$topics$topic
  ranked_terms <- object$terms
  reference_terms <- unique(ranked_terms$term)
  incidence <- topic_document_incidence(
    object$documents$text,
    reference_terms,
    object$settings$min_token_length,
    stem = isTRUE(object$settings$stem),
    stop_words = if (is.null(object$settings$stop_words)) {
      character()
    } else {
      object$settings$stop_words
    },
    token_lists = token_lists,
    cores = cores,
    numbers = if (is.null(object$settings$numbers)) "keep" else object$settings$numbers,
    roman_numerals = if (is.null(object$settings$roman_numerals)) "keep" else object$settings$roman_numerals,
    section_numbers = if (is.null(object$settings$section_numbers)) "keep" else object$settings$section_numbers
  )
  document_frequency <- colSums(incidence)
  co_document_frequency <- crossprod(incidence)
  n_documents <- nrow(incidence)
  term_position <- seq_len(ncol(incidence))
  names(term_position) <- colnames(incidence)

  scores <- vapply(
    topic_ids,
    function(topic_id) {
      topic_terms <- ranked_terms[ranked_terms$topic == topic_id, , drop = FALSE]
      topic_terms <- topic_terms[order(topic_terms$rank), , drop = FALSE]
      selected <- utils::head(topic_terms$term, as.integer(n_terms))
      term_indices <- term_position[selected]
      score_topic_coherence(
        term_indices = unname(term_indices),
        document_frequency = document_frequency,
        co_document_frequency = co_document_frequency,
        n_documents = n_documents,
        measure = measure,
        smoothing = smoothing
      )
    },
    numeric(1)
  )
  terms_used <- vapply(
    topic_ids,
    function(topic_id) {
      min(
        as.integer(n_terms),
        sum(ranked_terms$topic == topic_id)
      )
    },
    integer(1)
  )

  result <- data.frame(
    topic = topic_ids,
    label = object$topics$label,
    measure = measure,
    n_terms = terms_used,
    coherence = scores,
    stringsAsFactors = FALSE
  )
  # A topic with fewer than two scorable terms has no coherence (NA by
  # definition), so the corpus mean is taken over the topics that do; with
  # none it is NA rather than the NaN of an empty mean.
  is_scored <- !is.na(scores)
  attr(result, "mean_coherence") <- if (!any(is_scored)) {
    NA_real_
  } else if (weight == "size") {
    stats::weighted.mean(
      scores[is_scored],
      as.numeric(object$topics$n_documents)[is_scored]
    )
  } else {
    mean(scores[is_scored])
  }
  attr(result, "weight") <- weight
  result
}

#' Measure the diversity of topic terms
#'
#' @description
#' `topic_diversity()` measures the diversity of topic terms (Dieng et al.
#' 2020): it pools the top `n_terms` terms of every topic and returns the
#' proportion of them that are distinct. A value near one means that the topics
#' are described by different words; a low value means that several topics
#' repeat the same words and may be redundant.
#'
#' It returns a single number between 0 and 1 and complements [coherence()],
#' which scores each topic on its own.
#'
#' @param object A topic model fitted by [topics()].
#' @param n_terms Top terms per topic to pool (default 10), capped at the
#'   terms a topic has.
#' @return A single number between 0 and 1.
#' @section Conditions:
#'   An error of class `sbert_no_terms` when the model has no terms.
#' @seealso [coherence()]; [summary()][summary.sbert_topic_model];
#'   [compare_topics()], which reports both measures per candidate.
#' @references
#' Dieng, A. B., Ruiz, F. J. R., and Blei, D. M. (2020). Topic modeling in
#' embedding spaces. *Transactions of the Association for Computational
#' Linguistics*, 8, 439--453. \doi{10.1162/tacl_a_00325}
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings)
#' topic_diversity(topic_model)
#' topic_diversity(topic_model, n_terms = 5)
topic_diversity <- function(object, n_terms = 10L) {
  stopifnot(
    inherits(object, "sbert_topic_model"),
    is.numeric(n_terms),
    length(n_terms) == 1L,
    is.finite(n_terms),
    n_terms >= 1,
    n_terms == as.integer(n_terms)
  )

  ranked_terms <- object$terms
  pooled_terms <- unlist(
    lapply(
      object$topics$topic,
      function(topic_id) {
        topic_terms <- ranked_terms[ranked_terms$topic == topic_id, , drop = FALSE]
        topic_terms <- topic_terms[order(topic_terms$rank), , drop = FALSE]
        utils::head(topic_terms$term, as.integer(n_terms))
      }
    ),
    use.names = FALSE
  )
  if (length(pooled_terms) == 0L) {
    sbert_abort(
      "The topic model has no terms to evaluate.",
      class = "sbert_no_terms"
    )
  }
  length(unique(pooled_terms)) / length(pooled_terms)
}

#' Summarize a topic model
#'
#' @description
#' `summary()` reports the quality of a fitted topic model: the number of
#' documents (and segments), topics, and the embedding model; the share of the
#' embedding variance between topics; the mean coherence of the topics' terms;
#' and the diversity of the terms. Below this overview, a table gives the size
#' and coherence of every topic, so that small or incoherent topics stand out. A
#' fit whose k-means did not converge is reported as such.
#'
#' The result is an object that prints as the report; calling `summary()`
#' does not print by itself.
#'
#' @param object A topic model fitted by [topics()].
#' @param measure Coherence measure passed to [coherence()]: `"npmi"`
#'   (default) or `"umass"`.
#' @param n_terms Top terms per topic used for coherence and diversity
#'   (default 10).
#' @param ... Ignored.
#' @return A data frame of class `summary.sbert_topic_model` with one row per
#'   topic and columns `topic`, `label`, `n_documents`, `proportion`, and
#'   `coherence`. The overview is kept with it and printed above the table;
#'   [as.data.frame()] returns the table as a plain data frame.
#' @section Conditions:
#'   An error of class `sbert_no_terms` when the model has no terms.
#' @seealso [coherence()] and [topic_diversity()] for the measures;
#'   [topic_sizes()]; [print.summary.sbert_topic_model()].
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings)
#' summary(topic_model)
#' as.data.frame(summary(topic_model))
summary.sbert_topic_model <- function(
  object,
  measure = c("npmi", "umass"),
  n_terms = 10L,
  ...
) {
  measure <- match.arg(measure)
  coherence <- coherence(object, measure = measure, n_terms = n_terms)
  topic_diversity <- topic_diversity(object, n_terms = n_terms)
  explained <- if (object$diagnostics$totss > 0) {
    object$diagnostics$betweenss / object$diagnostics$totss
  } else {
    0
  }

  quality <- data.frame(
    topic = object$topics$topic,
    label = object$topics$label,
    n_documents = object$topics$n_documents,
    proportion = object$topics$proportion,
    coherence = coherence$coherence,
    stringsAsFactors = FALSE
  )
  segmented <- is_segmented_topic_model(object)
  attr(quality, "overview") <- list(
    n_documents = length(unique(object$documents$document_id)),
    n_segments = if (segmented) nrow(object$documents) else NA_integer_,
    segment = topic_segmentation(object)$segment,
    n_topics = nrow(object$topics),
    model = object$model$id,
    explained = explained,
    measure = measure,
    mean_coherence = attr(coherence, "mean_coherence"),
    topic_diversity = topic_diversity,
    n_terms = as.integer(n_terms),
    converged = object$diagnostics$converged %||% NA
  )
  class(quality) <- c("summary.sbert_topic_model", "data.frame")
  quality
}

#' Print a topic model summary
#'
#' @description
#' `print()` shows the overview of a topic model summary (documents, segments,
#' topics, model, between-topic share of the variance, mean coherence, topic
#' diversity, and a note when k-means did not converge) followed by the table of
#' topics.
#'
#' @param x A summary returned by [summary()][summary.sbert_topic_model].
#' @param digits Significant digits in the table of topics (default 4).
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @seealso [summary.sbert_topic_model()].
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings)
#' print(summary(topic_model), digits = 2)
print.summary.sbert_topic_model <- function(x, digits = 4L, ...) {
  overview <- attr(x, "overview")
  cat("Semantic topic model summary\n")
  cat(sprintf("  documents:            %d\n", as.integer(overview$n_documents)))
  if (!is.na(overview$n_segments)) {
    cat(sprintf(
      "  segments:             %d (%s level)\n",
      as.integer(overview$n_segments),
      overview$segment
    ))
  }
  cat(sprintf(
    paste0(
      "  topics:               %d\n",
      "  model:                %s\n",
      "  between/total SS:     %.1f%%\n",
      "  mean %-5s coherence:  %.4f\n",
      "  topic diversity:      %.3f (top %d terms)\n"
    ),
    as.integer(overview$n_topics),
    overview$model,
    100 * overview$explained,
    overview$measure,
    overview$mean_coherence,
    overview$topic_diversity,
    overview$n_terms
  ))
  if (isFALSE(overview$converged)) {
    cat("  k-means:              did not converge (raise iter_max)\n")
  }
  cat("\n")
  plain <- x
  attr(plain, "overview") <- NULL
  class(plain) <- "data.frame"
  print(plain, row.names = FALSE, digits = digits)
  invisible(x)
}
