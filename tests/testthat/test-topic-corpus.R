local_fixture <- function() {
  readRDS(system.file("extdata", "feedback_embeddings.rds", package = "sbert"))
}
model_surfaces <- function(m) {
  m[c("documents", "topics", "terms", "representatives", "centers")]
}

testthat::test_that("topics(corpus) is byte-identical to topics(text, embeddings)", {
  fx <- local_fixture()
  corpus <- topic_corpus(fx$text, embeddings = fx$embeddings)
  for (k in c(4L, 6L, 8L)) {
    direct <- topics(fx$text, n_topics = k, embeddings = fx$embeddings)
    reused <- topics(corpus, n_topics = k)
    testthat::expect_identical(model_surfaces(reused), model_surfaces(direct))
  }
})

testthat::test_that("select_topics on a corpus matches select_topics on raw text", {
  fx <- local_fixture()
  corpus <- topic_corpus(fx$text, embeddings = fx$embeddings)
  raw <- select_topics(fx$text, n_topics = c(4, 6, 8), embeddings = fx$embeddings, measure = "npmi")
  via <- select_topics(corpus, n_topics = c(4, 6, 8), measure = "npmi")
  testthat::expect_identical(as.data.frame(raw), as.data.frame(via))
  testthat::expect_identical(
    lapply(attr(raw, "models"), model_surfaces),
    lapply(attr(via, "models"), model_surfaces)
  )
})

testthat::test_that("topic_corpus carries embedding source and settings", {
  fx <- local_fixture()
  corpus <- topic_corpus(fx$text, embeddings = fx$embeddings, min_token_length = 3L)
  testthat::expect_s3_class(corpus, "sbert_topic_corpus")
  testthat::expect_identical(length(corpus$text), length(fx$text))
  testthat::expect_identical(corpus$settings$min_token_length, 3L)
  testthat::expect_identical(corpus$model$id, "precomputed embeddings")
  # the cached tokens are what topics() would compute in place
  testthat::expect_identical(
    corpus$token_lists,
    sbert:::tokenize_topic_documents(unname(fx$text), default_stop_words(), 3L)
  )
})

testthat::test_that("parallel tokenization is byte-identical to serial", {
  words <- c(
    "alpha", "beta", "gamma", "delta", "epsilon", "zeta",
    "café", "東京", "isn't", "o'clock"
  )
  docs <- vapply(
    seq_len(2500L),
    function(i) paste(words[((i + 0:5) %% length(words)) + 1L], collapse = " "),
    character(1)
  )
  serial <- sbert:::tokenize_topic_documents(docs, default_stop_words(), 2L, cores = 1L)
  parallelized <- sbert:::tokenize_topic_documents(docs, default_stop_words(), 2L, cores = 2L)
  testthat::expect_identical(serial, parallelized)
})

testthat::test_that("a prepared corpus refuses conflicting model or embeddings", {
  fx <- local_fixture()
  corpus <- topic_corpus(fx$text, embeddings = fx$embeddings)
  testthat::expect_error(
    topics(corpus, n_topics = 6, embeddings = fx$embeddings),
    "topic_corpus"
  )
  testthat::expect_error(
    topics(corpus, n_topics = 6, model = "all-MiniLM-L6-v2"),
    "topic_corpus"
  )
  # passing a corpus back to topic_corpus() returns it unchanged
  testthat::expect_identical(topic_corpus(corpus), corpus)
})
