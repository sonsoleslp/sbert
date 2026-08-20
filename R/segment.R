# Deterministic rule-based text segmentation: an abbreviation gazetteer plus
# numeric and parenthetical guards for sentence-boundary detection, and shallow
# clause chunking at discourse connectives. Matching is case-insensitive so the
# same rules work on cased prose and on all-caps abstract text.

# Word-boundary-anchored so "ST." (Saint) never matches the end of "COST.".
# "ETC." is deliberately absent: boundaries only fire at "period space word",
# and mid-sentence "etc." is written "ETC.," or "ETC.)" (never bare), so
# protecting it can only glue true sentence ends ("..., ETC. HOWEVER, ...").
.sbert_segment_abbreviations <- c(
  "E.G.", "I.E.", "ET AL.", "VS.", "CF.", "FIG.", "FIGS.", "EQ.",
  "EQS.", "NO.", "NOS.", "VOL.", "PP.", "DR.", "PROF.", "ST.", "REF.", "REFS.",
  "U.S.", "U.K.", "PH.D.", "M.SC.", "B.SC.", "APPROX."
)

# Subordinating hinges that reliably begin a new clause and are NOT list items.
# Bare "AND"/"OR" are intentionally excluded: they mostly join enumerations,
# which stay intact at clause level. Multi-word hinges are matched first.
.sbert_segment_hinges <- c(
  "IN TERMS OF", "IN ORDER TO", "SUCH THAT", "AS WELL AS", "RATHER THAN",
  "WHEREAS", "WHEREBY", "WHICH", "WHERE", "WHILE", "BECAUSE", "ALTHOUGH",
  "THOUGH"
)

# Weak break points used only as a last resort by max_tokens, when a run has no
# punctuation or clause hinge to split on. Breaking *before* one of these
# function words — a coordinator, preposition, article, or relative pronoun —
# lands on the start of a phrase rather than in the middle of one. Lower-case,
# because the search runs on already-lowered comparison copies.
.sbert_segment_break_before <- c(
  "and", "but", "or", "nor", "yet", "so",
  "of", "in", "on", "to", "for", "with", "at", "by", "from", "as", "into",
  "about", "over", "under", "after", "before", "between", "through", "during",
  "against", "than", "upon", "within", "without", "toward", "towards", "across",
  "that", "which", "who", "whom", "whose", "when", "where", "while", "because",
  "a", "an", "the", "this", "these", "those"
)

# ASCII sentinels that cannot occur in the normalized source text.
.sbert_segment_boundary <- "@@B@@"
.sbert_segment_period <- "@@P@@"
.sbert_segment_comma <- "@@C@@"

#' Obtain the Built-in Abbreviation Gazetteer
#'
#' Returns the abbreviations whose periods are never treated as sentence
#' boundaries by [segment()]. Matching is case-insensitive and anchored
#' at a word boundary, so `"ST."` protects `"St. Petersburg"` but never the
#' end of `"cost."`.
#'
#' @return A sorted character vector of uppercase abbreviations, each ending
#'   in a period.
#' @export
#' @examples
#' head(abbreviations())
abbreviations <- function() {
  sort(unique(.sbert_segment_abbreviations))
}

segment_normalize <- function(text) {
  text <- enc2utf8(text)
  text <- gsub(
    "(*UTF)[\\x{2018}\\x{2019}\\x{201B}\\x{2032}]", "'", text,
    perl = TRUE
  )
  text <- gsub("(*UTF)[\\x{201C}\\x{201D}]", "\"", text, perl = TRUE)
  text <- gsub("(*UTF)[\\x{2013}\\x{2014}]", " - ", text, perl = TRUE)
  trimws(gsub("\\s+", " ", text, perl = TRUE))
}

# Mask periods/commas inside parentheses so "(e.g., Python)" never splits.
segment_protect_parentheticals <- function(text) {
  matches <- gregexpr("\\([^()]*\\)", text, perl = TRUE)
  regmatches(text, matches) <- lapply(
    regmatches(text, matches),
    function(spans) {
      spans <- gsub(".", .sbert_segment_period, spans, fixed = TRUE)
      gsub(",", .sbert_segment_comma, spans, fixed = TRUE)
    }
  )
  text
}

# Mask periods inside abbreviations and decimals so they are not boundaries.
# Masking edits the matched span in place, preserving the original case.
segment_protect_periods <- function(text, abbreviations) {
  patterns <- paste0(
    "(?i)\\b",
    gsub(".", "\\.", toupper(abbreviations), fixed = TRUE)
  )
  text <- Reduce(
    function(current, pattern) {
      matches <- gregexpr(pattern, current, perl = TRUE)
      regmatches(current, matches) <- lapply(
        regmatches(current, matches),
        function(spans) gsub(".", .sbert_segment_period, spans, fixed = TRUE)
      )
      current
    },
    patterns,
    text
  )
  gsub(
    "([0-9])\\.([0-9])",
    paste0("\\1", .sbert_segment_period, "\\2"),
    text,
    perl = TRUE
  )
}

# Insert a boundary sentinel at every separator permitted by `level`.
# `sentence_split = FALSE` skips the sentence-ending "." "?" "!" split, used when
# re-splitting an already-sentence-segmented piece — which holds no sentence
# boundary, so the period split (and its abbreviation guard) is pure overhead.
# `protect_initials = TRUE` keeps a comma that precedes an initial (a lone
# letter and period, as in "Tomlinson, C. A.") from splitting a name from its
# initials; ordinary comma lists still split.
segment_mark <- function(text, level, sentence_split = TRUE, protect_initials = FALSE) {
  if (sentence_split) {
    text <- gsub(
      "([.?!])\\s+",
      paste0("\\1", .sbert_segment_boundary),
      text,
      perl = TRUE
    )
  }
  if (level %in% c("clause", "phrase")) {
    text <- gsub(
      "([;:])\\s+",
      paste0("\\1", .sbert_segment_boundary),
      text,
      perl = TRUE
    )
    text <- gsub(
      "\\s-\\s",
      paste0(" ", .sbert_segment_boundary),
      text,
      perl = TRUE
    )
    text <- Reduce(
      function(current, hinge) {
        gsub(
          paste0("(?i)\\s+(", hinge, ")\\b"),
          paste0(" ", .sbert_segment_boundary, "\\1"),
          current,
          perl = TRUE
        )
      },
      .sbert_segment_hinges,
      text
    )
  }
  if (level == "phrase") {
    comma_pattern <- if (protect_initials) {
      ",\\s+(?![A-Za-z]\\.)"
    } else {
      ",\\s+"
    }
    text <- gsub(
      comma_pattern,
      paste0(",", .sbert_segment_boundary),
      text,
      perl = TRUE
    )
  }
  text
}

segment_restore <- function(parts) {
  parts <- gsub(.sbert_segment_period, ".", parts, fixed = TRUE)
  trimws(gsub(.sbert_segment_comma, ",", parts, fixed = TRUE))
}

# Re-join any segment with fewer than `min_words` words into the previous one
# (or the next, for a short leader): the enumeration / short-shard guard.
segment_merge_short <- function(segments, min_words) {
  if (min_words <= 1L || length(segments) <= 1L) {
    return(segments)
  }
  word_count <- function(segment) length(strsplit(segment, "\\s+")[[1L]])
  merged <- Reduce(
    function(accumulated, segment) {
      if (length(accumulated) > 0L && word_count(segment) < min_words) {
        accumulated[length(accumulated)] <-
          trimws(paste(accumulated[length(accumulated)], segment))
        accumulated
      } else {
        c(accumulated, segment)
      }
    },
    segments,
    character(0)
  )
  if (length(merged) > 1L && word_count(merged[[1L]]) < min_words) {
    merged <- c(trimws(paste(merged[[1L]], merged[[2L]])), merged[-(1:2)])
  }
  merged
}

# A counter for segment length: whitespace words when no model is given
# (deterministic and offline), or exact encoder tokens when one is. encode()
# re-enables padding and truncation on every call, so clearing them here to read
# a true length never affects later encoding.
segment_unit_counter <- function(model = NULL) {
  if (is.null(model)) {
    function(x) {
      vapply(strsplit(x, "\\s+"), function(w) sum(nzchar(w)), integer(1))
    }
  } else {
    tokenizer <- model$tokenizer
    tokenizer$no_padding()
    tokenizer$no_truncation()
    function(x) {
      if (length(x) == 0L) {
        return(integer(0))
      }
      encoded <- tokenizer$encode_batch(as.list(x), add_special_tokens = TRUE)
      vapply(encoded, function(item) length(item$ids), integer(1))
    }
  }
}

# Greedily merge consecutive units so each returned chunk stays within the
# budget, keeping their original order. A single unit already over budget is
# emitted on its own (the caller has already broken it down as far as it can).
segment_pack_units <- function(units, max_units, count_units) {
  if (length(units) == 0L) {
    return(character(0))
  }
  counts <- count_units(units)
  chunks <- character(0)
  current <- character(0)
  current_count <- 0L
  for (i in seq_along(units)) {
    if (length(current) > 0L && current_count + counts[[i]] > max_units) {
      chunks <- c(chunks, paste(current, collapse = " "))
      current <- units[i]
      current_count <- counts[[i]]
    } else {
      current <- c(current, units[i])
      current_count <- current_count + counts[[i]]
    }
  }
  c(chunks, paste(current, collapse = " "))
}

# Last-resort split for a run with no punctuation or clause hinge. Fills each
# chunk to the largest that fits the budget, then, rather than cutting there,
# backs up a short window to end just before a function word so the break lands
# at the start of a phrase instead of mid-phrase. If the window holds no such
# word it cuts at the budget. Every chunk fits the budget and no word is lost.
segment_smart_chop <- function(words, max_units, count_units) {
  n <- length(words)
  if (n == 0L) {
    return(character(0))
  }
  # Per-word unit counts, computed once. Word budgets are then exact (each word
  # is one unit); token budgets use the per-word sum as a close estimate, which
  # keeps this an O(n) pass rather than re-counting a growing prefix each step.
  word_units <- count_units(words)
  cumulative <- cumsum(word_units)
  lowered <- tolower(words)
  is_break <- lowered %in% .sbert_segment_break_before
  chunks <- character(0)
  i <- 1L
  while (i <= n) {
    # Largest j whose chunk still fits the budget (cumulative counts from i).
    budget_end <- cumulative[i] - word_units[i] + max_units
    j <- i
    hi <- findInterval(budget_end, cumulative)
    if (hi > i) {
      j <- hi
    }
    if (j >= n) {
      chunks <- c(chunks, paste(words[i:n], collapse = " "))
      break
    }
    # Prefer to end this chunk just before a function word within a window of the
    # budget edge, so the next chunk starts a phrase rather than continuing one.
    window <- max(1L, as.integer(floor(0.25 * (j - i + 1L))))
    cut <- j
    for (k in seq.int(j, max(i, j - window + 1L))) {
      if (is_break[[k + 1L]]) {
        cut <- k
        break
      }
    }
    chunks <- c(chunks, paste(words[i:cut], collapse = " "))
    i <- cut + 1L
  }
  chunks
}

# Split already-normalized segments at the finest sub-sentence boundaries
# (";", ":", " - ", clause hinges, commas). The inputs are existing sentence or
# clause segments, so they carry no sentence boundary: the period split and its
# per-abbreviation guard are skipped, which is the bulk of the cost. Only the
# parenthetical guard is kept, so a comma inside "(a, b)" does not split.
# Vectorized — the regex passes run once over the whole vector rather than once
# per segment. Returns a list of atom vectors, one per input.
segment_phrase_atoms <- function(texts) {
  guarded <- segment_protect_parentheticals(texts)
  marked <- segment_mark(
    guarded, "phrase", sentence_split = FALSE, protect_initials = TRUE
  )
  lapply(
    strsplit(marked, .sbert_segment_boundary, fixed = TRUE),
    function(parts) {
      parts <- segment_restore(parts)
      parts[nzchar(parts) & grepl("[[:alnum:]]", parts)]
    }
  )
}

# Cap every over-long segment across the whole corpus in one pass. Each over-long
# segment is re-split at the finest logical boundaries (phrase level), those
# pieces are packed back up to the budget so the split lands on punctuation
# wherever possible, and only a piece that alone still exceeds the budget — a run
# with no internal punctuation — is chopped further, preferring a break just
# before a function word over the raw budget edge (see segment_smart_chop).
# Over-long segments are phrase-split together (vectorized) so the cost scales
# with their number, not with per-segment regex overhead. `count_units` measures
# words or encoder tokens. Operates on the per-document list and preserves it,
# including empty documents.
segment_cap_lists <- function(segment_lists, max_units, count_units) {
  if (is.null(max_units)) {
    return(segment_lists)
  }
  lengths_per_doc <- lengths(segment_lists)
  all_segments <- unlist(segment_lists, use.names = FALSE)
  if (length(all_segments) == 0L) {
    return(segment_lists)
  }
  over <- which(count_units(all_segments) > max_units)
  if (length(over) == 0L) {
    return(segment_lists)
  }
  atom_lists <- segment_phrase_atoms(all_segments[over])
  pieces <- as.list(all_segments)
  for (k in seq_along(over)) {
    atoms <- atom_lists[[k]]
    if (length(atoms) == 0L) {
      atoms <- all_segments[[over[[k]]]]
    }
    atom_counts <- count_units(atoms)
    units <- unlist(
      Map(
        function(atom, atom_count) {
          if (atom_count <= max_units) {
            atom
          } else {
            words <- strsplit(atom, "\\s+")[[1L]]
            segment_smart_chop(words[nzchar(words)], max_units, count_units)
          }
        },
        atoms,
        atom_counts
      ),
      use.names = FALSE
    )
    pieces[[over[[k]]]] <- segment_pack_units(units, max_units, count_units)
  }
  # Re-assemble the per-document lists, keeping every document (empty ones too).
  document_of <- rep.int(seq_along(segment_lists), lengths_per_doc)
  out <- rep(list(character(0)), length(segment_lists))
  grouped <- split(pieces, document_of)
  for (name in names(grouped)) {
    out[[as.integer(name)]] <- unlist(grouped[[name]], use.names = FALSE)
  }
  out
}

segment_document <- function(text, level, merge_below, abbreviations) {
  normalized <- segment_normalize(text)
  if (!nzchar(normalized)) {
    return(character(0))
  }
  guarded <- segment_protect_periods(
    segment_protect_parentheticals(normalized),
    abbreviations
  )
  parts <- strsplit(
    segment_mark(guarded, level),
    .sbert_segment_boundary,
    fixed = TRUE
  )[[1L]]
  parts <- segment_restore(parts)
  parts <- parts[nzchar(parts) & grepl("[[:alnum:]]", parts)]
  segment_merge_short(parts, as.integer(merge_below))
}

#' Segment Text into Sentences, Clauses, or Phrases
#'
#' Splits each document into units at a selectable granularity using
#' deterministic sentence-boundary rules: a word-boundary-anchored,
#' case-insensitive abbreviation gazetteer (see [abbreviations()]),
#' a decimal-number guard, and a parenthetical guard, plus shallow clause
#' chunking at discourse connectives. No model call is involved, so
#' segmentation works offline and is fully reproducible.
#'
#' Each finer level adds separators:
#' \describe{
#'   \item{`"sentence"`}{splits at `.`, `?`, and `!` only.}
#'   \item{`"clause"`}{additionally splits at `;`, `:`, spaced dashes, and
#'     subordinating hinges (for example "which", "where", "in terms of").
#'     Comma-separated enumerations stay whole. This is the default.}
#'   \item{`"phrase"`}{additionally splits at commas, for maximal granularity.}
#' }
#'
#' Before segmentation, each document is normalized: curly quotes become
#' straight quotes, en and em dashes become spaced hyphens, and runs of
#' whitespace collapse to single spaces. Letter case is preserved.
#'
#' @param text A character vector of documents. Names, when present, are
#'   carried into the `document_name` column.
#' @param level `"clause"` (default), `"sentence"`, or `"phrase"`.
#' @param merge_below Re-join segments shorter than this many words into their
#'   neighbor. `0` (default) disables merging and returns the pure
#'   segmentation.
#' @param abbreviations Character vector of abbreviations (each ending in a
#'   period) whose periods never end a sentence. Defaults to the built-in
#'   gazetteer from [abbreviations()]; matching is case-insensitive.
#' @param cores Number of forked worker processes used to split documents.
#'   Default `1` (serial). Values above one use `parallel::mclapply` on
#'   Unix-alikes and fall back to serial on Windows or for small inputs; the
#'   segmentation is identical regardless of the count.
#' @param max_tokens Optional cap on segment length, so no segment overruns an
#'   encoder's context window and is silently truncated. `NULL` (default) leaves
#'   segments uncapped. When set, any segment over the budget is re-split at the
#'   finest logical boundaries — clause hinges, `";"`, `":"`, `" - "`, and
#'   commas (though a comma that would sever a name from its initials, as in
#'   `"Tomlinson, C. A."`, does not split) — and the pieces are packed back up to
#'   the budget, so a split lands on punctuation wherever possible. A run with no
#'   such boundary is chopped
#'   further, but even then the break is placed just before a function word (a
#'   coordinator, preposition, article, or relative pronoun) near the budget
#'   edge rather than mid-phrase, falling back to the raw edge only when the run
#'   has no function word either. With `model = NULL` the budget counts
#'   whitespace-delimited words, a deterministic offline proxy; set it below the
#'   model's true token limit (for example around 200 for a 256-token model),
#'   since a tokenizer emits somewhat more tokens than words.
#' @param model Optional loaded [sbert_model][load_model()]. When supplied with
#'   `max_tokens`, the budget counts that model's exact sub-word tokens instead
#'   of words, so `max_tokens` can be the model's real limit. Token-counted
#'   segmentation runs serially (the tokenizer is not forked), so `cores` is
#'   ignored in that case.
#' @return A base data frame with one row per segment and columns
#'   `document_id` (integer position in `text`), `document_name` (name of the
#'   input element, or `""`), `segment` (integer position within the
#'   document), and `text` (the segment). Blank documents contribute no rows.
#' @export
#' @examples
#' segment(
#'   "We propose a simulator which runs alongside the processor."
#' )
#'
#' segment(
#'   c(intro = "See Fig. 3 for details. The next part follows."),
#'   level = "sentence"
#' )
segment <- function(
  text,
  level = c("clause", "sentence", "phrase"),
  merge_below = 0L,
  abbreviations = default_abbreviations(),
  cores = 1L,
  max_tokens = NULL,
  model = NULL
) {
  level <- match.arg(level)
  stopifnot(
    is.character(text),
    length(text) >= 1L,
    !anyNA(text),
    is.numeric(merge_below),
    length(merge_below) == 1L,
    is.finite(merge_below),
    merge_below >= 0,
    merge_below == as.integer(merge_below),
    is.character(abbreviations),
    !anyNA(abbreviations),
    is.null(max_tokens) ||
      (is.numeric(max_tokens) && length(max_tokens) == 1L &&
        is.finite(max_tokens) && max_tokens >= 1 &&
        max_tokens == as.integer(max_tokens)),
    is.null(model) || inherits(model, "sbert_model")
  )
  max_tokens <- if (is.null(max_tokens)) NULL else as.integer(max_tokens)
  if (is.null(max_tokens) && !is.null(model)) {
    stop("`model` is only used when `max_tokens` is set.", call. = FALSE)
  }
  # The unit counter is built once. With a model it holds an external tokenizer
  # pointer, so token-capped segmentation runs in one process rather than across
  # forks. Word-based capping stays parallelisable.
  count_units <- if (is.null(max_tokens)) NULL else segment_unit_counter(model)

  document_names <- names(text)
  if (is.null(document_names)) {
    document_names <- rep.int("", length(text))
  }
  # Splitting a document is independent of every other document, so the per-
  # document list is built in parallel across forks when asked and recombined in
  # order — byte-identical to the serial pass, only faster.
  n_cores <- if (is.null(model)) resolve_cores(cores, length(text)) else 1L
  segment_one <- function(document) {
    segment_document(
      document,
      level = level,
      merge_below = merge_below,
      abbreviations = abbreviations
    )
  }
  segment_lists <- if (n_cores > 1L) {
    chunks <- parallel::splitIndices(length(text), n_cores)
    parts <- parallel::mclapply(
      chunks,
      function(indices) lapply(unname(text)[indices], segment_one),
      mc.cores = n_cores
    )
    if (any(vapply(parts, inherits, logical(1), "try-error"))) {
      lapply(unname(text), segment_one)
    } else {
      unlist(parts, recursive = FALSE, use.names = FALSE)
    }
  } else {
    lapply(unname(text), segment_one)
  }
  # Cap over-long segments in one vectorized pass after the base segmentation,
  # so the regex re-split of every over-long segment happens together rather than
  # once per segment. Deterministic and independent of `cores`.
  if (!is.null(max_tokens)) {
    segment_lists <- segment_cap_lists(
      segment_lists, max_tokens, count_units
    )
  }
  counts <- lengths(segment_lists)
  data.frame(
    document_id = rep.int(seq_along(text), counts),
    document_name = rep.int(unname(document_names), counts),
    segment = sequence(counts),
    text = as.character(unlist(segment_lists, use.names = FALSE)),
    stringsAsFactors = FALSE
  )
}
