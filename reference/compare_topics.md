# Compare numbers of topics and segmentation levels

`compare_topics()` fits
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) for every
candidate number of topics, and for every segmentation level in
`segment`, on one shared set of embeddings, and reports measures of the
quality of each fit. The number of topics, like the unit of analysis
(the whole document or its sentences, clauses, or phrases), sets the
granularity of a topic model and has no single correct value: fewer
topics give broad themes, more topics give narrower ones, until some of
them split a theme into near-duplicates.

Three measures are reported per candidate: the mean coherence of the
topics' terms
([`coherence()`](https://sonsoles.me/sbert/reference/coherence.md)), the
diversity of the terms across topics
([`topic_diversity()`](https://sonsoles.me/sbert/reference/topic_diversity.md)),
and the share of the embedding variance that lies between topics.
Coherence tends to fall and between-topic variance to rise as the number
of topics grows, so a useful candidate is often the count after which
coherence stops improving rather than the count with the highest
coherence. Comparing candidates on such measures is a better basis for
the choice than fixing a number in advance. The function compares; it
does not choose.

The result is a table of class `sbert_topic_sweep` with one row per
candidate. The fitted candidates are kept, so a chosen one is taken out
with
[fitted()](https://sonsoles.me/sbert/reference/fitted.sbert_topic_sweep.md)
without refitting.

The measures are a guide; the choice should also rest on reading the
representative texts of the candidate models.

## Usage

``` r
compare_topics(
  text,
  n_topics = c(5L, 10L, 15L, 20L, 25L, 30L),
  column = NULL,
  model = NULL,
  embeddings = NULL,
  measure = c("npmi", "umass"),
  n_terms = 10L,
  n_representatives = 1L,
  keep_models = TRUE,
  batch_size = 32L,
  cores = 1L,
  segment = c("document", "sentence", "clause", "phrase"),
  max_tokens = NULL,
  merge_below = 0L,
  min_content = 0,
  coherence_weight = c("none", "size"),
  ...
)
```

## Arguments

- text:

  Documents: a character vector, a data frame together with `column`, or
  a corpus prepared by
  [`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md).

- n_topics:

  Candidate numbers of topics: distinct integers of at least 2 and below
  the number of modeled units. Default `c(5, 10, 15, 20, 25, 30)`.

- column:

  Name of the text column when `text` is a data frame. The other columns
  are carried into the document table. Rows whose text is missing,
  blank, or the placeholder `"[No abstract available]"` are dropped, and
  so are their rows of `embeddings`. `NULL` (default) for a character
  vector.

- model:

  The encoder: a model from
  [`load_model()`](https://sonsoles.me/sbert/reference/load_model.md), a
  pinned model name, or `NULL` (default) for the default model. Not used
  when `embeddings` are given.

- embeddings:

  Optional precomputed embedding matrix, one row per modeled unit. When
  several `segment` levels are compared, a list of matrices named by
  level. Default `NULL`.

- measure:

  Coherence measure: `"npmi"` (default) or `"umass"`.

- n_terms:

  Top terms per topic used for coherence and diversity (default 10).

- n_representatives:

  Representative units stored per topic in each candidate (default 1).

- keep_models:

  Whether to keep the fitted candidates (default `TRUE`). With `FALSE`,
  only the table is kept and
  [fitted()](https://sonsoles.me/sbert/reference/fitted.sbert_topic_sweep.md)
  is not available.

- batch_size:

  Texts encoded per model call (default 32).

- cores:

  Number of forked worker processes for tokenization and for fitting the
  candidates (default 1; Unix-alikes only). Results do not depend on it.

- segment:

  Unit or units of analysis, as in
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md): one or
  more of `"document"` (default), `"sentence"`, `"clause"`, and
  `"phrase"`. With several levels, every level is fitted for every
  candidate.

- max_tokens, merge_below, min_content:

  Segmentation options passed to
  [`segment()`](https://sonsoles.me/sbert/reference/segment.md), for
  segmented fits only: the maximum segment length (in the model's
  tokens, or in words with precomputed `embeddings`; default `NULL`, no
  limit), the number of words below which a segment is joined to its
  neighbor (default 0), and the minimum share of letters for a segment
  to be kept (default 0; see
  [`content_ratio()`](https://sonsoles.me/sbert/reference/content_ratio.md)).

- coherence_weight:

  How the coherences of a candidate's topics are averaged: `"none"`
  (default), every topic equally, or `"size"`, each topic in proportion
  to its number of units, so a very small topic cannot decide the
  comparison.

- ...:

  Further arguments to
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md), for
  example `stop_words` or `weighting`.

## Value

An object of class `sbert_topic_sweep`: a data frame with one row per
candidate and columns `n_topics`, `coherence` (the mean over the topics
that can be scored, averaged as `coherence_weight` says; `NA` when no
topic can be scored), `topic_diversity`, `explained` (the between-topic
share of the variance), and `converged`, preceded by `segment` when
several levels are compared. The coherence measure and the weighting are
kept as the attributes `measure` and `coherence_weight`.
[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_sweep.md)
gives the most coherent candidate per level,
[plot()](https://sonsoles.me/sbert/reference/plot.sbert_topic_sweep.md)
draws the measures, and
[fitted()](https://sonsoles.me/sbert/reference/fitted.sbert_topic_sweep.md)
returns a fitted candidate.

## Conditions

Errors of class `sbert_bad_input` when fewer than three units are
modeled, a candidate is not below the number of units, a list of
embeddings is given for a single level, several levels are given with a
prepared corpus or with embeddings that are not a list named by level;
and the conditions of
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) for each
candidate. Non-convergence of a candidate is recorded in the `converged`
column.

## See also

[`topics()`](https://sonsoles.me/sbert/reference/topics.md) to fit one
model; [`coherence()`](https://sonsoles.me/sbert/reference/coherence.md)
and
[`topic_diversity()`](https://sonsoles.me/sbert/reference/topic_diversity.md)
for the measures;
[`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md)
and
[`reduce_topics()`](https://sonsoles.me/sbert/reference/reduce_topics.md)
to merge the topics of a fit.

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
comparison <- compare_topics(corpus, n_topics = c(4, 6, 8),
                             column = "translation",
                             embeddings = feedback_embeddings)
comparison
#> <sbert_topic_sweep> 3 candidates, coherence measure: npmi
#>  n_topics  coherence topic_diversity explained converged
#>         4 -0.2070855       0.9250000 0.1229819      TRUE
#>         6 -0.1044246       0.9166667 0.2255144      TRUE
#>         8 -0.1181287       0.9000000 0.2433832      TRUE
#> 
#> Fitted models retained: fitted(x, n_topics = 6)
summary(comparison)
#> Topic-count comparison: highest mean npmi coherence per level
#> 
#>   segment n_candidates min_topics max_topics best_n_topics coherence
#>  document            3          4          8             6    -0.104
#>  topic_diversity explained all_converged
#>            0.917     0.226          TRUE
fitted(comparison, n_topics = 6)
#> <sbert_topic_model>
#>   documents: 600 
#>   topics: 6
#>   model: precomputed embeddings
#>   algorithm: deterministic k-means (Lloyd)
#>   topic sizes: 223, 133, 131, 49, 37, 27
#>   between/total SS: 22.6%

# Documents against sentences (one embedding matrix per level)
documents <- c(
  "Cats chase mice. Stocks and bonds trade.",
  "Dogs chase balls. Markets price shares.",
  "Kittens nap in sunshine. Banks report profit."
)
levels <- compare_topics(
  documents,
  n_topics = 2,
  segment = c("document", "sentence"),
  embeddings = list(
    document = rbind(c(0.7, 0.7), c(0.6, 0.8), c(0.8, 0.6)),
    sentence = rbind(
      c(1, 0), c(0, 1), c(0.9, 0.1),
      c(0.1, 0.9), c(0.95, 0.05), c(0.05, 0.95)
    )
  ),
  n_terms = 2
)
levels
#> <sbert_topic_sweep> 2 candidates, coherence measure: npmi
#>   segment n_topics  coherence topic_diversity explained converged
#>  document        2  0.6845351               1 0.7491596      TRUE
#>  sentence        2 -0.1934264               1 0.9954323      TRUE
#> 
#> Fitted models retained: fitted(x, n_topics = 2, segment = "document")
```
