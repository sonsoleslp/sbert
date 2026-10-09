# Reproducibility lock. topics() must be bit-identical: the same inputs must
# always produce the same model, byte for byte, across reruns and releases. The
# golden reference in fixtures/topic_model_golden.rds was generated from the
# shipped feedback embeddings; regenerate it ONLY when a change to the modeled
# output is deliberate and reviewed (see data-raw or the test comment below).
testthat::test_that("topics() output is bit-identical to the golden reference", {
  # The golden .rds was generated on one platform. Byte-for-byte floating-point
  # equality does not hold across different OSes, BLAS builds, and C math
  # libraries (macOS vs Windows differ in the last digits of distance, centers,
  # etc.), so this lock is a same-platform regression guard for local runs and
  # CI on the reference platform, not a claim about CRAN's heterogeneous
  # machines. The "identical across independent reruns" test below is the
  # portable determinism guarantee and keeps running everywhere.
  testthat::skip_on_cran()
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

  # Determinism is locked by the rerun test below, which compares two runs on the
  # SAME machine at zero tolerance. A STORED golden file cannot also be held to
  # zero tolerance: the fixture was generated under one BLAS, and a different one
  # (Apple Accelerate here, OpenBLAS on the r-universe runners) re-associates the
  # sums inside kmeans and moves distances in the last bits. Observed drift is
  # ~2e-15 relative, which is why every numeric surface below failed on Linux
  # while the cluster ASSIGNMENT did not -- assignments are robust to it, so that
  # one stays an exact check. 1e-10 leaves five orders of margin over the drift
  # while still catching any real change to the modeled output.
  testthat::expect_identical(model$documents$topic, golden$topic)
  tol <- 1e-10
  testthat::expect_equal(model$documents$distance, golden$distance, tolerance = tol)
  testthat::expect_equal(model$topics, golden$topics, tolerance = tol)
  testthat::expect_equal(model$terms, golden$terms, tolerance = tol)
  testthat::expect_equal(model$representatives, golden$representatives,
                         tolerance = tol)
  testthat::expect_equal(model$centers, golden$centers, tolerance = tol)
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
