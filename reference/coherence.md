# Score the coherence of topics

`coherence()` scores the coherence of each topic of a fitted model:
whether the top terms of the topic tend to occur in the same texts. A
topic whose terms co-occur is more likely to be interpretable as one
subject than a topic whose terms rarely appear together, and coherence
is the usual intrinsic measure of topic quality, computed from the
corpus itself without external judgments.

Each topic is scored from its top `n_terms` terms and the co-occurrence
of those terms in the modeled units (documents, or segments of a
segmented model). Two measures are available: normalized pointwise
mutual information (NPMI; Bouma 2009), the mean over term pairs of how
much more often two terms co-occur than expected, bounded between -1 and
1; and UMass coherence (Mimno et al. 2011), the mean log ratio of the
number of units holding both terms of a pair to the number holding the
higher-ranked one, usually negative. For both, larger values are more
coherent. The result is a table with one row per topic; the mean over
topics is kept with it, and is what
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
and
[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_model.md)
report.

Coherence is computed from words, while the topics are formed from
embeddings, so a topic of short texts that share meaning but not
vocabulary can score low. It complements reading the representative
texts and does not replace it.

## Usage

``` r
coherence(
  object,
  measure = c("npmi", "umass"),
  n_terms = 10L,
  smoothing = 1,
  token_lists = NULL,
  cores = 1L,
  weight = c("none", "size")
)
```

## Arguments

- object:

  A topic model fitted by
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md).

- measure:

  `"npmi"` (default) or `"umass"`.

- n_terms:

  Top terms per topic to score (default 10), capped at the terms a topic
  has.

- smoothing:

  Count added to each co-occurrence count for UMass (default 1).

- token_lists:

  Optional precomputed token lists, one per modeled unit, as held by a
  [`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md);
  `NULL` (default) tokenizes the text. The scores are the same either
  way.

- cores:

  Number of forked worker processes for tokenization (default 1;
  Unix-alikes only). Results do not depend on it.

- weight:

  How topic scores are averaged into the mean: `"none"` (default), every
  topic equally, or `"size"`, each topic in proportion to its number of
  units, so that a very small topic of near-identical texts cannot move
  the mean.

## Value

A base data frame with one row per topic and columns `topic`, `label`,
`measure`, `n_terms` (terms scored), and `coherence` (`NA` for a topic
with fewer than two terms). The mean over the scored topics is attached
as the attribute `mean_coherence` (`NA` when no topic can be scored) and
the averaging as `weight`;
[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_model.md)
prints the mean.

## References

Bouma, G. (2009). Normalized (pointwise) mutual information in
collocation extraction. *Proceedings of GSCL*, 31–40.

Mimno, D., Wallach, H. M., Talley, E., Leenders, M., and McCallum, A.
(2011). Optimizing semantic coherence in topic models. *Proceedings of
EMNLP 2011*, 262–272.

## See also

[`topic_diversity()`](https://sonsoles.me/sbert/reference/topic_diversity.md);
[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_model.md)
for the model report;
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
to compare numbers of topics.

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings)
coherence(topic_model)
#>   topic                                                       label measure
#> 1     1   Where is the cow and the cake? Choose all the pictures...    npmi
#> 2     2            All the ones between the cat and the strawberry.    npmi
#> 3     3         What does “all the ones between the leaf and the...    npmi
#> 4     4 Are you sure you have fewer pictures in the red box than...    npmi
#> 5     5      In the top middle box, it means something is in the...    npmi
#> 6     6    It is not a person, does not have a hat, and is sitting.    npmi
#>   n_terms  coherence
#> 1      10 -0.2367956
#> 2      10 -0.4150297
#> 3      10 -0.2563526
#> 4      10  0.3010516
#> 5      10 -0.2043292
#> 6      10  0.1849079
coherence(topic_model, measure = "umass", weight = "size")
#>   topic                                                       label measure
#> 1     1   Where is the cow and the cake? Choose all the pictures...   umass
#> 2     2            All the ones between the cat and the strawberry.   umass
#> 3     3         What does “all the ones between the leaf and the...   umass
#> 4     4 Are you sure you have fewer pictures in the red box than...   umass
#> 5     5      In the top middle box, it means something is in the...   umass
#> 6     6    It is not a person, does not have a hat, and is sitting.   umass
#>   n_terms coherence
#> 1      10 -2.752499
#> 2      10 -2.657697
#> 3      10 -2.671608
#> 4      10 -1.445615
#> 5      10 -1.897612
#> 6      10 -1.482345
```
