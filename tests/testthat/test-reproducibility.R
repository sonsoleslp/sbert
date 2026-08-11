# Reproducibility lock. topics() must be bit-identical: the same inputs must
# always produce the same model, byte for byte, across reruns and releases. The
# golden reference in fixtures/topic_model_golden.rds was generated from the
# shipped feedback embeddings; regenerate it ONLY when a change to the modeled
# output is deliberate and reviewed (see data-raw or the test comment below).
testthat::test_that("topics() output is bit-identical to the golden reference", {
  embeddings_fixture <- readRDS(
    system.file("extdata", "feedback_embeddings.rds", package = "sbert")
  )
  golden <- readRDS(
    testthat::test_path("fixtures", "topic_model_golden.rds")
  )

  model <- topics(
    embeddings_fixture$text,
    n_topics = 6,
    embeddings = embeddings_fixture$embeddings
  )

  # Every modeled surface, compared with zero tolerance.
  testthat::expect_identical(model$documents$topic, golden$topic)
  testthat::expect_identical(model$documents$distance, golden$distance)
  testthat::expect_identical(model$topics, golden$topics)
  testthat::expect_identical(model$terms, golden$terms)
  testthat::expect_identical(model$representatives, golden$representatives)
  testthat::expect_identical(model$centers, golden$centers)
})

testthat::test_that("topics() is identical across independent reruns", {
  embeddings_fixture <- readRDS(
    system.file("extdata", "feedback_embeddings.rds", package = "sbert")
  )
  run <- function() {
    m <- topics(
      embeddings_fixture$text,
      n_topics = 6,
      embeddings = embeddings_fixture$embeddings
    )
    m[c("documents", "topics", "terms", "representatives", "centers")]
  }
  testthat::expect_identical(run(), run())
})
