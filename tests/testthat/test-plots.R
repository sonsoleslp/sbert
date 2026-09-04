plots_test_model <- function(keep_embeddings = TRUE) {
  text <- c(
    animals_1 = "Cats chase mice and sleep.",
    animals_2 = "Dogs chase balls and sleep.",
    learning_1 = "Neural networks learn representations.",
    learning_2 = "Machine learning models learn patterns.",
    vehicles_1 = "Bicycles have wheels and pedals.",
    vehicles_2 = "Cars have wheels and engines."
  )
  embeddings <- rbind(
    c(1, 0, 0), c(0.95, 0.05, 0),
    c(0, 1, 0), c(0.05, 0.95, 0),
    c(0, 0, 1), c(0.05, 0, 0.95)
  )
  topics(
    text,
    3L,
    embeddings = embeddings,
    n_terms = 4L,
    keep_embeddings = keep_embeddings
  )
}

testthat::test_that("the palette returns the requested number of colours", {
  colours <- topic_palette(3L)
  testthat::expect_length(colours, 3L)
  testthat::expect_true(all(grepl("^#", colours)))
  testthat::expect_error(topic_palette(0))
})

testthat::test_that("every plot type draws without error and returns the model", {
  model <- plots_test_model()
  temporary_device <- tempfile(fileext = ".pdf")
  grDevices::pdf(temporary_device)
  on.exit(
    {
      grDevices::dev.off()
      unlink(temporary_device)
    },
    add = TRUE
  )

  testthat::expect_identical(plot(model, type = "sizes"), model)
  testthat::expect_identical(plot(model, type = "terms", n_terms = 3L), model)
  testthat::expect_identical(
    plot(model, type = "representatives", n_representatives = 2L),
    model
  )
  testthat::expect_identical(
    plot(model, type = "fit", n_terms = 3L, n_representatives = 2L),
    model
  )
  testthat::expect_identical(
    plot(model, type = "fit", topics = 2L),
    model
  )
  testthat::expect_identical(plot(model, type = "map"), model)
})

testthat::test_that("terms plot accepts metrics and a topic subset", {
  model <- plots_test_model()
  temporary_device <- tempfile(fileext = ".pdf")
  grDevices::pdf(temporary_device)
  on.exit(
    {
      grDevices::dev.off()
      unlink(temporary_device)
    },
    add = TRUE
  )

  for (metric in c("score", "beta", "frequency")) {
    testthat::expect_identical(plot(model, type = "terms", by = metric), model)
  }
  testthat::expect_identical(
    plot(model, type = "terms", by = c("frequency", "score", "beta")),
    model
  )
  testthat::expect_identical(
    plot(model, type = "terms", by = c("frequency", "beta"), topics = 2L),
    model
  )
  testthat::expect_identical(
    plot(model, type = "representatives", topics = c(1L, 3L)),
    model
  )
  for (ty in c("terms", "representatives", "fit")) {
    testthat::expect_identical(plot(model, type = ty, per_topic = TRUE), model)
  }
  testthat::expect_identical(
    plot(model, type = "fit", per_topic = TRUE, topics = c(1L, 2L)),
    model
  )
  testthat::expect_error(plot(model, type = "terms", by = "tfidf"))
  testthat::expect_error(plot(model, type = "terms", topics = 99L))
  testthat::expect_error(plot(model, type = "fit", per_topic = NA))
})

testthat::test_that("representatives plot caps at the retained document count", {
  model <- plots_test_model()
  temporary_device <- tempfile(fileext = ".pdf")
  grDevices::pdf(temporary_device)
  on.exit(
    {
      grDevices::dev.off()
      unlink(temporary_device)
    },
    add = TRUE
  )

  testthat::expect_identical(
    plot(model, type = "representatives", n_representatives = 99L),
    model
  )
  testthat::expect_error(plot(model, type = "representatives", n_representatives = 0))
})

testthat::test_that("the map requires stored embeddings", {
  model <- plots_test_model(keep_embeddings = FALSE)
  temporary_device <- tempfile(fileext = ".pdf")
  grDevices::pdf(temporary_device)
  on.exit(
    {
      grDevices::dev.off()
      unlink(temporary_device)
    },
    add = TRUE
  )

  testthat::expect_error(plot(model, type = "map"), "keep_embeddings")
  testthat::expect_error(plot(model, type = "orbit"))
})

testthat::test_that("term panels tolerate a topic with no surviving terms", {
  # A topic whose documents contain only stop words keeps zero terms after
  # filtering, so terms() returns no rows for it. The bar panels used to hand
  # barplot() an empty vector, which fails with "need finite 'ylim' values".
  text <- c(
    "Cats chase mice and sleep.",
    "Dogs chase balls and sleep.",
    "Neural networks learn representations.",
    "Machine learning models learn patterns.",
    "the and of to",
    "the and of to"
  )
  embeddings <- rbind(
    c(1, 0, 0), c(0.95, 0.05, 0),
    c(0, 1, 0), c(0.05, 0.95, 0),
    c(0, 0, 1), c(0.05, 0, 0.95)
  )
  model <- topics(text, 3L, embeddings = embeddings, n_terms = 4L)
  term_table <- terms(model)
  empty_topic <- setdiff(model$topics$topic, unique(term_table$topic))
  testthat::expect_length(empty_topic, 1L)

  temporary_device <- tempfile(fileext = ".pdf")
  grDevices::pdf(temporary_device)
  on.exit(
    {
      grDevices::dev.off()
      unlink(temporary_device)
    },
    add = TRUE
  )
  testthat::expect_identical(plot(model, type = "terms"), model)
  testthat::expect_identical(
    plot(model, type = "terms", by = c("frequency", "score", "beta")),
    model
  )
  testthat::expect_identical(plot(model, type = "fit"), model)
  testthat::expect_identical(plot(model, type = "fit", per_topic = TRUE), model)
  testthat::expect_identical(
    plot(model, type = "fit", per_topic = TRUE, topics = empty_topic),
    model
  )
  testthat::expect_identical(
    draw_topic_bar_panel(numeric(0), character(0), "empty", "#000000", "%d"),
    numeric(0)
  )
})

testthat::test_that("a device too small for the stacked fit report errors", {
  model <- plots_test_model()
  temporary_device <- tempfile(fileext = ".pdf")
  # Three topic rows need roughly 0.7 inches each; one inch is not enough.
  grDevices::pdf(temporary_device, width = 7, height = 1)
  on.exit(
    {
      grDevices::dev.off()
      unlink(temporary_device)
    },
    add = TRUE
  )
  testthat::expect_error(
    plot(model, type = "fit"),
    class = "sbert_plot_too_small"
  )
  testthat::expect_error(plot(model, type = "fit"), "per_topic = TRUE")
})
