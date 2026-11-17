# Fit semantic topics to documents

`topics()` fits an embedding-based topic model: it groups texts, or the
sentences, clauses, or phrases of texts, by what they mean rather than
by the words they share, and each group is a topic. Each unit is
represented by a Sentence-BERT embedding (Reimers and Gurevych 2019), a
vector in which texts of similar meaning lie close together, and the
embeddings are partitioned into groups of semantically similar texts.

Every unit is assigned to one of `n_topics` topics by k-means clustering
(Lloyd 1982) of the L2-normalized embeddings, started from
farthest-point initial centers. The fit is deterministic: the same input
always gives the same topics, and no random seed is involved. Each topic
is described by its distinctive terms, scored by class-based TF-IDF
(Grootendorst 2022; Mendonca and Figueira 2025), and by its
representative units, those nearest its center. By default a topic is
labeled by its most central text. Topics are numbered by size, largest
first, unless `seeds` fix their order. Unlike latent Dirichlet
allocation, the model does not represent a text as a mixture of word
distributions, so it does not depend on words co-occurring within texts,
which they rarely do in short texts.

The result, an object of class `sbert_topic_model`, shows which kinds of
content a corpus holds and how much of the corpus each kind accounts
for.

To choose the number of topics and the unit of analysis, compare
candidate fits with
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md).
To fit several models to one corpus, prepare it once with
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md).
New texts are assigned to the fitted topics by
[predict()](https://sonsoles.me/sbert/reference/predict.sbert_topic_model.md),
and each document's mixture of topics is given by
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md).
To merge the topics of an existing fit, use
[`reduce_topics()`](https://sonsoles.me/sbert/reference/reduce_topics.md).

## Usage

``` r
topics(
  text,
  n_topics,
  column = NULL,
  model = NULL,
  embeddings = NULL,
  batch_size = 32L,
  iter_max = 100L,
  n_terms = 10L,
  n_representatives = 5L,
  stop_words = default_stop_words(),
  min_term_frequency = 1L,
  min_token_length = 2L,
  weighting = c("ctfidf", "bm25"),
  reduce_frequent_words = FALSE,
  stem = FALSE,
  keep_embeddings = TRUE,
  seeds = NULL,
  seed_embeddings = NULL,
  fixed_seeds = FALSE,
  cores = 1L,
  numbers = c("keep", "remove"),
  roman_numerals = c("keep", "remove"),
  section_numbers = c("keep", "remove"),
  segment = c("document", "sentence", "clause", "phrase"),
  max_tokens = NULL,
  merge_below = 0L,
  min_content = 0,
  label = c("representative", "terms")
)
```

## Arguments

- text:

  Documents: a character vector with one document per element, a data
  frame together with `column`, or a corpus prepared by
  [`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md).

- n_topics:

  Number of topics: an integer of at least 2 and at most the number of
  modeled units.

- column:

  Name of the text column when `text` is a data frame. The other columns
  are carried into the document table. Rows whose text is missing,
  blank, or the placeholder `"[No abstract available]"` are dropped, and
  so are their rows of `embeddings`. `NULL` (default) for a character
  vector.

- model:

  The encoder: a model from
  [`load_model()`](https://sonsoles.me/sbert/reference/load_model.md), a
  pinned model name from
  [`models()`](https://sonsoles.me/sbert/reference/models.md), or `NULL`
  (default) for the default model. Not used when `embeddings` are given.

- embeddings:

  Optional numeric matrix of precomputed embeddings, one row per modeled
  unit (per document, or per segment with `segment`). When it is given,
  no model is loaded. Default `NULL`.

- batch_size:

  Texts encoded per model call (default 32).

- iter_max:

  Maximum number of k-means iterations (default 100).

- n_terms:

  Terms stored per topic (default 10).

- n_representatives:

  Representative units stored per topic (default 5).

- stop_words:

  Words excluded from the topic terms; default
  [`stop_words()`](https://sonsoles.me/sbert/reference/stop_words.md).
  [`character()`](https://rdrr.io/r/base/character.html) turns the
  filter off.

- min_term_frequency:

  Minimum corpus-wide frequency of a term (default 1).

- min_token_length:

  Minimum length of a term, in characters (default 2).

- weighting:

  Term weighting: `"ctfidf"` (default) or `"bm25"`, which down-weights
  terms shared by many topics more strongly.

- reduce_frequent_words:

  Whether to take the square root of within-topic term frequencies
  before weighting (default `FALSE`).

- stem:

  Whether to merge inflected forms of a term under one Porter stem,
  shown as its most frequent form (default `FALSE`; needs the SnowballC
  package).

- keep_embeddings:

  Whether to store the normalized embeddings in the model (default
  `TRUE`). Without them,
  [`reduce_topics()`](https://sonsoles.me/sbert/reference/reduce_topics.md),
  [`topic_membership()`](https://sonsoles.me/sbert/reference/topic_membership.md),
  and
  [`representatives()`](https://sonsoles.me/sbert/reference/representatives.md)
  need the embeddings supplied again.

- seeds:

  Optional guided topics: a character vector, or a list of character
  vectors, of seed words or descriptions, one element per seeded topic.
  The embedding of seed `i` is the starting center of topic `i`, and the
  names of `seeds`, if any, become topic labels. Default `NULL`.

- seed_embeddings:

  Matrix of seed embeddings, one row per seed. Needed when `seeds` are
  combined with precomputed `embeddings`.

- fixed_seeds:

  If `TRUE`, the seed centers are held fixed and each unit joins its
  nearest seed (zero-shot classification); `n_topics` must equal the
  number of seeds, and a topic may be empty. Default `FALSE`.

- cores:

  Number of forked worker processes for tokenization (default 1;
  Unix-alikes only). Results do not depend on it.

- numbers, roman_numerals, section_numbers:

  Whether to `"keep"` (default) or `"remove"` digit-only tokens,
  Roman-numeral tokens, and section or list numbering (`1.2.3`, `1.`)
  from the topic terms. They change the terms only, not the text that is
  embedded; to clean the text, use
  [`clean_corpus()`](https://sonsoles.me/sbert/reference/clean_corpus.md).

- segment:

  Unit of analysis: `"document"` (default), or `"sentence"`, `"clause"`,
  or `"phrase"`, which split each document with
  [`segment()`](https://sonsoles.me/sbert/reference/segment.md) and fit
  the topics to the segments, so that a document can take part in
  several topics.

- max_tokens, merge_below, min_content:

  Segmentation options passed to
  [`segment()`](https://sonsoles.me/sbert/reference/segment.md), for
  segmented fits only: the maximum segment length (in the model's
  tokens, or in words with precomputed `embeddings`; default `NULL`, no
  limit), the number of words below which a segment is joined to its
  neighbor (default 0), and the minimum share of letters for a segment
  to be kept (default 0; see
  [`content_ratio()`](https://sonsoles.me/sbert/reference/content_ratio.md)).

- label:

  How topics are labeled: `"representative"` (default), the most central
  text shortened to 60 characters, or `"terms"`, the three most
  distinctive terms. Named `seeds` override both.

## Value

An object of class `sbert_topic_model`, a list with

- `documents`:

  One row per modeled unit (document, or segment): `document_id`,
  `document_name`, `segment` (segmented fits only), `text`, `topic`,
  `label`, and `distance` (cosine distance to the topic center),
  followed by the columns carried from a data frame.

- `topics`:

  One row per topic: `topic`, `label`, `n_documents`, `proportion`, and
  `withinss`.

- `terms`, `representatives`:

  The stored terms and representative units of each topic.

- `centers`:

  Numeric matrix of topic centers, one row per topic: the k-means means
  of the L2-normalized embeddings. They are not rescaled, so their norms
  are below one; verbs that use cosine similarity normalize them first.

- `embeddings`:

  The normalized embeddings, or `NULL` when `keep_embeddings = FALSE`.

- `diagnostics`:

  Sums of squares (`totss`, `tot_withinss`, `betweenss`), `iterations`,
  `converged` (whether k-means converged within `iter_max`), `warnings`
  (warnings raised by
  [`stats::kmeans()`](https://rdrr.io/r/stats/kmeans.html)), and
  `algorithm`.

- `model`, `settings`:

  The identity of the embedding model and the settings of the fit, which
  later verbs reuse.

Read it through its accessors rather than its fields:
[as.data.frame()](https://sonsoles.me/sbert/reference/as.data.frame.sbert_topic_model.md)
with `what = "documents"`, `"topics"`, `"terms"`, or
`"representatives"`;
[`topic_sizes()`](https://sonsoles.me/sbert/reference/topic_sizes.md);
[terms()](https://sonsoles.me/sbert/reference/terms.sbert_topic_model.md);
[`representatives()`](https://sonsoles.me/sbert/reference/representatives.md);
and
[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_model.md),
which also reports a fit that did not converge.

## Conditions

Errors of class `sbert_bad_input` for conflicting arguments, embeddings
without one row per unit, more topics than distinct embeddings, or a
`model`, `embeddings`, or different `segment` combined with a prepared
corpus; `sbert_missing_package` for `stem = TRUE` without SnowballC;
`sbert_no_terms` when no term passes the filters; and
`sbert_clustering_failed` when k-means fails or leaves a topic empty.
Arguments of the wrong type or range fail a plain
[`stopifnot()`](https://rdrr.io/r/base/stopifnot.html) check. When a
model is used, the errors of
[`load_model()`](https://sonsoles.me/sbert/reference/load_model.md) and
[`encode()`](https://sonsoles.me/sbert/reference/encode.md) apply. A
warning of class `sbert_no_converge` when k-means reaches `iter_max`
without converging; the fit is still returned. Errors inherit
`sbert_error` and warnings `sbert_warning`.

## References

Reimers, N. and Gurevych, I. (2019). Sentence-BERT: Sentence embeddings
using Siamese BERT-networks. *Proceedings of EMNLP-IJCNLP 2019*,
3982–3992.
[doi:10.18653/v1/D19-1410](https://doi.org/10.18653/v1/D19-1410)

Grootendorst, M. (2022). BERTopic: Neural topic modeling with a
class-based TF-IDF procedure. arXiv:2203.05794.

Mendonca, M. and Figueira, A. (2025). Modeling political discourse with
Sentence-BERT and BERTopic. arXiv:2510.22904.

Lloyd, S. P. (1982). Least squares quantization in PCM. *IEEE
Transactions on Information Theory*, 28(2), 129–137.
[doi:10.1109/TIT.1982.1056489](https://doi.org/10.1109/TIT.1982.1056489)

## See also

[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
to choose the number of topics;
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)
to prepare a corpus once;
[`name_topics()`](https://sonsoles.me/sbert/reference/name_topics.md) to
name the topics;
[plot()](https://sonsoles.me/sbert/reference/plot.sbert_topic_model.md)
for figures;
[predict()](https://sonsoles.me/sbert/reference/predict.sbert_topic_model.md)
and
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
for new texts and topic mixtures;
[feedback_embeddings](https://sonsoles.me/sbert/reference/feedback_embeddings.md)
for the example data.

## Examples

``` r
# 600 distinct feedback messages with their precomputed embeddings
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings)
topic_model
#> <sbert_topic_model>
#>   documents: 600 
#>   topics: 6
#>   model: precomputed embeddings
#>   algorithm: deterministic k-means (Lloyd)
#>   topic sizes: 223, 133, 131, 49, 37, 27
#>   between/total SS: 22.6%
topic_sizes(topic_model, weights = "n")
#>   topic                                                       label n_documents
#> 1     1   Where is the cow and the cake? Choose all the pictures...         223
#> 2     2            All the ones between the cat and the strawberry.         133
#> 3     3         What does “all the ones between the leaf and the...         131
#> 4     4 Are you sure you have fewer pictures in the red box than...          49
#> 5     5      In the top middle box, it means something is in the...          37
#> 6     6    It is not a person, does not have a hat, and is sitting.          27
#>   proportion n_weighted weighted_share
#> 1 0.37166667        267     0.36081081
#> 2 0.22166667        162     0.21891892
#> 3 0.21833333        138     0.18648649
#> 4 0.08166667         76     0.10270270
#> 5 0.06166667         57     0.07702703
#> 6 0.04500000         40     0.05405405
terms(topic_model, n = 3)
#>    topic                                                       label       term
#> 1      1   Where is the cow and the cake? Choose all the pictures...    picture
#> 2      1   Where is the cow and the cake? Choose all the pictures...   pictures
#> 3      1   Where is the cow and the cake? Choose all the pictures...     choose
#> 4      2            All the ones between the cat and the strawberry.       ones
#> 5      2            All the ones between the cat and the strawberry.   broccoli
#> 6      2            All the ones between the cat and the strawberry.      candy
#> 7      3         What does “all the ones between the leaf and the...       mean
#> 8      3         What does “all the ones between the leaf and the...       ones
#> 9      3         What does “all the ones between the leaf and the... strawberry
#> 10     4 Are you sure you have fewer pictures in the red box than...        box
#> 11     4 Are you sure you have fewer pictures in the red box than...        red
#> 12     4 Are you sure you have fewer pictures in the red box than...       blue
#> 13     5      In the top middle box, it means something is in the...      means
#> 14     5      In the top middle box, it means something is in the...     middle
#> 15     5      In the top middle box, it means something is in the...      right
#> 16     6    It is not a person, does not have a hat, and is sitting.       it's
#> 17     6    It is not a person, does not have a hat, and is sitting.     person
#> 18     6    It is not a person, does not have a hat, and is sitting.     animal
#>    rank      score frequency       beta
#> 1     1 0.15812657        99 0.10174717
#> 2     2 0.15734447       130 0.13360740
#> 3     3 0.15707789        89 0.09146968
#> 4     1 0.30963920        82 0.21025641
#> 5     2 0.07420924         9 0.02307692
#> 6     3 0.06596377         8 0.02051282
#> 7     1 0.34359216       130 0.26104418
#> 8     2 0.11237273        38 0.07630522
#> 9     3 0.05446666         9 0.01807229
#> 10    1 0.27236446        32 0.10631229
#> 11    2 0.24904937        27 0.08970100
#> 12    3 0.23982532        26 0.08637874
#> 13    1 0.31653087        19 0.11111111
#> 14    2 0.18182559        10 0.05847953
#> 15    3 0.15309964        10 0.05847953
#> 16    1 0.57814172        22 0.20560748
#> 17    2 0.55210406        19 0.17757009
#> 18    3 0.42837319        14 0.13084112

# Sentence-level fit: one embedding per sentence
documents <- c(
  "Cats chase mice. Stocks and bonds trade.",
  "Dogs chase balls. Markets price shares."
)
sentence_model <- topics(
  documents, n_topics = 2, segment = "sentence",
  embeddings = rbind(c(1, 0), c(0, 1), c(0.9, 0.1), c(0.1, 0.9))
)
topic_sizes(sentence_model, by = "document")
#>   topic                   label n_documents proportion
#> 1     1        Cats chase mice.           2          1
#> 2     2 Stocks and bonds trade.           2          1
topic_gamma(sentence_model)
#>   document_id topic gamma n_segments
#> 1           1     1   0.5          2
#> 2           1     2   0.5          2
#> 3           2     1   0.5          2
#> 4           2     2   0.5          2
```
