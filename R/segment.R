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

#' List the abbreviations protected from sentence splitting
#'
#' @description
#' `abbreviations()` returns the built-in list of abbreviations whose period
#' does not end a sentence, which [segment()] uses by default. A period ends a
#' sentence far more often than not, but abbreviations such as "e.g.", "Fig." or
#' "et al." also end in one, so rule-based sentence splitting needs such a list.
#'
#' Matching in [segment()] ignores case and starts at a word boundary, so
#' `"ST."` protects `"St. Petersburg"` but not the end of `"cost."`.
#'
#' To protect further abbreviations, pass an extended vector to the
#' `abbreviations` argument of [segment()].
#'
#' @return A sorted character vector of abbreviations in upper case, each
#'   ending in a period.
#' @seealso [segment()], which uses the list.
#' @export
#' @examples
#' abbreviations()
#'
#' # "App." is not in the list, so its period ends a sentence ...
#' segment("See App. B for the items. Then stop.", level = "sentence")
#'
#' # ... unless it is added.
#' segment("See App. B for the items. Then stop.", level = "sentence",
#'         abbreviations = c(abbreviations(), "APP."))
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
    # A missing space: a lower-case letter, a period, then an upper-case letter
    # ("results.The next") is a run-together sentence boundary, not an acronym
    # (acronyms are upper-case, e.g. "U.S."), so split there too. Abbreviation
    # and decimal periods are already masked, so they never match.
    text <- gsub(
      "(*UTF)(*UCP)([[:lower:]][.?!])([[:upper:]])",
      paste0("\\1", .sbert_segment_boundary, "\\2"),
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
      n <- length(x)
      if (n == 0L) {
        return(integer(0))
      }
      # Tokenize in batches and keep only the per-item id counts. Encoding all
      # inputs in one `encode_batch` call materializes an encoding object (ids,
      # mask, offsets, ...) for every input at once, which exhausts memory on a
      # corpus of millions of segments; batching bounds that to one batch.
      out <- integer(n)
      batch <- 10000L
      for (start in seq.int(1L, n, batch)) {
        idx <- start:min(start + batch - 1L, n)
        encoded <- tokenizer$encode_batch(
          as.list(x[idx]),
          add_special_tokens = TRUE
        )
        out[idx] <- vapply(encoded, function(item) length(item$ids), integer(1))
      }
      out
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

#' Split documents into sentences, clauses, or phrases
#'
#' @description
#' `segment()` splits documents into sentences, clauses, or phrases by
#' deterministic rules, with no model involved, so the result is reproducible
#' and needs no download. A long document usually discusses several things, and
#' one embedding of the whole document averages them; shorter units can each be
#' embedded and assigned to a topic on their own, so that a document can be
#' described as a mixture of topics, and each unit stays within the input length
#' of the model.
#'
#' The `"sentence"` level splits at `.`, `?` and `!`, protecting the periods of
#' abbreviations (see [abbreviations()]), decimal numbers and parenthetical
#' remarks. The `"clause"` level, the default, also splits at `;`, `:`, spaced
#' dashes, and subordinating words such as "which", "where" or "in terms of",
#' while comma-separated lists stay whole. The `"phrase"` level also splits at
#' commas. Quotes, dashes and whitespace are normalized first; letter case is
#' kept. Optional steps merge very short segments into their neighbors, cap
#' segment length at a number of words or model tokens, and drop segments with
#' little alphabetic content, such as citation fragments. The result is a data
#' frame with one row per segment.
#'
#' The topic verbs segment documents themselves through their `segment`
#' argument (see [topics()] and [topic_corpus()]); call `segment()` directly
#' to inspect the units, or to reuse one segmentation and its embeddings in
#' [topic_gamma()] and [blend()].
#'
#' @param text Character vector of documents. Names are carried into the
#'   `document_name` column.
#' @param level `"clause"` (default), `"sentence"`, or `"phrase"`.
#' @param merge_below Join segments shorter than this many words to a
#'   neighbor; `0` (default) keeps every segment as split.
#' @param abbreviations Abbreviations, each ending in a period, whose period
#'   never ends a sentence (default [abbreviations()]); matched ignoring case.
#' @param cores Number of forked processes used to split documents (default
#'   1). Ignored on Windows and for small inputs; the result does not depend
#'   on it.
#' @param max_tokens Maximum length of a segment, or `NULL` (default) for no
#'   limit. A longer segment is split again at clause words, `;`, `:`, dashes
#'   or commas, or, failing those, before a function word near the limit.
#'   Length is counted in words, or in the tokens of `model` when one is given;
#'   a tokenizer yields more tokens than words, so a word limit should sit
#'   below the model's token limit.
#' @param model `NULL` (default), or a model from [load_model()] whose
#'   tokenizer counts the length for `max_tokens`. Requires `max_tokens`;
#'   splitting then runs in one process.
#' @param min_content Minimum share of alphabetic content, between 0 and 1,
#'   for a segment to be kept (see [content_ratio()]); `0` (default) keeps
#'   every segment.
#' @return A base data frame with one row per segment and columns
#'   `document_id` (position of the document in `text`), `document_name`
#'   (its name, or `""`), `segment` (position within the document), and
#'   `text`. Blank documents contribute no rows.
#' @section Conditions:
#'   `sbert_bad_input` when `model` is given without `max_tokens`.
#' @seealso [abbreviations()] for the protected abbreviations;
#'   [content_ratio()] for `min_content`; [topics()] and [topic_corpus()],
#'   which segment through their `segment` argument; [topic_gamma()] and
#'   [blend()], which take this data frame.
#' @export
#' @examples
#' feedback <- c(
#'   first = paste("The task was clear. I liked the colors, the sounds",
#'                 "and the pictures, which were funny."),
#'   second = "Too hard; I did not understand the question."
#' )
#' segment(feedback)
#' segment(feedback, level = "sentence")
#' segment(feedback, level = "phrase")
#'
#' # Abbreviation and decimal periods do not end a sentence.
#' segment("See Fig. 3 for details. The mean was 2.5 points.",
#'         level = "sentence")
segment <- function(
  text,
  level = c("clause", "sentence", "phrase"),
  merge_below = 0L,
  abbreviations = default_abbreviations(),
  cores = 1L,
  max_tokens = NULL,
  model = NULL,
  min_content = 0
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
    is.null(model) || inherits(model, "sbert_model"),
    is.numeric(min_content), length(min_content) == 1L,
    is.finite(min_content), min_content >= 0, min_content <= 1
  )
  max_tokens <- if (is.null(max_tokens)) NULL else as.integer(max_tokens)
  if (is.null(max_tokens) && !is.null(model)) {
    sbert_abort(
      "`model` is only used when `max_tokens` is set.",
      class = "sbert_bad_input"
    )
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
  # Drop low-content segments — citation fragments, number lists, reference
  # noise — by alphabetic density. A domain-agnostic filter: prose scores near
  # 1, references far below. min_content = 0 (default) keeps everything.
  if (min_content > 0) {
    segment_lists <- lapply(segment_lists, function(parts) {
      if (length(parts) == 0L) parts else parts[content_ratio(parts) >= min_content]
    })
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
