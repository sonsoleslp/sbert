# The 600 distinct English feedback messages whose embeddings ship as the
# `feedback_embeddings` dataset, rows aligned.
feedback_fixture <- function() {
  corpus <- utils::head(dedupe(feedback_translations$translation), 600L)
  list(text = corpus$text, n = corpus$n, embeddings = feedback_embeddings)
}
