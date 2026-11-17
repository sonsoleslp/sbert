# Topic terms are a pure function of the fitted assignments and the document
# text, so retuning them never needs the clustering — let alone the encoding —
# to run again. This is the verb that used to be reachable only as
# sbert:::topic_term_scores().

#' Compute the terms of each topic
#'
#' @description
#' `terms()` computes the ranked terms of each topic of a fitted model: the
#' words that distinguish its texts from the texts of the other topics.
#' Class-based TF-IDF (Grootendorst 2022) treats all the texts of a topic as one
#' document and weights each term by its frequency in the topic against its
#' frequency across all topics, so that a word frequent everywhere ranks low and
#' a word frequent in one topic ranks high.
#'
#' The terms describe a topic in words and complement its representative texts.
#' They depend only on the topic assignments and the text, so `terms()`
#' recomputes them under any term settings: changing the weighting, the stop
#' words, the number filters, or stemming does not refit the model or encode
#' anything. Every argument left `NULL` keeps the value the model was fitted
#' with. Besides the weight (`score`), each term has its frequency in the topic
#' and its probability within the topic (`beta`), and `sort_by = "beta"` ranks
#' the words a topic uses most rather than the most distinctive ones. The result
#' is a data frame with one row per topic and term.
#'
#' @param x A topic model fitted by [topics()].
#' @param n Terms per topic; `NULL` (default) uses the model's `n_terms`.
#' @param stop_words Words excluded from the terms; `NULL` (default) uses the
#'   model's list. See [stop_words()].
#' @param min_term_frequency Minimum corpus-wide frequency of a term.
#' @param min_token_length Minimum length of a term, in characters.
#' @param weighting Term weighting: `"ctfidf"` or `"bm25"`.
#' @param reduce_frequent_words Whether to take the square root of
#'   within-topic frequencies before weighting.
#' @param stem Whether to merge inflected forms under one Porter stem (needs
#'   the SnowballC package).
#' @param numbers,roman_numerals,section_numbers Whether to `"keep"` or
#'   `"remove"` digit-only tokens, Roman-numeral tokens, and section or list
#'   numbering.
#' @param smoothing Additive smoothing of `beta` (default 0). With 0, each
#'   topic's `beta` over its terms sums to one; a positive value reserves
#'   probability for the terms a topic does not use.
#' @param sort_by Order of the terms within a topic: `"score"` (default), the
#'   class-based weight, or `"beta"`, the probability within the topic. `n` is
#'   applied after ordering.
#' @param ... Ignored.
#' @return A base data frame with one row per topic and term, and columns
#'   `topic`, `label`, `term`, `rank`, `score` (the class-based weight),
#'   `frequency` (count within the topic), and `beta` (the probability of the
#'   term within the topic).
#' @section Conditions:
#'   An error of class `sbert_no_terms` when no term passes the filters, and
#'   `sbert_missing_package` for `stem = TRUE` without SnowballC.
#' @seealso [topics()]; [keywords()] for the keywords of single documents;
#'   [coherence()] and [topic_diversity()], which evaluate the terms;
#'   [plot()][plot.sbert_topic_model] with `type = "terms"`.
#' @references
#' Grootendorst, M. (2022). BERTopic: Neural topic modeling with a class-based
#' TF-IDF procedure. arXiv:2203.05794.
#'
#' Mendonca, M. and Figueira, A. (2025). Modeling political discourse with
#' Sentence-BERT and BERTopic. arXiv:2510.22904.
#' @importFrom stats terms
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings)
#' terms(topic_model, n = 3)
#' terms(topic_model, n = 3, weighting = "bm25", sort_by = "beta")
terms.sbert_topic_model <- function(
  x,
  n = NULL,
  stop_words = NULL,
  min_term_frequency = NULL,
  min_token_length = NULL,
  weighting = NULL,
  reduce_frequent_words = NULL,
  stem = NULL,
  numbers = NULL,
  roman_numerals = NULL,
  section_numbers = NULL,
  smoothing = 0,
  sort_by = c("score", "beta"),
  ...
) {
  sort_by <- match.arg(sort_by)
  stopifnot(inherits(x, "sbert_topic_model"))
  settings <- x$settings
  # Anything not restated keeps the value the model was fitted with.
  n <- if (is.null(n)) settings$n_terms else n
  stop_words <- if (is.null(stop_words)) settings$stop_words else stop_words
  min_term_frequency <- if (is.null(min_term_frequency)) {
    settings$min_term_frequency
  } else {
    min_term_frequency
  }
  min_token_length <- if (is.null(min_token_length)) {
    settings$min_token_length
  } else {
    min_token_length
  }
  weighting <- if (is.null(weighting)) settings$weighting else weighting
  reduce_frequent_words <- if (is.null(reduce_frequent_words)) {
    settings$reduce_frequent_words
  } else {
    reduce_frequent_words
  }
  stem <- if (is.null(stem)) settings$stem else stem
  numbers <- if (is.null(numbers)) {
    if (is.null(settings$numbers)) "keep" else settings$numbers
  } else {
    numbers
  }
  roman_numerals <- if (is.null(roman_numerals)) {
    if (is.null(settings$roman_numerals)) "keep" else settings$roman_numerals
  } else {
    roman_numerals
  }
  section_numbers <- if (is.null(section_numbers)) {
    if (is.null(settings$section_numbers)) "keep" else settings$section_numbers
  } else {
    section_numbers
  }
  stopifnot(
    is.numeric(smoothing),
    length(smoothing) == 1L,
    is.finite(smoothing),
    smoothing >= 0
  )

  n_topics <- settings$n_topics
  vocabulary_size <- length(unique(unlist(
    tokenize_topic_documents(
      x$documents$text,
      stop_words = stop_words,
      min_token_length = min_token_length,
      stem = stem,
      numbers = numbers,
      roman_numerals = roman_numerals,
      section_numbers = section_numbers
    ),
    use.names = FALSE
  )))
  # The whole vocabulary is scored first so that `n` can cut the list after
  # it has been ordered by the requested key. Taking the top n by score and
  # then re-sorting those by beta would answer a different question.
  scored <- topic_term_scores(
    text = x$documents$text,
    topic = x$documents$topic,
    n_topics = n_topics,
    n_terms = max(vocabulary_size, 1L),
    stop_words = stop_words,
    min_term_frequency = min_term_frequency,
    min_token_length = min_token_length,
    weighting = weighting,
    reduce_frequent_words = reduce_frequent_words,
    stem = stem,
    numbers = numbers,
    roman_numerals = roman_numerals,
    section_numbers = section_numbers
  )

  # p(term | topic) from the same counts the scores were built on, so `beta`
  # and `score` can never disagree about the vocabulary.
  counts <- scored$counts
  topic_totals <- rowSums(counts)
  beta_matrix <- (counts + smoothing) /
    (topic_totals + smoothing * ncol(counts))

  result <- insert_topic_label(scored$terms, x$topics$label)
  result$beta <- beta_matrix[
    cbind(result$topic, match(result$term, colnames(counts)))
  ]

  # Order within each topic by the requested key, renumber rank to match, then
  # keep the first n of each topic.
  key <- if (identical(sort_by, "beta")) result$beta else result$score
  result <- result[order(result$topic, -key, result$term), , drop = FALSE]
  result$rank <- unlist(
    lapply(rle(result$topic)$lengths, seq_len),
    use.names = FALSE
  )
  if (!is.null(n)) {
    result <- result[result$rank <= as.integer(n), , drop = FALSE]
  }
  rownames(result) <- NULL
  result
}
