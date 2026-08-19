testthat::test_that("curly and straight apostrophes tokenize identically", {
  tokens <- sbert:::tokenize_topic_documents(
    c("It’s fine", "It's fine"),
    stop_words = character(),
    min_token_length = 2L
  )
  testthat::expect_identical(tokens[[1L]], tokens[[2L]])
  testthat::expect_identical(tokens[[1L]], c("it's", "fine"))
})

testthat::test_that("stemming collapses inflections to a shared display form", {
  testthat::skip_if_not_installed("SnowballC")
  tokens <- sbert:::tokenize_topic_documents(
    c("animals animal animals", "meaning means mean"),
    stop_words = character(),
    min_token_length = 2L,
    stem = TRUE
  )
  # "animals" is the most frequent surface for its stem, so it is the display
  # form; "mean" is most frequent for the mean/means/meaning stem.
  testthat::expect_identical(unique(tokens[[1L]]), "animals")
  testthat::expect_true(all(tokens[[2L]] == tokens[[2L]][[1L]]))
  testthat::expect_length(unique(unlist(tokens)), 2L)
})

testthat::test_that("stemming keeps topic terms distinct and deduplicated", {
  testthat::skip_if_not_installed("SnowballC")
  text <- c(
    "animals animal run", "animal animals move",
    "colour colours bright", "colours colour vivid"
  )
  embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
  model <- topics(
    text, 2L,
    embeddings = embeddings,
    n_terms = 3L,
    stem = TRUE
  )

  testthat::expect_true(model$settings$stem)
  testthat::expect_false(any(c("animal", "colour") %in%
    model$terms$term[model$terms$term %in% c("animals", "colours") == FALSE &
      duplicated(model$terms$term)]))
  # No inflection pair (animal/animals, colour/colours) survives together.
  terms <- model$terms$term
  testthat::expect_false(all(c("animal", "animals") %in% terms))
  testthat::expect_false(all(c("colour", "colours") %in% terms))
})

testthat::test_that("numbers = 'remove' drops purely numeric tokens", {
  text <- c("the year 2020 had 15 covid19 studies", "aged 65 patients")
  keep <- sbert:::tokenize_topic_documents(text, default_stop_words(), 2L, numbers = "keep")
  drop <- sbert:::tokenize_topic_documents(text, default_stop_words(), 2L, numbers = "remove")
  testthat::expect_true("2020" %in% keep[[1]])
  testthat::expect_false(any(grepl("^[0-9]+$", unlist(drop))))
  # alphanumerics and words survive
  testthat::expect_true("covid19" %in% drop[[1]])
  testthat::expect_true("studies" %in% drop[[1]])
  testthat::expect_true("patients" %in% drop[[2]])
})

testthat::test_that("numbers = 'keep' is the default and unchanged", {
  text <- c("count 42 things", "measure 7 items")
  testthat::expect_identical(
    sbert:::tokenize_topic_documents(text, default_stop_words(), 2L),
    sbert:::tokenize_topic_documents(text, default_stop_words(), 2L, numbers = "keep")
  )
})

testthat::test_that("roman_numerals = 'remove' drops numerals but keeps units", {
  text <- "chapter iv part xii uses ml and mm and covid19"
  keep <- sbert:::tokenize_topic_documents(text, default_stop_words(), 2L)
  drop <- sbert:::tokenize_topic_documents(text, default_stop_words(), 2L, roman_numerals = "remove")
  testthat::expect_true(all(c("iv", "xii") %in% keep[[1]]))
  testthat::expect_false(any(c("iv", "xii") %in% drop[[1]]))
  # scientific units that are also valid Roman numerals are kept
  testthat::expect_true(all(c("ml", "mm") %in% drop[[1]]))
  testthat::expect_true("covid19" %in% drop[[1]])
})

testthat::test_that("section_numbers = 'remove' strips multi-level indices only", {
  text <- "see section 1.2.3 value 3.14 in table 4.5.6 year 2020"
  drop <- sbert:::tokenize_topic_documents(
    text, default_stop_words(), 2L, section_numbers = "remove", numbers = "keep"
  )
  # multi-level indices gone; the year survives
  testthat::expect_true("2020" %in% drop[[1]])
  # a decimal keeps its parts (period splits it); no "123" or "456" leaked
  testthat::expect_false(any(c("123", "456") %in% drop[[1]]))
})

testthat::test_that("roman_numerals/section_numbers default to keep, unchanged", {
  text <- c("chapter iv section 1.2.3", "measure 7 items")
  base <- sbert:::tokenize_topic_documents(text, default_stop_words(), 2L)
  same <- sbert:::tokenize_topic_documents(
    text, default_stop_words(), 2L, roman_numerals = "keep", section_numbers = "keep"
  )
  testthat::expect_identical(base, same)
})

testthat::test_that("section_numbers = 'remove' also drops enumeration markers", {
  text <- "1. background 2. methods figure 12. results in 2020 covid-19 section 1.2.3"
  drop <- sbert:::tokenize_topic_documents(text, default_stop_words(), 2L,
                                           section_numbers = "remove")
  toks <- drop[[1]]
  # enumeration/list markers gone (12. removed; 1./2. were single-digit anyway)
  testthat::expect_false("12" %in% toks)
  # genuine values survive even under numbers = "keep"
  testthat::expect_true("2020" %in% toks)   # four-digit year
  testthat::expect_true("19" %in% toks)     # covid-19, hyphenated
  # words intact
  testthat::expect_true(all(c("background", "methods", "results") %in% toks))
})
