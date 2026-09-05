# The `segment` argument on the fitting verbs: a segmented fit must be the
# same model as fitting the segments by hand, and every downstream verb must
# know the parent document of each segment.

segment_fit_documents <- function() {
  c(
    alpha = "Cats chase mice. Kittens nap in the sun. Stocks and bonds trade daily.",
    beta = "Dogs chase balls. Markets price shares. Banks report profit.",
    gamma = "Cats purr softly. Bonds yield less."
  )
}

# One two-dimensional row per sentence of segment_fit_documents(): the first
# axis is "pets", the second "finance".
segment_fit_embeddings <- function() {
  rbind(
    c(1, 0), c(0.95, 0.05), c(0, 1),
    c(0.9, 0.1), c(0.05, 0.95), c(0, 0.9),
    c(1, 0.1), c(0.1, 1)
  )
}

segment_fit_model <- function(...) {
  topics(
    segment_fit_documents(),
    n_topics = 2,
    segment = "sentence",
    embeddings = segment_fit_embeddings(),
    n_terms = 3,
    ...
  )
}

model_surfaces <- function(m) {
  m[c("topics", "terms", "centers")]
}

testthat::test_that("a segmented fit is the fit of the hand-made segments", {
  by_argument <- segment_fit_model()
  segments <- segment(segment_fit_documents(), level = "sentence")
  by_hand <- topics(
    segments$text,
    n_topics = 2,
    embeddings = segment_fit_embeddings(),
    n_terms = 3
  )
  testthat::expect_identical(model_surfaces(by_argument), model_surfaces(by_hand))
  testthat::expect_identical(by_argument$documents$topic, by_hand$documents$topic)
  testthat::expect_identical(by_argument$documents$distance, by_hand$documents$distance)
  testthat::expect_identical(by_argument$documents$text, segments$text)
})

testthat::test_that("segmented documents carry their parent and position", {
  model <- segment_fit_model()
  testthat::expect_identical(
    names(model$documents),
    c("document_id", "document_name", "segment", "text", "topic", "label", "distance")
  )
  testthat::expect_identical(model$documents$document_id, c(1L, 1L, 1L, 2L, 2L, 2L, 3L, 3L))
  testthat::expect_identical(model$documents$segment, c(1L, 2L, 3L, 1L, 2L, 3L, 1L, 2L))
  testthat::expect_identical(
    model$documents$document_name,
    rep(c("alpha", "beta", "gamma"), c(3L, 3L, 2L))
  )
  testthat::expect_identical(model$settings$segment, "sentence")
  testthat::expect_null(model$settings$max_tokens)
  testthat::expect_identical(model$settings$merge_below, 0L)
  testthat::expect_identical(model$settings$min_content, 0)
  # representatives name the segment too
  testthat::expect_true(all(c("document_id", "segment") %in% names(model$representatives)))
  testthat::expect_snapshot(print(model))
})

testthat::test_that("an explicit segment = \"document\" is the default fit", {
  text <- c("Cats chase mice", "Dogs chase balls", "Stocks and bonds trade", "Markets price shares")
  embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
  default_fit <- topics(text, 2, embeddings = embeddings)
  explicit_fit <- topics(text, 2, embeddings = embeddings, segment = "document")
  testthat::expect_identical(default_fit, explicit_fit)
  testthat::expect_identical(default_fit$settings$segment, "document")
  testthat::expect_false("segment" %in% names(default_fit$documents))
})

testthat::test_that("data-frame metadata is expanded to one row per segment", {
  frame <- data.frame(
    id = c("a", "b", "c"),
    year = c(2020L, 2021L, 2022L),
    body = unname(segment_fit_documents()),
    stringsAsFactors = FALSE
  )
  model <- topics(
    frame,
    column = "body",
    n_topics = 2,
    segment = "sentence",
    embeddings = segment_fit_embeddings(),
    n_terms = 3
  )
  testthat::expect_identical(nrow(model$documents), 8L)
  testthat::expect_identical(model$documents$id, rep(c("a", "b", "c"), c(3L, 3L, 2L)))
  testthat::expect_identical(model$documents$year, rep(c(2020L, 2021L, 2022L), c(3L, 3L, 2L)))
})

testthat::test_that("topic_corpus records the segmentation and fits identically", {
  corpus <- topic_corpus(
    segment_fit_documents(),
    segment = "sentence",
    embeddings = segment_fit_embeddings()
  )
  testthat::expect_identical(corpus$settings$segment, "sentence")
  testthat::expect_identical(names(corpus$units), c("document_id", "document_name", "segment"))
  testthat::expect_identical(length(corpus$text), 8L)
  via_corpus <- topics(corpus, n_topics = 2, n_terms = 3)
  direct <- segment_fit_model()
  testthat::expect_identical(
    via_corpus[c("documents", "topics", "terms", "representatives", "centers", "settings")],
    direct[c("documents", "topics", "terms", "representatives", "centers", "settings")]
  )
  testthat::expect_snapshot(print(corpus))
})

testthat::test_that("compare_topics fits every candidate on the segments", {
  comparison <- compare_topics(
    segment_fit_documents(),
    n_topics = 2:3,
    segment = "sentence",
    embeddings = segment_fit_embeddings(),
    n_terms = 3
  )
  testthat::expect_s3_class(comparison, "sbert_topic_sweep")
  testthat::expect_identical(comparison$n_topics, 2:3)
  two <- fitted(comparison, n_topics = 2)
  testthat::expect_identical(two$settings$segment, "sentence")
  testthat::expect_identical(nrow(two$documents), 8L)
  # a candidate count is bounded by the segment count, not the document count
  testthat::expect_error(
    compare_topics(
      segment_fit_documents(),
      n_topics = c(2L, 8L),
      segment = "sentence",
      embeddings = segment_fit_embeddings()
    ),
    "below the number of units"
  )
})

testthat::test_that("topic_sizes counts segments or source documents", {
  model <- segment_fit_model()
  by_segment <- topic_sizes(model)
  by_document <- topic_sizes(model, by = "document")
  testthat::expect_identical(sum(by_segment$n_documents), nrow(model$documents))
  testthat::expect_true(all(by_document$n_documents <= 3L))
  # every document here has a sentence in each topic
  testthat::expect_identical(by_document$n_documents, c(3L, 3L))
  testthat::expect_identical(by_document$proportion, c(1, 1))
  weighted <- topic_sizes(model, by = "document", weights = c(3, 1, 1))
  testthat::expect_identical(weighted$n_weighted, c(5, 5))
  testthat::expect_error(topic_sizes(model, by = "document", weights = rep(1, 8)))
  testthat::expect_error(topic_sizes(model, weights = c(1, 1, 1)))

  # on a document-level model the two scales coincide
  text <- c("Cats chase mice", "Dogs chase balls", "Stocks and bonds trade", "Markets price shares")
  plain <- topics(text, 2, embeddings = rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9)))
  testthat::expect_identical(topic_sizes(plain, by = "document"), topic_sizes(plain))
})

testthat::test_that("topic_gamma of a segmented model needs no text", {
  model <- segment_fit_model()
  gamma <- topic_gamma(model)
  testthat::expect_identical(names(gamma), c("document_id", "topic", "gamma", "n_segments"))
  testthat::expect_identical(nrow(gamma), 6L)
  totals <- tapply(gamma$gamma, gamma$document_id, sum)
  testthat::expect_equal(as.numeric(totals), c(1, 1, 1))
  # the mixture is the share of each document's stored segments per topic
  expected <- with(
    model$documents,
    table(factor(document_id, levels = 1:3), factor(topic, levels = 1:2))
  )
  testthat::expect_equal(
    gamma$gamma,
    as.numeric(t(expected / rowSums(expected)))
  )
  # the same answer from the stored segments handed back explicitly
  explicit <- topic_gamma(
    model,
    model$documents[, c("document_id", "text")],
    embeddings = model$embeddings
  )
  testthat::expect_equal(gamma, explicit)
  testthat::expect_error(topic_gamma(model, level = "clause"), "apply only when")
  # a document-level model has no stored segments to count
  plain <- topics(
    c("Cats chase mice", "Dogs chase balls", "Stocks and bonds trade"),
    2,
    embeddings = rbind(c(1, 0), c(0.9, 0.1), c(0, 1))
  )
  testthat::expect_error(topic_gamma(plain), "supply `text`")
})

testthat::test_that("predict segments new text the way the model was fitted", {
  model <- segment_fit_model()
  prediction <- predict(
    model,
    c(new = "Cats nap. Markets rise."),
    embeddings = rbind(c(1, 0), c(0, 1))
  )
  testthat::expect_identical(
    names(prediction),
    c("document_id", "document_name", "segment", "text", "topic", "label", "distance")
  )
  testthat::expect_identical(prediction$document_id, c(1L, 1L))
  testthat::expect_identical(prediction$segment, c(1L, 2L))
  testthat::expect_identical(prediction$text, c("Cats nap.", "Markets rise."))
  testthat::expect_false(identical(prediction$topic[1], prediction$topic[2]))
  # rows must align with the segments, not the documents
  testthat::expect_error(
    predict(model, "Cats nap. Markets rise.", embeddings = rbind(c(1, 0))),
    "2 rows"
  )
})

testthat::test_that("representatives of the fitted segments name their source", {
  model <- segment_fit_model()
  examples <- representatives(model, n = 2)
  testthat::expect_identical(
    names(examples),
    c("topic", "rank", "document_id", "segment", "text", "distance", "margin")
  )
  testthat::expect_true(all(examples$text %in% model$documents$text))
  # the source columns are right: each example's text is at that position
  lookup <- paste(model$documents$document_id, model$documents$segment)
  testthat::expect_identical(
    model$documents$text[match(paste(examples$document_id, examples$segment), lookup)],
    examples$text
  )
  # supplied text is ranked as before, without source columns
  supplied <- representatives(
    model,
    c("kittens pounce", "bond yields"),
    embeddings = rbind(c(1, 0.1), c(0.1, 1)),
    n = 1
  )
  testthat::expect_identical(names(supplied), c("topic", "rank", "text", "distance", "margin"))
})

testthat::test_that("reduce_topics keeps the segment columns and refreshes labels", {
  three <- topics(
    segment_fit_documents(),
    n_topics = 3,
    segment = "sentence",
    embeddings = segment_fit_embeddings(),
    n_terms = 3
  )
  two <- reduce_topics(three, 2)
  testthat::expect_identical(names(two$documents), names(three$documents))
  testthat::expect_identical(two$documents$document_id, three$documents$document_id)
  testthat::expect_identical(two$documents$segment, three$documents$segment)
  testthat::expect_identical(two$documents$label, two$topics$label[two$documents$topic])
  testthat::expect_identical(two$settings$segment, "sentence")
  testthat::expect_true("label" %in% names(two$terms))
})

testthat::test_that("max_tokens caps the fitted segments and is recorded", {
  segments <- segment(segment_fit_documents(), level = "sentence", max_tokens = 3)
  # alternate the two axes so every capped segment has a unit-norm embedding
  parity <- seq_len(nrow(segments)) %% 2
  model <- topics(
    segment_fit_documents(),
    n_topics = 2,
    segment = "sentence",
    max_tokens = 3,
    embeddings = cbind(parity, 1 - parity),
    n_terms = 3
  )
  testthat::expect_identical(model$documents$text, segments$text)
  testthat::expect_true(all(lengths(strsplit(model$documents$text, " ")) <= 3L))
  testthat::expect_identical(model$settings$max_tokens, 3L)
  # predict re-applies the cap, counting words when no model is involved
  prediction <- predict(
    model,
    "one two three four five six.",
    embeddings = rbind(c(1, 0), c(0, 1))
  )
  testthat::expect_identical(nrow(prediction), 2L)
})

testthat::test_that("segment options are refused where they cannot apply", {
  text <- c("Cats chase mice", "Dogs chase balls", "Stocks and bonds trade")
  embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1))
  testthat::expect_error(
    topics(text, 2, embeddings = embeddings, max_tokens = 5),
    "apply only when segment"
  )
  testthat::expect_error(
    topics(text, 2, embeddings = embeddings, merge_below = 2),
    "apply only when segment"
  )
  testthat::expect_error(
    topic_corpus(text, embeddings = embeddings, min_content = 0.5),
    "apply only when segment"
  )
  # embeddings must follow the segments
  testthat::expect_error(
    topics(segment_fit_documents(), 2, segment = "sentence", embeddings = segment_fit_embeddings()[1:3, ]),
    "8 segments were produced but 3 rows"
  )
  # a prepared corpus owns its segmentation
  corpus <- topic_corpus(segment_fit_documents(), segment = "sentence", embeddings = segment_fit_embeddings())
  testthat::expect_error(topics(corpus, 2, segment = "clause"), "fixed by a prepared topic_corpus")
  testthat::expect_error(topic_corpus(corpus, segment = "clause"), "fixed by a prepared topic_corpus")
  testthat::expect_error(compare_topics(corpus, n_topics = 2:3, segment = "clause"), "fixed by a prepared topic_corpus")
})

testthat::test_that("select_topics is a deprecated alias of compare_topics", {
  text <- c("Cats chase mice", "Dogs chase balls", "Stocks and bonds trade", "Markets price shares")
  embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
  new <- compare_topics(text, n_topics = 2:3, embeddings = embeddings, n_terms = 3)
  testthat::expect_warning(
    old <- select_topics(text, n_topics = 2:3, embeddings = embeddings, n_terms = 3),
    class = "deprecatedWarning"
  )
  testthat::expect_identical(old, new)
})

level_documents <- function() {
  c(
    "Cats chase mice. Stocks and bonds trade.",
    "Dogs chase balls. Markets price shares.",
    "Kittens nap in sunshine. Banks report profit."
  )
}

level_embeddings <- function() {
  list(
    document = rbind(c(0.7, 0.7), c(0.6, 0.8), c(0.8, 0.6)),
    sentence = rbind(
      c(1, 0), c(0, 1), c(0.9, 0.1), c(0.1, 0.9), c(0.95, 0.05), c(0.05, 0.95)
    )
  )
}

testthat::test_that("compare_topics compares several segment levels in one table", {
  levels <- compare_topics(
    level_documents(),
    n_topics = 2,
    segment = c("document", "sentence"),
    embeddings = level_embeddings(),
    n_terms = 2
  )
  testthat::expect_s3_class(levels, "sbert_topic_sweep")
  testthat::expect_identical(
    names(levels),
    c("segment", "n_topics", "coherence", "topic_diversity", "explained")
  )
  testthat::expect_identical(levels$segment, c("document", "sentence"))
  # each level's row is the single-level comparison of that level
  sentence_only <- compare_topics(
    level_documents(),
    n_topics = 2,
    segment = "sentence",
    embeddings = level_embeddings()$sentence,
    n_terms = 2
  )
  testthat::expect_equal(
    as.data.frame(subset(levels, segment == "sentence", select = -segment)),
    as.data.frame(sentence_only),
    ignore_attr = TRUE
  )
  # fitted() needs the level and hands back a model of that level
  by_level <- fitted(levels, n_topics = 2, segment = "sentence")
  testthat::expect_identical(by_level$settings$segment, "sentence")
  testthat::expect_identical(nrow(by_level$documents), 6L)
  testthat::expect_identical(
    fitted(levels, n_topics = 2, segment = "document")$settings$segment,
    "document"
  )
  testthat::expect_error(fitted(levels, n_topics = 2), "several segment levels")
  testthat::expect_error(fitted(sentence_only, 2, segment = "sentence"), "single segment level")
  testthat::expect_snapshot(print(levels))
})

testthat::test_that("several levels need per-level embeddings and raw text", {
  testthat::expect_error(
    compare_topics(
      level_documents(),
      n_topics = 2,
      segment = c("document", "sentence"),
      embeddings = level_embeddings()$sentence
    ),
    "list of matrices named by level"
  )
  testthat::expect_error(
    compare_topics(level_documents(), n_topics = 2, embeddings = level_embeddings()),
    "only for comparing several segment levels"
  )
  corpus <- topic_corpus(level_documents(), embeddings = level_embeddings()$document)
  testthat::expect_error(
    compare_topics(corpus, n_topics = 2, segment = c("document", "sentence")),
    "fixes one segmentation"
  )
})

testthat::test_that("a multi-level comparison plots one line per level", {
  levels <- compare_topics(
    level_documents(),
    n_topics = 2,
    segment = c("document", "sentence"),
    embeddings = level_embeddings(),
    n_terms = 2
  )
  path <- tempfile(fileext = ".png")
  grDevices::png(path, width = 1200, height = 420)
  testthat::expect_silent(plot(levels))
  grDevices::dev.off()
  testthat::expect_true(file.exists(path))
})

testthat::test_that("a comparison draws one fit report per level", {
  documents <- c(level_documents(), "Cats purr softly. Bonds yield less.")
  embeddings <- list(
    document = rbind(level_embeddings()$document, c(0.75, 0.65)),
    sentence = rbind(level_embeddings()$sentence, c(1, 0.1), c(0.1, 1))
  )
  levels <- compare_topics(
    documents,
    n_topics = 2:3,
    segment = c("document", "sentence"),
    embeddings = embeddings,
    n_terms = 2
  )
  testthat::expect_error(plot(levels, type = "fit"), "pass n_topics")
  pages <- tempfile("fit-")
  dir.create(pages)
  grDevices::png(file.path(pages, "page-%02d.png"), width = 1000, height = 600)
  testthat::expect_silent(
    plot(levels, type = "fit", n_topics = 2, n_terms = 2, n_representatives = 2)
  )
  grDevices::dev.off()
  # one figure per level
  testthat::expect_identical(length(list.files(pages, pattern = "^page-")), 2L)
  testthat::expect_error(
    plot(levels, type = "fit", n_topics = 2, segment = "phrase"),
    "should be one of"
  )
})
