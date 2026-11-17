# Embedding-based keyword extraction (the KeyBERT design): candidate words
# and phrases come from the document itself, are embedded with the same model
# as the document, and are ranked by cosine topic_similarity to the document vector.
# Maximal marginal relevance trades relevance against redundancy so the
# selected keywords do not all say the same thing.

# Internal encoding seam so tests can substitute a deterministic embedder.
encode_keyword_texts <- function(texts, model, batch_size) {
  model <- resolve_sbert_model(model)
  encode(texts, model = model, batch_size = batch_size)
}

# Consecutive-token n-grams of length 1..max_length over one token sequence.
token_ngrams <- function(tokens, max_length) {
  if (length(tokens) == 0L) {
    return(character(0))
  }
  lengths <- seq_len(min(max_length, length(tokens)))
  unique(unlist(
    lapply(
      lengths,
      function(size) {
        starts <- seq_len(length(tokens) - size + 1L)
        vapply(
          starts,
          function(start) {
            paste(tokens[seq.int(start, start + size - 1L)], collapse = " ")
          },
          character(1)
        )
      }
    ),
    use.names = FALSE
  ))
}

# Maximal marginal relevance: iteratively pick the candidate maximizing
# (1 - topic_diversity) * relevance - topic_diversity * max-topic_similarity-to-already-chosen.
# Candidates arrive alphabetically sorted, so which.max ties are deterministic.
mmr_select <- function(relevance, candidate_similarity, n, topic_diversity) {
  n_candidates <- length(relevance)
  picks <- min(n, n_candidates)
  state <- Reduce(
    function(current, step) {
      available <- current$available
      scores <- if (length(current$chosen) == 0L) {
        relevance[available]
      } else {
        redundancy <- apply(
          candidate_similarity[
            available,
            current$chosen,
            drop = FALSE
          ],
          1L,
          max
        )
        (1 - topic_diversity) * relevance[available] - topic_diversity * redundancy
      }
      pick <- available[which.max(scores)]
      list(
        chosen = c(current$chosen, pick),
        available = setdiff(available, pick)
      )
    },
    seq_len(picks),
    list(chosen = integer(0), available = seq_len(n_candidates))
  )
  state$chosen
}

#' Extract the keywords of documents
#'
#' @description
#' `keywords()` extracts the keywords of each document: the words and short
#' phrases that best express what it is about. Embedding-based keyword
#' extraction compares the meaning of each candidate phrase with the meaning of
#' the whole document, and a phrase whose embedding is close to the document's
#' embedding summarizes it well; because picking the closest phrases alone tends
#' to return near-synonyms, the selection also rewards phrases that differ from
#' those already chosen, by maximal marginal relevance (Carbonell and Goldstein
#' 1998), as in KeyBERT (Grootendorst 2020).
#'
#' The candidates are the words and phrases of up to `ngrams` consecutive words
#' of each document after stop words are removed; the documents and the
#' candidates are encoded with the same model, and up to `n` keywords per
#' document are selected. The result is a data frame with one row per keyword.
#' `keywords()` describes single documents; to describe topics, use
#' [terms()][terms.sbert_topic_model], which compares the words of a topic with
#' those of the other topics.
#'
#' `keywords()` encodes text, so it needs a downloaded model.
#'
#' @param text Documents: a character vector. Names, if any, are carried into
#'   `document_name`.
#' @param model The encoder: a model from [load_model()], a pinned model name,
#'   or `NULL` (default) for the default model.
#' @param n Maximum number of keywords per document (default 10).
#' @param ngrams Maximum length of a candidate phrase, in words (default 2).
#' @param topic_diversity Trade-off between relevance and diversity, in
#'   `[0, 1)`: 0 ranks by similarity to the document alone, and larger values
#'   penalize candidates similar to those already chosen (default 0.3).
#' @param stop_words Words excluded from the candidates; default
#'   [stop_words()].
#' @param min_token_length Minimum length of a candidate word, in characters
#'   (default 3).
#' @param batch_size Texts encoded per model call (default 32).
#' @return A base data frame with one row per keyword and columns
#'   `document_id`, `document_name`, `rank`, `keyword`, and
#'   `topic_similarity` (the cosine similarity between the keyword and its
#'   document).
#' @section Conditions:
#'   An error of class `sbert_no_terms` when no candidate is left after stop
#'   words and short words are removed; the errors of [load_model()] and
#'   [encode()].
#' @seealso [terms()][terms.sbert_topic_model] for the terms of topics;
#'   [stop_words()]; [model_download()] to download a model.
#' @references
#' Carbonell, J. and Goldstein, J. (1998). The use of MMR, diversity-based
#' reranking for reordering documents and producing summaries. *Proceedings
#' of SIGIR 1998*, 335--336. \doi{10.1145/290941.291025}
#'
#' Grootendorst, M. (2020). KeyBERT: Minimal keyword extraction with BERT.
#' \doi{10.5281/zenodo.4461265}
#' @export
#' @examples
#' # Pinned models that can encode the text
#' models()
#'
#' \donttest{
#' if (interactive()) {
#'   keywords(
#'     "Transition network analysis models learning event sequences.",
#'     n = 5
#'   )
#' }
#' }
keywords <- function(
  text,
  model = NULL,
  n = 10L,
  ngrams = 2L,
  topic_diversity = 0.3,
  stop_words = default_stop_words(),
  min_token_length = 3L,
  batch_size = 32L
) {
  stopifnot(
    is.character(text),
    length(text) >= 1L,
    !anyNA(text),
    all(nzchar(trimws(text))),
    is.numeric(n),
    length(n) == 1L,
    is.finite(n),
    n >= 1,
    n == as.integer(n),
    is.numeric(ngrams),
    length(ngrams) == 1L,
    is.finite(ngrams),
    ngrams >= 1,
    ngrams == as.integer(ngrams),
    is.numeric(topic_diversity),
    length(topic_diversity) == 1L,
    is.finite(topic_diversity),
    topic_diversity >= 0,
    topic_diversity < 1,
    is.character(stop_words),
    !anyNA(stop_words)
  )

  document_names <- names(text)
  if (is.null(document_names)) {
    document_names <- rep.int("", length(text))
  }
  token_lists <- tokenize_topic_documents(
    unname(text),
    stop_words = stop_words,
    min_token_length = min_token_length
  )
  candidate_lists <- lapply(token_lists, token_ngrams, max_length = ngrams)
  all_candidates <- sort(unique(unlist(candidate_lists, use.names = FALSE)))
  if (length(all_candidates) == 0L) {
    sbert_abort(
      "No keyword candidates survive tokenization; ",
      "lower min_token_length or supply fewer stop_words.",
      class = "sbert_no_terms"
    )
  }

  document_embeddings <- normalize_rows(
    encode_keyword_texts(unname(text), model, batch_size)
  )
  candidate_embeddings <- normalize_rows(
    encode_keyword_texts(all_candidates, model, batch_size)
  )

  per_document <- lapply(
    seq_along(text),
    function(document_index) {
      candidates <- candidate_lists[[document_index]]
      if (length(candidates) == 0L) {
        return(NULL)
      }
      candidates <- sort(candidates)
      rows <- match(candidates, all_candidates)
      vectors <- candidate_embeddings[rows, , drop = FALSE]
      relevance <- as.numeric(
        vectors %*% document_embeddings[document_index, ]
      )
      chosen <- mmr_select(
        relevance = relevance,
        candidate_similarity = tcrossprod(vectors),
        n = n,
        topic_diversity = topic_diversity
      )
      data.frame(
        document_id = rep.int(document_index, length(chosen)),
        document_name = rep.int(
          document_names[[document_index]],
          length(chosen)
        ),
        rank = seq_along(chosen),
        keyword = candidates[chosen],
        topic_similarity = relevance[chosen],
        stringsAsFactors = FALSE
      )
    }
  )
  result <- do.call(rbind, Filter(Negate(is.null), per_document))
  rownames(result) <- NULL
  result
}
