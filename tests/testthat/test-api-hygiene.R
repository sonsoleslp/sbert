# Tidy accessors, summaries, classed conditions, and convergence reporting.

feedback_model <- function(...) {
  corpus <- utils::head(
    dedupe(feedback_translations, column = "translation"),
    600L
  )
  topics(
    corpus,
    n_topics = 6,
    column = "translation",
    embeddings = feedback_embeddings,
    ...
  )
}

toy_text <- c(
  "Cats chase mice", "Dogs chase balls", "Kittens nap in sunshine",
  "Stocks and bonds trade", "Markets price shares", "Banks report profit"
)
toy_embeddings <- rbind(
  c(1, 0), c(0.95, 0.05), c(0.9, 0.1),
  c(0, 1), c(0.05, 0.95), c(0.1, 0.9)
)

testthat::test_that("`%||%` is defined in the namespace for R < 4.4", {
  # Base R gained `%||%` in 4.4.0; DESCRIPTION supports R >= 4.1.0.
  namespace <- asNamespace("sbert")
  testthat::expect_true(exists("%||%", envir = namespace, inherits = FALSE))
  operator <- get("%||%", envir = namespace, inherits = FALSE)
  testthat::expect_identical(operator(NULL, "b"), "b")
  testthat::expect_identical(operator("a", "b"), "a")
})

testthat::test_that("dedupe() on a data frame matches the vector form and keeps columns", {
  frame <- data.frame(
    text = c("a", "b", "a", NA, "  ", "c", "b"),
    group = c("x", "y", "z", "w", "v", "u", "t"),
    stringsAsFactors = FALSE
  )
  result <- dedupe(frame, column = "text")
  testthat::expect_identical(names(result), c("text", "group", "n"))
  testthat::expect_identical(result$text, c("a", "b", "c"))
  testthat::expect_identical(result$group, c("x", "y", "u"))
  testthat::expect_identical(result$n, c(2L, 2L, 1L))
  # Invariant: the counts add up to the usable rows, as for a vector.
  testthat::expect_identical(sum(result$n), 5L)
  vector_form <- dedupe(frame$text)
  testthat::expect_identical(vector_form$text, result$text)
  testthat::expect_identical(vector_form$n, result$n)

  full <- dedupe(feedback_translations, column = "translation")
  testthat::expect_identical(full$translation, dedupe(feedback_translations$translation)$text)
  testthat::expect_identical(sum(full$n), nrow(feedback_translations))
})

testthat::test_that("dedupe() raises classed errors on bad input", {
  frame <- data.frame(text = c("a", "b"), n = 1:2)
  testthat::expect_error(dedupe(frame), class = "sbert_bad_input")
  testthat::expect_error(dedupe(frame, column = "missing"), class = "sbert_bad_input")
  testthat::expect_error(dedupe(frame, column = "text"), class = "sbert_bad_input")
  testthat::expect_error(dedupe(c("a", "b"), column = "text"), class = "sbert_bad_input")
  testthat::expect_error(dedupe(c(NA, " ")), class = "sbert_error")
})

testthat::test_that("feedback_embeddings is aligned with the deduplicated corpus", {
  testthat::expect_identical(dim(feedback_embeddings), c(600L, 384L))
  norms <- sqrt(rowSums(feedback_embeddings^2))
  testthat::expect_true(all(abs(norms - 1) < 1e-3))
  model <- feedback_model()
  # The bundled six-topic model is the one the golden fixture locks.
  golden <- readRDS(testthat::test_path("fixtures", "topic_model_golden.rds"))
  testthat::expect_identical(model$documents$topic, golden$topic)
})

testthat::test_that("topic_sizes(weights = <column>) equals the vector form", {
  model <- feedback_model()
  corpus <- utils::head(dedupe(feedback_translations, column = "translation"), 600L)
  by_column <- topic_sizes(model, weights = "n")
  by_vector <- topic_sizes(model, weights = corpus$n)
  testthat::expect_identical(by_column, by_vector)
  testthat::expect_equal(sum(by_column$weighted_share), 1)
  testthat::expect_identical(sum(by_column$n_weighted), as.numeric(sum(corpus$n)))
  testthat::expect_error(topic_sizes(model, weights = "nope"), class = "sbert_bad_input")
})

testthat::test_that("topic_sizes(weights = <column>, by = 'document') counts each document once", {
  documents <- data.frame(
    text = c("Cats chase mice. Stocks and bonds trade.",
             "Dogs chase balls. Markets price shares."),
    n = c(10, 1)
  )
  model <- topics(
    documents, 2,
    column = "text",
    segment = "sentence",
    embeddings = rbind(c(1, 0), c(0, 1), c(0.9, 0.1), c(0.1, 0.9))
  )
  sizes <- topic_sizes(model, weights = "n", by = "document")
  # Each topic holds one sentence of each document: weights 10 + 1.
  testthat::expect_identical(sizes$n_weighted, c(11, 11))
  segment_sizes <- topic_sizes(model, weights = "n", by = "segment")
  testthat::expect_identical(segment_sizes$n_weighted, c(11, 11))
})

testthat::test_that("as.data.frame() reads every table of a topic model", {
  model <- feedback_model()
  documents <- as.data.frame(model)
  testthat::expect_s3_class(documents, "data.frame")
  testthat::expect_identical(nrow(documents), 600L)
  testthat::expect_true(all(c("document_id", "text", "topic", "label", "distance",
                              "feedback", "n") %in% names(documents)))
  testthat::expect_identical(as.data.frame(model, what = "topics"), model$topics)
  testthat::expect_identical(nrow(as.data.frame(model, what = "terms")), nrow(model$terms))
  testthat::expect_identical(
    nrow(as.data.frame(model, what = "representatives")),
    nrow(model$representatives)
  )
  testthat::expect_error(as.data.frame(model, what = "centers"))
})

testthat::test_that("as.data.frame() reads hierarchies and corpora", {
  model <- topics(toy_text, 3, embeddings = toy_embeddings, n_terms = 3)
  tree <- topic_hierarchy(model)
  merges <- as.data.frame(tree)
  testthat::expect_identical(names(merges), c("step", "height", "left", "right"))
  testthat::expect_identical(nrow(merges), 2L)

  corpus <- topic_corpus(toy_text, embeddings = toy_embeddings)
  units <- as.data.frame(corpus)
  testthat::expect_identical(units$text, toy_text)
  testthat::expect_identical(units$document_id, seq_along(toy_text))

  frame <- data.frame(body = toy_text, year = 2020:2025)
  segmented <- topic_corpus(
    data.frame(body = c("One. Two.", "Three. Four."), year = 1:2),
    column = "body",
    segment = "sentence",
    embeddings = rbind(c(1, 0), c(0, 1), c(1, 0.1), c(0.1, 1))
  )
  segmented_units <- as.data.frame(segmented)
  testthat::expect_identical(segmented_units$document_id, c(1L, 1L, 2L, 2L))
  testthat::expect_identical(segmented_units$year, c(1L, 1L, 2L, 2L))
  testthat::expect_true("segment" %in% names(segmented_units))
  testthat::expect_identical(as.data.frame(topic_corpus(frame, column = "body",
    embeddings = toy_embeddings))$year, 2020:2025)
})

testthat::test_that("summary() of a topic model returns an object and prints only on print", {
  model <- topics(toy_text, 2, embeddings = toy_embeddings, n_terms = 3)
  testthat::expect_silent(quality <- summary(model))
  testthat::expect_s3_class(quality, "summary.sbert_topic_model")
  testthat::expect_identical(
    names(quality),
    c("topic", "label", "n_documents", "proportion", "coherence")
  )
  testthat::expect_output(print(quality), "Semantic topic model summary")
  testthat::expect_output(print(quality), "topic diversity:")
  plain <- as.data.frame(quality)
  testthat::expect_identical(class(plain), "data.frame")
})

testthat::test_that("summary() of a sweep reports the most coherent count per level", {
  comparison <- compare_topics(toy_text, n_topics = 2:3, embeddings = toy_embeddings)
  overview <- summary(comparison)
  testthat::expect_s3_class(overview, "summary.sbert_topic_sweep")
  testthat::expect_identical(nrow(overview), 1L)
  table <- as.data.frame(comparison)
  testthat::expect_identical(
    overview$best_n_topics,
    as.integer(table$n_topics[which.max(table$coherence)])
  )
  testthat::expect_identical(overview$segment, "document")
  testthat::expect_true(overview$all_converged)
  testthat::expect_output(print(overview), "highest mean npmi coherence")
})

testthat::test_that("summary() of a hierarchy gives each topic its nearest neighbour", {
  model <- topics(toy_text, 3, embeddings = toy_embeddings, n_terms = 3)
  tree <- topic_hierarchy(model)
  neighbours <- summary(tree)
  testthat::expect_s3_class(neighbours, "summary.sbert_topic_hierarchy")
  testthat::expect_identical(nrow(neighbours), 3L)
  testthat::expect_true(all(neighbours$nearest_topic != neighbours$topic))
  # Calibration: the reported distance is the cosine distance between the
  # normalized centers, computed by hand.
  centers <- model$centers / sqrt(rowSums(model$centers^2))
  hand <- 1 - tcrossprod(centers)
  testthat::expect_equal(
    neighbours$distance,
    hand[cbind(neighbours$topic, neighbours$nearest_topic)],
    tolerance = 1e-12
  )
  # Invariant: the first merge joins the closest pair at that pair's distance.
  testthat::expect_equal(min(neighbours$distance), min(neighbours$merge_height))
})

testthat::test_that("topic_similarity(tidy = TRUE) is the long form of the matrix", {
  x <- rbind(a = c(1, 0), b = c(0, 1), c = c(1, 1))
  wide <- topic_similarity(x)
  long <- topic_similarity(x, tidy = TRUE)
  testthat::expect_identical(names(long), c("from", "to", "similarity"))
  testthat::expect_identical(nrow(long), 9L)
  testthat::expect_equal(long$similarity, as.vector(unname(wide)))
  testthat::expect_equal(
    long$similarity[long$from == "a" & long$to == "c"],
    1 / sqrt(2)
  )
  unnamed <- topic_similarity(unname(x), c(1, 0), tidy = TRUE)
  testthat::expect_identical(unnamed$from, 1:3)
  testthat::expect_identical(unnamed$to, rep(1L, 3L))
  testthat::expect_error(
    topic_similarity(matrix(1, 1L, 2L), matrix(1, 1L, 3L)),
    class = "sbert_dimension_mismatch"
  )
})

testthat::test_that("user-facing errors carry sbert classes", {
  model <- topics(toy_text, 2, embeddings = toy_embeddings, keep_embeddings = FALSE)
  testthat::expect_error(reduce_topics(model, 2), class = "sbert_bad_input")
  testthat::expect_error(
    representatives(model),
    class = "sbert_no_embeddings"
  )
  testthat::expect_error(
    predict(model, "new", embeddings = rbind(c(1, 0, 0))),
    class = "sbert_dimension_mismatch"
  )
  testthat::expect_error(
    topics(data.frame(x = toy_text), 2, embeddings = toy_embeddings),
    class = "sbert_bad_input"
  )
  testthat::expect_error(topics(toy_text, 2, embeddings = toy_embeddings,
                                model = "all-MiniLM-L6-v2"),
                         class = "sbert_error")
  comparison <- compare_topics(toy_text, n_topics = 2:3, embeddings = toy_embeddings,
                               keep_models = FALSE)
  testthat::expect_error(fitted(comparison, n_topics = 2), class = "sbert_no_fitted_model")
  testthat::expect_error(model_status(model = "no-such-model"), class = "sbert_unknown_model")
})

testthat::test_that("k-means non-convergence is reported and recorded", {
  converged <- feedback_model()
  testthat::expect_true(converged$diagnostics$converged)
  testthat::expect_identical(converged$diagnostics$warnings, character())

  testthat::expect_warning(
    capped <- feedback_model(iter_max = 2),
    class = "sbert_no_converge"
  )
  testthat::expect_false(capped$diagnostics$converged)
  testthat::expect_identical(capped$diagnostics$iterations, 2L)
  testthat::expect_match(capped$diagnostics$warnings, "did not converge")
  testthat::expect_output(print(summary(capped)), "did not converge")

  corpus <- utils::head(dedupe(feedback_translations, column = "translation"), 600L)
  warned <- 0L
  sweep <- withCallingHandlers(
    compare_topics(corpus, column = "translation", n_topics = c(4, 6),
                   embeddings = feedback_embeddings, iter_max = 2),
    sbert_no_converge = function(condition) {
      warned <<- warned + 1L
      invokeRestart("muffleWarning")
    }
  )
  testthat::expect_identical(warned, 2L)
  testthat::expect_identical(as.data.frame(sweep)$converged, c(FALSE, FALSE))
  testthat::expect_false(summary(sweep)$all_converged)
})

testthat::test_that("fixed-seed fits are marked converged", {
  model <- topics(
    toy_text, 2,
    embeddings = toy_embeddings,
    seeds = c("pets", "money"),
    seed_embeddings = rbind(c(1, 0), c(0, 1)),
    fixed_seeds = TRUE
  )
  testthat::expect_true(model$diagnostics$converged)
})

testthat::test_that("cache_size() works with its default cache directory", {
  # The default used to be `cache_dir = cache_dir()`, a self-reference that
  # failed with "promise already under evaluation".
  testthat::skip_if_not_installed("withr")
  root <- file.path(tempdir(), "sbert-default-cache")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  withr::local_envvar(R_USER_CACHE_DIR = root)
  testthat::expect_identical(cache_size(), 0)
  dir.create(cache_dir(), recursive = TRUE)
  writeLines("abc", file.path(cache_dir(), "file.txt"))
  testthat::expect_identical(cache_size(), cache_size(cache_dir()))
  testthat::expect_true(cache_size() > 0)
})

testthat::test_that("topic_similarity(top =) returns each row's nearest neighbors in order", {
  x <- rbind(a = c(1, 0), b = c(0.9, 0.1), c = c(0, 1), d = c(0.2, 0.8))
  nearest <- topic_similarity(x, tidy = TRUE, top = 2)
  testthat::expect_identical(names(nearest), c("from", "to", "similarity", "rank"))
  testthat::expect_identical(nrow(nearest), 8L)
  # No row is its own neighbor, and similarities fall within each row.
  testthat::expect_false(any(nearest$from == nearest$to))
  testthat::expect_identical(nearest$to[nearest$from == "a"], c("b", "d"))
  ordered <- tapply(nearest$similarity, nearest$from, function(v) !is.unsorted(rev(v)))
  testthat::expect_true(all(ordered))
  # Calibration against the full matrix: the top neighbor is the row maximum.
  wide <- topic_similarity(x)
  diag(wide) <- -Inf
  testthat::expect_equal(
    nearest$similarity[nearest$rank == 1L],
    unname(apply(wide, 1L, max))
  )
  query <- topic_similarity(c(1, 0.05), x, tidy = TRUE, top = 1)
  testthat::expect_identical(query$to, "a")
  testthat::expect_error(topic_similarity(x, top = 2), class = "sbert_bad_input")
})

testthat::test_that("name_topics() errors inherit sbert_error", {
  model <- topics(toy_text, 2, embeddings = toy_embeddings, n_terms = 3)
  testthat::expect_error(name_topics(model, "only one"), class = "sbert_bad_topic_names")
  testthat::expect_error(name_topics(model, "only one"), class = "sbert_error")
})

testthat::test_that("between/total SS is the partition's share after merging or with fixed seeds", {
  corpus <- utils::head(dedupe(feedback_translations, column = "translation"), 600L)
  partition_ss <- function(model, embeddings) {
    normalized <- embeddings / sqrt(rowSums(embeddings^2))
    topic <- as.data.frame(model)$topic
    within <- sum(vapply(unique(topic), function(k) {
      rows <- normalized[topic == k, , drop = FALSE]
      sum(sweep(rows, 2L, colMeans(rows))^2)
    }, numeric(1)))
    total <- sum(sweep(normalized, 2L, colMeans(normalized))^2)
    c(within = within, explained = 1 - within / total)
  }
  fine <- topics(corpus, 15, column = "translation", embeddings = feedback_embeddings)
  merged <- reduce_topics(fine, 6)
  hand <- partition_ss(merged, feedback_embeddings)
  testthat::expect_equal(merged$diagnostics$tot_withinss, unname(hand[["within"]]))
  explained <- attr(summary(merged), "overview")$explained
  testthat::expect_equal(explained, unname(hand[["explained"]]))
  testthat::expect_true(explained >= 0 && explained <= 1)

  seeds <- rbind(colMeans(utils::head(feedback_embeddings, 50)),
                 colMeans(utils::tail(feedback_embeddings, 50)))
  zero_shot <- topics(corpus, 2, column = "translation", embeddings = feedback_embeddings,
                      seeds = c("a", "b"), seed_embeddings = seeds, fixed_seeds = TRUE)
  seeded_explained <- attr(summary(zero_shot), "overview")$explained
  testthat::expect_true(seeded_explained >= 0 && seeded_explained <= 1)
  testthat::expect_equal(
    seeded_explained,
    unname(partition_ss(zero_shot, feedback_embeddings)[["explained"]])
  )
})
