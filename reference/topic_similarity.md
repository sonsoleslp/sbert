# Compute Cosine Similarity

Cosine similarity between embedding rows, for example to check how close
two texts are in meaning before or after topic modeling. Rows are
L2-normalized first, so unnormalized embeddings give the same result.

## Usage

``` r
topic_similarity(x, y = NULL)
```

## Arguments

- x:

  Numeric embedding matrix, or one numeric vector.

- y:

  Optional second embedding matrix or vector. When omitted, computes all
  pairwise similarities among rows of `x`.

## Value

A numeric matrix of cosine similarities in `[-1, 1]` with one row per
row of `x` and one column per row of `y` (or of `x` when `y` is
omitted). A vector counts as a one-row matrix.

## Examples

``` r
x <- rbind(c(1, 0), c(0, 1), c(1, 1))
topic_similarity(x)
#>           [,1]      [,2]      [,3]
#> [1,] 1.0000000 0.0000000 0.7071068
#> [2,] 0.0000000 1.0000000 0.7071068
#> [3,] 0.7071068 0.7071068 1.0000000
```
