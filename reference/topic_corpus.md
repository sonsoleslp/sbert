# Prepare a corpus once for several topic models

`topic_corpus()` prepares a corpus once for several topic models: it
segments the texts, embeds them, and tokenizes them for term scoring,
and returns a prepared corpus that
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) and
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
accept in place of the texts. Fitting topic models usually means fitting
several (different numbers of topics, term settings, or seeds on the
same texts), and these three steps do not depend on any of those
choices; embedding is by far the most expensive step.

Models fitted to the corpus are identical to models fitted to the raw
texts. The corpus fixes the embeddings (from `model` or `embeddings`),
the segmentation, and the tokenization settings; the settings of each
model, such as `n_topics`, `n_terms`, `weighting`, and `seeds`, are
still chosen per call. The result is an object of class
`sbert_topic_corpus`.

[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
builds a corpus itself, so a corpus is needed only when models are
fitted one at a time.

## Usage

``` r
topic_corpus(
  text,
  column = NULL,
  model = NULL,
  embeddings = NULL,
  batch_size = 32L,
  stop_words = default_stop_words(),
  min_token_length = 2L,
  stem = FALSE,
  cores = 1L,
  numbers = c("keep", "remove"),
  roman_numerals = c("keep", "remove"),
  section_numbers = c("keep", "remove"),
  segment = c("document", "sentence", "clause", "phrase"),
  max_tokens = NULL,
  merge_below = 0L,
  min_content = 0
)
```

## Arguments

- text:

  Documents: a character vector with one document per element, or a data
  frame together with `column`.

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

- stop_words:

  Words excluded from the topic terms; default
  [`stop_words()`](https://sonsoles.me/sbert/reference/stop_words.md).
  [`character()`](https://rdrr.io/r/base/character.html) turns the
  filter off.

- min_token_length:

  Minimum length of a term, in characters (default 2).

- stem:

  Whether to merge inflected forms of a term under one Porter stem,
  shown as its most frequent form (default `FALSE`; needs the SnowballC
  package).

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

## Value

An object of class `sbert_topic_corpus`. Its units (one row per
document, or per segment) are given by
[as.data.frame()](https://sonsoles.me/sbert/reference/as.data.frame.sbert_topic_corpus.md);
printing it shows the number of documents and segments, the embedding
dimension, the model, and the tokenization settings.

## Conditions

Errors of class `sbert_bad_input` when both `model` and `embeddings` are
given, a document is blank, the embeddings do not have one row per unit,
the segmentation produces fewer than two segments, or `segment` is
passed together with an existing corpus; `sbert_missing_package` for
`stem = TRUE` without SnowballC. When a model is used, the errors of
[`load_model()`](https://sonsoles.me/sbert/reference/load_model.md) and
[`encode()`](https://sonsoles.me/sbert/reference/encode.md) apply.

## See also

[`topics()`](https://sonsoles.me/sbert/reference/topics.md) and
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md),
which take the corpus;
[as.data.frame()](https://sonsoles.me/sbert/reference/as.data.frame.sbert_topic_corpus.md)
for its units;
[`segment()`](https://sonsoles.me/sbert/reference/segment.md) for the
segmentation.

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
prepared <- topic_corpus(corpus, column = "translation",
                         embeddings = feedback_embeddings)
prepared
#> <sbert_topic_corpus>
#>   documents: 600 
#>   embedding dimension: 384 
#>   model: precomputed embeddings 
#>   tokenization: min_token_length = 2  
topic_sizes(topics(prepared, n_topics = 4))
#>   topic                                                     label n_documents
#> 1     1 Where is the cow and the cake? Choose all the pictures...         405
#> 2     2       What does “all the ones between the leaf and the...         143
#> 3     3  It is not a person, does not have a hat, and is sitting.          27
#> 4     4                     What does it mean to be on the grass?          25
#>   proportion
#> 1 0.67500000
#> 2 0.23833333
#> 3 0.04500000
#> 4 0.04166667
topic_sizes(topics(prepared, n_topics = 6))
#>   topic                                                       label n_documents
#> 1     1   Where is the cow and the cake? Choose all the pictures...         223
#> 2     2            All the ones between the cat and the strawberry.         133
#> 3     3         What does “all the ones between the leaf and the...         131
#> 4     4 Are you sure you have fewer pictures in the red box than...          49
#> 5     5      In the top middle box, it means something is in the...          37
#> 6     6    It is not a person, does not have a hat, and is sitting.          27
#>   proportion
#> 1 0.37166667
#> 2 0.22166667
#> 3 0.21833333
#> 4 0.08166667
#> 5 0.06166667
#> 6 0.04500000
```
