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
    stop(
      sprintf(
        "Embeddings have %d dimensions but the topic model was fitted with %d.",
        ncol(embeddings),
        ncol(centers)
      ),
      call. = FALSE
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
    stop("Supply model or embeddings, not both.", call. = FALSE)
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
    stop(
      sprintf(
        "embeddings must be a finite numeric matrix with %d rows (one per unit).",
        n_expected
      ),
      call. = FALSE
    )
  }
  embeddings
}

#' Assign New Documents to Fitted Topics
#'
#' Predicts the topic of unseen documents by embedding them and assigning each
#' to the nearest stored topic centroid under cosine distance. The fitted
#' model is not modified. Supply either a loaded `model` (to embed `text`) or
#' a precomputed embedding matrix whose rows align with `text`.
#'
#' @param object A fitted [topics()] model.
#' @param text Character vector of new documents. A model fitted with
#'   `segment = "sentence"`, `"clause"`, or `"phrase"` splits them the same
#'   way first (with the fitted `max_tokens`, `merge_below`, and
#'   `min_content`) and assigns every segment.
#' @param model A loaded [sbert_model][load_model()], a pinned model
#'   name, or `NULL` for the default model; ignored when `embeddings` are
#'   supplied. The embedding dimension must match the fitted model.
#' @param embeddings Optional numeric matrix with one row per document, or
#'   one row per segment for a segmented model.
#' @param batch_size Batch size passed to [encode()] when `model` is
#'   used.
#' @param ... Unused; included for S3 compatibility.
#' @return A base data frame with one row per document and columns
#'   `document_id`, `document_name`, `text`, `topic`, `label` (the fitted
#'   topic label), and `distance` (cosine distance to the assigned centroid).
#'   For a segmented model, one row per segment, with `document_id` naming
#'   the source document and `segment` its position within it.
#' @export
#' @examples
#' text <- c(
#'   "Cats chase mice", "Dogs chase balls",
#'   "Stocks and bonds trade", "Markets price shares"
#' )
#' embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
#' fitted <- topics(text, 2, embeddings = embeddings)
#' predict(fitted, "Bulls and bears move markets", embeddings = rbind(c(0.2, 0.8)))
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

#' Soft Topic Membership Probabilities
#'
#' Computes fuzzy-c-means-style topic_membership of every document in every topic
#' from cosine distances to the stored centroids, without changing the
#' deterministic hard clustering. In high-dimensional embedding spaces
#' distances concentrate, so the textbook fuzzifier `sharpness = 2` collapses
#' memberships toward the uniform `1/k`; the default `sharpness = 1.15`
#' preserves contrast. The topic_membership ranking of topics within a document is
#' invariant to `sharpness`; the probability magnitudes are not, and should be
#' interpreted relative to the chosen value.
#'
#' @param object A fitted [topics()] model.
#' @param embeddings Optional numeric matrix of document embeddings. When
#'   omitted, the embeddings stored by `topics(keep_embeddings = TRUE)`
#'   are used.
#' @param sharpness Fuzzy-c-means fuzzifier `m`. Must be greater than 1;
#'   values close to 1 give crisper memberships.
#' @return A base data frame with one row per document-topic pair and columns
#'   `document_id`, `topic`, `probability`, and `rank` (1 is the strongest
#'   topic of the document). Probabilities sum to 1 within each document.
#' @export
#' @examples
#' text <- c(
#'   "Cats chase mice", "Dogs chase balls",
#'   "Stocks and bonds trade", "Markets price shares"
#' )
#' embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
#' fitted <- topics(text, 2, embeddings = embeddings, keep_embeddings = TRUE)
#' topic_membership(fitted)
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
      stop(
        paste0(
          "The model stores no embeddings. Refit with keep_embeddings = TRUE ",
          "or supply embeddings."
        ),
        call. = FALSE
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


#' Document-Topic Distributions from Segment Assignments
#'
#' Computes `gamma`, the distribution of every document over the fitted
#' topics, by segmenting each document with [segment()], assigning each
#' segment to its nearest topic centroid, and normalizing the per-document
#' segment counts. This yields parameter-free mixed topic_membership: a document
#' that discusses two topics in different sentences receives weight on both,
#' which the single-embedding hard assignment cannot express.
#'
#' @param object A fitted [topics()] model.
#' @param text Either `NULL`, a character vector of documents (segmented here
#'   at `level`), or the data frame returned by [segment()] (used as-is).
#'   `NULL` — the default — works for a model fitted with `segment =
#'   "sentence"`, `"clause"`, or `"phrase"`: its own segments and their topic
#'   assignments are already stored, so the mixture of every fitted document
#'   comes back with no encoding at all. Passing your own segmentation keeps
#'   every segment option in [segment()] and lets you reuse one set of segment
#'   embeddings across this and other verbs. A data frame must have
#'   `document_id` and `text` columns; `gamma` is then computed per
#'   `document_id`.
#' @param model A loaded [sbert_model][load_model()], a pinned model
#'   name, or `NULL` for the default model, used to embed the segments;
#'   ignored when `embeddings` are supplied.
#' @param embeddings Optional precomputed numeric matrix of segment
#'   embeddings, one row per segment. When `text` is raw documents the rows must
#'   align with `segment(text, level = level)`; when `text` is a [segment()]
#'   data frame they must align with its rows — which is automatic, since no
#'   re-segmentation happens.
#' @param level Segmentation granularity passed to [segment()] when `text` is
#'   a character vector: `"clause"`, `"sentence"`, or `"phrase"`. `NULL` (the
#'   default) uses the fitted segmentation — level, `max_tokens`,
#'   `merge_below`, and `min_content` — for a segmented model, so new
#'   documents are cut exactly as the fitted ones were, and `"clause"` for a
#'   document-level model. Ignored when `text` is already a [segment()] data
#'   frame.
#' @param batch_size Batch size passed to [encode()] when `model` is
#'   used.
#' @param cores Number of forked worker processes used to split documents into
#'   segments (passed to [segment()]). Default `1`. Segmenting a large corpus
#'   dominates the non-encoding cost, so `cores > 1` can noticeably speed up
#'   sentence- and clause-level gamma; the result is identical for any count.
#'   Encoding itself is parallelized separately, via `load_model(threads =)`.
#'   Ignored when `text` is already a [segment()] data frame.
#' @param dedupe_segments When `TRUE`, encode each distinct segment only once
#'   and expand the embeddings back by position, rather than encoding every
#'   occurrence. Real corpora are often close to half duplicate segments, so
#'   this can roughly halve encoding time (the dominant cost). Only applies when
#'   `embeddings` are not supplied. Assignments match encoding every occurrence
#'   up to the ~1e-7 floating-point effect of encoding a smaller batched set,
#'   which can flip a rare borderline segment; it is therefore opt-in and off by
#'   default. With the static `potion-base-8M` model, encoding has no batch
#'   effect and the result is identical.
#' @param sort_by_length Passed to [encode()]. Groups segments of similar length
#'   into the same batch so the model computes over less padding. Segment
#'   lengths vary far more than document lengths — at clause level 60.1% of
#'   token work is padding in input order against 1.6% when sorted — so this is
#'   the single largest saving available on this verb, measured at 1.9x. Off by
#'   default for the same ~1e-7 reason as `dedupe_segments`.
#' @return A base data frame with one row per document-topic pair and columns
#'   `document_id`, `topic`, `gamma`, and `n_segments`. `gamma` sums to 1
#'   within each document; documents with no segments contribute no rows.
#' @export
#' @examples
#' text <- c(
#'   "Cats chase mice", "Dogs chase balls",
#'   "Stocks and bonds trade", "Markets price shares"
#' )
#' embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
#' fitted <- topics(text, 2, embeddings = embeddings)
#' mixed <- "Cats chase mice. Stocks and bonds trade."
#' segment_embeddings <- rbind(c(1, 0), c(0, 1))
#' topic_gamma(fitted, mixed, embeddings = segment_embeddings)
#'
#' # Segment once (with any options), reuse the segments and their embeddings:
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
topic_gamma <- function(
  object,
  text = NULL,
  model = NULL,
  embeddings = NULL,
  level = NULL,
  batch_size = 32L,
  cores = 1L,
  dedupe_segments = FALSE,
  sort_by_length = FALSE
) {
  stopifnot(
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
      stop(
        "topic_gamma: supply `text` to segment and assign, or fit the model ",
        "with segment = \"sentence\", \"clause\", or \"phrase\" so its own ",
        "segments carry each document's topic mixture.",
        call. = FALSE
      )
    }
    if (!is.null(model) || !is.null(embeddings) || !is.null(level)) {
      stop(
        "topic_gamma: model, embeddings, and level apply only when `text` ",
        "is supplied.",
        call. = FALSE
      )
    }
    return(gamma_from_assignments(
      object$documents$document_id,
      object$documents$topic,
      nrow(object$topics)
    ))
  }

  # Accept either raw documents (segmented here) or the data frame returned by
  # segment() (used as-is). Passing your own segmentation keeps all its
  # options in one place and means a supplied `embeddings` matrix always lines
  # up with the segments.
  if (is.data.frame(text)) {
    if (!all(c("document_id", "text") %in% names(text))) {
      stop(
        paste0(
          "A pre-segmented data frame must have `document_id` and `text` ",
          "columns, as returned by segment()."
        ),
        call. = FALSE
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
    stop("No document produced any segment.", call. = FALSE)
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
  gamma_from_assignments(
    segments$document_id,
    assignment$topic,
    nrow(object$topics)
  )
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

#' Representative Text Units for Every Topic
#'
#' Selects, for each fitted topic, the text units (documents, sentences, or
#' clause segments) that best evidence it. The default ranking is by
#' *distinctiveness margin* — the unit's cosine distance to its second-best
#' centroid minus the distance to its own — rather than by raw closeness.
#' Raw closeness systematically favors long units, because topic centroids
#' are averages of whole-document embeddings and long units resemble whole
#' documents; the margin instead rewards units that are unambiguously about
#' one topic and no other, which are naturally short and pointed. Ties break
#' toward the shorter unit, then alphabetically, so the selection is fully
#' deterministic.
#'
#' @param object A fitted [topics()] model.
#' @param text Character vector of candidate units, for example the `text`
#'   column of [segment()]. `NULL` (the default) ranks the units the model
#'   was fitted on — its documents, or its segments for a model fitted with
#'   `segment =` — from their stored embeddings, with no encoding.
#' @param model A loaded [sbert_model][load_model()], a pinned model
#'   name, or `NULL` for the default model; ignored when `embeddings` are
#'   supplied.
#' @param embeddings Optional numeric matrix with one row per unit.
#' @param n Number of units returned per topic.
#' @param rank `"margin"` (default) or `"distance"` (raw closeness to the
#'   topic centroid).
#' @param batch_size Batch size passed to [encode()] when `model` is
#'   used.
#' @return A base data frame with columns `topic`, `rank`, `text`,
#'   `distance` (to the unit's own centroid), and `margin`, ordered by topic
#'   and rank. When the fitted units are ranked (`text = NULL`), `document_id`
#'   — and `segment`, for a segmented model — sit between `rank` and `text`
#'   so every example can be traced to its source. Topics to which no unit is
#'   assigned contribute no rows.
#' @export
#' @examples
#' text <- c(
#'   "Cats chase mice", "Dogs chase balls",
#'   "Stocks and bonds trade", "Markets price shares"
#' )
#' embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
#' fitted <- topics(text, 2, embeddings = embeddings)
#' representatives(
#'   fitted,
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
        stop(
          "representatives: this model kept no embeddings. Refit with ",
          "topics(..., keep_embeddings = TRUE), or supply 'text'.",
          call. = FALSE
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
