# Soft Topic Membership Probabilities

Computes fuzzy-c-means-style membership of every document in every topic
from cosine distances to the stored centroids, without changing the
deterministic hard clustering. In high-dimensional embedding spaces
distances concentrate, so the textbook fuzzifier `sharpness = 2`
collapses memberships toward the uniform `1/k`; the default
`sharpness = 1.15` preserves contrast. The membership ranking of topics
within a document is invariant to `sharpness`; the probability
magnitudes are not, and should be interpreted relative to the chosen
value.

## Usage

``` r
topic_membership(object, embeddings = NULL, sharpness = 1.15)
```

## Arguments

- object:

  A fitted [`topics()`](https://sonsoles.me/sbert/reference/topics.md)
  model.

- embeddings:

  Optional numeric matrix of document embeddings. When omitted, the
  embeddings stored by `topics(keep_embeddings = TRUE)` are used.

- sharpness:

  Fuzzy-c-means fuzzifier `m`. Must be greater than 1; values close to 1
  give crisper memberships.

## Value

A base data frame with one row per document-topic pair and columns
`document_id`, `topic`, `probability`, and `rank` (1 is the strongest
topic of the document). Probabilities sum to 1 within each document.

## References

Bezdek, J. C. (1981). *Pattern Recognition with Fuzzy Objective Function
Algorithms*. Plenum Press, New York.
[doi:10.1007/978-1-4757-0450-1](https://doi.org/10.1007/978-1-4757-0450-1)

## Examples

``` r
text <- c(
  "Cats chase mice", "Dogs chase balls",
  "Stocks and bonds trade", "Markets price shares"
)
embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
fitted <- topics(text, 2, embeddings = embeddings, keep_embeddings = TRUE)
topic_membership(fitted)
#>   document_id topic  probability rank
#> 1           1     1 1.000000e+00    1
#> 2           1     2 6.206785e-38    2
#> 3           2     1 1.000000e+00    1
#> 4           2     2 3.229897e-37    2
#> 5           3     2 1.000000e+00    1
#> 6           3     1 6.206785e-38    2
#> 7           4     2 1.000000e+00    1
#> 8           4     1 3.229897e-37    2
```
