# Build data/covid.rda from the raw bibliographic export.
#
# Source: covid.csv — a bibliographic database export of COVID-19 research
# articles (2020-2024). The raw CSV carries the usual bibliographic columns
# (authors, title, source, DOI, keywords, ...); only the publication year and
# the abstract are kept. The raw CSV is large and .Rbuildignore'd; only the
# .rda ships.
# Run from the package root:
#   Rscript data-raw/covid.R

raw <- read.csv(
  "covid.csv",
  stringsAsFactors = FALSE,
  encoding = "UTF-8",
  check.names = FALSE
)
stopifnot(all(c("Year", "Abstract") %in% names(raw)))

covid <- data.frame(
  Year = as.integer(raw$Year),
  Abstract = as.character(raw$Abstract),
  stringsAsFactors = FALSE
)
covid <- covid[!is.na(covid$Year) & nzchar(trimws(covid$Abstract)), , drop = FALSE]

# Drop editorial notices (retractions, corrections, errata, duplications). They
# are not research abstracts and, being semantic outliers, destabilise
# clustering. The "[No abstract available]" placeholder rows are kept: they are
# a genuine coverage feature that an analysis can filter with one line.
notice <- grepl(
  paste(
    "^at the decision of the publisher",
    "^following (the )?publication of the original",
    "^the editor.?in.?chief has retracted",
    "^the publisher regrets",
    "^the article was published with an error",
    "^this article (has been|was) retracted",
    "^retracted article",
    "^there (were|was) (an )?errors? in the published",
    "^in the original (version|publication|article)",
    "^the original (version|article|publication) of this article",
    "^an? erratum",
    "^(a )?correction to",
    "^corrigendum",
    "^the authors? (have )?(identified|regret)",
    "^the initial online publication",
    "^after an internal investigation",
    "^in this article,? the legend",
    sep = "|"
  ),
  trimws(covid$Abstract),
  ignore.case = TRUE
)
covid <- covid[!notice, , drop = FALSE]
rownames(covid) <- NULL
stopifnot(
  nrow(covid) == 4170L,
  all(covid$Year >= 2020L & covid$Year <= 2024L),
  !anyNA(covid$Abstract)
)

save(covid, file = file.path("data", "covid.rda"), compress = "xz")
cat(
  "Wrote data/covid.rda:", nrow(covid), "rows,",
  file.size(file.path("data", "covid.rda")), "bytes\n"
)
