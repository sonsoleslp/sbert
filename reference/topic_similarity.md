# Compute cosine similarity between embeddings

`topic_similarity()` computes the cosine similarity between every row of
`x` and every row of `y`, or between all pairs of rows of `x` when `y`
is omitted. In a sentence-embedding space, the closeness of two texts in
meaning is measured by the cosine of the angle between their embeddings:
1 for the same direction, 0 for unrelated directions, and negative
values for opposed ones; cosine similarity ignores vector length, so it
compares texts of different lengths on an equal footing.

Rows are scaled to unit length first, so embeddings need not be
normalized. The result is a matrix, or with `tidy = TRUE` a long data
frame with one row per pair. With `top`, the data frame keeps only the
nearest neighbors of each row of `x`: its `top` most similar rows of
`y`, most similar first, where a row is not its own neighbor when `y` is
omitted.

Any embeddings can be compared: texts from
[`encode()`](https://sonsoles.me/sbert/reference/encode.md), the bundled
[feedback_embeddings](https://sonsoles.me/sbert/reference/feedback_embeddings.md),
or rows of another embedding matrix with the same number of columns. To
assign texts to fitted topics use
[predict()](https://sonsoles.me/sbert/reference/predict.sbert_topic_model.md);
to relate the topics of a model to one another use
[`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md).

## Usage

``` r
topic_similarity(x, y = NULL, tidy = FALSE, top = NULL)
```

## Arguments

- x:

  Numeric embedding matrix, or a numeric vector (one embedding).

- y:

  Numeric embedding matrix or vector, or `NULL` (default) to compare the
  rows of `x` with each other.

- tidy:

  `FALSE` (default) for a matrix; `TRUE` for a data frame.

- top:

  `NULL` (default) for every pair, or a whole number: with
  `tidy = TRUE`, the `top` most similar rows of `y` for each row of `x`.

## Value

With `tidy = FALSE`, a numeric matrix of similarities in `[-1, 1]` with
one row per row of `x` and one column per row of `y` (or of `x`); a
vector counts as one row. With `tidy = TRUE`, a base data frame with one
row per pair and columns `from` (row of `x`), `to` (row of `y`), and
`similarity`; `from` and `to` are row names when the matrices have them,
else row numbers. With `top`, at most `top` rows per row of `x`, ordered
by `from` and decreasing similarity (ties by position in `y`), with a
`rank` column (1 for the most similar).

## Conditions

`sbert_dimension_mismatch` when `x` and `y` have different numbers of
columns; `sbert_bad_input` when a row is zero, or when `top` is given
without `tidy = TRUE`.

## See also

[`encode()`](https://sonsoles.me/sbert/reference/encode.md) for
embeddings;
[predict()](https://sonsoles.me/sbert/reference/predict.sbert_topic_model.md)
to assign texts to topics;
[`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md)
for similarity between topics.

## Examples

``` r
# Three feedback messages compared with each other.
topic_similarity(head(feedback_embeddings, 3))
#>            [,1]       [,2]       [,3]
#> [1,] 1.00000000 0.36132672 0.09539736
#> [2,] 0.36132672 1.00000000 0.09345878
#> [3,] 0.09539736 0.09345878 1.00000000
topic_similarity(head(feedback_embeddings, 3), tidy = TRUE)
#>   from to similarity
#> 1    1  1 1.00000000
#> 2    2  1 0.36132672
#> 3    3  1 0.09539736
#> 4    1  2 0.36132672
#> 5    2  2 1.00000000
#> 6    3  2 0.09345878
#> 7    1  3 0.09539736
#> 8    2  3 0.09345878
#> 9    3  3 1.00000000

# The three nearest neighbors of each of the 600 messages.
neighbors <- topic_similarity(feedback_embeddings, tidy = TRUE, top = 3)
head(neighbors)
#>   from  to similarity rank
#> 1    1   4  0.4894304    1
#> 2    1 566  0.4232803    2
#> 3    1 227  0.3940784    3
#> 4    2 475  0.8977640    1
#> 5    2  10  0.8975812    2
#> 6    2   9  0.8695729    3

# Toy vectors: rows of x against one vector y.
x <- rbind(c(1, 0), c(0, 1), c(1, 1))
topic_similarity(x, c(1, 1))
#>           [,1]
#> [1,] 0.7071068
#> [2,] 0.7071068
#> [3,] 1.0000000
```
