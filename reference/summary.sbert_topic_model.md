# Summarize a topic model

[`summary()`](https://rdrr.io/r/base/summary.html) reports the quality
of a fitted topic model: the number of documents (and segments), topics,
and the embedding model; the share of the embedding variance between
topics; the mean coherence of the topics' terms; and the diversity of
the terms. Below this overview, a table gives the size and coherence of
every topic, so that small or incoherent topics stand out. A fit whose
k-means did not converge is reported as such.

The result is an object that prints as the report; calling
[`summary()`](https://rdrr.io/r/base/summary.html) does not print by
itself.

## Usage

``` r
# S3 method for class 'sbert_topic_model'
summary(object, measure = c("npmi", "umass"), n_terms = 10L, ...)
```

## Arguments

- object:

  A topic model fitted by
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md).

- measure:

  Coherence measure passed to
  [`coherence()`](https://sonsoles.me/sbert/reference/coherence.md):
  `"npmi"` (default) or `"umass"`.

- n_terms:

  Top terms per topic used for coherence and diversity (default 10).

- ...:

  Ignored.

## Value

A data frame of class `summary.sbert_topic_model` with one row per topic
and columns `topic`, `label`, `n_documents`, `proportion`, and
`coherence`. The overview is kept with it and printed above the table;
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) returns
the table as a plain data frame.

## Conditions

An error of class `sbert_no_terms` when the model has no terms.

## See also

[`coherence()`](https://sonsoles.me/sbert/reference/coherence.md) and
[`topic_diversity()`](https://sonsoles.me/sbert/reference/topic_diversity.md)
for the measures;
[`topic_sizes()`](https://sonsoles.me/sbert/reference/topic_sizes.md);
[`print.summary.sbert_topic_model()`](https://sonsoles.me/sbert/reference/print.summary.sbert_topic_model.md).

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings)
summary(topic_model)
#> Semantic topic model summary
#>   documents:            600
#>   topics:               6
#>   model:                precomputed embeddings
#>   between/total SS:     22.6%
#>   mean npmi  coherence:  -0.1044
#>   topic diversity:      0.917 (top 10 terms)
#> 
#>  topic                                                       label n_documents
#>      1   Where is the cow and the cake? Choose all the pictures...         223
#>      2            All the ones between the cat and the strawberry.         133
#>      3         What does “all the ones between the leaf and the...         131
#>      4 Are you sure you have fewer pictures in the red box than...          49
#>      5      In the top middle box, it means something is in the...          37
#>      6    It is not a person, does not have a hat, and is sitting.          27
#>  proportion coherence
#>     0.37167   -0.2368
#>     0.22167   -0.4150
#>     0.21833   -0.2564
#>     0.08167    0.3011
#>     0.06167   -0.2043
#>     0.04500    0.1849
as.data.frame(summary(topic_model))
#>   topic                                                       label n_documents
#> 1     1   Where is the cow and the cake? Choose all the pictures...         223
#> 2     2            All the ones between the cat and the strawberry.         133
#> 3     3         What does “all the ones between the leaf and the...         131
#> 4     4 Are you sure you have fewer pictures in the red box than...          49
#> 5     5      In the top middle box, it means something is in the...          37
#> 6     6    It is not a person, does not have a hat, and is sitting.          27
#>   proportion  coherence
#> 1 0.37166667 -0.2367956
#> 2 0.22166667 -0.4150297
#> 3 0.21833333 -0.2563526
#> 4 0.08166667  0.3010516
#> 5 0.06166667 -0.2043292
#> 6 0.04500000  0.1849079
```
