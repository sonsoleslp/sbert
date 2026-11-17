#' AI-generated mathematics feedback with English translations
#'
#' @description
#' `feedback_translations` is a dataset of AI-generated feedback messages shown
#' to young learners solving mathematics exercises in an educational
#' application, paired with their English translations. The messages are short
#' instructional hints and encouragements ("Choose the picture...", "Try
#' listening to the instruction again.") whose source languages include Czech,
#' Slovak, Polish, German, Hungarian, Romanian, Ukrainian, Russian, Mongolian,
#' and Vietnamese.
#'
#' The corpus keeps the quirks of real data: translations repeat (templates
#' such as "Try again." recur), some source messages remain in their original
#' language, and a few are identical to their translation. It is the example
#' corpus of the package for embedding, similarity, segmentation, and topic
#' modeling; [feedback_embeddings] holds precomputed embeddings of its first
#' 600 distinct translations.
#'
#' @format A data frame with 8,757 rows and 2 character columns:
#' \describe{
#'   \item{feedback}{The original feedback message in the source language.}
#'   \item{translation}{The English translation of the message.}
#' }
#' There are 8,005 distinct translations, of at most 193 characters.
#'
#' @source Anonymized export of the AI mathematics feedback of the Levebee
#'   educational application (<https://www.levebee.com/>), December 2025. The
#'   messages address learners generically and contain no personal names or
#'   identifiers.
#' @seealso [feedback_embeddings] for precomputed embeddings; [dedupe()] to
#'   collapse repeated messages; [covid] for a corpus of longer texts.
#' @examples
#' head(feedback_translations)
#'
#' # Repeated messages collapse to one row with their count
#' head(dedupe(feedback_translations, column = "translation"))
#'
#' # Split the first five translations into sentences
#' with(head(feedback_translations, 5), segment(translation, level = "sentence"))
"feedback_translations"

#' COVID-19 research abstracts
#'
#' @description
#' `covid` is a corpus of abstracts of peer-reviewed research on COVID-19, drawn
#' from a bibliographic database export and covering the effects of the pandemic
#' on education, children, schools, and society. The abstracts are longer and
#' more technical than the messages of [feedback_translations], and every record
#' has a publication year, so the corpus serves for topic models of long
#' documents, for segmented fits, and for following topics across the years of
#' the pandemic.
#'
#' @format A data frame with 4,170 rows and 2 columns:
#' \describe{
#'   \item{Year}{Integer publication year, from 2020 to 2024.}
#'   \item{Abstract}{The article abstract. 323 records carry the placeholder
#'     `"[No abstract available]"`; the other 3,847 hold 3,670 distinct
#'     abstracts, the longest of 5,285 characters.}
#' }
#' Editorial notices (retractions, corrections, and errata) were removed, so
#' every row is a research abstract or a placeholder. [topics()] and
#' [compare_topics()] drop the placeholder rows when given the data frame
#' with `column = "Abstract"`.
#'
#' @source Bibliographic database export of COVID-19 research articles
#'   (2020-2024), prepared by `data-raw/covid.R`.
#' @seealso [topics()] with `segment = "sentence"` for long documents;
#'   [clean_corpus()]; [feedback_translations] for a corpus of short texts.
#' @examples
#' xtabs(~ Year, data = covid)
#'
#' abstracts <- subset(covid, Abstract != "[No abstract available]")
#' nrow(abstracts)
#' with(abstracts, summary(nchar(Abstract)))
"covid"

#' Precomputed embeddings of 600 feedback messages
#'
#' @description
#' `feedback_embeddings` is a matrix of Sentence-BERT embeddings of the first
#' 600 distinct English translations of [feedback_translations], in order of
#' first appearance. They let topic models be fitted, compared, and inspected
#' without downloading a model, and they are the embeddings used by the examples
#' and articles of the package.
#'
#' Row `i` is the embedding of row `i` of
#' `head(dedupe(feedback_translations, column = "translation"), 600)`. Pass
#' the matrix as `embeddings =` to [topics()], [compare_topics()], or
#' [topic_corpus()] together with that data frame.
#'
#' @format A numeric matrix with 600 rows (messages) and 384 columns
#'   (embedding dimensions). Rows are L2-normalized and rounded to four
#'   decimals.
#' @source Encoded with the pinned `sentence-transformers/all-MiniLM-L6-v2`
#'   model (revision `1110a243fdf4706b3f48f1d95db1a4f5529b4d41`) by
#'   `data-raw/feedback_embeddings.R`. Encoding the same messages with
#'   [encode()] gives the same embeddings up to the rounding.
#' @seealso [feedback_translations], [topics()], [encode()].
#' @examples
#' dim(feedback_embeddings)
#'
#' corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
#' topic_model <- topics(corpus, n_topics = 6, column = "translation",
#'                       embeddings = feedback_embeddings)
#' topic_sizes(topic_model, weights = "n")
"feedback_embeddings"
