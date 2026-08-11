# COVID-19 Research Abstracts

Abstracts of peer-reviewed research on COVID-19, drawn from a
bibliographic database export and covering its effects on education,
children, schools, and society. Longer and more technical than
\[feedback_translations\], with a publication year on every record, the
corpus is a realistic benchmark for the package's embedding and
topic-modeling workflow — including temporal analysis across the
pandemic years.

## Usage

``` r
covid
```

## Format

A data frame with 4,170 rows and 2 columns:

- Year:

  Integer publication year, from 2020 to 2024.

- Abstract:

  The article abstract. 323 records carry the placeholder \`"\[No
  abstract available\]"\`; 3,671 of the abstracts are distinct and the
  longest is 5,285 characters.

Editorial notices (retractions, corrections, and errata) are removed
during preparation, so every row is a research abstract or a
placeholder.

## Source

Bibliographic database export of COVID-19 research articles (2020-2024),
prepared by \`data-raw/covid.R\`.

## Examples

``` r
table(covid$Year)
#> 
#> 2020 2021 2022 2023 2024 
#>  754 2745  560  106    5 

content <- covid$Abstract[covid$Abstract != "[No abstract available]"]
nchar(content[1])
#> [1] 1654
```
