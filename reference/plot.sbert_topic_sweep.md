# Plot a topic-count comparison

[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws the
measures of a topic-count comparison, or the fit report of one of its
candidates. With `type = "metrics"` (default) it draws three panels
against the number of topics: mean coherence, topic diversity, and the
share of the variance between topics, with a dotted line at the most
coherent candidate. A comparison of several segment levels draws one
line per level, told apart by color, point shape, and line type. The
useful signal is usually the count after which coherence stops
improving, not the highest value.

`type = "fit"` draws the fit report of
[plot()](https://sonsoles.me/sbert/reference/plot.sbert_topic_model.md)
for the kept model with `n_topics` topics, one figure per segment level,
so that one number of topics can be read across segmentations.

## Usage

``` r
# S3 method for class 'sbert_topic_sweep'
plot(
  x,
  type = c("metrics", "fit"),
  main = "Topic-count comparison",
  n_topics = NULL,
  segment = NULL,
  n_terms = 8L,
  n_representatives = 5L,
  ...
)
```

## Arguments

- x:

  A comparison returned by
  [`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md).

- type:

  `"metrics"` (default) or `"fit"`.

- main:

  Overall title for `type = "metrics"` (default
  `"Topic-count comparison"`).

- n_topics:

  For `type = "fit"`, the number of topics of the models to draw;
  required when the comparison holds several candidates. Default `NULL`.

- segment:

  For `type = "fit"`, the segment levels to draw; `NULL` (default) for
  every level.

- n_terms, n_representatives:

  For `type = "fit"`, terms and representatives per topic (defaults 8
  and 5), passed to
  [plot()](https://sonsoles.me/sbert/reference/plot.sbert_topic_model.md).

- ...:

  Passed to the underlying plotting calls.

## Value

`x`, invisibly. Called for the plot.

## Conditions

An error of class `sbert_bad_input` when `type = "fit"` and `n_topics`
is missing for a comparison of several candidates.

## See also

[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md);
[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_sweep.md).

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
comparison <- compare_topics(corpus, n_topics = c(4, 6, 8),
                             column = "translation",
                             embeddings = feedback_embeddings)
plot(comparison)
```
