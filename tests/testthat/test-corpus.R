testthat::test_that("dedupe counts and preserves first-appearance order", {
  result <- dedupe(c("b", "a", "b", NA, "  ", "b", "a", "c"))

  testthat::expect_identical(names(result), c("text", "n"))
  testthat::expect_identical(result$text, c("b", "a", "c"))
  testthat::expect_identical(result$n, c(3L, 2L, 1L))
  testthat::expect_error(dedupe(c(NA_character_, " ")), "non-blank")
  testthat::expect_error(dedupe(1:3))
})

testthat::test_that("topic_sizes reports both scales exactly", {
  fitted <- topics(
    c("apple apple banana", "banana apple fruit", "stocks trade daily", "markets trade stocks"),
    2L,
    embeddings = rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9)),
    stop_words = character()
  )

  plain <- topic_sizes(fitted)
  testthat::expect_identical(
    names(plain),
    c("topic", "label", "n_documents", "proportion")
  )
  testthat::expect_identical(plain$n_documents, fitted$topics$n_documents)

  weighted <- topic_sizes(fitted, weights = c(10, 1, 1, 1))
  testthat::expect_identical(
    names(weighted),
    c("topic", "label", "n_documents", "proportion", "n_weighted", "weighted_share")
  )
  fruit_topic <- fitted$documents$topic[[1L]]
  fruit_row <- subset(weighted, topic == fruit_topic)
  testthat::expect_identical(fruit_row$n_weighted, 11)
  testthat::expect_equal(fruit_row$weighted_share, 11 / 13, tolerance = 1e-12)
  testthat::expect_equal(sum(weighted$weighted_share), 1, tolerance = 1e-12)

  testthat::expect_error(topic_sizes(fitted, weights = c(1, 2)))
  testthat::expect_error(topic_sizes(fitted, weights = c(-1, 1, 1, 1)))
})

testthat::test_that("dedupe and sizes compose into the weighted workflow", {
  corpus <- dedupe(c("aa bb", "cc dd", "aa bb", "aa bb", "ee ff", "gg hh"))
  fitted <- topics(
    corpus$text,
    2L,
    embeddings = rbind(c(1, 0), c(0.95, 0.05), c(0, 1), c(0.05, 0.95)),
    stop_words = character()
  )
  sizes <- topic_sizes(fitted, weights = corpus$n)
  testthat::expect_identical(sum(sizes$n_weighted), 6)
  testthat::expect_identical(sum(sizes$n_documents), 4L)
})

testthat::test_that("strip_list_markers removes markers but keeps real content", {
  testthat::expect_identical(
    strip_list_markers(c("1. background 2. methods", "(i) first (ii) second")),
    c("background methods", "first second")
  )
  # real words / years / counts / decimals are left alone
  testthat::expect_identical(
    strip_list_markers("the concept of (civil) society in (2020) with 1.5 units"),
    "the concept of (civil) society in (2020) with 1.5 units"
  )
})

testthat::test_that("strip_list_markers tolerates spaces in the marker", {
  testthat::expect_identical(strip_list_markers("2 . one 3 . two ( i ) three"),
                             "one two three")
})

testthat::test_that("content_ratio scores prose high and references low", {
  testthat::expect_true(content_ratio("A real sentence here.") > 0.9)
  testthat::expect_true(content_ratio("OJ No L 297, 24.11.1979, p. 1.") < 0.4)
  testthat::expect_identical(content_ratio("45, 67, 89."), 0)
  testthat::expect_identical(content_ratio(character(0)), numeric(0))
  testthat::expect_identical(content_ratio("   "), 0)
})

testthat::test_that("clean_corpus cleans markers and repairs characters by default", {
  out <- clean_corpus(c(
    "1. First finding about learning outcomes for the students",
    "(i) Second point on teaching in section 3.2.1 here",
    "Results &amp; findings with  extra   spaces"
  ))
  testthat::expect_false(any(grepl("^\\s*(1\\.|\\(i\\))", out)))
  testthat::expect_false(any(grepl("3\\.2\\.1", out)))
  testthat::expect_true(any(grepl("Results & findings", out, fixed = TRUE)))
  # numbers and roman are opt-in, so they are kept by default
  testthat::expect_true(grepl("outcomes", out[[1]]))
})

testthat::test_that("clean_corpus numbers/roman are opt-in", {
  testthat::expect_identical(
    clean_corpus("the year 2020 had chapter iv and covid19 studies",
                 numbers = TRUE, roman_numerals = TRUE),
    "the year had chapter and covid19 studies"
  )
})

testthat::test_that("clean_corpus drops low-content rows and keeps metadata aligned", {
  df <- data.frame(
    abstract = c("(3) OJ No L 297, 24.11.1979, p. 1.",
                 "The directive entered into force across all member states now.",
                 "Vol. 3, No. 2, pp. 15-30.",
                 "Schools received additional funding for the programs this year."),
    id = 1:4, stringsAsFactors = FALSE
  )
  out <- clean_corpus(df, column = "abstract", min_content = 0.5)
  testthat::expect_identical(out$id, c(2L, 4L))
  testthat::expect_true(all(content_ratio(out$abstract) >= 0.5))
})

testthat::test_that("clean_corpus drops rows that become empty after stripping", {
  out <- clean_corpus(c("1. 2. 3.", "A real sentence remains here."))
  testthat::expect_identical(out, "A real sentence remains here.")
})

testthat::test_that("clean_corpus strips markup, urls, citations, and page refs", {
  testthat::expect_identical(
    clean_corpus("Peer <b>support</b> improved outcomes [12] pp. 15-30 here."),
    "Peer support improved outcomes here."
  )
  testthat::expect_identical(
    clean_corpus("Full report at https://example.org/x.pdf and doi:10.1/y today."),
    "Full report at and today."
  )
  # math and initials are not mistaken for tags or page refs
  testthat::expect_identical(clean_corpus("x < 3 and y > 2 held"), "x < 3 and y > 2 held")
  testthat::expect_true(grepl("P. M. Jones", clean_corpus("by P. M. Jones here")))
})

testthat::test_that("clean_corpus remove= applies custom domain patterns", {
  out <- clean_corpus("as set out in OJ No L 313 it applies here.",
                      remove = "OJ No L?\\s*\\d+")
  testthat::expect_false(grepl("OJ No L", out))
  testthat::expect_true(grepl("it applies here", out))
})

testthat::test_that("strip_list_markers removes bare Roman-numeral section markers", {
  testthat::expect_identical(strip_list_markers("IV. The sector expanded here."),
                             "The sector expanded here.")
  testthat::expect_identical(strip_list_markers("V. Capacity grew widely now."),
                             "Capacity grew widely now.")
  # false positives are left intact
  testthat::expect_identical(strip_list_markers("the case Smith v. Jones held"),
                             "the case Smith v. Jones held")
  testthat::expect_identical(strip_list_markers("edited by V. Nabokov here"),
                             "edited by V. Nabokov here")
  testthat::expect_identical(strip_list_markers("the reading was 5 V. today"),
                             "the reading was 5 V. today")
})
