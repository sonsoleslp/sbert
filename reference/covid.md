# COVID-19 Research Abstracts

Abstracts of peer-reviewed research on COVID-19, drawn from a
bibliographic database export and covering its effects on education,
children, schools, and society. Longer and more technical than
[feedback_translations](https://sonsoles.me/sbert/reference/feedback_translations.md),
with a publication year on every record, the corpus is a realistic
benchmark for the package's embedding and topic-modeling workflow —
including temporal analysis across the pandemic years.

## Usage

``` r
covid
```

## Format

A data frame with 4,170 rows and 2 columns:

- Year:

  Integer publication year, from 2020 to 2024.

- Abstract:

  The article abstract. 323 records carry the placeholder
  `"[No abstract available]"`; the other 3,847 hold 3,670 distinct
  abstracts, and the longest is 5,285 characters.

Editorial notices (retractions, corrections, and errata) are removed
during preparation, so every row is a research abstract or a
placeholder. [`topics()`](https://sonsoles.me/sbert/reference/topics.md)
and
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
drop the placeholder rows themselves when given the data frame with
`column = "Abstract"`.

## Source

Bibliographic database export of COVID-19 research articles (2020-2024),
prepared by `data-raw/covid.R`.

## Examples

``` r
xtabs(~ Year, data = covid)
#> Year
#> 2020 2021 2022 2023 2024 
#>  754 2745  560  106    5 

abstracts <- subset(covid, Abstract != "[No abstract available]")
nrow(abstracts)
#> [1] 3847
with(abstracts, summary(nchar(Abstract)))
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>     171    1016    1316    1350    1640    5285 
```
