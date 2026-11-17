# Build data/feedback_embeddings.rda — the precomputed embeddings the
# vignettes, examples, and tests use so they run without a model download.
#
# Recipe (matches the vignette narrative): the first 600 distinct English
# translations of feedback_translations, in order of first appearance, encoded
# with the pinned all-MiniLM-L6-v2. Rebuild data/feedback_translations.rda
# first (data-raw/feedback_translations.R) so this reflects the cleaned CSV.
#
# Run from the package root (downloads the runtime + model on first use):
#   Rscript data-raw/feedback_embeddings.R

library(sbert)

load(file.path("data", "feedback_translations.rda"))

corpus <- head(dedupe(feedback_translations$translation), 600L)
stopifnot(nrow(corpus) == 600L)

install_runtime()
model_download("all-MiniLM-L6-v2")
model <- load_model("all-MiniLM-L6-v2")

embeddings <- encode(corpus$text, model = model, batch_size = 64L)
stopifnot(
  is.matrix(embeddings),
  nrow(embeddings) == 600L,
  ncol(embeddings) == model$dimension,
  max(abs(sqrt(rowSums(embeddings^2)) - 1)) < 1e-4  # L2-normalized
)

# Round to 4 decimals: this is an illustrative vignette fixture, not a parity
# reference, and rounding keeps the shipped .rds small (~0.4 MB vs ~1.7 MB).
embeddings <- round(embeddings, 4L)

feedback_embeddings <- unname(embeddings)
save(
  feedback_embeddings,
  file = file.path("data", "feedback_embeddings.rda"),
  compress = "xz"
)
message(sprintf(
  "Wrote data/feedback_embeddings.rda: %d x %d, %d bytes",
  nrow(feedback_embeddings), ncol(feedback_embeddings),
  file.size(file.path("data", "feedback_embeddings.rda"))
))
