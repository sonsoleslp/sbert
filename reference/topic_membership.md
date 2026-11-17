# Compute graded topic membership

`topic_membership()` computes graded (fuzzy) topic membership: a
probability-like weight of every unit on every topic, so that units on a
boundary and units squarely inside a topic can be told apart, whereas a
hard assignment places each unit in one topic. The weights follow the
membership function of fuzzy c-means (Bezdek, 1981): a unit's weight on
a topic falls with its distance to that topic's center relative to its
distances to the other centers.

The weights are computed from the cosine distance of each unit to each
topic center, after scaling the centers to unit length: \\u\_{ij}
\propto d\_{ij}^{-2/(m-1)}\\, normalized to sum to one over topics, with
\\m\\ the `sharpness`. The topics themselves are not refitted. In
high-dimensional embedding spaces distances are similar in size, so the
usual \\m = 2\\ gives nearly uniform weights; the default 1.15 keeps
them distinct. The order of topics within a unit does not depend on
`sharpness`; the size of the weights does, and should be read relative
to the chosen value. The result is a data frame with one row per
unit-topic pair, with weights that sum to one within each unit.

The rank-1 topic is the topic
[predict()](https://sonsoles.me/sbert/reference/predict.sbert_topic_model.md)
assigns, by cosine similarity to the unit-length centers.
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) fits Lloyd's
k-means, which assigns by squared Euclidean distance to the raw means of
the normalized embeddings; on the fitted units the two rules agree for
almost every unit but can differ for a few units on topic boundaries.
For the share of a long document's segments in each topic, use
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md).

## Usage

``` r
topic_membership(object, embeddings = NULL, sharpness = 1.15)
```

## Arguments

- object:

  A fitted model from
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md).

- embeddings:

  Numeric matrix of embeddings, one row per unit, or `NULL` (default)
  for the embeddings stored in the model (fitted with
  `keep_embeddings = TRUE`, the default).

- sharpness:

  The fuzzifier \\m\\, greater than 1 (default 1.15); values near 1 give
  crisper weights.

## Value

A base data frame with one row per unit-topic pair and columns
`document_id` (row of `embeddings`, or of the fitted units), `topic`,
`probability`, and `rank` (1 for the unit's highest weight), ordered by
unit and rank. Probabilities sum to one within each unit.

## Conditions

`sbert_no_embeddings` when `embeddings` is `NULL` and the model stores
none; `sbert_dimension_mismatch` when the embeddings have a different
number of columns from the fitted model; `sbert_bad_input` when an
embedding row is zero.

## References

Bezdek, J. C. (1981). *Pattern Recognition with Fuzzy Objective Function
Algorithms*. Plenum Press, New York.
[doi:10.1007/978-1-4757-0450-1](https://doi.org/10.1007/978-1-4757-0450-1)

## See also

[predict()](https://sonsoles.me/sbert/reference/predict.sbert_topic_model.md)
for single assignments;
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
for document mixtures from segments;
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) for the fit.

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings)
head(topic_membership(topic_model), 12)
#>    document_id topic  probability rank
#> 1            1     3 8.222489e-01    1
#> 2            1     5 9.239112e-02    2
#> 3            1     4 7.655749e-02    3
#> 4            1     2 4.998566e-03    4
#> 5            1     6 2.140314e-03    5
#> 6            1     1 1.663651e-03    6
#> 7            2     4 9.999992e-01    1
#> 8            2     1 4.087932e-07    2
#> 9            2     3 1.635870e-07    3
#> 10           2     2 1.519842e-07    4
#> 11           2     5 8.044388e-08    5
#> 12           2     6 1.038709e-08    6

# The textbook fuzzifier spreads the weights more evenly.
head(topic_membership(topic_model, sharpness = 2), 6)
#>   document_id topic probability rank
#> 1           1     3   0.2710096    1
#> 2           1     5   0.1952445    2
#> 3           1     4   0.1898158    3
#> 4           1     2   0.1260553    4
#> 5           1     6   0.1109956    5
#> 6           1     1   0.1068793    6
```
