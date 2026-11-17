# Measure the diversity of topic terms

`topic_diversity()` measures the diversity of topic terms (Dieng et al.
2020): it pools the top `n_terms` terms of every topic and returns the
proportion of them that are distinct. A value near one means that the
topics are described by different words; a low value means that several
topics repeat the same words and may be redundant.

It returns a single number between 0 and 1 and complements
[`coherence()`](https://sonsoles.me/sbert/reference/coherence.md), which
scores each topic on its own.

## Usage

``` r
topic_diversity(object, n_terms = 10L)
```

## Arguments

- object:

  A topic model fitted by
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md).

- n_terms:

  Top terms per topic to pool (default 10), capped at the terms a topic
  has.

## Value

A single number between 0 and 1.

## Conditions

An error of class `sbert_no_terms` when the model has no terms.

## References

Dieng, A. B., Ruiz, F. J. R., and Blei, D. M. (2020). Topic modeling in
embedding spaces. *Transactions of the Association for Computational
Linguistics*, 8, 439–453.
[doi:10.1162/tacl_a_00325](https://doi.org/10.1162/tacl_a_00325)

## See also

[`coherence()`](https://sonsoles.me/sbert/reference/coherence.md);
[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_model.md);
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md),
which reports both measures per candidate.

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings)
topic_diversity(topic_model)
#> [1] 0.9166667
topic_diversity(topic_model, n_terms = 5)
#> [1] 0.9666667
```
