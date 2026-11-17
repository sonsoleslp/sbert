#' Collapse repeated texts and count them
#'
#' @description
#' `dedupe()` collapses repeated texts: it keeps the first occurrence of every
#' distinct non-blank text, in order of first appearance, and adds its number of
#' occurrences as `n`. Many corpora repeat texts (templates, standard replies,
#' and copied messages); repeated texts carry no new information about the
#' topics, but in a clustering they pull the topic centers toward themselves and
#' inflate the size of the topics they fall in.
#'
#' Modeling each distinct text once, and carrying how often it occurred,
#' separates what kinds of text there are from how often each kind is used. The
#' result is a data frame with one row per distinct text. The counts can be used
#' as weights after fitting, for example with `topic_sizes(weights = "n")`.
#'
#' @param text A character vector, or a data frame together with `column`.
#'   Missing and blank texts are dropped.
#' @param column Name of the text column when `text` is a data frame; `NULL`
#'   (default) for a character vector.
#' @return A base data frame with one row per distinct text, in order of first
#'   appearance. For a character vector, the columns are `text` and `n`; for a
#'   data frame, all its columns, with the values of the row where the text
#'   first occurs, followed by `n`.
#' @section Conditions:
#'   An error of class `sbert_bad_input` when no non-blank text remains, when
#'   `column` is missing, not found, or given for a character vector, or when
#'   the data frame already has a column `n`.
#' @seealso [topic_sizes()] to weight topic sizes by the counts;
#'   [clean_corpus()] to clean the texts first.
#' @export
#' @examples
#' dedupe(c("Very good!", "Try again.", "Very good!", NA, "  "))
#'
#' corpus <- dedupe(feedback_translations, column = "translation")
#' head(corpus)
dedupe <- function(text, column = NULL) {
  if (is.data.frame(text)) {
    if (is.null(column)) {
      sbert_abort(
        "dedupe: supply `column` naming the text column of the data frame.",
        class = "sbert_bad_input"
      )
    }
    stopifnot(
      "`column` must be a single column name" =
        is.character(column) && length(column) == 1L && !is.na(column)
    )
    if (!column %in% names(text)) {
      sbert_abort(
        sprintf("dedupe: column '%s' not found in the data frame.", column),
        class = "sbert_bad_input"
      )
    }
    if ("n" %in% names(text)) {
      sbert_abort(
        "dedupe: the data frame already has a column `n`; rename it first.",
        class = "sbert_bad_input"
      )
    }
    values <- as.character(text[[column]])
    usable <- !is.na(values) & nzchar(trimws(values))
    if (!any(usable)) {
      sbert_abort(
        "dedupe: the text column contains no non-blank elements.",
        class = "sbert_bad_input"
      )
    }
    kept <- text[usable, , drop = FALSE]
    kept_values <- values[usable]
    first <- !duplicated(kept_values)
    out <- kept[first, , drop = FALSE]
    out$n <- as.integer(tabulate(
      match(kept_values, kept_values[first]),
      nbins = sum(first)
    ))
    rownames(out) <- NULL
    stopifnot(sum(out$n) == length(kept_values))
    return(out)
  }
  if (!is.null(column)) {
    sbert_abort(
      "dedupe: `column` applies only when `text` is a data frame.",
      class = "sbert_bad_input"
    )
  }
  stopifnot(
    "`text` must be a non-empty character vector or a data frame" =
      is.character(text) && length(text) >= 1L
  )

  kept <- text[!is.na(text) & nzchar(trimws(text))]
  if (length(kept) == 0L) {
    sbert_abort(
      "text contains no non-blank elements.",
      class = "sbert_bad_input"
    )
  }
  counts <- table(factor(kept, levels = unique(kept)))
  data.frame(
    text = names(counts),
    n = as.integer(counts),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

#' Remove list and enumeration markers from text
#'
#' @description
#' `strip_list_markers()` removes the markers of numbered and lettered lists,
#' such as `"1."`, `"(ii)"`, `"(a)"` and `"IV."`, from the text itself, before
#' segmentation and encoding. Such markers, common in texts taken from
#' documents, forms, or reports, carry no meaning, but they split sentences
#' where there is no sentence boundary, shift the embeddings, and appear in the
#' representative texts.
#'
#' It removes a one- or two-digit number with a period where a list can be (at
#' the start of the text or of a sentence, or continuing a list); a
#' parenthesized number, single letter, or Roman numeral; and an upper-case
#' Roman numeral with a period. A marker must stand alone, so a number that ends
#' a sentence (`"in the top 20."`), years, decimals, and words in parentheses
#' are kept. The result is `text` with the markers removed and white space
#' collapsed.
#'
#' The `numbers`, `roman_numerals`, and `section_numbers` arguments of
#' [topics()] filter the terms only. [clean_corpus()] applies this function
#' together with other cleaning steps.
#'
#' @param text A character vector without missing values.
#' @return `text` with the markers removed, runs of white space collapsed to
#'   one space, and each element trimmed.
#' @seealso [clean_corpus()], which includes this step; [dedupe()];
#'   [segment()].
#' @export
#' @examples
#' strip_list_markers(c("1. background 2. methods", "(i) first (ii) second"))
#' strip_list_markers("the concept of (civil) society in (2020)")
#' strip_list_markers("The student ranks in the top 20. Good work.")
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
  text <- strip_enumeration_markers(text)
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

#' Compute the share of letters in text
#'
#' @description
#' `content_ratio()` computes the share of letters among the non-space
#' characters of each element of `text`. The share separates prose from other
#' units without relying on a language: sentences score close to one, while
#' reference lists, citations, tables of numbers, and identifiers, which consist
#' mostly of digits and punctuation and form spurious topics of their own when
#' they are clustered, score low.
#'
#' It returns one value between 0 and 1 per element and is the measure behind
#' the `min_content` filters of [clean_corpus()], [segment()], and [topics()].
#'
#' @param text A character vector.
#' @return A numeric vector of the same length as `text`, with values between
#'   0 and 1; an empty or all-space element scores 0.
#' @seealso [clean_corpus()] and [segment()], which filter on it.
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
# where a list can be ("1. aims 2. methods", see strip_enumeration_markers()).
# Mirrors the tokenizer's section_numbers = "remove",
# operating on the source text.
clean_section_numbers <- function(text) {
  text <- gsub("[0-9]+(?:\\.[0-9]+){2,}", " ", text, perl = TRUE)
  # Two or three upper-case letters, a period, then digits ("II.2", "AA.2"): a
  # section or annex index. Two letters minimum keeps single-letter forms that
  # are usually content ("B.12" vitamin, "A.1") intact, and upper-case only
  # keeps mixed-case words and lower-case abbreviations untouched.
  text <- gsub("\\b[A-Z]{2,3}\\.[0-9]+\\b", " ", text, perl = TRUE)
  strip_enumeration_markers(text)
}

# Numbered-list markers ("1.", "2 ."). A one- or two-digit number with a period
# is a marker only where a list can be: at the start of the text or of a
# sentence, as a "1." directly followed by a "2.", or as the next number of a
# list already under way. Anywhere else it ends a sentence ("in the top 20.",
# "for student 10.") and is content, so it is kept.
enumeration_marker_pattern <- "(^|\\s)([0-9]{1,2})\\s*\\.(?=\\s|$)"

strip_enumeration_markers <- function(text) {
  has_candidate <- grepl(enumeration_marker_pattern, text, perl = TRUE)
  text[has_candidate] <- vapply(
    text[has_candidate],
    strip_document_enumeration_markers,
    character(1),
    USE.NAMES = FALSE
  )
  text
}

strip_document_enumeration_markers <- function(document) {
  matches <- gregexpr(enumeration_marker_pattern, document, perl = TRUE)
  number_start <- attr(matches[[1L]], "capture.start")[, 2L]
  number_length <- attr(matches[[1L]], "capture.length")[, 2L]
  numbers <- as.integer(substring(document, number_start, number_start + number_length - 1L))
  # What precedes the number, ignoring spaces, quotes, and an opening bracket:
  # nothing (start of text) or sentence/clause punctuation is a list position.
  before <- sub(
    "[[:space:]\"'(]+$", "",
    substring(document, 1L, number_start - 1L),
    perl = TRUE
  )
  boundary <- !nzchar(before) | grepl("[.:;!?]$", before, perl = TRUE)
  starts_list <- numbers == 1L & c(numbers[-1L] == 2L, FALSE)
  continues <- function(previous, i) !is.na(previous) && numbers[i] == previous + 1L
  # Whether a number continues a list depends on the markers before it, so the
  # last marker number is carried forward through the candidates in order.
  last_marker <- Reduce(
    function(previous, i) {
      if (boundary[i] || starts_list[i] || continues(previous, i)) numbers[i] else previous
    },
    seq_along(numbers),
    accumulate = TRUE,
    NA_integer_
  )
  previous <- last_marker[seq_along(numbers)]
  marker <- boundary | starts_list |
    vapply(seq_along(numbers), \(i) continues(previous[i], i), logical(1))
  regmatches(document, matches) <- list(
    ifelse(marker, " ", regmatches(document, matches)[[1L]])
  )
  document
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

#' Clean a corpus before encoding
#'
#' @description
#' `clean_corpus()` removes material without topical meaning from a corpus
#' before encoding: markup, links, citation numbers, list markers, and broken
#' characters. Text exported from web pages, databases, and documents carries
#' such material; left in place, it shifts the embeddings, appears among the
#' topic terms, and can form topics of its own. Cleaning the text once, before
#' encoding, means that the encoder, the topic terms, and the representative
#' texts all see the same clean text.
#'
#' It always repairs broken characters and removes markup, links, e-mail
#' addresses, DOIs, and bracketed citation numbers. It removes list markers and
#' section numbering by default, and on request numbers, Roman numerals, and the
#' matches of patterns of one's own (`remove`). Words, author citations, dates,
#' decimals, and numbers within sentences are kept. Documents left empty, or
#' with a share of letters below `min_content` (see [content_ratio()]), are
#' dropped. For a data frame, the dropped rows are removed whole, so other
#' columns stay aligned with the text. It returns the cleaned texts that are
#' kept or, for a data frame, the kept rows with `column` cleaned.
#'
#' The `numbers`, `roman_numerals`, and `section_numbers` arguments of
#' [topics()], by contrast, filter only the topic terms and leave the text
#' unchanged.
#'
#' @param text A character vector, or a data frame together with `column`.
#' @param column Name of the text column when `text` is a data frame; `NULL`
#'   (default) for a character vector.
#' @param list_markers Remove list and enumeration markers (default `TRUE`);
#'   see [strip_list_markers()].
#' @param section_numbers Remove section numbering such as `1.2.3` and
#'   `II.2` (default `TRUE`).
#' @param numbers Remove stand-alone numbers such as years and counts, keeping
#'   words with digits such as `covid19` (default `FALSE`).
#' @param roman_numerals Remove stand-alone Roman numerals of two or more
#'   letters, such as `ii` and `xiv` (default `FALSE`).
#' @param remove Optional character vector of Perl-compatible regular
#'   expressions, matched case-insensitively; each match is replaced by a
#'   space. Default `NULL`.
#' @param min_content Minimum share of letters for a document to be kept,
#'   between 0 and 1 (default 0, keep every non-empty document).
#' @return For a character vector, the cleaned texts that are kept. For a data
#'   frame, the rows that are kept, with `column` cleaned.
#' @section Conditions:
#'   An error of class `sbert_bad_input` when `column` is given for a
#'   character vector.
#' @seealso [strip_list_markers()] and [content_ratio()], which it uses;
#'   [dedupe()] to collapse repeated texts after cleaning.
#' @export
#' @examples
#' clean_corpus(c(
#'   "1. The directive entered into force in 2020.",
#'   "OJ No L 297, 24.11.1979, p. 1."
#' ), min_content = 0.5)
#'
#' # Remove a reference form of one's own corpus
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
      sbert_abort(
        "`column` applies only when `text` is a data frame.",
        class = "sbert_bad_input"
      )
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

#' Compute the size of each topic
#'
#' @description
#' `topic_sizes()` returns the number and proportion of units in every topic of
#' a fitted model and, with `weights`, the weighted size and share. The size of
#' a topic can be counted in several ways: counted in distinct texts, it says
#' how varied the content of the topic is; weighted by how often each text
#' occurred, it says how much of the original corpus the topic accounts for.
#'
#' A topic whose weighted share far exceeds its share of distinct texts is a
#' small set of texts that are repeated many times. For a segmented model, a
#' topic can be counted in segments or, with `by = "document"`, in the documents
#' that have at least one segment in it; a document with segments in several
#' topics then counts in each of them, so the proportions need not sum to one.
#' For a model fitted to documents, the two scales are the same.
#'
#' @param object A topic model fitted by [topics()].
#' @param weights Optional weights: the name of a numeric column carried in
#'   the model (for example `"n"` from [dedupe()]), or a numeric vector of
#'   non-negative weights, one per unit on the chosen scale. Default `NULL`.
#' @param by Unit counted: `"segment"` (default), every modeled unit, or
#'   `"document"`, the source documents.
#' @return A base data frame with one row per topic and columns `topic`,
#'   `label`, `n_documents`, and `proportion`, followed by `n_weighted` and
#'   `weighted_share` when `weights` are given.
#' @section Conditions:
#'   An error of class `sbert_bad_input` when `weights` names a column that
#'   the model does not carry.
#' @seealso [dedupe()] for the counts; [topics()];
#'   [as.data.frame()][as.data.frame.sbert_topic_model] for the full tables;
#'   [plot()][plot.sbert_topic_model] with `type = "sizes"`.
#' @export
#' @examples
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings)
#' topic_sizes(topic_model)
#' topic_sizes(topic_model, weights = "n")
topic_sizes <- function(object, weights = NULL, by = c("segment", "document")) {
  by <- match.arg(by)
  stopifnot(inherits(object, "sbert_topic_model"))
  documents <- object$documents

  # The counting scale: every fitted unit (the sizes the fit recorded), or the
  # distinct source documents, each counted once per topic it reaches.
  if (by == "document") {
    pairs <- unique(documents[, c("document_id", "topic")])
    unit_id <- pairs$document_id
    unit_topic <- pairs$topic
    n_units <- length(unique(documents$document_id))
    counts <- tabulate(unit_topic, nbins = nrow(object$topics))
    proportion <- counts / n_units
  } else {
    unit_id <- seq_len(nrow(documents))
    unit_topic <- documents$topic
    n_units <- nrow(documents)
    counts <- object$topics$n_documents
    proportion <- object$topics$proportion
  }
  weight_column <- NULL
  if (is.character(weights)) {
    stopifnot(
      "`weights` must be a single column name or a numeric vector" =
        length(weights) == 1L && !is.na(weights)
    )
    weight_column <- weights
    if (!weight_column %in% setdiff(names(documents), c("document_id", "topic"))) {
      sbert_abort(
        sprintf(
          paste0(
            "topic_sizes: column '%s' is not carried in the model. Fit the ",
            "model on a data frame with `column =` so its other columns are kept."
          ),
          weight_column
        ),
        class = "sbert_bad_input"
      )
    }
    values <- documents[[weight_column]]
    weights <- if (by == "document") {
      values[match(unit_id, documents$document_id)]
    } else {
      values
    }
    unit_id <- seq_along(unit_id)
    n_units <- length(unit_id)
  }
  stopifnot(
    "`weights` must be a finite non-negative vector with one value per unit on the chosen scale" =
      is.null(weights) ||
        (
          is.numeric(weights) &&
            length(weights) == n_units &&
            !anyNA(weights) &&
            all(is.finite(weights)) &&
            all(weights >= 0)
        )
  )

  sizes <- data.frame(
    topic = object$topics$topic,
    label = object$topics$label,
    n_documents = counts,
    proportion = proportion,
    stringsAsFactors = FALSE
  )
  if (is.null(weights)) {
    return(sizes)
  }

  weighted_totals <- vapply(
    sizes$topic,
    function(topic_id) sum(weights[unit_id[unit_topic == topic_id]]),
    numeric(1)
  )
  sizes$n_weighted <- weighted_totals
  sizes$weighted_share <- weighted_totals / sum(weighted_totals)
  sizes
}

# Accepts either a character vector (the historical input) or a data frame
# together with `column`, the name of the text column. Rows whose text is
# missing, blank, or a bibliographic placeholder cannot be modeled, so they
# are dropped once here instead of by every caller; the surviving row indices
# come back so precomputed embeddings can be subset the same way.
prepare_topic_input <- function(text, column = NULL) {
  if (!is.data.frame(text)) {
    if (!is.null(column)) {
      sbert_abort(
        "topics: 'column' applies only when the first argument is a ",
        "data frame.",
        class = "sbert_bad_input"
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
    sbert_abort(
      "topics: supply 'column' naming the text column of the data ",
      "frame, for example column = \"abstract\".",
      class = "sbert_bad_input"
    )
  }
  stopifnot(is.character(column), length(column) == 1L, !is.na(column))
  if (!column %in% names(text)) {
    sbert_abort(
      sprintf(
        "topics: column '%s' not found. Available: %s.",
        column,
        paste(utils::head(names(text), 12L), collapse = ", ")
      ),
      class = "sbert_bad_input"
    )
  }

  values <- text[[column]]
  if (!is.character(values)) {
    values <- as.character(values)
  }
  n_supplied <- length(values)
  kept <- which(usable_document_text(values))
  if (length(kept) < 2L) {
    sbert_abort(
      "topics: fewer than two usable documents after dropping missing, ",
      "blank, and placeholder text.",
      class = "sbert_bad_input"
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
