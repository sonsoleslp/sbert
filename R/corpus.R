#' Deduplicate a Text Corpus with Frequencies
#'
#' Collapses a character vector to its distinct non-blank texts, keeping the
#' order of first appearance and counting how often each text occurred.
#' Embedding and clustering operate on the distinct texts (so repeated
#' templates cannot drag the cluster geometry), while the returned counts
#' carry the original frequencies back into reporting, for example through
#' [topic_sizes()].
#'
#' @param text A character vector. `NA` and blank (whitespace-only) elements
#'   are dropped before deduplication.
#' @return A base data frame with one row per distinct text and columns
#'   `text` (in order of first appearance) and `n` (number of occurrences).
#' @export
#' @examples
#' dedupe(c("Very good!", "Try again.", "Very good!", NA, "  "))
dedupe <- function(text) {
  stopifnot(is.character(text), length(text) >= 1L)

  kept <- text[!is.na(text) & nzchar(trimws(text))]
  if (length(kept) == 0L) {
    stop("text contains no non-blank elements.", call. = FALSE)
  }
  counts <- table(factor(kept, levels = unique(kept)))
  data.frame(
    text = names(counts),
    n = as.integer(counts),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

#' Strip Enumeration and List Markers from Text
#'
#' Removes list and enumeration markers — `"1."`, `"2."`, `"(i)"`, `"(a)"`,
#' `"(iv)"`, `"IV."`, `"V."` — from each document. The `numbers`,
#' `roman_numerals`, and `section_numbers` arguments of [topics()] clean only the
#' extracted *terms*; this cleans the source *text*, so markers no longer
#' over-fragment [segment()], skew the embeddings, or surface in
#' [representatives()][representatives]. Run it once, before embedding or
#' segmentation, as a companion to [dedupe()].
#'
#' A marker must stand alone — whitespace or a string boundary on both sides —
#' so real words in parentheses (`"(civil)"`), four-digit years (`"(2020)"`),
#' counts (`"(n=100)"`), multi-word parentheticals (`"(see Fig 1)"`), and
#' decimals (`"1.5"`) are left untouched. Removed forms are a standalone one- or
#' two-digit number followed by a period (`"1."`, `"12."`); a parenthesized
#' one- or two-digit number, single letter, or Roman numeral up to 39 (`"(1)"`,
#' `"(a)"`, `"(iv)"`); and a bare upper-case Roman-numeral section marker with a
#' period (`"II."`, `"IV."`). A multi-letter numeral is removed anywhere; a
#' single-letter one (`"V."`, `"X."`) only at the start of the text, so a
#' mid-sentence initial (`"by V. Nabokov"`), unit (`"5 V."`), and lower-case
#' `"v."` (versus) are kept.
#'
#' @param text A character vector.
#' @return `text` with markers removed and runs of whitespace collapsed to a
#'   single space; each element trimmed.
#' @seealso [dedupe()], and the `numbers` / `roman_numerals` / `section_numbers`
#'   arguments of [topics()] for cleaning the terms rather than the text.
#' @export
#' @examples
#' strip_list_markers(c("1. background 2. methods", "(i) first (ii) second"))
#' strip_list_markers("the concept of (civil) society in (2020)")
strip_list_markers <- function(text) {
  stopifnot(is.character(text), !anyNA(text))
  if (length(text) == 0L) {
    return(text)
  }
  # A Roman numeral from 1 to 39, non-empty (the lookahead forbids the empty
  # match that the otherwise-all-optional pattern would allow). One to three
  # digits covers footnote numbers like "(109)" while a four-digit year in
  # parentheses ("(2020)") does not match and is kept.
  roman <- "(?=[ivxlcdm])x{0,3}(?:ix|iv|v?i{0,3})"
  parenthesized <- paste0("(?i:[0-9]{1,3}|[a-z]|", roman, ")")
  # `\\s*` tolerates the space that OCR and reflowed text leave around the mark,
  # so "2 ." and "( i )" are caught as well as "2." and "(i)".
  text <- gsub("(^|\\s)[0-9]{1,2}\\s*\\.(?=\\s|$)", " ", text, perl = TRUE)
  text <- gsub(
    paste0("(^|\\s)\\(\\s*", parenthesized, "\\s*\\)(?=\\s|$)"),
    " ", text,
    perl = TRUE
  )
  # Bare Roman-numeral section markers ("IV.", "V.", "II."). Matched upper-case
  # only, so a lower-case "v." (versus, as in "Smith v. Jones") is left alone.
  # Multi-character numerals (II, III, IV, ...) cannot be a single-letter
  # initial, so they are stripped wherever they stand. A single-letter numeral
  # (V, X, L, C, D, M) is stripped only at the very start of the text — the one
  # unambiguous enumeration position — so a mid-sentence initial ("by V.
  # Nabokov", "P. M. Jones"), a unit ("5 V."), and a decision ("Smith v. Jones")
  # all keep their letter.
  multi <- .sbert_roman_numerals[nchar(.sbert_roman_numerals) >= 2L]
  multi <- toupper(multi[order(-nchar(multi))])
  text <- gsub(
    paste0("(^|\\s)(?:", paste(multi, collapse = "|"), ")\\.(?=\\s|$)"),
    " ", text, perl = TRUE
  )
  text <- gsub("^\\s*[VXLCDM]\\.(?=\\s|$)", " ", text, perl = TRUE)
  trimws(gsub("[[:space:]]+", " ", text, perl = TRUE))
}

#' Alphabetic Content Ratio of Text
#'
#' The fraction of a string's non-space characters that are letters. A
#' domain-agnostic measure of how much of a unit is prose rather than numbers,
#' punctuation, or symbols: real sentences score near 1, while citation
#' fragments, reference lists, number tables, and identifiers (`"OJ No L 297,
#' 24.11.1979, p. 1."`, `"doi:10.1007/..."`) score low. Used by the
#' `min_content` filters of [segment()] and [topics()].
#'
#' @param text A character vector.
#' @return A numeric vector in `[0, 1]`; empty or space-only elements score `0`.
#' @export
#' @examples
#' content_ratio(c("A real sentence here.", "OJ No L 297, 24.11.1979, p. 1."))
content_ratio <- function(text) {
  stopifnot(is.character(text))
  if (length(text) == 0L) {
    return(numeric(0))
  }
  text <- enc2utf8(text)
  letters <- nchar(gsub("(*UTF)[^\\p{L}]+", "", text, perl = TRUE), type = "chars")
  total <- nchar(gsub("[[:space:]]+", "", text, perl = TRUE), type = "chars")
  ifelse(total == 0L, 0, letters / total)
}

# Repair junk and strip non-content markup: decode common HTML entities and
# tags, remove URLs, emails, DOIs, and bracketed numeric citations, normalize
# curly quotes/dashes and bullets, drop control/zero-width/BOM/replacement
# characters and non-breaking spaces, and collapse whitespace. Everything here
# carries no topical meaning, so it is always applied by clean_corpus().
clean_characters <- function(text) {
  text <- enc2utf8(text)
  # HTML entities.
  text <- gsub("&amp;", "&", text, fixed = TRUE)
  text <- gsub("&nbsp;", " ", text, fixed = TRUE)
  text <- gsub("&lt;", "<", text, fixed = TRUE)
  text <- gsub("&gt;", ">", text, fixed = TRUE)
  text <- gsub("&quot;", "\"", text, fixed = TRUE)
  text <- gsub("&#39;|&#8217;|&#8216;|&rsquo;|&lsquo;|&apos;", "'", text, perl = TRUE)
  # HTML / XML tags (a letter or slash after "<", so "x < 3" is not a tag).
  text <- gsub("</?[[:alpha:]][^>]*>|<[[:alpha:]]+/?>", " ", text, perl = TRUE)
  # URLs, DOIs, and email addresses — long non-content tokens.
  text <- gsub("(?i)\\b(?:https?://|www\\.|doi:\\s*)\\S+", " ", text, perl = TRUE)
  text <- gsub("[[:alnum:]._%+-]+@[[:alnum:].-]+\\.[[:alpha:]]{2,}", " ", text, perl = TRUE)
  # Bracketed numeric citations: "[12]", "[1,2]", "[1-3]" (letters are left).
  text <- gsub("\\[[0-9][0-9,;[:space:]-]*\\]", " ", text, perl = TRUE)
  # Page references: "p. 1", "pp. 15-30" — generic across academic and legal
  # text (a digit is required, so an initial "p. M" is not touched).
  text <- gsub(
    "(*UTF)(?i)\\bpp?\\.\\s*[0-9]+(?:\\s*[-\\x{2013}]\\s*[0-9]+)?", " ",
    text, perl = TRUE
  )
  # Normalize curly quotes, dashes, and bullets to plain forms, as segment().
  text <- gsub("(*UTF)[\\x{2018}\\x{2019}\\x{201B}\\x{2032}]", "'", text, perl = TRUE)
  text <- gsub("(*UTF)[\\x{201C}\\x{201D}]", "\"", text, perl = TRUE)
  text <- gsub("(*UTF)[\\x{2013}\\x{2014}]", " - ", text, perl = TRUE)
  text <- gsub("(*UTF)[\\x{2022}\\x{25CF}\\x{25AA}\\x{00B7}\\x{2023}\\x{2043}\\x{2219}]", " ", text, perl = TRUE)
  # Control, zero-width, BOM, replacement, non-breaking space.
  text <- gsub(
    "(*UTF)[\\x{00}-\\x{08}\\x{0B}\\x{0C}\\x{0E}-\\x{1F}\\x{7F}]", " ",
    text, perl = TRUE
  )
  text <- gsub(
    "(*UTF)[\\x{200B}-\\x{200D}\\x{FEFF}\\x{00AD}\\x{FFFD}]", "",
    text, perl = TRUE
  )
  text <- gsub("(*UTF)\\x{00A0}", " ", text, perl = TRUE)
  trimws(gsub("[[:space:]]+", " ", text, perl = TRUE))
}

# Text-level section/reference numbering: multi-level numeric indices ("1.2.3"),
# alphanumeric section indices ("II.2", "AA.2", "A.1"), and enumeration markers
# ("1.", "figure 12."). Mirrors the tokenizer's section_numbers = "remove",
# operating on the source text.
clean_section_numbers <- function(text) {
  text <- gsub("[0-9]+(?:\\.[0-9]+){2,}", " ", text, perl = TRUE)
  # Two or three upper-case letters, a period, then digits ("II.2", "AA.2"): a
  # section or annex index. Two letters minimum keeps single-letter forms that
  # are usually content ("B.12" vitamin, "A.1") intact, and upper-case only
  # keeps mixed-case words and lower-case abbreviations untouched.
  text <- gsub("\\b[A-Z]{2,3}\\.[0-9]+\\b", " ", text, perl = TRUE)
  gsub("(^|\\s)[0-9]{1,2}\\s*\\.(?=\\s|$)", " ", text, perl = TRUE)
}

# Text-level numeric-token removal: drop stand-alone digit runs (years, counts)
# while keeping alphanumerics such as "covid19", whose digits are not on a word
# boundary.
clean_numbers <- function(text) {
  gsub("\\b[0-9]+\\b", " ", text, perl = TRUE)
}

# Text-level Roman-numeral removal: drop stand-alone canonical numerals of two
# or more characters ("ii", "iv", "xii"), case-insensitively. Length two keeps
# the pronoun "I" and article "a"; the 1-to-100 bound keeps abbreviations that
# are also numerals ("ml", "mm", "cc").
clean_roman_numerals <- function(text) {
  multi <- .sbert_roman_numerals[nchar(.sbert_roman_numerals) >= 2L]
  pattern <- paste0("(?i)\\b(?:", paste(multi, collapse = "|"), ")\\b")
  gsub(pattern, " ", text, perl = TRUE)
}

#' Clean a Text Corpus Before Encoding
#'
#' One place for the text-level cleaning that should happen *before* embedding,
#' so the same clean text feeds the encoder, the topic terms, and the
#' representative examples. Junk characters are always repaired; the structured
#' removals are opt-in. Because cleaning happens up front, encode the result and
#' pass those embeddings on — nothing downstream needs to re-clean.
#'
#' The operations, in order: repair junk and strip non-content markup (decode
#' HTML entities and tags; remove URLs, DOIs, emails, and bracketed numeric
#' citations such as `[12]`; normalize curly quotes, dashes, and bullets; drop
#' control, zero-width, BOM, and replacement characters; normalize whitespace);
#' strip list and section numbering; optionally remove numeric and Roman-numeral
#' tokens; then drop documents that fall below `min_content` (see
#' [content_ratio()]) or are left empty. Content-bearing text — real words,
#' author citations, dates, decimals, inline numbers — is left intact. When
#' `text` is a data frame the surviving rows are returned whole, so metadata
#' stays aligned.
#'
#' @param text A character vector, or a data frame together with `column`.
#' @param column When `text` is a data frame, the name of the text column to
#'   clean. Every other column rides along and is filtered in step.
#' @param list_markers Remove enumeration and list markers (`1.`, `(i)`,
#'   `(a)`); default `TRUE`. See [strip_list_markers()].
#' @param section_numbers Remove multi-level indices (`1.2.3`) and enumeration
#'   markers; default `TRUE`.
#' @param numbers Remove stand-alone numeric tokens (years, counts) while
#'   keeping alphanumerics such as `covid19`; default `FALSE`.
#' @param roman_numerals Remove stand-alone Roman-numeral tokens (`ii`, `iv`,
#'   up to 100); default `FALSE`. A few numerals that are also words (`iv`,
#'   `vi`) go too.
#' @param remove Optional character vector of custom Perl-compatible regular
#'   expressions. Each match is replaced with a space, before the other steps.
#'   The extension point for domain-specific noise the generic cleaners leave —
#'   for example `remove = "OJ No L?\\s*\\d+"` for European Union Official
#'   Journal references, or a journal-citation pattern. Matching is
#'   case-insensitive.
#' @param min_content Minimum alphabetic-content ratio, in `[0, 1]`, for a
#'   document to be kept (see [content_ratio()]). Documents below the floor —
#'   citation lists, reference footnotes, number tables — are dropped. `0`
#'   (default) keeps every non-empty document.
#' @return If `text` is a character vector, the cleaned vector with dropped
#'   documents removed. If a data frame, the surviving rows with the `column`
#'   cleaned in place.
#' @seealso [strip_list_markers()], [content_ratio()], [dedupe()].
#' @export
#' @examples
#' clean_corpus(c(
#'   "1. The directive entered into force in 2020.",
#'   "OJ No L 297, 24.11.1979, p. 1."
#' ), min_content = 0.5)
#'
#' # strip a domain-specific reference form the generic cleaner leaves
#' clean_corpus("as set out in OJ No L 313 it applies.",
#'              remove = "OJ No L?\\s*\\d+")
clean_corpus <- function(
  text,
  column = NULL,
  list_markers = TRUE,
  section_numbers = TRUE,
  numbers = FALSE,
  roman_numerals = FALSE,
  remove = NULL,
  min_content = 0
) {
  stopifnot(
    is.logical(list_markers), length(list_markers) == 1L, !is.na(list_markers),
    is.logical(section_numbers), length(section_numbers) == 1L, !is.na(section_numbers),
    is.logical(numbers), length(numbers) == 1L, !is.na(numbers),
    is.logical(roman_numerals), length(roman_numerals) == 1L, !is.na(roman_numerals),
    is.null(remove) || (is.character(remove) && !anyNA(remove)),
    is.numeric(min_content), length(min_content) == 1L,
    is.finite(min_content), min_content >= 0, min_content <= 1
  )
  is_frame <- is.data.frame(text)
  values <- if (is_frame) {
    stopifnot(is.character(column), length(column) == 1L, column %in% names(text))
    as.character(text[[column]])
  } else {
    stopifnot(is.character(text))
    if (!is.null(column)) {
      stop("`column` applies only when `text` is a data frame.", call. = FALSE)
    }
    text
  }
  if (length(values) == 0L) {
    return(text)
  }
  na <- is.na(values)
  values[na] <- ""

  values <- clean_characters(values)
  # Judge the content floor on the repaired text, before the number and marker
  # removals: stripping a reference's dates and page numbers would otherwise
  # raise its letter ratio and let it slip through. A unit is dropped for being
  # reference-like based on what it was, not what stripping made it look like.
  content_ok <- if (min_content > 0) content_ratio(values) >= min_content else TRUE

  # Custom domain patterns run next, so the extension point sees repaired text.
  for (pattern in remove) {
    values <- gsub(paste0("(?i)", pattern), " ", values, perl = TRUE)
  }

  if (section_numbers) {
    values <- clean_section_numbers(values)
  }
  if (list_markers) {
    values <- strip_list_markers(values)
  }
  if (numbers) {
    values <- clean_numbers(values)
  }
  if (roman_numerals) {
    values <- clean_roman_numerals(values)
  }
  # Tidy punctuation the removals left dangling: a space before punctuation, and
  # runs of separators collapsed to one.
  values <- gsub("\\s+([,.;:])", "\\1", values, perl = TRUE)
  values <- gsub("(?:\\s*[,;:]\\s*){2,}", ", ", values, perl = TRUE)
  values <- gsub(",\\s*\\.", ".", values, perl = TRUE)
  values <- trimws(gsub("[[:space:]]+", " ", values, perl = TRUE))
  values <- trimws(gsub("^[,.;:\\s]+", "", values, perl = TRUE))

  keep <- !na & nzchar(values) & content_ok
  if (is_frame) {
    text[[column]] <- values
    out <- text[keep, , drop = FALSE]
    rownames(out) <- NULL
    out
  } else {
    values[keep]
  }
}

#' Topic Sizes on the Distinct and Weighted Scales
#'
#' Returns the size of every topic as fitted (distinct documents) and,
#' when `weights` are supplied, on the weighted scale — for example the
#' original row frequencies from [dedupe()]. The gap between
#' `proportion` and `weighted_share` measures how template-driven a topic
#' is: a topic whose weighted share far exceeds its distinct share is a
#' small repertoire of heavily repeated texts.
#'
#' @param object A fitted [topics()] model.
#' @param weights Optional numeric vector with one non-negative weight per
#'   fitted document (in document order), typically the `n` column of
#'   [dedupe()].
#' @return A base data frame with one row per topic and columns `topic`,
#'   `label`, `n_documents`, and `proportion`, plus `n_weighted` and
#'   `weighted_share` when `weights` are supplied.
#' @export
#' @examples
#' text <- c(
#'   "Cats chase mice", "Dogs chase balls",
#'   "Stocks and bonds trade", "Markets price shares"
#' )
#' embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
#' fitted <- topics(text, 2, embeddings = embeddings)
#' topic_sizes(fitted, weights = c(10, 1, 1, 1))
topic_sizes <- function(object, weights = NULL) {
  stopifnot(
    inherits(object, "sbert_topic_model"),
    is.null(weights) ||
      (
        is.numeric(weights) &&
          length(weights) == nrow(object$documents) &&
          !anyNA(weights) &&
          all(is.finite(weights)) &&
          all(weights >= 0)
      )
  )

  sizes <- data.frame(
    topic = object$topics$topic,
    label = object$topics$label,
    n_documents = object$topics$n_documents,
    proportion = object$topics$proportion,
    stringsAsFactors = FALSE
  )
  if (is.null(weights)) {
    return(sizes)
  }

  weighted_totals <- vapply(
    sizes$topic,
    function(topic_id) sum(weights[object$documents$topic == topic_id]),
    numeric(1)
  )
  sizes$n_weighted <- weighted_totals
  sizes$weighted_share <- weighted_totals / sum(weighted_totals)
  sizes
}

# Accepts either a character vector (the historical input) or a data frame
# together with `column`, the name of the text column. Rows whose text is
# missing, blank, or a bibliographic placeholder cannot be modelled, so they
# are dropped once here instead of by every caller; the surviving row indices
# come back so precomputed embeddings can be subset the same way.
prepare_topic_input <- function(text, column = NULL) {
  if (!is.data.frame(text)) {
    if (!is.null(column)) {
      stop(
        "topics: 'column' applies only when the first argument is a ",
        "data frame.",
        call. = FALSE
      )
    }
    return(list(
      text = text,
      metadata = NULL,
      kept = seq_along(text),
      n_supplied = length(text)
    ))
  }

  if (is.null(column)) {
    stop(
      "topics: supply 'column' naming the text column of the data ",
      "frame, for example column = \"abstract\".",
      call. = FALSE
    )
  }
  stopifnot(is.character(column), length(column) == 1L, !is.na(column))
  if (!column %in% names(text)) {
    stop(
      sprintf(
        "topics: column '%s' not found. Available: %s.",
        column,
        paste(utils::head(names(text), 12L), collapse = ", ")
      ),
      call. = FALSE
    )
  }

  values <- text[[column]]
  if (!is.character(values)) {
    values <- as.character(values)
  }
  n_supplied <- length(values)
  kept <- which(usable_document_text(values))
  if (length(kept) < 2L) {
    stop(
      "topics: fewer than two usable documents after dropping missing, ",
      "blank, and placeholder text.",
      call. = FALSE
    )
  }
  metadata <- text[kept, setdiff(names(text), column), drop = FALSE]
  rownames(metadata) <- NULL
  list(
    text = values[kept],
    metadata = metadata,
    kept = kept,
    n_supplied = n_supplied
  )
}

# Bibliographic exports mark absent abstracts with a literal placeholder that
# would otherwise be embedded as if it were content.
usable_document_text <- function(values) {
  trimmed <- trimws(values)
  !is.na(trimmed) &
    nzchar(trimmed) &
    !toupper(trimmed) %in% c(
      "[NO ABSTRACT AVAILABLE]", "NO ABSTRACT AVAILABLE", "NA", "NULL"
    )
}

# Puts `label` directly after `topic` in any table keyed by topic id.
insert_topic_label <- function(table, labels) {
  if (is.null(table) || nrow(table) == 0L || !"topic" %in% names(table)) {
    return(table)
  }
  table$label <- labels[table$topic]
  position <- match("topic", names(table))
  reordered <- append(
    setdiff(names(table), "label"),
    "label",
    after = position
  )
  table[, reordered, drop = FALSE]
}

# The exported verb is now `stop_words()`, which collides with the argument of
# the same name; a default of `stop_words()` inside a function whose parameter
# is `stop_words` is a self-reference. Callers get the same list either way.
default_stop_words <- function() stop_words()

# Same shadowing problem as default_stop_words(): a parameter named `cache_dir`
# or `abbreviations` hides the verb of that name from its own default. These
# wrappers resolve the verb in a scope where nothing shadows it.
default_cache_dir <- function() cache_dir()

default_abbreviations <- function() abbreviations()
