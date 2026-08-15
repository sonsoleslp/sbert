# The cache trades recomputation for a lookup, so the only thing that matters is
# that a hit is indistinguishable from a miss. Every test here compares cached
# output against freshly encoded output with zero tolerance, and checks that any
# setting able to change an embedding also changes its key.

deterministic_encoder <- function() {
  # A stand-in whose output depends only on the text, so a cache hit and a fresh
  # encode must agree exactly. Counts calls to prove reuse actually happened.
  calls <- new.env(parent = emptyenv())
  calls$rows <- 0L
  list(
    env = calls,
    fun = function(model, text, normalize) {
      calls$rows <- calls$rows + length(text)
      cbind(nchar(text), vapply(text, function(x) sum(utf8ToInt(x)), numeric(1), USE.NAMES = FALSE))
    }
  )
}

testthat::test_that("a cached run reproduces an uncached run exactly", {
  model <- fake_sbert_model()
  text <- c("alpha", "beta gamma", "delta", "epsilon zeta eta")
  store <- file.path(tempdir(), "cache-exact.rds")
  unlink(store)

  encoder <- deterministic_encoder()
  testthat::local_mocked_bindings(encode_sbert_batch = encoder$fun, .package = "sbert")

  plain <- encode(text, model, batch_size = 2L)
  cold <- encode(text, model, batch_size = 2L, cache = store)
  warm <- encode(text, model, batch_size = 2L, cache = store)

  testthat::expect_equal(cold, plain, tolerance = 0)
  testthat::expect_equal(warm, plain, tolerance = 0)
  testthat::expect_true(file.exists(store))
  unlink(store)
})

testthat::test_that("a warm cache encodes nothing at all", {
  model <- fake_sbert_model()
  text <- c("one", "two", "three", "four", "five")
  store <- file.path(tempdir(), "cache-hits.rds")
  unlink(store)

  encoder <- deterministic_encoder()
  testthat::local_mocked_bindings(encode_sbert_batch = encoder$fun, .package = "sbert")

  encode(text, model, cache = store)
  after_cold <- encoder$env$rows
  encode(text, model, cache = store)

  testthat::expect_identical(after_cold, 5L)
  testthat::expect_identical(encoder$env$rows, 5L)  # nothing re-encoded
  unlink(store)
})

testthat::test_that("only changed documents are re-encoded", {
  model <- fake_sbert_model()
  original <- c("aa", "bb", "cc", "dd", "ee")
  edited <- c("aa", "bb", "CHANGED", "dd", "ALSO CHANGED")
  store <- file.path(tempdir(), "cache-partial.rds")
  unlink(store)

  encoder <- deterministic_encoder()
  testthat::local_mocked_bindings(encode_sbert_batch = encoder$fun, .package = "sbert")

  encode(original, model, cache = store)
  baseline_rows <- encoder$env$rows
  result <- encode(edited, model, cache = store)

  testthat::expect_identical(baseline_rows, 5L)
  testthat::expect_identical(encoder$env$rows - baseline_rows, 2L)
  testthat::expect_equal(result, encode(edited, model), tolerance = 0)
  unlink(store)
})

testthat::test_that("reordering and subsetting a corpus costs no encoding", {
  model <- fake_sbert_model()
  text <- c("aa", "bb", "cc", "dd", "ee")
  store <- file.path(tempdir(), "cache-reorder.rds")
  unlink(store)

  encoder <- deterministic_encoder()
  testthat::local_mocked_bindings(encode_sbert_batch = encoder$fun, .package = "sbert")

  encode(text, model, cache = store)
  used <- encoder$env$rows

  reversed <- rev(text)
  shuffled <- encode(reversed, model, cache = store)
  subset_rows <- encode(text[c(2L, 4L)], model, cache = store)

  testthat::expect_identical(encoder$env$rows, used)   # no new encoding at all
  testthat::expect_equal(shuffled, encode(reversed, model), tolerance = 0)
  testthat::expect_equal(subset_rows, encode(text[c(2L, 4L)], model), tolerance = 0)
  unlink(store)
})

testthat::test_that("duplicated documents are encoded once but returned per row", {
  model <- fake_sbert_model()
  text <- c("same", "other", "same", "same")
  store <- file.path(tempdir(), "cache-dupes.rds")
  unlink(store)

  encoder <- deterministic_encoder()
  testthat::local_mocked_bindings(encode_sbert_batch = encoder$fun, .package = "sbert")

  result <- encode(text, model, cache = store)

  testthat::expect_identical(encoder$env$rows, 2L)       # "same" and "other"
  testthat::expect_identical(nrow(result), 4L)
  testthat::expect_equal(result[1L, ], result[3L, ], tolerance = 0)
  testthat::expect_equal(result[1L, ], result[4L, ], tolerance = 0)
  unlink(store)
})

testthat::test_that("keys separate anything that can change an embedding", {
  model <- fake_sbert_model()
  text <- c("alpha", "beta")
  base <- sbert:::embedding_cache_keys(text, model, normalize = TRUE)

  testthat::expect_length(base, 2L)
  testthat::expect_false(base[[1]] == base[[2]])

  # normalize changes values, so it must change the key
  testthat::expect_false(
    identical(base, sbert:::embedding_cache_keys(text, model, normalize = FALSE))
  )

  other <- model
  for (field in c("id", "revision", "pooling")) {
    changed <- model
    changed[[field]] <- paste0(model[[field]], "-x")
    testthat::expect_false(
      identical(base, sbert:::embedding_cache_keys(text, changed, normalize = TRUE)),
      info = field
    )
  }
  changed <- model
  changed$dimension <- 99L
  testthat::expect_false(
    identical(base, sbert:::embedding_cache_keys(text, changed, normalize = TRUE))
  )
})

testthat::test_that("a different model does not reuse another model's rows", {
  text <- c("alpha", "beta")
  store <- file.path(tempdir(), "cache-models.rds")
  unlink(store)

  first <- fake_sbert_model()
  second <- fake_sbert_model()
  second$id <- "test/other-model"
  second$revision <- "other-revision"

  encoder <- deterministic_encoder()
  testthat::local_mocked_bindings(encode_sbert_batch = encoder$fun, .package = "sbert")

  encode(text, first, cache = store)
  used <- encoder$env$rows
  encode(text, second, cache = store)

  testthat::expect_identical(used, 2L)
  testthat::expect_identical(encoder$env$rows - used, 2L)  # re-encoded, not reused
  unlink(store)
})

testthat::test_that("a corrupt or foreign cache is rebuilt rather than trusted", {
  model <- fake_sbert_model()
  text <- c("alpha", "beta")
  store <- file.path(tempdir(), "cache-corrupt.rds")

  encoder <- deterministic_encoder()
  testthat::local_mocked_bindings(encode_sbert_batch = encoder$fun, .package = "sbert")

  writeLines("this is not an rds file", store)
  testthat::expect_warning(result <- encode(text, model, cache = store))
  testthat::expect_equal(result, encode(text, model), tolerance = 0)

  # right structure, wrong embedding dimension
  saveRDS(
    list(version = 1L, key = c("a", "b"), embeddings = matrix(0, 2L, 99L)),
    store
  )
  testthat::expect_warning(rebuilt <- encode(text, model, cache = store))
  testthat::expect_identical(ncol(rebuilt), 2L)
  unlink(store)
})

testthat::test_that("encode validates the cache argument", {
  model <- fake_sbert_model()
  text <- c("one", "two")
  testthat::expect_error(encode(text, model, cache = NA_character_))
  testthat::expect_error(encode(text, model, cache = ""))
  testthat::expect_error(encode(text, model, cache = c("a", "b")))
  testthat::expect_error(encode(text, model, cache = 1L))
})

testthat::test_that("the cache directory is created and writes are atomic", {
  model <- fake_sbert_model()
  nested <- file.path(tempdir(), "cache-nested-dir", "deeper", "store.rds")
  unlink(dirname(dirname(nested)), recursive = TRUE)

  encoder <- deterministic_encoder()
  testthat::local_mocked_bindings(encode_sbert_batch = encoder$fun, .package = "sbert")

  encode(c("alpha", "beta"), model, cache = nested)
  testthat::expect_true(file.exists(nested))
  # no temporary file should survive a completed write
  leftovers <- list.files(dirname(nested), pattern = "\\.tmp", full.names = TRUE)
  testthat::expect_length(leftovers, 0L)
  unlink(dirname(dirname(nested)), recursive = TRUE)
})
