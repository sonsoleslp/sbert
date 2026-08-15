# Regression tests for the two encoding optimizations. Both are performance
# changes, so what matters is that the OUTPUT did not move: pooling must stay
# bit-identical to the sweep()/apply() formulation it replaced, and length
# sorting must return rows in the caller's order.

reference_pool <- function(token_embeddings, attention_mask, normalize, method) {
  # The pre-optimization implementation, kept verbatim as the oracle.
  batch_size <- dim(token_embeddings)[[1L]]
  hidden_size <- dim(token_embeddings)[[3L]]
  if (method == "cls") {
    pooled <- matrix(token_embeddings[, 1L, ], nrow = batch_size, ncol = hidden_size)
  } else {
    masked <- sweep(token_embeddings, c(1L, 2L), attention_mask, `*`)
    pooled <- apply(masked, c(1L, 3L), sum) |>
      matrix(nrow = batch_size, ncol = hidden_size)
    pooled <- pooled / pmax(rowSums(attention_mask), 1e-9)
  }
  if (normalize) {
    pooled <- pooled / pmax(sqrt(rowSums(pooled^2)), 1e-12)
  }
  dimnames(pooled) <- NULL
  pooled
}

right_padded_mask <- function(batch, sequence, lengths) {
  t(vapply(
    lengths,
    function(n) c(rep(1, n), rep(0, sequence - n)),
    numeric(sequence)
  ))
}

testthat::test_that("rowsum pooling is bit-identical to the sweep/apply formulation", {
  set.seed(42)
  batch <- 8L
  sequence <- 16L
  hidden <- 5L
  embeddings <- array(rnorm(batch * sequence * hidden), dim = c(batch, sequence, hidden))
  mask <- right_padded_mask(batch, sequence, sample(2:sequence, batch, replace = TRUE))

  for (normalize in c(TRUE, FALSE)) {
    for (method in c("mean", "cls")) {
      got <- pool(embeddings, mask, normalize = normalize, method = method)
      want <- reference_pool(embeddings, mask, normalize = normalize, method = method)
      testthat::expect_identical(dim(got), dim(want))
      # tolerance = 0: the rewrite must not move a single bit, not merely agree.
      testthat::expect_equal(got, want, tolerance = 0)
    }
  }
})

testthat::test_that("pooling handles a fully masked row and a single-token batch", {
  embeddings <- array(rnorm(1L * 4L * 3L), dim = c(1L, 4L, 3L))
  all_zero <- matrix(0, nrow = 1L, ncol = 4L)
  pooled <- pool(embeddings, all_zero, normalize = FALSE)
  testthat::expect_identical(dim(pooled), c(1L, 3L))
  testthat::expect_false(anyNA(pooled))

  single <- array(rnorm(3L * 1L * 2L), dim = c(3L, 1L, 2L))
  mask <- matrix(1, nrow = 3L, ncol = 1L)
  testthat::expect_equal(
    pool(single, mask, normalize = FALSE),
    reference_pool(single, mask, normalize = FALSE, method = "mean"),
    tolerance = 0
  )
})

testthat::test_that("pool_impl and the exported pool agree", {
  set.seed(7)
  embeddings <- array(rnorm(4L * 6L * 3L), dim = c(4L, 6L, 3L))
  mask <- right_padded_mask(4L, 6L, c(6L, 4L, 2L, 1L))
  testthat::expect_equal(
    sbert:::pool_impl(embeddings, mask, normalize = TRUE, method = "mean"),
    pool(embeddings, mask, normalize = TRUE, method = "mean"),
    tolerance = 0
  )
})

testthat::test_that("pool still rejects malformed input", {
  embeddings <- array(rnorm(2L * 3L * 2L), dim = c(2L, 3L, 2L))
  testthat::expect_error(pool(embeddings, matrix(1, 3L, 2L)))
  testthat::expect_error(pool(embeddings, matrix(2, 2L, 3L)))
  testthat::expect_error(pool(embeddings, matrix(1, 2L, 3L), method = "max"))
})

testthat::test_that("sort_by_length returns rows in the caller's order", {
  # With a deterministic per-text encoder, batch composition cannot change any
  # value, so sorting must reproduce the unsorted result exactly. That isolates
  # the permutation logic from the ~1e-7 float effect a real model would add.
  model <- fake_sbert_model()
  testthat::local_mocked_bindings(
    encode_sbert_batch = function(model, text, normalize) {
      cbind(nchar(text), seq_along(text))
    },
    .package = "sbert"
  )
  text <- c(a = "dddd", b = "b", c = "ccc", d = "aa", e = "eeeee", f = "f")

  plain <- encode(text, model, batch_size = 2L)
  sorted <- encode(text, model, batch_size = 2L, sort_by_length = TRUE)

  testthat::expect_identical(unname(sorted[, 1L]), nchar(unname(text)))
  testthat::expect_identical(rownames(sorted), names(text))
  testthat::expect_identical(dim(sorted), dim(plain))
})

testthat::test_that("sort_by_length handles ties, one element, and empty input", {
  model <- fake_sbert_model()
  testthat::local_mocked_bindings(
    encode_sbert_batch = function(model, text, normalize) {
      cbind(nchar(text), seq_along(text))
    },
    .package = "sbert"
  )

  tied <- c("aa", "bb", "cc", "dd")
  testthat::expect_identical(
    unname(encode(tied, model, batch_size = 2L, sort_by_length = TRUE)[, 1L]),
    nchar(tied)
  )
  testthat::expect_identical(
    nrow(encode("solo", model, sort_by_length = TRUE)),
    1L
  )
  testthat::expect_identical(
    dim(encode(character(), model, sort_by_length = TRUE)),
    c(0L, 2L)
  )
})

testthat::test_that("sort_by_length validates its argument", {
  model <- fake_sbert_model()
  text <- c("one", "two")
  testthat::expect_error(encode(text, model, sort_by_length = NA))
  testthat::expect_error(encode(text, model, sort_by_length = c(TRUE, TRUE)))
  testthat::expect_error(encode(text, model, sort_by_length = "yes"))
})

testthat::test_that("encode stops when inference returns missing values", {
  model <- fake_sbert_model()
  testthat::local_mocked_bindings(
    run_sbert_onnx = function(onnx_model, inputs, token_type_ids = TRUE) {
      list(last_hidden_state = array(
        NA_real_,
        dim = c(nrow(inputs$input_ids), ncol(inputs$input_ids), 2L)
      ))
    },
    .package = "sbert"
  )
  testthat::expect_error(encode("hello", model), "missing or non-finite")
})

testthat::test_that("threads = \"auto\" resolves to a usable positive count", {
  resolved <- sbert:::resolve_inference_threads("auto")
  testthat::expect_type(resolved, "integer")
  testthat::expect_length(resolved, 1L)
  testthat::expect_false(is.na(resolved))
  testthat::expect_gte(resolved, 1L)
  testthat::expect_lte(resolved, 8L)
  # never more than the machine actually has
  logical_cores <- parallel::detectCores(logical = TRUE)
  if (!is.na(logical_cores)) {
    testthat::expect_lte(resolved, max(1L, as.integer(logical_cores)))
  }
})

testthat::test_that("explicit thread counts pass through unchanged", {
  testthat::expect_identical(sbert:::resolve_inference_threads(1L), 1L)
  testthat::expect_identical(sbert:::resolve_inference_threads(4L), 4L)
  testthat::expect_identical(sbert:::resolve_inference_threads(4), 4L)
})

testthat::test_that("detect_performance_cores is bounded and integer", {
  detected <- sbert:::detect_performance_cores()
  testthat::expect_type(detected, "integer")
  testthat::expect_length(detected, 1L)
  testthat::expect_gte(detected, 1L)
  testthat::expect_lte(detected, 8L)
})

testthat::test_that("load_model rejects malformed thread arguments", {
  testthat::expect_error(load_model("all-MiniLM-L6-v2", threads = 0L))
  testthat::expect_error(load_model("all-MiniLM-L6-v2", threads = -2L))
  testthat::expect_error(load_model("all-MiniLM-L6-v2", threads = 2.5))
  testthat::expect_error(load_model("all-MiniLM-L6-v2", threads = "many"))
  testthat::expect_error(load_model("all-MiniLM-L6-v2", threads = c(1L, 2L)))
  testthat::expect_error(load_model("all-MiniLM-L6-v2", threads = NA_integer_))
})

# ---------------------------------------------------------------------------
# Regressions found by adversarial review of the optimization above. Each of
# these was a real defect introduced by moving validation off the hot path.
# ---------------------------------------------------------------------------

testthat::test_that("zero-length sequences keep their batch rows", {
  # rowsum() sees no groups when there are no sequence positions and drops every
  # row; the sweep()/apply() version summed the empty set to zero and kept them.
  empty_sequence <- array(numeric(), dim = c(3L, 0L, 2L))
  empty_mask <- matrix(numeric(), nrow = 3L, ncol = 0L)

  pooled <- pool(empty_sequence, empty_mask, normalize = FALSE)
  testthat::expect_identical(dim(pooled), c(3L, 2L))
  testthat::expect_true(all(pooled == 0))

  normalized <- pool(empty_sequence, empty_mask, normalize = TRUE)
  testthat::expect_identical(dim(normalized), c(3L, 2L))
  testthat::expect_false(anyNA(normalized))
})

testthat::test_that("pool_impl rejects a mask that does not match the batch", {
  # A wrongly shaped ONNX output previously recycled silently and returned the
  # wrong number of rows, breaking input-to-embedding correspondence.
  embeddings <- array(as.numeric(1:6), dim = c(3L, 2L, 1L))
  mismatched <- matrix(1L, nrow = 2L, ncol = 3L)
  testthat::expect_error(
    sbert:::pool_impl(embeddings, mismatched, normalize = FALSE, method = "mean")
  )
  testthat::expect_error(
    sbert:::pool_impl(embeddings, as.vector(mismatched), normalize = FALSE, method = "mean")
  )
})

testthat::test_that("encode rejects infinite inference output, not only NA", {
  # anyNA() does not see Inf. An unmasked Inf pools to Inf; a masked one becomes
  # Inf * 0 = NaN. Both must be refused rather than returned as embeddings.
  model <- fake_sbert_model()
  make_output <- function(value, position) {
    function(onnx_model, inputs, token_type_ids = TRUE) {
      dims <- c(nrow(inputs$input_ids), ncol(inputs$input_ids), 2L)
      hidden <- array(1, dim = dims)
      hidden[[position]] <- value
      list(last_hidden_state = hidden)
    }
  }
  for (value in list(Inf, -Inf, NaN, NA_real_)) {
    testthat::local_mocked_bindings(
      run_sbert_onnx = make_output(value, 1L),
      .package = "sbert"
    )
    testthat::expect_error(encode("hello", model), "missing or non-finite|missing values")
  }
})

testthat::test_that("topic_gamma validates sort_by_length even when embeddings are supplied", {
  # Supplying `embeddings` short-circuits encode(), so encode()'s own validation
  # never runs and a malformed value was accepted in silence.
  text <- c("Cats chase mice", "Dogs chase balls", "Stocks trade", "Markets price shares")
  fitted <- topics(text, 2, embeddings = rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9)))
  mixed <- "Cats chase mice. Stocks trade."
  segment_embeddings <- rbind(c(1, 0), c(0, 1))

  testthat::expect_error(
    topic_gamma(fitted, mixed, embeddings = segment_embeddings, sort_by_length = "yes")
  )
  testthat::expect_error(
    topic_gamma(fitted, mixed, embeddings = segment_embeddings, sort_by_length = NA)
  )
  testthat::expect_error(
    topic_gamma(fitted, mixed, embeddings = segment_embeddings, sort_by_length = c(TRUE, FALSE))
  )
})
