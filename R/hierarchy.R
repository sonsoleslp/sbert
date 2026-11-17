# Topic hierarchy and reduction: agglomerative clustering of topic centroids
# (cosine distance, deterministic) exposes which topics are near-duplicates
# and which are genuinely distinct, and cutting the tree merges a fitted
# model down to fewer topics without re-running k-means.

# A topic is named by the unit nearest its centroid: a sentence (or document)
# says what the topic is about, where its top words only hint at it. The text
# is shortened to `width` characters at a word boundary so the label fits a
# table cell or a plot title. A topic with no units keeps a placeholder.
topic_labels_from_representatives <- function(representatives, n_topics, width = 60L) {
  vapply(
    seq_len(n_topics),
    function(topic_id) {
      central <- representatives$text[
        representatives$topic == topic_id & representatives$rank == 1L
      ]
      if (length(central) == 0L) {
        sprintf("topic_%d", topic_id)
      } else {
        shorten_topic_label(central[[1L]], width)
      }
    },
    character(1)
  )
}

shorten_topic_label <- function(text, width) {
  text <- gsub("[[:space:]]+", " ", trimws(text))
  if (nchar(text) <= width) {
    return(text)
  }
  clipped <- substr(text, 1L, width - 3L)
  # Cut at the last space unless that would drop more than half the label.
  boundary <- regexpr(" [^ ]*$", clipped)
  if (boundary > width %/% 2L) {
    clipped <- substr(clipped, 1L, boundary - 1L)
  }
  paste0(clipped, "...")
}

# `label` is recorded in the model's settings; models saved before the
# setting existed were labeled by their words.
topic_labels_for <- function(label, terms, representatives, n_topics) {
  if (identical(label %||% "terms", "terms")) {
    topic_labels_from_terms(terms, n_topics)
  } else {
    topic_labels_from_representatives(representatives, n_topics)
  }
}

topic_labels_from_terms <- function(terms, n_topics) {
  vapply(
    seq_len(n_topics),
    function(topic_id) {
      label_terms <- terms$term[terms$topic == topic_id & terms$rank <= 3L]
      if (length(label_terms) == 0L) {
        sprintf("topic_%d", topic_id)
      } else {
        paste(label_terms, collapse = " / ")
      }
    },
    character(1)
  )
}

topic_center_distance <- function(object) {
  centers <- normalize_rows(object$centers)
  cosine_distance <- 1 - tcrossprod(centers)
  cosine_distance[cosine_distance < 0] <- 0
  cosine_distance
}

hierarchy_tree <- function(object, method) {
  cosine_distance <- topic_center_distance(object)
  tree <- stats::hclust(stats::as.dist(cosine_distance), method = method)
  tree$labels <- topic_title(object$topics$topic, object$topics$label, 40L)
  tree
}

#' Build the hierarchy of the topics of a model
#'
#' @description
#' `topic_hierarchy()` clusters the topic centers of a model hierarchically,
#' showing which topics are nearest neighbors, in what order they would merge,
#' and at what distance. The topics of a model are not equally distinct: some
#' lie close together in the embedding space and describe facets of one broader
#' theme, while others stand apart. Topics that merge early, at a small
#' distance, are near-duplicates, which suggests that the number of topics is
#' finer than the data support.
#'
#' It computes the cosine distances between the topic centers and clusters them
#' with [stats::hclust()]. The result, an object of class
#' `sbert_topic_hierarchy`, is deterministic. Use it to choose a smaller number
#' of topics for [reduce_topics()], or to report how the topics group into
#' themes.
#'
#' @param object A topic model fitted by [topics()].
#' @param method Agglomeration method passed to [stats::hclust()] (default
#'   `"average"`).
#' @return An object of class `sbert_topic_hierarchy`.
#'   [as.data.frame()][as.data.frame.sbert_topic_hierarchy] gives the merge
#'   table, one row per merge; [summary()][summary.sbert_topic_hierarchy]
#'   gives the nearest neighbor of every topic; [plot()][plot.sbert_topic_hierarchy]
#'   draws the dendrogram.
#' @section Conditions:
#'   An error of class `sbert_bad_input` when the model has fewer than two
#'   topics.
#' @seealso [reduce_topics()] to merge topics; [compare_topics()] to compare
#'   numbers of topics; [topic_similarity()] for cosine similarities between
#'   embeddings.
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings, label = "terms")
#' tree <- topic_hierarchy(topic_model)
#' tree
#' summary(tree)
topic_hierarchy <- function(object, method = "average") {
  stopifnot(
    inherits(object, "sbert_topic_model"),
    is.character(method),
    length(method) == 1L
  )
  if (nrow(object$topics) < 2L) {
    sbert_abort(
      "A topic hierarchy needs at least two topics.",
      class = "sbert_bad_input"
    )
  }
  tree <- hierarchy_tree(object, method)
  branch_name <- function(node) {
    if (node < 0L) {
      sprintf("topic %d (%s)", -node, object$topics$label[-node])
    } else {
      sprintf("merge %d", node)
    }
  }
  merges <- data.frame(
    step = seq_len(nrow(tree$merge)),
    height = tree$height,
    left = vapply(tree$merge[, 1L], branch_name, character(1)),
    right = vapply(tree$merge[, 2L], branch_name, character(1)),
    stringsAsFactors = FALSE
  )
  structure(
    list(
      merges = merges,
      tree = tree,
      n_topics = nrow(object$topics),
      topics = object$topics[, c("topic", "label")],
      distance = unname(topic_center_distance(object))
    ),
    class = "sbert_topic_hierarchy"
  )
}

#' Print a topic hierarchy
#'
#' @description
#' `print()` shows a topic hierarchy: the number of topics and merges, and the
#' merge table: one row per merge, with the cosine distance at which it happens
#' and the two branches it joins.
#'
#' @param x A hierarchy built by [topic_hierarchy()].
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @seealso [topic_hierarchy()];
#'   [as.data.frame()][as.data.frame.sbert_topic_hierarchy];
#'   [summary()][summary.sbert_topic_hierarchy].
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
#' print(tree)
print.sbert_topic_hierarchy <- function(x, ...) {
  cat(sprintf(
    "<sbert_topic_hierarchy> %d topics, %d merges (cosine distance)\n\n",
    x$n_topics,
    nrow(x$merges)
  ))
  print(x$merges, row.names = FALSE)
  invisible(x)
}

#' Plot a topic hierarchy as a dendrogram
#'
#' @description
#' `plot()` draws the hierarchy of the topics as a dendrogram with the topic
#' labels as leaves and the cosine distance between topic centers on the
#' vertical axis. Topics joined low in the tree are near-duplicates; topics
#' joined only near the top are distinct from the rest.
#'
#' @param x A hierarchy built by [topic_hierarchy()].
#' @param main Plot title (default `"Topic hierarchy"`).
#' @param cex Size of the leaf labels (default 0.8).
#' @param ... Passed to the `plot()` method of [stats::hclust()].
#' @return `x`, invisibly. Called for the plot.
#' @seealso [topic_hierarchy()]; [summary()][summary.sbert_topic_hierarchy];
#'   [reduce_topics()].
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings, label = "terms")
#' plot(topic_hierarchy(topic_model))
plot.sbert_topic_hierarchy <- function(
  x,
  main = "Topic hierarchy",
  cex = 0.8,
  ...
) {
  # The leaf labels hang below the tree, so the bottom margin grows with them.
  bottom <- 1 + 0.45 * cex * max(nchar(x$tree$labels))
  previous <- graphics::par(mar = c(bottom, 4.2, 2.6, 0.6), mgp = c(2.4, 0.6, 0))
  on.exit(graphics::par(previous), add = TRUE)
  plot(
    x$tree,
    hang = -1,
    main = main,
    sub = "",
    xlab = "",
    ylab = "Cosine distance",
    cex = cex,
    font.main = 2,
    adj = 0.5,
    ...
  )
  invisible(x)
}

#' Merge the topics of a model into fewer topics
#'
#' @description
#' `reduce_topics()` merges the closest topics of a fitted model into `n_topics`
#' topics, giving a coarser model in which every document keeps its place:
#' documents that shared a topic still share one. A model with more topics than
#' the data support has near-duplicate topics that divide one theme between
#' them; merging them differs from fitting a new model with fewer topics, in
#' which documents may be regrouped.
#'
#' It cuts the hierarchy of [topic_hierarchy()] into `n_topics` groups and
#' merges the topics within each group. The new topic centers are the normalized
#' means of their members' embeddings, and the terms, labels, sizes,
#' representatives, and sums of squares are computed again for the merged
#' topics. The result is a topic model like any other, so every verb applies to
#' it. Names given with [name_topics()] are dropped, because the merged topics
#' need new ones.
#'
#' @param object A topic model fitted by [topics()].
#' @param n_topics Number of topics after merging: at least 2 and below the
#'   current number.
#' @param embeddings The embedding matrix the model was fitted on. Needed only
#'   for a model fitted with `keep_embeddings = FALSE`. Default `NULL`.
#' @param method Agglomeration method passed to [stats::hclust()] (default
#'   `"average"`).
#' @return A topic model of class `sbert_topic_model` with `n_topics` topics,
#'   structured as a [topics()] fit.
#' @section Conditions:
#'   Errors of class `sbert_bad_input` when `n_topics` is not below the
#'   current number of topics, and `sbert_no_embeddings` when the model holds
#'   no embeddings and none are given.
#' @seealso [topic_hierarchy()] to see which topics would merge;
#'   [compare_topics()] to compare fits with different numbers of topics.
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings)
#' reduced <- reduce_topics(topic_model, n_topics = 4)
#' topic_sizes(reduced, weights = "n")
reduce_topics <- function(object, n_topics, embeddings = NULL, method = "average") {
  stopifnot(
    inherits(object, "sbert_topic_model"),
    is.numeric(n_topics),
    length(n_topics) == 1L,
    is.finite(n_topics),
    n_topics == as.integer(n_topics),
    n_topics >= 2L
  )
  n_topics <- as.integer(n_topics)
  if (n_topics >= nrow(object$topics)) {
    sbert_abort(
      "n_topics must be below the current topic count; ",
      "use the model as is for the same count.",
      class = "sbert_bad_input"
    )
  }
  if (is.null(embeddings)) {
    embeddings <- object$embeddings
  }
  if (is.null(embeddings)) {
    sbert_abort(
      "The model carries no embeddings; refit with keep_embeddings = TRUE ",
      "or supply the original embedding matrix through 'embeddings'.",
      class = "sbert_no_embeddings"
    )
  }
  stopifnot(
    is.matrix(embeddings),
    nrow(embeddings) == nrow(object$documents)
  )

  topic_membership <- stats::cutree(hierarchy_tree(object, method), k = n_topics)
  normalized <- normalize_rows(embeddings)
  merged_topic <- as.integer(topic_membership[object$documents$topic])
  # Package convention: topic 1 is the largest (ties broken by first
  # appearance), matching topics().
  first_sizes <- tabulate(merged_topic, nbins = n_topics)
  topic_order <- order(-first_sizes, seq_len(n_topics))
  renumbered <- integer(n_topics)
  renumbered[topic_order] <- seq_len(n_topics)
  merged_topic <- as.integer(renumbered[merged_topic])

  centers <- do.call(rbind, lapply(
    seq_len(n_topics),
    function(topic_id) {
      member_rows <- normalized[merged_topic == topic_id, , drop = FALSE]
      colMeans(member_rows)
    }
  ))
  centers <- normalize_rows(centers)

  assigned_centers <- centers[merged_topic, , drop = FALSE]
  distance <- 1 - rowSums(normalized * assigned_centers)
  distance[distance < 0] <- 0

  # The units, their parents, segment positions, and carried metadata are all
  # kept; only the assignment and its distance change, and the stale label is
  # replaced below.
  documents <- object$documents
  documents$topic <- merged_topic
  documents$distance <- distance
  documents$label <- NULL

  settings <- object$settings
  # Names given with name_topics() belong to the topics before merging.
  settings$topic_names <- NULL
  term_results <- topic_term_scores(
    text = documents$text,
    topic = documents$topic,
    n_topics = n_topics,
    n_terms = settings$n_terms,
    stop_words = settings$stop_words,
    min_term_frequency = settings$min_term_frequency,
    min_token_length = settings$min_token_length,
    weighting = settings$weighting,
    reduce_frequent_words = settings$reduce_frequent_words,
    stem = settings$stem,
    numbers = if (is.null(settings$numbers)) "keep" else settings$numbers,
    roman_numerals = if (is.null(settings$roman_numerals)) "keep" else settings$roman_numerals,
    section_numbers = if (is.null(settings$section_numbers)) "keep" else settings$section_numbers
  )
  settings$n_topics <- n_topics
  representatives <- topic_representatives(
    documents,
    n_topics,
    settings$n_representatives
  )
  labels <- topic_labels_for(
    settings$label, term_results$terms, representatives, n_topics
  )

  sizes <- tabulate(documents$topic, nbins = n_topics)
  withinss <- vapply(
    seq_len(n_topics),
    function(topic_id) {
      member_rows <- normalized[documents$topic == topic_id, , drop = FALSE]
      # Around the members' mean, not the unit-length stored center, so that
      # between/total SS stays the share of variance the merged partition
      # explains, in [0, 1].
      sum(sweep(member_rows, 2L, colMeans(member_rows))^2)
    },
    numeric(1)
  )
  global_center <- matrix(
    colMeans(normalized),
    nrow = nrow(normalized),
    ncol = ncol(normalized),
    byrow = TRUE
  )
  totss <- sum((normalized - global_center)^2)

  topics <- data.frame(
    topic = seq_len(n_topics),
    label = labels,
    n_documents = sizes,
    proportion = sizes / nrow(documents),
    withinss = withinss,
    stringsAsFactors = FALSE
  )

  structure(
    list(
      documents = insert_topic_label(documents, labels),
      topics = topics,
      terms = insert_topic_label(term_results$terms, labels),
      representatives = insert_topic_label(representatives, labels),
      centers = centers,
      embeddings = if (is.null(object$embeddings)) NULL else normalized,
      diagnostics = list(
        totss = totss,
        tot_withinss = sum(withinss),
        betweenss = totss - sum(withinss),
        iterations = object$diagnostics$iterations,
        converged = object$diagnostics$converged %||% NA,
        warnings = object$diagnostics$warnings %||% character(),
        algorithm = "hierarchical merge of deterministic k-means topics"
      ),
      model = object$model,
      settings = settings
    ),
    class = "sbert_topic_model"
  )
}
