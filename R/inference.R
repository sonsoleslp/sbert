# Inferential layer for fitted topic models: assignment of new documents,
# soft topic topic_membership, generative word probabilities, and document-topic
# distributions. Everything operates on the deterministic k-means centroids
# stored in the fitted model; nothing here refits or perturbs the clustering.

# Assign embedding rows to the nearest stored centroid by cosine distance.
assign_topic_embeddings <- function(embeddings, centers) {
  stopifnot(
    is.matrix(embeddings),
    is.numeric(embeddings),
    nrow(embeddings) >= 1L,
    !anyNA(embeddings),
    all(is.finite(embeddings)),
    is.matrix(centers),
    is.numeric(centers)
  )
  if (ncol(embeddings) != ncol(centers)) {
    sbert_abort(
      sprintf(
        "Embeddings have %d dimensions but the topic model was fitted with %d.",
        ncol(embeddings),
        ncol(centers)
      ),
      class = "sbert_dimension_mismatch"
    )
  }

  normalized <- normalize_embedding_rows(embeddings)
  normalized_centers <- normalize_embedding_rows(centers)
  topic_similarity <- normalized %*% t(normalized_centers)
  topic <- max.col(topic_similarity, ties.method = "first")
  distance <- pmax(
    0,
    1 - topic_similarity[cbind(seq_len(nrow(topic_similarity)), topic)]
  )
  list(
    topic = as.integer(topic),
    distance = unname(distance),
    topic_similarity = unname(topic_similarity)
  )
}

# Resolve the embedding matrix for new text from exactly one of model /
# embeddings, mirroring the topics() contract.
resolve_new_embeddings <- function(
  text,
  model,
  embeddings,
  batch_size,
  n_expected,
  sort_by_length = FALSE
) {
  if (!is.null(model) && !is.null(embeddings)) {
    sbert_abort(
      "Supply model or embeddings, not both.",
      class = "sbert_bad_input"
    )
  }
  if (is.null(embeddings)) {
    embeddings <- encode(
      text,
      resolve_sbert_model(model),
      batch_size = as.integer(batch_size),
      normalize = TRUE,
      sort_by_length = sort_by_length
    )
  }
  if (
    !is.matrix(embeddings) ||
      !is.numeric(embeddings) ||
      nrow(embeddings) != n_expected ||
      anyNA(embeddings) ||
      any(!is.finite(embeddings))
  ) {
    sbert_abort(
      sprintf(
        "embeddings must be a finite numeric matrix with %d rows (one per unit).",
        n_expected
      ),
      class = "sbert_bad_input"
    )
  }
  embeddings
}

#' Assign new documents to fitted topics
#'
#' @description
#' `predict()` assigns new documents to the topics of a fitted model without
#' fitting again: it embeds the new texts (or takes their embeddings) and
#' assigns each to the topic whose center has the highest cosine similarity with
#' it, after scaling the centers to unit length. A fitted topic model defines
#' its topics by their centers in the embedding space, so new texts (later
#' responses, a held-out sample, another cohort) can be placed in the same
#' topics, which keeps the topics and their labels fixed and makes the counts
#' comparable across samples.
#'
#' `distance` is one minus that similarity. A model fitted on segments splits
#' the new texts with the same segmentation settings first and assigns each
#' segment. The fitted model is not changed. The result is a data frame with one
#' row per document, or per segment for a segmented model.
#'
#' This rule differs from the one that formed the topics: [topics()] fits
#' Lloyd's k-means, which assigns each unit to the nearest raw mean of the
#' normalized embeddings by squared Euclidean distance, and those means are
#' shorter than unit length by different amounts. On the units a model was
#' fitted on, the two rules agree for almost every unit but can differ for a
#' few units on topic boundaries, so `predict()` on the training texts need
#' not reproduce the fitted topics exactly; read the fitted assignment with
#' `as.data.frame(fit, what = "documents")`. For graded rather than single
#' assignments use [topic_membership()]; for the topic mixture of long
#' documents, [topic_gamma()].
#'
#' @param object A fitted model from [topics()].
#' @param text Character vector of new documents.
#' @param model A model from [load_model()], a pinned model name, or `NULL`
#'   (default) for the default model, used to embed `text`; ignored when
#'   `embeddings` are given. Its dimension must match the fitted model.
#' @param embeddings Numeric matrix with one row per document (one per
#'   segment for a segmented model), or `NULL` (default) to encode `text`.
#' @param batch_size Texts per model call when encoding (default 32).
#' @param ... Unused.
#' @return A base data frame with one row per document and columns
#'   `document_id`, `document_name`, `text`, `topic`, `label` (the fitted
#'   topic label), and `distance` (cosine distance to the assigned center).
#'   For a segmented model, one row per segment, with `segment` (position in
#'   the document) after `document_name`.
#' @section Conditions:
#'   `sbert_dimension_mismatch` when the embeddings have a different number
#'   of columns from the fitted model; `sbert_bad_input` when both `model` and
#'   `embeddings` are given, when `embeddings` has the wrong number of rows or
#'   non-finite values or a zero row, or when segmentation yields no segment;
#'   when encoding, the conditions of [encode()].
#' @seealso [topics()] for the fit; [topic_membership()] for graded
#'   membership; [topic_gamma()] for document mixtures; [representatives()]
#'   for the clearest examples of each topic.
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings)
#'
#' # Assign three messages, giving their precomputed embeddings.
#' new_messages <- head(corpus, 3)
#' with(new_messages,
#'      predict(topic_model, translation,
#'              embeddings = head(feedback_embeddings, 3)))
#'
#' # A small model on toy two-dimensional embeddings.
#' text <- c(
#'   "Cats chase mice", "Dogs chase balls",
#'   "Stocks and bonds trade", "Markets price shares"
#' )
#' embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
#' toy_model <- topics(text, 2, embeddings = embeddings)
#' predict(toy_model, "Bulls and bears move markets",
#'         embeddings = rbind(c(0.2, 0.8)))
#'
#' \donttest{
#' if (interactive()) {
#'   predict(topic_model, c("The pictures were too small.",
#'                          "I liked the counting game."))
#' }
#' }
predict.sbert_topic_model <- function(
  object,
  text,
  model = NULL,
  embeddings = NULL,
  batch_size = 32L,
  ...
) {
  stopifnot(
    inherits(object, "sbert_topic_model"),
    is.character(text),
    length(text) >= 1L,
    !anyNA(text),
    is.numeric(batch_size),
    length(batch_size) == 1L,
    is.finite(batch_size),
    batch_size >= 1,
    batch_size == as.integer(batch_size)
  )

  # New text takes the fitted unit: whole documents, or segments cut with the
  # same options the model was fitted with.
  segmentation <- topic_segmentation(object)
  units <- NULL
  unit_text <- text
  if (segmentation$segment != "document") {
    units <- segment_topic_documents(
      text,
      segmentation,
      model = if (!is.null(segmentation$max_tokens) && is.null(embeddings)) {
        resolve_sbert_model(model)
      } else {
        NULL
      },
      minimum = 1L
    )
    unit_text <- units$text
  }
  embedding_matrix <- resolve_new_embeddings(
    unit_text,
    model,
    embeddings,
    batch_size,
    n_expected = length(unit_text)
  )
  assignment <- assign_topic_embeddings(embedding_matrix, object$centers)

  if (is.null(units)) {
    document_names <- names(text)
    if (is.null(document_names)) {
      document_names <- rep.int("", length(text))
    }
    return(data.frame(
      document_id = seq_along(text),
      document_name = unname(document_names),
      text = unname(text),
      topic = assignment$topic,
      label = object$topics$label[assignment$topic],
      distance = assignment$distance,
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    document_id = units$document_id,
    document_name = units$document_name,
    segment = units$segment,
    text = units$text,
    topic = assignment$topic,
    label = object$topics$label[assignment$topic],
    distance = assignment$distance,
    stringsAsFactors = FALSE
  )
}

#' Compute graded topic membership
#'
#' @description
#' `topic_membership()` computes graded (fuzzy) topic membership: a
#' probability-like weight of every unit on every topic, so that units on a
#' boundary and units squarely inside a topic can be told apart, whereas a hard
#' assignment places each unit in one topic. The weights follow the membership
#' function of fuzzy c-means (Bezdek, 1981): a unit's weight on a topic falls
#' with its distance to that topic's center relative to its distances to the
#' other centers.
#'
#' The weights are computed from the cosine distance of each unit to each topic
#' center, after scaling the centers to unit length:
#' \eqn{u_{ij} \propto d_{ij}^{-2/(m-1)}}{u_ij ~ d_ij^(-2/(m-1))}, normalized to
#' sum to one over topics, with \eqn{m} the `sharpness`. The topics themselves
#' are not refitted. In high-dimensional embedding spaces distances are similar
#' in size, so the usual \eqn{m = 2} gives nearly uniform weights; the default
#' 1.15 keeps them distinct. The order of topics within a unit does not depend
#' on `sharpness`; the size of the weights does, and should be read relative to
#' the chosen value. The result is a data frame with one row per unit-topic
#' pair, with weights that sum to one within each unit.
#'
#' The rank-1 topic is the topic [predict()][predict.sbert_topic_model] assigns,
#' by cosine similarity to the unit-length centers. [topics()] fits Lloyd's
#' k-means, which assigns by squared Euclidean distance to the raw means of the
#' normalized embeddings; on the fitted units the two rules agree for almost
#' every unit but can differ for a few units on topic boundaries. For the share
#' of a long document's segments in each topic, use [topic_gamma()].
#'
#' @param object A fitted model from [topics()].
#' @param embeddings Numeric matrix of embeddings, one row per unit, or `NULL`
#'   (default) for the embeddings stored in the model (fitted with
#'   `keep_embeddings = TRUE`, the default).
#' @param sharpness The fuzzifier \eqn{m}, greater than 1 (default 1.15);
#'   values near 1 give crisper weights.
#' @return A base data frame with one row per unit-topic pair and columns
#'   `document_id` (row of `embeddings`, or of the fitted units), `topic`,
#'   `probability`, and `rank` (1 for the unit's highest weight), ordered by
#'   unit and rank. Probabilities sum to one within each unit.
#' @section Conditions:
#'   `sbert_no_embeddings` when `embeddings` is `NULL` and the model stores
#'   none; `sbert_dimension_mismatch` when the embeddings have a different
#'   number of columns from the fitted model; `sbert_bad_input` when an
#'   embedding row is zero.
#' @seealso [predict()][predict.sbert_topic_model] for single assignments;
#'   [topic_gamma()] for document mixtures from segments; [topics()] for the
#'   fit.
#' @references Bezdek, J. C. (1981). *Pattern Recognition with Fuzzy
#'   Objective Function Algorithms*. Plenum Press, New York.
#'   \doi{10.1007/978-1-4757-0450-1}
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings)
#' head(topic_membership(topic_model), 12)
#'
#' # The textbook fuzzifier spreads the weights more evenly.
#' head(topic_membership(topic_model, sharpness = 2), 6)
topic_membership <- function(object, embeddings = NULL, sharpness = 1.15) {
  stopifnot(
    inherits(object, "sbert_topic_model"),
    is.numeric(sharpness),
    length(sharpness) == 1L,
    is.finite(sharpness),
    sharpness > 1
  )
  if (is.null(embeddings)) {
    embeddings <- object$embeddings
    if (is.null(embeddings)) {
      sbert_abort(
        paste0(
          "The model stores no embeddings. Refit with keep_embeddings = TRUE ",
          "or supply embeddings."
        ),
        class = "sbert_no_embeddings"
      )
    }
  }

  assignment <- assign_topic_embeddings(embeddings, object$centers)
  distance <- pmax(1 - assignment$topic_similarity, 1e-12)
  # Fuzzy-c-means topic_membership computed in log space for numerical stability:
  # u_ij = d_ij^(-2/(m-1)) / sum_l d_il^(-2/(m-1)).
  weight <- -(2 / (sharpness - 1)) * log(distance)
  weight <- weight - apply(weight, 1L, max)
  unnormalized <- exp(weight)
  probability <- unnormalized / rowSums(unnormalized)

  n_documents <- nrow(probability)
  n_topics <- ncol(probability)
  long <- data.frame(
    document_id = rep.int(seq_len(n_documents), rep.int(n_topics, n_documents)),
    topic = rep.int(seq_len(n_topics), n_documents),
    probability = as.numeric(t(probability)),
    stringsAsFactors = FALSE
  )
  ordering <- order(long$document_id, -long$probability, long$topic)
  long <- long[ordering, , drop = FALSE]
  long$rank <- rep.int(seq_len(n_topics), n_documents)
  rownames(long) <- NULL
  long
}


#' Compute document-topic mixtures from segments
#'
#' @description
#' `topic_gamma()` returns, for each document, its mixture over topics: the
#' share of its segments assigned to each topic, the document-topic distribution
#' conventionally called gamma. A document that discusses two subjects in
#' different sentences belongs partly to two topics, which a single embedding of
#' the whole document cannot express; counting the topics of its segments gives
#' the mixture without any additional parameter.
#'
#' For a model fitted on segments (`segment =` in [topics()]) and `text = NULL`,
#' it counts the fitted assignments, with no encoding. Otherwise it segments the
#' given documents (with the fitted segmentation, or at `level`), or takes a
#' [segment()] data frame as it is, embeds the segments, and assigns each to the
#' topic whose unit-length center has the highest cosine similarity, as
#' [predict()][predict.sbert_topic_model] does. The result is a data frame with
#' one row per document-topic pair.
#'
#' The fitted assignments come from Lloyd's k-means in [topics()], which uses
#' squared Euclidean distance to the raw means of the normalized embeddings;
#' for a few segments on topic boundaries this can differ from the
#' cosine-similarity rule applied to new text. For graded membership of
#' single units, use [topic_membership()].
#'
#' @param object A fitted model from [topics()].
#' @param text `NULL` (default) for the fitted segments of a segmented model;
#'   a character vector of documents to segment; or a data frame from
#'   [segment()] (columns `document_id` and `text`), used as it is.
#' @param model A model from [load_model()], a pinned model name, or `NULL`
#'   (default) for the default model, used to embed the segments; ignored
#'   when `embeddings` are given.
#' @param embeddings Numeric matrix of segment embeddings, one row per
#'   segment of `text` (in the order of [segment()]), or `NULL` (default) to
#'   encode them.
#' @param level `"clause"`, `"sentence"`, or `"phrase"` for segmenting a
#'   character `text`, or `NULL` (default) for the fitted segmentation of a
#'   segmented model and `"clause"` otherwise.
#' @param batch_size Texts per model call when encoding (default 32).
#' @param cores Number of forked processes for segmenting (default 1), passed
#'   to [segment()]; the result does not depend on it.
#' @param dedupe_segments Encode each distinct segment once (default `FALSE`).
#'   Saves time on corpora with many repeated segments; the values can differ
#'   from encoding every occurrence by floating-point rounding.
#' @param sort_by_length Batch segments of similar length together when
#'   encoding (default `FALSE`); see [encode()].
#' @param top `NULL` (default) for every topic of every document, or a whole
#'   number: each document's `top` largest non-zero shares.
#' @return A base data frame with one row per document-topic pair and columns
#'   `document_id`, `topic`, `gamma` (the share of the document's segments in
#'   the topic), and `n_segments`. `gamma` sums to one within each document;
#'   documents without segments have no rows. With `top`, only the largest
#'   non-zero shares, ordered by document and share, with a `rank` column
#'   after `document_id`.
#' @section Conditions:
#'   `sbert_bad_input` when `text` is `NULL` for a model fitted on whole
#'   documents, when `model`, `embeddings` or `level` is given without
#'   `text`, when a data frame lacks `document_id` or `text`, when no segment
#'   results, or when `embeddings` has the wrong number of rows;
#'   `sbert_dimension_mismatch` when the embeddings have a different number of
#'   columns from the fitted model; when encoding, the conditions of
#'   [encode()].
#' @seealso [segment()] for the segments; [topic_membership()] for graded
#'   membership; [predict()][predict.sbert_topic_model] for single
#'   assignments; [topic_sizes()] for topic totals.
#' @export
#' @examples
#' text <- c(
#'   "Cats chase mice", "Dogs chase balls",
#'   "Stocks and bonds trade", "Markets price shares"
#' )
#' embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
#' fitted <- topics(text, 2, embeddings = embeddings)
#'
#' # A new document with one sentence on each topic.
#' mixed <- "Cats chase mice. Stocks and bonds trade."
#' segment_embeddings <- rbind(c(1, 0), c(0, 1))
#' topic_gamma(fitted, mixed, embeddings = segment_embeddings)
#'
#' # Segment once, then reuse the segments and their embeddings.
#' segments <- segment(mixed, level = "sentence")
#' topic_gamma(fitted, segments, embeddings = segment_embeddings)
#'
#' # A model fitted on sentences already holds its segments: no text needed.
#' sentence_model <- topics(
#'   c(mixed, "Dogs chase balls. Markets price shares."), 2,
#'   segment = "sentence",
#'   embeddings = rbind(c(1, 0), c(0, 1), c(0.9, 0.1), c(0.1, 0.9))
#' )
#' topic_gamma(sentence_model)
#' topic_gamma(sentence_model, top = 1)
topic_gamma <- function(
  object,
  text = NULL,
  model = NULL,
  embeddings = NULL,
  level = NULL,
  batch_size = 32L,
  cores = 1L,
  dedupe_segments = FALSE,
  sort_by_length = FALSE,
  top = NULL
) {
  stopifnot(
    "`top` must be NULL or a single positive whole number" = is.null(top) ||
      (is.numeric(top) && length(top) == 1L && is.finite(top) && top >= 1 &&
        top == as.integer(top)),
    inherits(object, "sbert_topic_model"),
    is.numeric(batch_size),
    length(batch_size) == 1L,
    is.finite(batch_size),
    batch_size >= 1,
    batch_size == as.integer(batch_size),
    is.logical(dedupe_segments),
    length(dedupe_segments) == 1L,
    !is.na(dedupe_segments),
    # Validated here as well as in encode(), because a supplied `embeddings`
    # short-circuits the encode() call and would otherwise swallow a malformed
    # value in silence.
    is.logical(sort_by_length),
    length(sort_by_length) == 1L,
    !is.na(sort_by_length)
  )
  if (!is.null(level)) {
    level <- match.arg(level, c("clause", "sentence", "phrase"))
  }
  segmented <- is_segmented_topic_model(object)

  # No text: a segmented model already stores every fitted segment with its
  # topic, so the mixture is a count, not an encoding.
  if (is.null(text)) {
    if (!segmented) {
      sbert_abort(
        "topic_gamma: supply `text` to segment and assign, or fit the model ",
        "with segment = \"sentence\", \"clause\", or \"phrase\" so its own ",
        "segments carry each document's topic mixture.",
        class = "sbert_bad_input"
      )
    }
    if (!is.null(model) || !is.null(embeddings) || !is.null(level)) {
      sbert_abort(
        "topic_gamma: model, embeddings, and level apply only when `text` ",
        "is supplied.",
        class = "sbert_bad_input"
      )
    }
    return(top_topic_gamma(
      gamma_from_assignments(
        object$documents$document_id,
        object$documents$topic,
        nrow(object$topics)
      ),
      top
    ))
  }

  # Accept either raw documents (segmented here) or the data frame returned by
  # segment() (used as-is). Passing your own segmentation keeps all its
  # options in one place and means a supplied `embeddings` matrix always lines
  # up with the segments.
  if (is.data.frame(text)) {
    if (!all(c("document_id", "text") %in% names(text))) {
      sbert_abort(
        paste0(
          "A pre-segmented data frame must have `document_id` and `text` ",
          "columns, as returned by segment()."
        ),
        class = "sbert_bad_input"
      )
    }
    segments <- text
    stopifnot(
      nrow(segments) >= 1L,
      is.character(segments$text),
      !anyNA(segments$text),
      is.numeric(segments$document_id),
      !anyNA(segments$document_id)
    )
  } else {
    stopifnot(is.character(text), length(text) >= 1L, !anyNA(text))
    segments <- if (is.null(level) && segmented) {
      # New documents are cut exactly as the fitted ones were, so their
      # mixtures are comparable with the fit.
      segmentation <- topic_segmentation(object)
      segment_topic_documents(
        text,
        segmentation,
        cores = cores,
        model = if (!is.null(segmentation$max_tokens) && is.null(embeddings)) {
          resolve_sbert_model(model)
        } else {
          NULL
        },
        minimum = 1L
      )
    } else {
      segment(
        text,
        level = if (is.null(level)) "clause" else level,
        cores = cores
      )
    }
  }
  if (nrow(segments) == 0L) {
    sbert_abort("No document produced any segment.", class = "sbert_bad_input")
  }
  if (dedupe_segments && is.null(embeddings)) {
    # Repeated segments ("See Fig. 3.", boilerplate sentences) are common; a
    # real corpus is often ~half duplicates. Encode each distinct segment once
    # and expand back by position, halving encoding on such corpora. Assignments
    # are unchanged from encoding every occurrence, up to the ~1e-7 batch-
    # composition effect on the (now smaller) encoded set — hence opt-in.
    distinct_segments <- unique(segments$text)
    distinct_embeddings <- resolve_new_embeddings(
      distinct_segments,
      model,
      NULL,
      batch_size,
      n_expected = length(distinct_segments),
      sort_by_length = sort_by_length
    )
    embedding_matrix <- distinct_embeddings[
      match(segments$text, distinct_segments), ,
      drop = FALSE
    ]
  } else {
    embedding_matrix <- resolve_new_embeddings(
      segments$text,
      model,
      embeddings,
      batch_size,
      n_expected = nrow(segments),
      sort_by_length = sort_by_length
    )
  }
  assignment <- assign_topic_embeddings(embedding_matrix, object$centers)
  top_topic_gamma(
    gamma_from_assignments(
      segments$document_id,
      assignment$topic,
      nrow(object$topics)
    ),
    top
  )
}

# Each document's `top` largest topic shares, largest first, with their rank.
# Zero shares are not topics of the document, so a document lists fewer than
# `top` when fewer topics occur in it. Ties break by topic number.
top_topic_gamma <- function(gamma, top) {
  if (is.null(top)) {
    return(gamma)
  }
  gamma <- gamma[gamma$gamma > 0, , drop = FALSE]
  gamma <- gamma[order(gamma$document_id, -gamma$gamma, gamma$topic), , drop = FALSE]
  gamma$rank <- as.integer(stats::ave(gamma$topic, gamma$document_id, FUN = seq_along))
  gamma <- gamma[gamma$rank <= top, c("document_id", "rank", "topic", "gamma", "n_segments")]
  rownames(gamma) <- NULL
  gamma
}

# Per-document topic mixture from segment assignments: the share of each
# document's segments falling in each topic, one row per document-topic pair.
gamma_from_assignments <- function(document_id, topic, n_topics) {
  segment_counts <- table(
    factor(document_id, levels = sort(unique(document_id))),
    factor(topic, levels = seq_len(n_topics))
  )
  count_matrix <- matrix(
    as.numeric(segment_counts),
    nrow = nrow(segment_counts)
  )
  totals <- rowSums(count_matrix)
  gamma_matrix <- count_matrix / totals
  documents_present <- as.integer(rownames(segment_counts))

  data.frame(
    document_id = rep.int(documents_present, rep.int(n_topics, length(documents_present))),
    topic = rep.int(seq_len(n_topics), length(documents_present)),
    gamma = as.numeric(t(gamma_matrix)),
    n_segments = rep.int(as.integer(totals), rep.int(n_topics, length(documents_present))),
    stringsAsFactors = FALSE
  )
}

#' Select representative texts for each topic
#'
#' @description
#' `representatives()` selects representative texts for each topic of a fitted
#' model: it ranks the units of each topic and returns the first `n`. A topic in
#' an embedding model is a region of meaning, and it is read most directly from
#' the texts it contains.
#'
#' Each unit is assigned to the topic whose unit-length center has the highest
#' cosine similarity with it. The texts closest to a topic's center are typical
#' of it but tend to be long, because long texts resemble the average of many
#' texts; texts that are clearly about one topic and no other are usually more
#' telling. With `rank = "margin"`, the default, units are ranked by their
#' margin: the cosine distance to the second-nearest center minus the distance
#' to their own. With `rank = "distance"` they are ranked by closeness to their
#' own center. Ties go to the shorter text; repeated texts and texts without a
#' word of two or more letters are skipped. By default the units the model was
#' fitted on are ranked, from their stored embeddings; given `text`, any
#' candidate texts are. The result is a data frame with one row per selected
#' text, ordered by topic and rank.
#'
#' Because the assignment uses cosine similarity to the unit-length centers,
#' while [topics()] fits Lloyd's k-means (squared Euclidean distance to the
#' raw means of the normalized embeddings), a few fitted units on topic
#' boundaries can be ranked under a different topic from the one they were
#' fitted to. The representatives stored at fitting time, shown by
#' `as.data.frame(fit, what = "representatives")`, are the units of each
#' fitted topic closest to its center. For topic words use
#' [terms()][terms.sbert_topic_model] or [keywords()].
#'
#' @param object A fitted model from [topics()].
#' @param text Character vector of candidate texts, or `NULL` (default) for
#'   the documents or segments the model was fitted on.
#' @param model A model from [load_model()], a pinned model name, or `NULL`
#'   (default) for the default model, used to embed `text`; ignored when
#'   `embeddings` are given.
#' @param embeddings Numeric matrix with one row per candidate, or `NULL`
#'   (default): the stored embeddings when `text` is `NULL`, else encode
#'   `text`.
#' @param n Number of texts per topic (default 3).
#' @param rank `"margin"` (default) or `"distance"`.
#' @param batch_size Texts per model call when encoding (default 32).
#' @return A base data frame with one row per selected text and columns
#'   `topic`, `rank`, `text`, `distance` (cosine distance to the unit's own
#'   center), and `margin`, ordered by topic and rank. When the fitted units
#'   are ranked, `document_id` (and `segment`, for a segmented model) follow
#'   `rank`. Topics without units have no rows.
#' @section Conditions:
#'   `sbert_no_embeddings` when `text` is `NULL` and the model stores no
#'   embeddings; `sbert_dimension_mismatch` when the embeddings have a
#'   different number of columns from the fitted model; `sbert_bad_input` when
#'   both `model` and `embeddings` are given or `embeddings` has the wrong
#'   number of rows; when encoding, the conditions of [encode()].
#' @seealso [terms()][terms.sbert_topic_model] and [keywords()] for topic
#'   words; [name_topics()] to label topics; `plot(fit, type =
#'   "representatives")` to draw them; [topic_membership()] for graded
#'   membership.
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings)
#' representatives(topic_model, n = 2)
#' representatives(topic_model, n = 2, rank = "distance")
#'
#' # Rank new candidate texts, giving their embeddings.
#' text <- c(
#'   "Cats chase mice", "Dogs chase balls",
#'   "Stocks and bonds trade", "Markets price shares"
#' )
#' embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
#' toy_model <- topics(text, 2, embeddings = embeddings)
#' representatives(
#'   toy_model,
#'   c("kittens pounce", "bond yields", "pets and prices"),
#'   embeddings = rbind(c(1, 0.1), c(0.1, 1), c(0.7, 0.7)),
#'   n = 1
#' )
representatives <- function(
  object,
  text = NULL,
  model = NULL,
  embeddings = NULL,
  n = 3L,
  rank = c("margin", "distance"),
  batch_size = 32L
) {
  rank <- match.arg(rank)
  stopifnot(inherits(object, "sbert_topic_model"))
  # With no text supplied, rank the units the model was fitted on. Their
  # embeddings are already stored, so nothing is re-encoded, and each example
  # keeps the source it came from.
  stored_units <- NULL
  if (is.null(text)) {
    stored_units <- object$documents[
      ,
      intersect(c("document_id", "segment"), names(object$documents)),
      drop = FALSE
    ]
    text <- object$documents$text
    if (is.null(embeddings)) {
      embeddings <- object$embeddings
      if (is.null(embeddings)) {
        sbert_abort(
          "representatives: this model kept no embeddings. Refit with ",
          "topics(..., keep_embeddings = TRUE), or supply 'text'.",
          class = "sbert_no_embeddings"
        )
      }
    }
  }
  stopifnot(
    is.character(text),
    length(text) >= 1L,
    !anyNA(text),
    is.numeric(n),
    length(n) == 1L,
    is.finite(n),
    n >= 1,
    n == as.integer(n),
    is.numeric(batch_size),
    length(batch_size) == 1L,
    is.finite(batch_size),
    batch_size >= 1,
    batch_size == as.integer(batch_size)
  )

  embedding_matrix <- resolve_new_embeddings(
    text,
    model,
    embeddings,
    batch_size,
    n_expected = length(text)
  )
  assignment <- assign_topic_embeddings(embedding_matrix, object$centers)
  # pmax() would strip the dim attribute; clamp by index assignment instead.
  distance_matrix <- 1 - assignment$topic_similarity
  distance_matrix[distance_matrix < 0] <- 0
  own_distance <- assignment$distance
  second_distance <- vapply(
    seq_len(nrow(distance_matrix)),
    function(unit) {
      others <- distance_matrix[unit, -assignment$topic[[unit]]]
      min(others)
    },
    numeric(1)
  )
  margin <- second_distance - own_distance

  candidates <- data.frame(
    topic = assignment$topic,
    text = unname(text),
    distance = own_distance,
    margin = margin,
    stringsAsFactors = FALSE
  )
  if (!is.null(stored_units)) {
    candidates <- cbind(stored_units, candidates)
  }
  selected <- lapply(
    sort(unique(candidates$topic)),
    function(topic_id) {
      topic_rows <- candidates[candidates$topic == topic_id, , drop = FALSE]
      ordering <- if (rank == "margin") {
        order(-topic_rows$margin, nchar(topic_rows$text), topic_rows$text)
      } else {
        order(topic_rows$distance, nchar(topic_rows$text), topic_rows$text)
      }
      # Distinct units that contain a real word (a run of two or more letters):
      # a repeated string is never a useful example, and a unit with no real word
      # ("2 .", "100", "1983, p.") is noise, not an example.
      ordered_text <- topic_rows$text[ordering]
      ordering <- ordering[
        !duplicated(ordered_text) & grepl("(*UTF)\\p{L}{2}", ordered_text, perl = TRUE)
      ]
      chosen <- utils::head(topic_rows[ordering, , drop = FALSE], as.integer(n))
      chosen$rank <- seq_len(nrow(chosen))
      chosen
    }
  )
  result <- do.call(rbind, selected)
  rownames(result) <- NULL
  result[
    ,
    c(
      "topic", "rank",
      intersect(c("document_id", "segment"), names(result)),
      "text", "distance", "margin"
    )
  ]
}
