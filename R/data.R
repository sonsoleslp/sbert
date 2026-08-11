#' Levebee AI Mathematics Feedback with English Translations
#'
#' AI-generated feedback messages shown to young learners solving mathematics
#' exercises in the Levebee educational application, paired with their English
#' translations. The messages are short instructional hints and encouragements
#' ("Choose the picture...", "Try listening to the instruction again.") whose
#' source languages include Czech, Slovak, Polish, German, Hungarian,
#' Romanian, Ukrainian, Russian, Mongolian, and Vietnamese. The corpus is a
#' realistic, quirk-preserving benchmark for the package's embedding,
#' similarity, segmentation, and topic-modeling workflow: translations repeat
#' (templates such as "Try again." recur), some source messages remain in
#' their original language, and a few are identical to their translation.
#'
#' @format A data frame with 8,757 rows and 2 character columns:
#' \describe{
#'   \item{feedback}{The original feedback message in the source language.}
#'   \item{translation}{The English translation of the message.}
#' }
#' There are 8,005 distinct translations. Messages are at most 193 characters
#' long.
#'
#' @source Anonymized export of the AI mathematics feedback of the Levebee
#'   educational application (<https://www.levebee.com/>), December 2025. The
#'   messages address learners generically and contain no personal names or
#'   identifiers.
#' @examples
#' head(feedback_translations)
#'
#' segment(
#'   head(feedback_translations$translation, 5),
#'   level = "sentence"
#' )
"feedback_translations"

#' COVID-19 Research Abstracts
#'
#' Abstracts of peer-reviewed research on COVID-19, drawn from a bibliographic
#' database export and covering its effects on education, children, schools, and
#' society. Longer and more technical than [feedback_translations], with a
#' publication year on every record, the corpus is a realistic benchmark for the
#' package's embedding and topic-modeling workflow — including temporal analysis
#' across the pandemic years.
#'
#' @format A data frame with 4,170 rows and 2 columns:
#' \describe{
#'   \item{Year}{Integer publication year, from 2020 to 2024.}
#'   \item{Abstract}{The article abstract. 323 records carry the placeholder
#'     `"[No abstract available]"`; 3,671 of the abstracts are distinct and the
#'     longest is 5,285 characters.}
#' }
#' Editorial notices (retractions, corrections, and errata) are removed during
#' preparation, so every row is a research abstract or a placeholder.
#'
#' @source Bibliographic database export of COVID-19 research articles
#'   (2020-2024), prepared by `data-raw/covid.R`.
#' @examples
#' table(covid$Year)
#'
#' content <- covid$Abstract[covid$Abstract != "[No abstract available]"]
#' nchar(content[1])
"covid"
