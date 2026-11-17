.sbert_english_stopwords <- c(
  "a", "about", "after", "again", "against", "all", "am", "an", "and",
  "any", "are", "as", "at", "be", "because", "been", "before", "being",
  "below", "between", "both", "but", "by", "can", "could", "did", "do",
  "does", "doing", "down", "during", "each", "few", "for", "from",
  "further", "had", "has", "have", "having", "he", "her", "here", "hers",
  "herself", "him", "himself", "his", "how", "i", "if", "in", "into",
  "is", "it", "its", "itself", "just", "me", "more", "most", "my",
  "myself", "no", "nor", "not", "now", "of", "off", "on", "once",
  "only", "or", "other", "our", "ours", "ourselves", "out", "over",
  "own", "same", "she", "should", "so", "some", "such", "than", "that",
  "the", "their", "theirs", "them", "themselves", "then", "there",
  "these", "they", "this", "those", "through", "to", "too", "under",
  "until", "up", "very", "was", "we", "were", "what", "when", "where",
  "which", "while", "who", "whom", "why", "will", "with", "would", "you",
  "your", "yours", "yourself", "yourselves"
)

# Canonical lowercase Roman numerals for 1 to 100, used by numbers-handling to
# drop chapter/section/list markers ("ii", "iv", "xii"). Bounded at 100 on
# purpose: every larger canonical form collides with a common scientific
# abbreviation that is also a valid Roman numeral (ml = 1050, mm = 2000,
# cc = 200, ci = 101, cv = 105), so extending the range would silently delete
# units. Single-character forms are included but are moot in practice, since the
# default min_token_length already drops them.
.sbert_roman_numerals <- local({
  int_to_roman <- function(n) {
    values <- c(100L, 90L, 50L, 40L, 10L, 9L, 5L, 4L, 1L)
    symbols <- c("c", "xc", "l", "xl", "x", "ix", "v", "iv", "i")
    out <- ""
    for (i in seq_along(values)) {
      while (n >= values[i]) {
        out <- paste0(out, symbols[i])
        n <- n - values[i]
      }
    }
    out
  }
  vapply(seq_len(100L), int_to_roman, character(1))
})

#' Get and adjust the stop-word list
#'
#' @description
#' `stop_words()` returns the built-in English list of stop words, extended with
#' `add` or reduced with `remove`. Stop words are frequent function words, such
#' as articles, pronouns, and prepositions, that occur in texts of every topic
#' and so say little about what distinguishes one topic from another; excluding
#' them lets the terms that describe a topic be its content words.
#'
#' Adding words that every text of a corpus shares, such as the name of the
#' course or the disease a corpus is about, removes them from the topic terms as
#' well. The list filters only the terms and keyword candidates; the text that
#' is embedded is unchanged.
#'
#' The result is passed as `stop_words =` to [topics()], [compare_topics()],
#' [topic_corpus()], [terms()][terms.sbert_topic_model], or [keywords()]. A
#' character vector of one's own replaces the list, and `character()` turns
#' the filter off.
#'
#' @param language Language of the list. Only `"en"` (default) is available.
#' @param add Words to add to the list, matched case-insensitively. Default
#'   `NULL`.
#' @param remove Words to remove from the list. Default `NULL`.
#' @return A character vector of lower-case stop words, sorted.
#' @section Conditions:
#'   An error of class `sbert_bad_input` when `language` is not `"en"`.
#' @seealso [topics()] and [terms()][terms.sbert_topic_model], which use the
#'   list; [clean_corpus()] to clean the text itself.
#' @export
#' @examples
#' head(stop_words())
#'
#' # Keep the defaults, add two domain words, and drop one entry
#' custom <- stop_words(add = c("try", "again"), remove = "against")
#'
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings, stop_words = custom)
#' terms(topic_model, n = 3)
stop_words <- function(language = "en", add = NULL, remove = NULL) {
  stopifnot(
    is.character(language),
    length(language) == 1L,
    !is.na(language),
    nzchar(language),
    is.null(add) || (is.character(add) && !anyNA(add)),
    is.null(remove) || (is.character(remove) && !anyNA(remove))
  )
  if (!identical(language, "en")) {
    sbert_abort(
      "Only the built-in English stop-word list is currently available.",
      class = "sbert_bad_input"
    )
  }
  words <- unique(c(.sbert_english_stopwords, tolower(add)))
  sort(setdiff(words, tolower(remove)))
}

# How many worker processes to actually use. Forking is deterministic and only
# available off Windows; tiny inputs are not worth the fork overhead. A
# parallelized pass is byte-identical to the serial one regardless of the count,
# so `cores` never changes results, only speed.
resolve_cores <- function(cores, n_items) {
  cores <- suppressWarnings(as.integer(cores))
  if (length(cores) != 1L || is.na(cores) || cores <= 1L) {
    return(1L)
  }
  if (.Platform$OS.type != "unix") {
    return(1L)
  }
  if (n_items < 2000L) {
    return(1L)
  }
  available <- tryCatch(parallel::detectCores(), error = function(e) 1L)
  if (is.na(available) || available < 1L) {
    available <- 1L
  }
  max(1L, min(cores, available, n_items))
}

tokenize_topic_documents <- function(text, stop_words, min_token_length, stem = FALSE, cores = 1L, numbers = "keep", roman_numerals = "keep", section_numbers = "keep") {
  stopifnot(
    is.character(text),
    !anyNA(text),
    is.character(stop_words),
    !anyNA(stop_words),
    is.numeric(min_token_length),
    length(min_token_length) == 1L,
    is.finite(min_token_length),
    min_token_length >= 1,
    min_token_length == as.integer(min_token_length),
    is.logical(stem),
    length(stem) == 1L,
    !is.na(stem),
    is.character(numbers),
    length(numbers) == 1L,
    numbers %in% c("keep", "remove"),
    is.character(roman_numerals),
    length(roman_numerals) == 1L,
    roman_numerals %in% c("keep", "remove"),
    is.character(section_numbers),
    length(section_numbers) == 1L,
    section_numbers %in% c("keep", "remove")
  )

  # Regex tokenization and stop-word/length filtering are per-document and
  # independent, so they parallelize by splitting the documents across forks.
  # Stemming stays on the combined corpus (it depends on corpus-wide surface
  # frequencies), so chunking never changes the result.
  n_cores <- resolve_cores(cores, length(text))
  if (n_cores > 1L) {
    chunks <- parallel::splitIndices(length(text), n_cores)
    parts <- parallel::mclapply(
      chunks,
      function(indices) {
        tokenize_topic_documents(
          text[indices], stop_words, min_token_length, stem = FALSE,
          cores = 1L, numbers = numbers, roman_numerals = roman_numerals,
          section_numbers = section_numbers
        )
      },
      mc.cores = n_cores
    )
    if (!any(vapply(parts, inherits, logical(1), "try-error"))) {
      combined <- unlist(parts, recursive = FALSE, use.names = FALSE)
      if (stem) {
        combined <- collapse_inflections(combined)
      }
      return(combined)
    }
    # A fork failed; fall through to the serial path below.
  }

  # Normalize the curly apostrophe (U+2019) to the straight one so that
  # contractions like "it's" and "it’s" are the same token.
  normalized_text <- gsub("\u2019", "'", tolower(enc2utf8(text)), fixed = TRUE)
  normalized_stopwords <- unique(
    gsub("\u2019", "'", tolower(enc2utf8(stop_words)), fixed = TRUE)
  )
  if (section_numbers == "remove") {
    # Strip section/reference numbering before tokenizing, since the tokenizer
    # splits on the periods and would otherwise leave stray digit tokens.
    # Multi-level indices ("1.2.3", "4.5.6.7") are three-or-more dot-separated
    # groups — unambiguous, since a decimal ("3.14") or two-part number ("2.1")
    # has at most one dot and is left alone.
    normalized_text <- gsub(
      "[0-9]+(?:\\.[0-9]+){2,}", " ", normalized_text, perl = TRUE
    )
    # Enumeration / list markers ("1. 2. 3.", "figure 12.") are a standalone
    # one- or two-digit number followed by a period and a space. Kept short and
    # required to stand alone so four-digit years ("2020."), hyphenated numbers
    # ("covid-19.") and larger counts survive even under numbers = "keep".
    normalized_text <- gsub(
      "(^|\\s)[0-9]{1,2}\\.(?=\\s|$)", " ", normalized_text, perl = TRUE
    )
  }

  # Single-pass tokenization, byte-identical to the grammar
  # `[[:alnum:]]+(?:'[[:alnum:]]+)*` but faster than a gregexpr + regmatches
  # pair: split on runs of non-(alnum or apostrophe), then within each piece
  # strip edge apostrophes and split any run of two or more apostrophes (which
  # never sit inside a token). Uses only base R.
  pieces <- strsplit(normalized_text, "(*UTF)(*UCP)[^[:alnum:]']+", perl = TRUE)
  filtered <- lapply(
    pieces,
    function(raw_pieces) {
      raw_pieces <- raw_pieces[nzchar(raw_pieces)]
      if (length(raw_pieces) == 0L) {
        return(character(0))
      }
      tokens <- gsub("^'+|'+$", "", raw_pieces)
      tokens <- unlist(strsplit(tokens, "''+"), use.names = FALSE)
      tokens <- tokens[nzchar(tokens)]
      keep <- nchar(tokens, type = "chars") >= min_token_length &
        !tokens %in% normalized_stopwords
      if (numbers == "remove") {
        # Drop purely numeric tokens (years, counts) while keeping alphanumerics
        # such as "covid19". Runs joined only by digits are numbers; letters make
        # a word.
        keep <- keep & grepl("[^0-9']", tokens)
      }
      if (roman_numerals == "remove") {
        # Drop chapter/section/list markers written as Roman numerals (bounded
        # at 100; see .sbert_roman_numerals).
        keep <- keep & !tokens %in% .sbert_roman_numerals
      }
      unname(tokens[keep])
    }
  )
  if (stem) {
    filtered <- collapse_inflections(filtered)
  }
  filtered
}

# Collapse inflected forms (mice/mouse aside, e.g. animal/animals, mean/means)
# onto a shared Porter stem, but display the most frequent surface form for each
# stem so labels stay readable ("picture", not "pictur"). Deterministic.
collapse_inflections <- function(token_lists) {
  if (!requireNamespace("SnowballC", quietly = TRUE)) {
    sbert_abort(
      "Stemming requires the 'SnowballC' package. Install it or use stem = FALSE.",
      class = "sbert_missing_package"
    )
  }
  all_tokens <- unlist(token_lists, use.names = FALSE)
  if (length(all_tokens) == 0L) {
    return(token_lists)
  }

  unique_tokens <- unique(all_tokens)
  token_stems <- SnowballC::wordStem(unique_tokens, language = "english")
  surface_frequency <- table(all_tokens)
  # Rank surfaces by descending corpus frequency, breaking ties alphabetically;
  # the first surface seen for each stem becomes that stem's display form.
  surface_order <- order(
    -as.integer(surface_frequency[unique_tokens]),
    unique_tokens
  )
  ordered_tokens <- unique_tokens[surface_order]
  ordered_stems <- token_stems[surface_order]
  display_form <- ordered_tokens[!duplicated(ordered_stems)]
  names(display_form) <- ordered_stems[!duplicated(ordered_stems)]
  canonical <- display_form[token_stems]
  names(canonical) <- unique_tokens

  lapply(
    token_lists,
    function(tokens) {
      if (length(tokens) == 0L) tokens else unname(canonical[tokens])
    }
  )
}

topic_term_scores <- function(
  text,
  topic,
  n_topics,
  n_terms,
  stop_words,
  min_term_frequency,
  min_token_length,
  weighting = c("ctfidf", "bm25"),
  reduce_frequent_words = FALSE,
  stem = FALSE,
  token_lists = NULL,
  cores = 1L,
  numbers = "keep",
  roman_numerals = "keep",
  section_numbers = "keep"
) {
  weighting <- match.arg(weighting)
  stopifnot(
    is.character(text),
    !anyNA(text),
    is.integer(topic),
    length(topic) == length(text),
    all(topic %in% seq_len(n_topics)),
    is.numeric(n_topics),
    length(n_topics) == 1L,
    n_topics == as.integer(n_topics),
    is.numeric(n_terms),
    length(n_terms) == 1L,
    n_terms >= 1,
    n_terms == as.integer(n_terms),
    is.numeric(min_term_frequency),
    length(min_term_frequency) == 1L,
    min_term_frequency >= 1,
    min_term_frequency == as.integer(min_term_frequency),
    is.logical(reduce_frequent_words),
    length(reduce_frequent_words) == 1L,
    !is.na(reduce_frequent_words)
  )

  # Tokenization depends only on the text and the token settings, never on the
  # clustering, so a prepared corpus can compute it once and inject it here for
  # reuse across many models. The result is identical to tokenizing in place.
  if (is.null(token_lists)) {
    token_lists <- tokenize_topic_documents(
      text, stop_words, min_token_length, stem = stem, cores = cores,
      numbers = numbers, roman_numerals = roman_numerals,
      section_numbers = section_numbers
    )
  }
  all_tokens <- unlist(token_lists, use.names = FALSE)
  if (length(all_tokens) == 0L) {
    sbert_abort(
      "No topic terms remain after tokenization and filtering.",
      class = "sbert_no_terms"
    )
  }

  corpus_counts <- table(all_tokens)
  vocabulary <- sort(names(corpus_counts[corpus_counts >= min_term_frequency]))
  if (length(vocabulary) == 0L) {
    sbert_abort(
      "No topic terms meet min_term_frequency.",
      class = "sbert_no_terms"
    )
  }

  count_matrix <- do.call(
    rbind,
    lapply(
      seq_len(n_topics),
      function(topic_id) {
        topic_tokens <- unlist(token_lists[topic == topic_id], use.names = FALSE)
        tabulate(match(topic_tokens, vocabulary), nbins = length(vocabulary))
      }
    )
  )
  storage.mode(count_matrix) <- "double"
  colnames(count_matrix) <- vocabulary
  row_totals <- rowSums(count_matrix)
  # A is the average number of words per class (kept as a float to match the
  # published c-TF-IDF formula, Mendonca & Figueira 2025, Eq. 1); f_x is the
  # frequency of a term across all classes.
  average_topic_length <- mean(row_totals)
  if (average_topic_length < 1) {
    sbert_abort(
      "The average topic length is zero after tokenization and filtering.",
      class = "sbert_no_terms"
    )
  }
  global_frequency <- pmax(colSums(count_matrix), 1)
  inverse_document_frequency <- if (weighting == "bm25") {
    # BM25 weighting (Eq. 2): down-weights terms common across classes.
    log1p((average_topic_length - global_frequency + 0.5) /
      (global_frequency + 0.5))
  } else {
    log1p(average_topic_length / global_frequency)
  }
  term_frequency <- count_matrix / pmax(row_totals, 1)
  if (reduce_frequent_words) {
    # reduce_frequent_words (Eq. 3): square-root damping of within-class tf.
    term_frequency <- sqrt(term_frequency)
  }
  score_matrix <- sweep(
    term_frequency,
    2L,
    inverse_document_frequency,
    `*`
  )

  topic_tables <- lapply(
    seq_len(n_topics),
    function(topic_id) {
      positive <- which(count_matrix[topic_id, ] > 0)
      if (length(positive) == 0L) {
        return(data.frame(
          topic = integer(),
          term = character(),
          rank = integer(),
          score = numeric(),
          frequency = integer(),
          stringsAsFactors = FALSE
        ))
      }
      ranking <- order(
        -score_matrix[topic_id, positive],
        -count_matrix[topic_id, positive],
        vocabulary[positive]
      )
      selected <- positive[utils::head(ranking, n_terms)]
      data.frame(
        topic = rep.int(as.integer(topic_id), length(selected)),
        term = vocabulary[selected],
        rank = seq_along(selected),
        score = unname(score_matrix[topic_id, selected]),
        frequency = as.integer(count_matrix[topic_id, selected]),
        stringsAsFactors = FALSE
      )
    }
  )

  terms <- do.call(rbind, topic_tables)
  rownames(terms) <- NULL
  list(
    terms = terms,
    counts = count_matrix,
    scores = score_matrix,
    average_topic_length = average_topic_length
  )
}

deterministic_topic_centers <- function(embeddings, n_topics, existing_centers = NULL) {
  stopifnot(
    is.matrix(embeddings),
    is.numeric(embeddings),
    nrow(embeddings) >= 2L,
    ncol(embeddings) >= 1L,
    !anyNA(embeddings),
    all(is.finite(embeddings)),
    is.numeric(n_topics),
    length(n_topics) == 1L,
    n_topics >= 1,
    n_topics == as.integer(n_topics),
    n_topics <= nrow(embeddings),
    is.null(existing_centers) ||
      (is.matrix(existing_centers) && ncol(existing_centers) == ncol(embeddings))
  )

  n_documents <- nrow(embeddings)
  n_dimensions <- ncol(embeddings)

  # Squared distance from every embedding row to one center, using the same
  # elementwise arithmetic as a full pairwise pass so the selections are
  # identical to a recompute-everything implementation. Farthest-point
  # selection then keeps a running nearest-center distance and touches one new
  # center per step, so the cost is O(n_topics * n * d) rather than the
  # O(n_topics^2 * n * d) of rebuilding the whole distance set each iteration.
  squared_distance_to <- function(center) {
    # Broadcasting the center to a full document-by-dimension matrix and
    # subtracting it allocates two corpus-sized transients per call, and this
    # runs once per selected center. Doing it in row blocks keeps the transient
    # to one block while leaving the per-row arithmetic (and the selections)
    # exactly the same.
    out <- numeric(n_documents)
    chunk <- 8192L
    for (start in seq.int(1L, n_documents, chunk)) {
      idx <- start:min(start + chunk - 1L, n_documents)
      center_block <- matrix(
        center,
        nrow = length(idx),
        ncol = n_dimensions,
        byrow = TRUE
      )
      out[idx] <- rowSums((embeddings[idx, , drop = FALSE] - center_block)^2)
    }
    out
  }

  if (is.null(existing_centers) || nrow(existing_centers) == 0L) {
    # First free center is the point farthest from the global mean.
    nearest_distance <- rep(Inf, n_documents)
    first_center <- which.max(squared_distance_to(colMeans(embeddings)))
  } else {
    # Seeded: distance to the nearest seed, accumulated one seed at a time; the
    # first free center is the point least covered by the seeds.
    nearest_distance <- Reduce(
      function(running, seed_row) {
        pmin(running, squared_distance_to(existing_centers[seed_row, ]))
      },
      seq_len(nrow(existing_centers)),
      init = rep(Inf, n_documents)
    )
    first_center <- which.max(nearest_distance)
  }

  selected <- first_center
  nearest_distance <- pmin(
    nearest_distance,
    squared_distance_to(embeddings[first_center, ])
  )
  nearest_distance[selected] <- -Inf

  for (unused_iteration in seq_len(n_topics - 1L)) {
    next_center <- which.max(nearest_distance)
    if (nearest_distance[[next_center]] <= 0) {
      # Every unselected point coincides with one already chosen: the corpus has
      # fewer distinct embeddings than requested topics. Detected here, exactly
      # when it matters, instead of by an up-front full-matrix dedup.
      sbert_abort(
        "n_topics cannot exceed the number of distinct document embeddings.",
        class = "sbert_bad_input"
      )
    }
    selected <- c(selected, next_center)
    nearest_distance <- pmin(
      nearest_distance,
      squared_distance_to(embeddings[next_center, ])
    )
    nearest_distance[selected] <- -Inf
  }

  embeddings[selected, , drop = FALSE]
}

fit_embedding_topics <- function(
  embeddings,
  n_topics,
  iter_max,
  initial_centers = NULL,
  reorder = TRUE,
  fixed = FALSE
) {
  stopifnot(
    is.matrix(embeddings),
    is.numeric(embeddings),
    !anyNA(embeddings),
    all(is.finite(embeddings)),
    is.numeric(iter_max),
    length(iter_max) == 1L,
    iter_max >= 1,
    iter_max == as.integer(iter_max),
    is.null(initial_centers) ||
      (is.matrix(initial_centers) && nrow(initial_centers) == n_topics),
    is.logical(reorder),
    length(reorder) == 1L,
    is.logical(fixed),
    length(fixed) == 1L,
    !fixed || !is.null(initial_centers)
  )

  normalized_embeddings <- normalize_embedding_rows(embeddings)
  starting_centers <- if (is.null(initial_centers)) {
    deterministic_topic_centers(normalized_embeddings, n_topics)
  } else {
    normalize_embedding_rows(initial_centers)
  }

  if (fixed) {
    # Zero-shot assignment: centroids stay exactly at the supplied centers and
    # every document joins its nearest one. Topics may legitimately be empty.
    assignment <- max.col(
      normalized_embeddings %*% t(starting_centers),
      ties.method = "first"
    )
    sizes <- tabulate(assignment, nbins = n_topics)
    fixed_withinss <- vapply(
      seq_len(n_topics),
      function(topic_id) {
        member_rows <- normalized_embeddings[
          assignment == topic_id, ,
          drop = FALSE
        ]
        if (nrow(member_rows) == 0L) {
          return(0)
        }
        # The sum of squares of the partition (around the members' mean), so
        # that between/total SS is the share of variance the assignment
        # explains, in [0, 1], as for a k-means fit. The frozen seeds are not
        # the members' mean, and measuring around them could exceed totss.
        sum(sweep(member_rows, 2L, colMeans(member_rows))^2)
      },
      numeric(1)
    )
    global_center <- matrix(
      colMeans(normalized_embeddings),
      nrow = nrow(normalized_embeddings),
      ncol = ncol(normalized_embeddings),
      byrow = TRUE
    )
    totss <- sum((normalized_embeddings - global_center)^2)
    fit <- list(
      cluster = as.integer(assignment),
      centers = unname(starting_centers),
      size = as.integer(sizes),
      withinss = fixed_withinss,
      totss = totss,
      tot.withinss = sum(fixed_withinss),
      betweenss = totss - sum(fixed_withinss),
      iter = 0L
    )
    converged <- TRUE
    kmeans_warnings <- character()
  } else {
    # Warnings from kmeans() are recorded in the diagnostics rather than lost:
    # with cores > 1 a fit can run in a forked worker, where an unrecorded
    # warning would never reach the user. Non-convergence is re-raised below
    # as a classed warning; anything else passes through unchanged.
    kmeans_warnings <- character()
    fit <- tryCatch(
      withCallingHandlers(
        stats::kmeans(
          normalized_embeddings,
          centers = starting_centers,
          iter.max = as.integer(iter_max),
          algorithm = "Lloyd"
        ),
        warning = function(warning_condition) {
          message_text <- conditionMessage(warning_condition)
          kmeans_warnings <<- c(kmeans_warnings, message_text)
          if (grepl("did not converge", message_text, fixed = TRUE)) {
            invokeRestart("muffleWarning")
          }
        }
      ),
      error = function(error_condition) {
        sbert_abort(
          sprintf("Topic clustering failed: %s", conditionMessage(error_condition)),
          class = "sbert_clustering_failed"
        )
      }
    )
    converged <- fit$iter <= iter_max && !identical(fit$ifault, 2L)
    if (!converged) {
      sbert_warn(
        sprintf(
          paste0(
            "k-means did not converge in %d iterations; the topics are ",
            "returned as they stood. Raise `iter_max` to continue the fit."
          ),
          as.integer(iter_max)
        ),
        class = "sbert_no_converge"
      )
    }
    if (length(fit$size) != n_topics || any(fit$size <= 0L)) {
      sbert_abort(
        "Topic clustering produced an empty topic.",
        class = "sbert_clustering_failed"
      )
    }
  }

  topic_order <- if (reorder) {
    order(-fit$size, seq_len(n_topics))
  } else {
    # Seeded models keep centroid identity: topic i stays seed i.
    seq_len(n_topics)
  }
  new_topic_id <- integer(n_topics)
  new_topic_id[topic_order] <- seq_len(n_topics)
  topic <- as.integer(new_topic_id[fit$cluster])
  centers <- unname(fit$centers[topic_order, , drop = FALSE])
  normalized_centers <- normalize_embedding_rows(centers)
  # Each document's cosine to its own topic centroid. Computed in row blocks so
  # the gathered centroids and the elementwise product are one block at a time,
  # not two full corpus-sized transients; the per-row arithmetic is unchanged.
  n_documents <- nrow(normalized_embeddings)
  cosine_similarity <- numeric(n_documents)
  chunk <- 8192L
  for (start in seq.int(1L, n_documents, chunk)) {
    idx <- start:min(start + chunk - 1L, n_documents)
    cosine_similarity[idx] <- rowSums(
      normalized_embeddings[idx, , drop = FALSE] *
        normalized_centers[topic[idx], , drop = FALSE]
    )
  }

  list(
    topic = topic,
    distance = pmax(0, 1 - cosine_similarity),
    centers = centers,
    normalized_embeddings = normalized_embeddings,
    size = as.integer(fit$size[topic_order]),
    withinss = unname(fit$withinss[topic_order]),
    diagnostics = list(
      totss = unname(fit$totss),
      tot_withinss = unname(fit$tot.withinss),
      betweenss = unname(fit$betweenss),
      iterations = min(as.integer(fit$iter), as.integer(iter_max)),
      converged = converged,
      warnings = kmeans_warnings,
      algorithm = if (fixed) {
        "fixed seed centroids (nearest-centroid assignment)"
      } else {
        "deterministic k-means (Lloyd)"
      }
    )
  )
}

topic_representatives <- function(documents, n_topics, n_representatives) {
  stopifnot(
    is.data.frame(documents),
    all(c("document_id", "document_name", "text", "topic", "distance") %in%
      names(documents)),
    is.numeric(n_representatives),
    length(n_representatives) == 1L,
    n_representatives >= 1,
    n_representatives == as.integer(n_representatives)
  )

  representatives <- lapply(
    seq_len(n_topics),
    function(topic_id) {
      topic_documents <- documents[documents$topic == topic_id, , drop = FALSE]
      ranking <- order(topic_documents$distance, topic_documents$document_id)
      # Distinct texts that contain an actual word (a run of two or more
      # letters): the same string repeated is never useful (duplicates are
      # common once documents are segmented), and a unit with no real word
      # ("2 .", "100", "1983, p.", a stray citation fragment) is noise, not an
      # example.
      ordered_text <- topic_documents$text[ranking]
      ranking <- ranking[
        !duplicated(ordered_text) &
          grepl("(*UTF)\\p{L}{2}", ordered_text, perl = TRUE)
      ]
      selected <- utils::head(ranking, n_representatives)
      # A segmented fit also names the segment's position in its document.
      unit_columns <- intersect(
        c("document_id", "document_name", "segment", "text", "distance"),
        names(topic_documents)
      )
      cbind(
        data.frame(
          topic = rep.int(as.integer(topic_id), length(selected)),
          rank = seq_along(selected),
          stringsAsFactors = FALSE
        ),
        topic_documents[selected, unit_columns, drop = FALSE]
      )
    }
  )
  result <- do.call(rbind, representatives)
  rownames(result) <- NULL
  result
}

encode_topic_documents <- function(text, model, batch_size) {
  stopifnot(
    is.character(text),
    !anyNA(text),
    inherits(model, "sbert_model"),
    is.numeric(batch_size),
    length(batch_size) == 1L,
    batch_size >= 1,
    batch_size == as.integer(batch_size)
  )
  encode(
    text,
    model,
    batch_size = as.integer(batch_size),
    normalize = TRUE
  )
}

# The segmentation options shared by every fitting verb, validated once. A
# document-level fit has nothing to segment, so the segment-only options are
# refused there rather than ignored.
validate_topic_segmentation <- function(
  segment,
  max_tokens,
  merge_below,
  min_content
) {
  stopifnot(
    is.null(max_tokens) ||
      (
        is.numeric(max_tokens) && length(max_tokens) == 1L &&
          is.finite(max_tokens) && max_tokens >= 1 &&
          max_tokens == as.integer(max_tokens)
      ),
    is.numeric(merge_below),
    length(merge_below) == 1L,
    is.finite(merge_below),
    merge_below >= 0,
    merge_below == as.integer(merge_below),
    is.numeric(min_content),
    length(min_content) == 1L,
    is.finite(min_content),
    min_content >= 0,
    min_content <= 1
  )
  if (
    segment == "document" &&
      (!is.null(max_tokens) || merge_below > 0 || min_content > 0)
  ) {
    sbert_abort(
      "max_tokens, merge_below, and min_content apply only when segment is ",
      "\"sentence\", \"clause\", or \"phrase\".",
      class = "sbert_bad_input"
    )
  }
  list(
    segment = segment,
    max_tokens = if (is.null(max_tokens)) NULL else as.integer(max_tokens),
    merge_below = as.integer(merge_below),
    min_content = as.numeric(min_content)
  )
}

# Split documents into the units a topic model is fitted on (or predicts for).
# `model` is only forwarded when `max_tokens` counts that model's own tokens;
# segment() refuses a model otherwise.
segment_topic_documents <- function(
  text,
  segmentation,
  cores = 1L,
  model = NULL,
  minimum = 2L
) {
  units <- segment(
    text,
    level = segmentation$segment,
    merge_below = segmentation$merge_below,
    cores = cores,
    max_tokens = segmentation$max_tokens,
    model = if (is.null(segmentation$max_tokens)) NULL else model,
    min_content = segmentation$min_content
  )
  if (nrow(units) < minimum) {
    sbert_abort(
      sprintf(
        paste0(
          "segment = \"%s\" produced %d segment(s) from %d document(s); ",
          "at least %d are needed."
        ),
        segmentation$segment,
        nrow(units),
        length(text),
        minimum
      ),
      class = "sbert_bad_input"
    )
  }
  units
}

# The segmentation a fitted model or prepared corpus was built with. Models
# fitted before the `segment` argument existed carry no record and are
# document-level.
topic_segmentation <- function(object) {
  settings <- object$settings
  merge_below <- settings$merge_below
  min_content <- settings$min_content
  list(
    segment = if (is.null(settings$segment)) "document" else settings$segment,
    max_tokens = settings$max_tokens,
    merge_below = if (is.null(merge_below)) 0L else merge_below,
    min_content = if (is.null(min_content)) 0 else min_content
  )
}

is_segmented_topic_model <- function(object) {
  !identical(topic_segmentation(object)$segment, "document")
}

#' Prepare a corpus once for several topic models
#'
#' @description
#' `topic_corpus()` prepares a corpus once for several topic models: it segments
#' the texts, embeds them, and tokenizes them for term scoring, and returns a
#' prepared corpus that [topics()] and [compare_topics()] accept in place of the
#' texts. Fitting topic models usually means fitting several (different numbers
#' of topics, term settings, or seeds on the same texts), and these three steps
#' do not depend on any of those choices; embedding is by far the most expensive
#' step.
#'
#' Models fitted to the corpus are identical to models fitted to the raw texts.
#' The corpus fixes the embeddings (from `model` or `embeddings`), the
#' segmentation, and the tokenization settings; the settings of each model, such
#' as `n_topics`, `n_terms`, `weighting`, and `seeds`, are still chosen per
#' call. The result is an object of class `sbert_topic_corpus`.
#'
#' [compare_topics()] builds a corpus itself, so a corpus is needed only
#' when models are fitted one at a time.
#'
#' @param text Documents: a character vector with one document per element,
#'   or a data frame together with `column`.
#' @inheritParams topics
#' @return An object of class `sbert_topic_corpus`. Its units (one row per
#'   document, or per segment) are given by
#'   [as.data.frame()][as.data.frame.sbert_topic_corpus]; printing it shows
#'   the number of documents and segments, the embedding dimension, the
#'   model, and the tokenization settings.
#' @section Conditions:
#'   Errors of class `sbert_bad_input` when both `model` and `embeddings` are
#'   given, a document is blank, the embeddings do not have one row per unit,
#'   the segmentation produces fewer than two segments, or `segment` is passed
#'   together with an existing corpus; `sbert_missing_package` for
#'   `stem = TRUE` without SnowballC. When a model is used, the errors of
#'   [load_model()] and [encode()] apply.
#' @seealso [topics()] and [compare_topics()], which take the corpus;
#'   [as.data.frame()][as.data.frame.sbert_topic_corpus] for its units;
#'   [segment()] for the segmentation.
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' prepared <- topic_corpus(corpus, column = "translation",
#'                          embeddings = feedback_embeddings)
#' prepared
#' topic_sizes(topics(prepared, n_topics = 4))
#' topic_sizes(topics(prepared, n_topics = 6))
topic_corpus <- function(
  text,
  column = NULL,
  model = NULL,
  embeddings = NULL,
  batch_size = 32L,
  stop_words = default_stop_words(),
  min_token_length = 2L,
  stem = FALSE,
  cores = 1L,
  numbers = c("keep", "remove"),
  roman_numerals = c("keep", "remove"),
  section_numbers = c("keep", "remove"),
  segment = c("document", "sentence", "clause", "phrase"),
  max_tokens = NULL,
  merge_below = 0L,
  min_content = 0
) {
  numbers <- match.arg(numbers)
  roman_numerals <- match.arg(roman_numerals)
  section_numbers <- match.arg(section_numbers)
  segment <- match.arg(segment)
  segmentation <- validate_topic_segmentation(
    segment, max_tokens, merge_below, min_content
  )
  if (inherits(text, "sbert_topic_corpus")) {
    if (segment != "document") {
      sbert_abort(
        "Segmentation is fixed by a prepared topic_corpus; pass segment = ",
        "to topic_corpus() when building it.",
        class = "sbert_bad_input"
      )
    }
    return(text)
  }
  if (!is.null(model) && !is.null(embeddings)) {
    sbert_abort(
      "Supply model or embeddings, not both.",
      class = "sbert_bad_input"
    )
  }
  prepared <- prepare_topic_input(text, column)
  text <- prepared$text
  metadata <- prepared$metadata
  # Supplied embeddings follow the modeled units: one row per document at
  # document level (so dropped rows are dropped here too), one row per segment
  # otherwise (checked once the segments exist).
  if (
    segment == "document" &&
      !is.null(embeddings) &&
      length(prepared$kept) < prepared$n_supplied
  ) {
    embeddings <- embeddings[prepared$kept, , drop = FALSE]
  }
  stopifnot(
    is.character(text),
    !anyNA(text),
    length(text) >= if (segment == "document") 2L else 1L,
    is.numeric(batch_size),
    length(batch_size) == 1L,
    is.finite(batch_size),
    batch_size >= 1,
    batch_size == as.integer(batch_size),
    is.character(stop_words),
    !anyNA(stop_words),
    is.numeric(min_token_length),
    length(min_token_length) == 1L,
    is.finite(min_token_length),
    min_token_length >= 1,
    min_token_length == as.integer(min_token_length),
    is.logical(stem),
    length(stem) == 1L,
    !is.na(stem)
  )
  if (stem && !requireNamespace("SnowballC", quietly = TRUE)) {
    sbert_abort(
      "stem = TRUE requires the 'SnowballC' package. Install it or use stem = FALSE.",
      class = "sbert_missing_package"
    )
  }
  if (any(!nzchar(trimws(text)))) {
    sbert_abort(
      "text cannot contain blank documents.",
      class = "sbert_bad_input"
    )
  }

  if (is.null(embeddings)) {
    model <- resolve_sbert_model(model)
  }
  # Segment before encoding so the model sees whole units, not the truncated
  # opening of a long document. Metadata is expanded to one row per unit so it
  # still rides along into $documents.
  units <- NULL
  if (segment != "document") {
    units <- segment_topic_documents(
      text,
      segmentation,
      cores = cores,
      model = if (is.null(embeddings)) model else NULL
    )
    if (!is.null(metadata)) {
      metadata <- metadata[units$document_id, , drop = FALSE]
      rownames(metadata) <- NULL
    }
    misaligned <- !is.null(embeddings) &&
      is.matrix(embeddings) &&
      nrow(embeddings) != nrow(units)
    if (misaligned) {
      sbert_abort(
        sprintf(
          paste0(
            "With segment = \"%s\", embeddings must have one row per segment: ",
            "%d segments were produced but %d rows were supplied. Encode the ",
            "`text` column of segment(text, level = \"%s\") to align them."
          ),
          segment,
          nrow(units),
          nrow(embeddings),
          segment
        ),
        class = "sbert_bad_input"
      )
    }
    text <- units$text
  }

  if (is.null(embeddings)) {
    embedding_matrix <- encode_topic_documents(
      text,
      model,
      batch_size = as.integer(batch_size)
    )
    model_information <- list(
      id = model$id,
      revision = model$revision,
      dimension = model$dimension
    )
  } else {
    embedding_matrix <- embeddings
    model_information <- list(
      id = "precomputed embeddings",
      revision = NA_character_,
      dimension = if (is.matrix(embeddings)) ncol(embeddings) else NA_integer_
    )
  }
  if (
    !is.matrix(embedding_matrix) ||
      !is.numeric(embedding_matrix) ||
      nrow(embedding_matrix) != length(text) ||
      ncol(embedding_matrix) < 1L ||
      anyNA(embedding_matrix) ||
      any(!is.finite(embedding_matrix))
  ) {
    sbert_abort(
      "embeddings must be a finite numeric matrix with one row per document.",
      class = "sbert_bad_input"
    )
  }

  token_lists <- tokenize_topic_documents(
    unname(text),
    stop_words,
    as.integer(min_token_length),
    stem = stem,
    cores = cores,
    numbers = numbers,
    roman_numerals = roman_numerals,
    section_numbers = section_numbers
  )

  structure(
    list(
      text = text,
      metadata = metadata,
      units = if (is.null(units)) {
        NULL
      } else {
        units[, c("document_id", "document_name", "segment")]
      },
      embeddings = embedding_matrix,
      token_lists = token_lists,
      model = model_information,
      settings = list(
        stop_words = stop_words,
        min_token_length = as.integer(min_token_length),
        stem = stem,
        numbers = numbers,
        roman_numerals = roman_numerals,
        section_numbers = section_numbers,
        segment = segmentation$segment,
        max_tokens = segmentation$max_tokens,
        merge_below = segmentation$merge_below,
        min_content = segmentation$min_content
      )
    ),
    class = "sbert_topic_corpus"
  )
}

#' Print a prepared topic corpus
#'
#' @description
#' `print()` shows what a corpus prepared by [topic_corpus()] holds: the number
#' of documents and, for a segmented corpus, of segments and their level; the
#' embedding dimension; the embedding model; and the minimum token length and
#' whether tokens are stemmed.
#'
#' @param x A corpus prepared by [topic_corpus()].
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @seealso [topic_corpus()];
#'   [as.data.frame()][as.data.frame.sbert_topic_corpus] for the units.
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' print(topic_corpus(corpus, column = "translation",
#'                    embeddings = feedback_embeddings))
print.sbert_topic_corpus <- function(x, ...) {
  cat("<sbert_topic_corpus>\n")
  if (is.null(x$units)) {
    cat("  documents:", length(x$text), "\n")
  } else {
    cat("  documents:", length(unique(x$units$document_id)), "\n")
    cat(
      "  segments:", length(x$text),
      sprintf("(%s level)", x$settings$segment), "\n"
    )
  }
  cat("  embedding dimension:", ncol(x$embeddings), "\n")
  cat("  model:", x$model$id, "\n")
  cat(
    "  tokenization: min_token_length =", x$settings$min_token_length,
    if (x$settings$stem) ", stemmed" else "", "\n"
  )
  invisible(x)
}

#' Fit semantic topics to documents
#'
#' @description
#' `topics()` fits an embedding-based topic model: it groups texts, or the
#' sentences, clauses, or phrases of texts, by what they mean rather than by the
#' words they share, and each group is a topic. Each unit is represented by a
#' Sentence-BERT embedding (Reimers and Gurevych 2019), a vector in which texts
#' of similar meaning lie close together, and the embeddings are partitioned
#' into groups of semantically similar texts.
#'
#' Every unit is assigned to one of `n_topics` topics by k-means clustering
#' (Lloyd 1982) of the L2-normalized embeddings, started from farthest-point
#' initial centers. The fit is deterministic: the same input always gives the
#' same topics, and no random seed is involved. Each topic is described by its
#' distinctive terms, scored by class-based TF-IDF (Grootendorst 2022; Mendonca
#' and Figueira 2025), and by its representative units, those nearest its
#' center. By default a topic is labeled by its most central text. Topics are
#' numbered by size, largest first, unless `seeds` fix their order. Unlike
#' latent Dirichlet allocation, the model does not represent a text as a mixture
#' of word distributions, so it does not depend on words co-occurring within
#' texts, which they rarely do in short texts.
#'
#' The result, an object of class `sbert_topic_model`, shows which kinds of
#' content a corpus holds and how much of the corpus each kind accounts for.
#'
#' To choose the number of topics and the unit of analysis, compare candidate
#' fits with [compare_topics()]. To fit several models to one corpus, prepare
#' it once with [topic_corpus()]. New texts are assigned to the fitted topics
#' by [predict()][predict.sbert_topic_model], and each document's mixture of
#' topics is given by [topic_gamma()]. To merge the topics of an existing fit,
#' use [reduce_topics()].
#'
#' @param text Documents: a character vector with one document per element, a
#'   data frame together with `column`, or a corpus prepared by
#'   [topic_corpus()].
#' @param n_topics Number of topics: an integer of at least 2 and at most the
#'   number of modeled units.
#' @param column Name of the text column when `text` is a data frame. The other
#'   columns are carried into the document table. Rows whose text is missing,
#'   blank, or the placeholder `"[No abstract available]"` are dropped, and so
#'   are their rows of `embeddings`. `NULL` (default) for a character vector.
#' @param model The encoder: a model from [load_model()], a pinned model name
#'   from [models()], or `NULL` (default) for the default model. Not used when
#'   `embeddings` are given.
#' @param embeddings Optional numeric matrix of precomputed embeddings, one row
#'   per modeled unit (per document, or per segment with `segment`). When it
#'   is given, no model is loaded. Default `NULL`.
#' @param batch_size Texts encoded per model call (default 32).
#' @param iter_max Maximum number of k-means iterations (default 100).
#' @param n_terms Terms stored per topic (default 10).
#' @param n_representatives Representative units stored per topic (default 5).
#' @param stop_words Words excluded from the topic terms; default
#'   [stop_words()]. `character()` turns the filter off.
#' @param min_term_frequency Minimum corpus-wide frequency of a term
#'   (default 1).
#' @param min_token_length Minimum length of a term, in characters
#'   (default 2).
#' @param numbers,roman_numerals,section_numbers Whether to `"keep"` (default)
#'   or `"remove"` digit-only tokens, Roman-numeral tokens, and section or list
#'   numbering (`1.2.3`, `1.`) from the topic terms. They change the terms
#'   only, not the text that is embedded; to clean the text, use
#'   [clean_corpus()].
#' @param weighting Term weighting: `"ctfidf"` (default) or `"bm25"`, which
#'   down-weights terms shared by many topics more strongly.
#' @param reduce_frequent_words Whether to take the square root of
#'   within-topic term frequencies before weighting (default `FALSE`).
#' @param stem Whether to merge inflected forms of a term under one Porter
#'   stem, shown as its most frequent form (default `FALSE`; needs the
#'   SnowballC package).
#' @param keep_embeddings Whether to store the normalized embeddings in the
#'   model (default `TRUE`). Without them, [reduce_topics()],
#'   [topic_membership()], and [representatives()] need the embeddings
#'   supplied again.
#' @param seeds Optional guided topics: a character vector, or a list of
#'   character vectors, of seed words or descriptions, one element per seeded
#'   topic. The embedding of seed `i` is the starting center of topic `i`, and
#'   the names of `seeds`, if any, become topic labels. Default `NULL`.
#' @param seed_embeddings Matrix of seed embeddings, one row per seed. Needed
#'   when `seeds` are combined with precomputed `embeddings`.
#' @param fixed_seeds If `TRUE`, the seed centers are held fixed and each unit
#'   joins its nearest seed (zero-shot classification); `n_topics` must equal
#'   the number of seeds, and a topic may be empty. Default `FALSE`.
#' @param cores Number of forked worker processes for tokenization (default 1;
#'   Unix-alikes only). Results do not depend on it.
#' @param segment Unit of analysis: `"document"` (default), or `"sentence"`,
#'   `"clause"`, or `"phrase"`, which split each document with [segment()]
#'   and fit the topics to the segments, so that a document can take part in
#'   several topics.
#' @param max_tokens,merge_below,min_content Segmentation options passed to
#'   [segment()], for segmented fits only: the maximum segment length (in the
#'   model's tokens, or in words with precomputed `embeddings`; default
#'   `NULL`, no limit), the number of words below which a segment is joined to
#'   its neighbor (default 0), and the minimum share of letters for a segment
#'   to be kept (default 0; see [content_ratio()]).
#' @param label How topics are labeled: `"representative"` (default), the most
#'   central text shortened to 60 characters, or `"terms"`, the three most
#'   distinctive terms. Named `seeds` override both.
#' @return An object of class `sbert_topic_model`, a list with
#'   \describe{
#'     \item{`documents`}{One row per modeled unit (document, or segment):
#'       `document_id`, `document_name`, `segment` (segmented fits only),
#'       `text`, `topic`, `label`, and `distance` (cosine distance to the topic
#'       center), followed by the columns carried from a data frame.}
#'     \item{`topics`}{One row per topic: `topic`, `label`, `n_documents`,
#'       `proportion`, and `withinss`.}
#'     \item{`terms`, `representatives`}{The stored terms and representative
#'       units of each topic.}
#'     \item{`centers`}{Numeric matrix of topic centers, one row per topic: the
#'       k-means means of the L2-normalized embeddings. They are not rescaled,
#'       so their norms are below one; verbs that use cosine similarity
#'       normalize them first.}
#'     \item{`embeddings`}{The normalized embeddings, or `NULL` when
#'       `keep_embeddings = FALSE`.}
#'     \item{`diagnostics`}{Sums of squares (`totss`, `tot_withinss`,
#'       `betweenss`), `iterations`, `converged` (whether k-means converged
#'       within `iter_max`), `warnings` (warnings raised by
#'       [stats::kmeans()]), and `algorithm`.}
#'     \item{`model`, `settings`}{The identity of the embedding model and the
#'       settings of the fit, which later verbs reuse.}
#'   }
#'   Read it through its accessors rather than its fields:
#'   [as.data.frame()][as.data.frame.sbert_topic_model] with `what =
#'   "documents"`, `"topics"`, `"terms"`, or `"representatives"`;
#'   [topic_sizes()]; [terms()][terms.sbert_topic_model];
#'   [representatives()]; and [summary()][summary.sbert_topic_model], which
#'   also reports a fit that did not converge.
#' @section Conditions:
#'   Errors of class `sbert_bad_input` for conflicting arguments, embeddings
#'   without one row per unit, more topics than distinct embeddings, or a
#'   `model`, `embeddings`, or different `segment` combined with a prepared
#'   corpus; `sbert_missing_package` for `stem = TRUE` without SnowballC;
#'   `sbert_no_terms` when no term passes the filters; and
#'   `sbert_clustering_failed` when k-means fails or leaves a topic empty.
#'   Arguments of the wrong type or range fail a plain [stopifnot()] check.
#'   When a model is used, the errors of [load_model()] and [encode()] apply.
#'   A warning of class `sbert_no_converge` when k-means reaches `iter_max`
#'   without converging; the fit is still returned. Errors inherit
#'   `sbert_error` and warnings `sbert_warning`.
#' @seealso [compare_topics()] to choose the number of topics;
#'   [topic_corpus()] to prepare a corpus once; [name_topics()] to name the
#'   topics; [plot()][plot.sbert_topic_model] for figures;
#'   [predict()][predict.sbert_topic_model] and [topic_gamma()] for new texts
#'   and topic mixtures; [feedback_embeddings] for the example data.
#' @references
#' Reimers, N. and Gurevych, I. (2019). Sentence-BERT: Sentence embeddings
#' using Siamese BERT-networks. *Proceedings of EMNLP-IJCNLP 2019*,
#' 3982--3992. \doi{10.18653/v1/D19-1410}
#'
#' Grootendorst, M. (2022). BERTopic: Neural topic modeling with a class-based
#' TF-IDF procedure. arXiv:2203.05794.
#'
#' Mendonca, M. and Figueira, A. (2025). Modeling political discourse with
#' Sentence-BERT and BERTopic. arXiv:2510.22904.
#'
#' Lloyd, S. P. (1982). Least squares quantization in PCM. *IEEE Transactions
#' on Information Theory*, 28(2), 129--137. \doi{10.1109/TIT.1982.1056489}
#' @export
#' @examples
#' # 600 distinct feedback messages with their precomputed embeddings
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings)
#' topic_model
#' topic_sizes(topic_model, weights = "n")
#' terms(topic_model, n = 3)
#'
#' # Sentence-level fit: one embedding per sentence
#' documents <- c(
#'   "Cats chase mice. Stocks and bonds trade.",
#'   "Dogs chase balls. Markets price shares."
#' )
#' sentence_model <- topics(
#'   documents, n_topics = 2, segment = "sentence",
#'   embeddings = rbind(c(1, 0), c(0, 1), c(0.9, 0.1), c(0.1, 0.9))
#' )
#' topic_sizes(sentence_model, by = "document")
#' topic_gamma(sentence_model)
topics <- function(
  text,
  n_topics,
  column = NULL,
  model = NULL,
  embeddings = NULL,
  batch_size = 32L,
  iter_max = 100L,
  n_terms = 10L,
  n_representatives = 5L,
  stop_words = default_stop_words(),
  min_term_frequency = 1L,
  min_token_length = 2L,
  weighting = c("ctfidf", "bm25"),
  reduce_frequent_words = FALSE,
  stem = FALSE,
  keep_embeddings = TRUE,
  seeds = NULL,
  seed_embeddings = NULL,
  fixed_seeds = FALSE,
  cores = 1L,
  numbers = c("keep", "remove"),
  roman_numerals = c("keep", "remove"),
  section_numbers = c("keep", "remove"),
  segment = c("document", "sentence", "clause", "phrase"),
  max_tokens = NULL,
  merge_below = 0L,
  min_content = 0,
  label = c("representative", "terms")
) {
  weighting <- match.arg(weighting)
  label <- match.arg(label)
  numbers <- match.arg(numbers)
  roman_numerals <- match.arg(roman_numerals)
  section_numbers <- match.arg(section_numbers)
  segment <- match.arg(segment)
  segmentation <- validate_topic_segmentation(
    segment, max_tokens, merge_below, min_content
  )

  # Seeds are embedded with the same model as the documents. The segmented
  # path hands the model to topic_corpus() and continues with the corpus, so
  # the model is remembered here for the seeds alone.
  seed_model <- model

  # A segmented fit is a corpus fit: topic_corpus() owns the segmentation,
  # encoding, and tokenization, so the two routes cannot drift apart.
  if (!inherits(text, "sbert_topic_corpus") && segment != "document") {
    text <- topic_corpus(
      text,
      column = column,
      model = model,
      embeddings = embeddings,
      batch_size = batch_size,
      stop_words = stop_words,
      min_token_length = min_token_length,
      stem = stem,
      cores = cores,
      numbers = numbers,
      roman_numerals = roman_numerals,
      section_numbers = section_numbers,
      segment = segment,
      max_tokens = max_tokens,
      merge_below = merge_below,
      min_content = min_content
    )
    if (!is.null(seeds) && is.null(embeddings)) {
      seed_model <- resolve_sbert_model(model)
    }
    model <- NULL
    embeddings <- NULL
  }

  # A prepared topic_corpus carries the corpus-level work already done once:
  # the segmentation, the embeddings, the tokenization, and their settings.
  # Reusing it across many models skips both encoding and tokenization, with
  # byte-identical results. The corpus fixes those settings, so conflicting
  # overrides are refused rather than silently ignored.
  precomputed_tokens <- NULL
  corpus_model_information <- NULL
  units <- NULL
  if (inherits(text, "sbert_topic_corpus")) {
    corpus <- text
    if (!is.null(model)) {
      sbert_abort(
        "A model cannot be combined with a prepared topic_corpus.",
        class = "sbert_bad_input"
      )
    }
    if (!is.null(embeddings)) {
      sbert_abort(
        "embeddings cannot be combined with a prepared topic_corpus.",
        class = "sbert_bad_input"
      )
    }
    if (segment != "document" && !identical(corpus$settings$segment, segment)) {
      sbert_abort(
        "Segmentation is fixed by a prepared topic_corpus; pass segment = ",
        "to topic_corpus() when building it.",
        class = "sbert_bad_input"
      )
    }
    text <- corpus$text
    metadata <- corpus$metadata
    units <- corpus$units
    embeddings <- corpus$embeddings
    precomputed_tokens <- corpus$token_lists
    stop_words <- corpus$settings$stop_words
    min_token_length <- corpus$settings$min_token_length
    stem <- corpus$settings$stem
    numbers <- if (is.null(corpus$settings$numbers)) "keep" else corpus$settings$numbers
    roman_numerals <- if (is.null(corpus$settings$roman_numerals)) "keep" else corpus$settings$roman_numerals
    section_numbers <- if (is.null(corpus$settings$section_numbers)) "keep" else corpus$settings$section_numbers
    segmentation <- topic_segmentation(corpus)
    corpus_model_information <- corpus$model
  } else {
    # A data frame goes in whole: `column` names the text to model, every other
    # column rides along into `$documents`, and unusable rows are dropped here
    # rather than by every caller in turn. A character vector keeps the old path.
    prepared <- prepare_topic_input(text, column)
    text <- prepared$text
    metadata <- prepared$metadata
    if (!is.null(embeddings) && length(prepared$kept) < prepared$n_supplied) {
      embeddings <- embeddings[prepared$kept, , drop = FALSE]
    }
  }
  stopifnot(
    is.character(text),
    !anyNA(text),
    length(text) >= 2L,
    is.numeric(n_topics),
    length(n_topics) == 1L,
    is.finite(n_topics),
    n_topics >= 2,
    n_topics == as.integer(n_topics),
    n_topics <= length(text),
    is.numeric(batch_size),
    length(batch_size) == 1L,
    is.finite(batch_size),
    batch_size >= 1,
    batch_size == as.integer(batch_size),
    is.numeric(iter_max),
    length(iter_max) == 1L,
    is.finite(iter_max),
    iter_max >= 1,
    iter_max == as.integer(iter_max),
    is.numeric(n_terms),
    length(n_terms) == 1L,
    is.finite(n_terms),
    n_terms >= 1,
    n_terms == as.integer(n_terms),
    is.numeric(n_representatives),
    length(n_representatives) == 1L,
    is.finite(n_representatives),
    n_representatives >= 1,
    n_representatives == as.integer(n_representatives),
    is.character(stop_words),
    !anyNA(stop_words),
    is.numeric(min_term_frequency),
    length(min_term_frequency) == 1L,
    is.finite(min_term_frequency),
    min_term_frequency >= 1,
    min_term_frequency == as.integer(min_term_frequency),
    is.numeric(min_token_length),
    length(min_token_length) == 1L,
    is.finite(min_token_length),
    min_token_length >= 1,
    min_token_length == as.integer(min_token_length),
    is.logical(reduce_frequent_words),
    length(reduce_frequent_words) == 1L,
    !is.na(reduce_frequent_words),
    is.logical(stem),
    length(stem) == 1L,
    !is.na(stem),
    is.logical(keep_embeddings),
    length(keep_embeddings) == 1L,
    !is.na(keep_embeddings)
  )
  if (stem && !requireNamespace("SnowballC", quietly = TRUE)) {
    sbert_abort(
      "stem = TRUE requires the 'SnowballC' package. Install it or use stem = FALSE.",
      class = "sbert_missing_package"
    )
  }
  if (any(!nzchar(trimws(text)))) {
    sbert_abort(
      "text cannot contain blank documents.",
      class = "sbert_bad_input"
    )
  }
  if (!is.null(model) && !is.null(embeddings)) {
    sbert_abort(
      "Supply model or embeddings, not both.",
      class = "sbert_bad_input"
    )
  }

  if (is.null(embeddings)) {
    model <- resolve_sbert_model(model)
    seed_model <- model
    embedding_matrix <- encode_topic_documents(
      text,
      model,
      batch_size = as.integer(batch_size)
    )
    model_information <- list(
      id = model$id,
      revision = model$revision,
      dimension = model$dimension
    )
  } else {
    embedding_matrix <- embeddings
    model_information <- if (!is.null(corpus_model_information)) {
      corpus_model_information
    } else {
      list(
        id = "precomputed embeddings",
        revision = NA_character_,
        dimension = if (is.matrix(embeddings)) ncol(embeddings) else NA_integer_
      )
    }
  }
  if (
    !is.matrix(embedding_matrix) ||
      !is.numeric(embedding_matrix) ||
      nrow(embedding_matrix) != length(text) ||
      ncol(embedding_matrix) < 1L ||
      anyNA(embedding_matrix) ||
      any(!is.finite(embedding_matrix))
  ) {
    sbert_abort(
      "embeddings must be a finite numeric matrix with one row per document.",
      class = "sbert_bad_input"
    )
  }

  seed_labels <- NULL
  initial_centers <- NULL
  if (!is.null(seeds)) {
    seed_texts <- if (is.list(seeds)) {
      vapply(seeds, function(seed) paste(seed, collapse = " "), character(1))
    } else {
      seeds
    }
    stopifnot(
      is.character(seed_texts),
      length(seed_texts) >= 1L,
      !anyNA(seed_texts),
      all(nzchar(trimws(seed_texts))),
      is.logical(fixed_seeds),
      length(fixed_seeds) == 1L,
      !is.na(fixed_seeds)
    )
    n_seeds <- length(seed_texts)
    if (fixed_seeds && n_seeds != n_topics) {
      sbert_abort(
        "With fixed_seeds = TRUE, n_topics must equal the number of seeds.",
        class = "sbert_bad_input"
      )
    }
    if (n_seeds > n_topics) {
      sbert_abort(
        "More seeds than topics; raise n_topics.",
        class = "sbert_bad_input"
      )
    }
    if (is.null(seed_embeddings)) {
      if (is.null(seed_model)) {
        sbert_abort(
          "Seeds need the encoding model; with precomputed embeddings, ",
          "supply seed_embeddings as well.",
          class = "sbert_bad_input"
        )
      }
      seed_embeddings <- encode_topic_documents(
        unname(seed_texts),
        resolve_sbert_model(seed_model),
        batch_size = as.integer(batch_size)
      )
    }
    stopifnot(
      is.matrix(seed_embeddings),
      nrow(seed_embeddings) == n_seeds,
      ncol(seed_embeddings) == ncol(embedding_matrix),
      !anyNA(seed_embeddings),
      all(is.finite(seed_embeddings))
    )
    seed_centers <- normalize_embedding_rows(seed_embeddings)
    free_topics <- as.integer(n_topics) - n_seeds
    initial_centers <- if (free_topics > 0L) {
      rbind(
        seed_centers,
        deterministic_topic_centers(
          normalize_embedding_rows(embedding_matrix),
          free_topics,
          existing_centers = seed_centers
        )
      )
    } else {
      seed_centers
    }
    seed_labels <- names(seed_texts)
  }

  clustering <- fit_embedding_topics(
    embedding_matrix,
    as.integer(n_topics),
    as.integer(iter_max),
    initial_centers = initial_centers,
    reorder = is.null(seeds),
    fixed = !is.null(seeds) && isTRUE(fixed_seeds)
  )
  # One row per modeled unit. A segmented fit keeps the parent document and
  # the segment's position so every downstream verb can aggregate back.
  documents <- if (is.null(units)) {
    document_names <- names(text)
    if (is.null(document_names)) {
      document_names <- rep.int("", length(text))
    }
    data.frame(
      document_id = seq_along(text),
      document_name = unname(document_names),
      text = unname(text),
      topic = clustering$topic,
      distance = clustering$distance,
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      document_id = units$document_id,
      document_name = units$document_name,
      segment = units$segment,
      text = unname(text),
      topic = clustering$topic,
      distance = clustering$distance,
      stringsAsFactors = FALSE
    )
  }
  if (!is.null(metadata) && ncol(metadata) > 0L) {
    documents <- cbind(documents, metadata)
  }
  term_results <- topic_term_scores(
    text = unname(text),
    topic = clustering$topic,
    n_topics = as.integer(n_topics),
    n_terms = as.integer(n_terms),
    stop_words = stop_words,
    min_term_frequency = as.integer(min_term_frequency),
    min_token_length = as.integer(min_token_length),
    weighting = weighting,
    reduce_frequent_words = reduce_frequent_words,
    stem = stem,
    token_lists = precomputed_tokens,
    cores = cores,
    numbers = numbers,
    roman_numerals = roman_numerals,
    section_numbers = section_numbers
  )
  representatives <- topic_representatives(
    documents,
    as.integer(n_topics),
    as.integer(n_representatives)
  )
  topic_labels <- topic_labels_for(
    label, term_results$terms, representatives, as.integer(n_topics)
  )
  if (!is.null(seed_labels) && any(nzchar(seed_labels))) {
    named_seeds <- which(nzchar(seed_labels))
    topic_labels[named_seeds] <- seed_labels[named_seeds]
  }
  topics <- data.frame(
    topic = seq_len(n_topics),
    label = topic_labels,
    n_documents = clustering$size,
    proportion = clustering$size / length(text),
    withinss = clustering$withinss,
    stringsAsFactors = FALSE
  )

  # The topic label belongs on every table that names a topic, so joining it
  # back by hand is never necessary.
  documents <- insert_topic_label(documents, topic_labels)
  term_results$terms <- insert_topic_label(term_results$terms, topic_labels)
  representatives <- insert_topic_label(representatives, topic_labels)

  structure(
    list(
      documents = documents,
      topics = topics,
      terms = term_results$terms,
      representatives = representatives,
      centers = clustering$centers,
      embeddings = if (keep_embeddings) {
        clustering$normalized_embeddings
      } else {
        NULL
      },
      diagnostics = clustering$diagnostics,
      model = model_information,
      settings = list(
        n_topics = as.integer(n_topics),
        n_terms = as.integer(n_terms),
        n_representatives = as.integer(n_representatives),
        label = label,
        min_term_frequency = as.integer(min_term_frequency),
        min_token_length = as.integer(min_token_length),
        weighting = weighting,
        reduce_frequent_words = reduce_frequent_words,
        stem = stem,
        stop_words = stop_words,
        numbers = numbers,
        roman_numerals = roman_numerals,
        section_numbers = section_numbers,
        segment = segmentation$segment,
        max_tokens = segmentation$max_tokens,
        merge_below = segmentation$merge_below,
        min_content = segmentation$min_content,
        seeds = if (is.null(seeds)) NULL else unname(
          if (is.list(seeds)) {
            vapply(seeds, function(seed) paste(seed, collapse = " "), character(1))
          } else {
            seeds
          }
        ),
        fixed_seeds = !is.null(seeds) && isTRUE(fixed_seeds)
      )
    ),
    class = "sbert_topic_model"
  )
}

#' Print a topic model
#'
#' @description
#' `print()` shows a fitted topic model at a glance: the number of documents
#' (and of segments, for a segmented fit), the number of topics, the embedding
#' model, the clustering algorithm, the size of every topic, and the share of
#' the embedding variance that lies between topics.
#'
#' @param x A topic model fitted by [topics()].
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @seealso [summary()][summary.sbert_topic_model] for coherence and topic
#'   diversity; [topic_sizes()] for the labeled size table;
#'   [as.data.frame()][as.data.frame.sbert_topic_model] for the tables.
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' print(topics(corpus, n_topics = 6, column = "translation",
#'              embeddings = feedback_embeddings))
print.sbert_topic_model <- function(x, ...) {
  stopifnot(inherits(x, "sbert_topic_model"))
  explained <- if (x$diagnostics$totss > 0) {
    x$diagnostics$betweenss / x$diagnostics$totss
  } else {
    0
  }
  cat("<sbert_topic_model>\n")
  if (is_segmented_topic_model(x)) {
    cat("  documents:", length(unique(x$documents$document_id)), "\n")
    cat(
      "  segments:", nrow(x$documents),
      sprintf("(%s level)", topic_segmentation(x)$segment), "\n"
    )
  } else {
    cat("  documents:", nrow(x$documents), "\n")
  }
  cat(sprintf(
    paste0(
      "  topics: %d\n",
      "  model: %s\n",
      "  algorithm: %s\n",
      "  topic sizes: %s\n",
      "  between/total SS: %.1f%%\n"
    ),
    nrow(x$topics),
    x$model$id,
    x$diagnostics$algorithm,
    paste(x$topics$n_documents, collapse = ", "),
    100 * explained
  ))
  invisible(x)
}

#' Name the topics of a fitted model
#'
#' @description
#' `name_topics()` replaces the label of every topic of a fitted model with the
#' names given, in topic order. The labels that [topics()] gives are drawn from
#' the data (the most central text of each topic, or its most distinctive
#' terms); once the representative texts of each topic have been read, a short
#' name for what the topic is about, such as the kind of message it holds,
#' communicates the result better.
#'
#' The names then appear in every table and figure that refers to a topic,
#' including [summary()][summary.sbert_topic_model], [topic_sizes()],
#' [terms()][terms.sbert_topic_model], [representatives()],
#' [predict()][predict.sbert_topic_model], [topic_hierarchy()], and
#' [plot()][plot.sbert_topic_model]. The model is not refitted; the result is
#' the topic model with its labels replaced.
#'
#' [reduce_topics()] drops the names, because merged topics need new ones.
#'
#' @param object A topic model fitted by [topics()].
#' @param labels Character vector of distinct, non-empty names, one per topic,
#'   in topic order (topic 1 first).
#' @return The topic model with its labels replaced; an object of class
#'   `sbert_topic_model`.
#' @section Conditions:
#'   An error of class `sbert_bad_topic_names` when `labels` is not a
#'   character vector of distinct, non-empty, non-missing names, one per topic.
#' @seealso [representatives()] to read each topic before naming it;
#'   [topics()].
#' @export
#' @examples
#' text <- c(
#'   "Cats chase mice", "Dogs chase balls",
#'   "Stocks and bonds trade", "Markets price shares"
#' )
#' embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
#' topic_model <- topics(text, n_topics = 2, embeddings = embeddings)
#' named <- name_topics(topic_model, c("Pets", "Finance"))
#' topic_sizes(named)
name_topics <- function(object, labels) {
  stopifnot(
    "`object` must be a model fitted with topics()" =
      inherits(object, "sbert_topic_model")
  )
  n_topics <- nrow(object$topics)
  valid <- is.character(labels) &&
    length(labels) == n_topics &&
    !anyNA(labels) &&
    all(nzchar(trimws(labels))) &&
    !anyDuplicated(labels)
  if (!valid) {
    stop(errorCondition(
      sprintf(
        "`labels` must be %d distinct, non-empty names, one per topic in topic order.",
        n_topics
      ),
      class = c("sbert_bad_topic_names", "sbert_error"),
      call = NULL
    ))
  }
  labels <- unname(labels)
  object$topics$label <- labels
  object$documents <- insert_topic_label(object$documents, labels)
  object$terms <- insert_topic_label(object$terms, labels)
  object$representatives <- insert_topic_label(object$representatives, labels)
  object$settings$topic_names <- labels
  object
}
