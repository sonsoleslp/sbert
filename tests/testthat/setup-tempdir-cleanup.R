# Remove whatever the tests add to tempdir() once the suite finishes, so the
# check leaves no stray files behind. Only entries created during the run are
# removed; anything already present is left alone.
tempdir_entries_before <- list.files(tempdir(), all.files = TRUE, no.. = TRUE)
withr::defer(
  {
    created <- setdiff(
      list.files(tempdir(), all.files = TRUE, no.. = TRUE),
      tempdir_entries_before
    )
    unlink(file.path(tempdir(), created), recursive = TRUE)
  },
  envir = testthat::teardown_env()
)
