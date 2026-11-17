# Encode texts as sentence embeddings

`encode()` returns one sentence embedding per text from a pinned model
(see [`models()`](https://sonsoles.me/sbert/reference/models.md)): a
point in a vector space learned so that texts with similar meaning lie
close together, whatever words they use. Sentence-BERT models (Reimers
and Gurevych, 2019) obtain such a vector by running a transformer
encoder over the text and pooling its token vectors; the cosine of the
angle between two embeddings then measures how close the two texts are
in meaning.

Each text is tokenized with the model's own tokenizer, truncated to the
model's maximum length, run through the ONNX graph, pooled with the
model's rule ([`pool()`](https://sonsoles.me/sbert/reference/pool.md)),
and by default scaled to unit length. The static `potion-base-8M` model
instead averages looked-up token vectors and needs no ONNX Runtime. With
`cache`, embeddings are stored in a file keyed by text and model, so
encoding an edited corpus again computes only the new or changed texts.
The result is a numeric matrix with one row per text, in input order.

Encoding is the expensive step of a workflow, and every analysis in the
package (topics, the assignment of new texts, similarity) starts from
its result: encode once and pass the matrix to the `embeddings` argument
of [`topics()`](https://sonsoles.me/sbert/reference/topics.md),
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md),
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md),
[predict()](https://sonsoles.me/sbert/reference/predict.sbert_topic_model.md),
[`representatives()`](https://sonsoles.me/sbert/reference/representatives.md)
and
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md).
To split long documents into sentences or clauses first, use
[`segment()`](https://sonsoles.me/sbert/reference/segment.md). The
bundled
[feedback_embeddings](https://sonsoles.me/sbert/reference/feedback_embeddings.md)
matrix is the output of `encode()` for 600 feedback messages and lets
the examples run without a model.

## Usage

``` r
encode(
  text,
  model = NULL,
  batch_size = 32L,
  normalize = TRUE,
  prefix = NULL,
  sort_by_length = FALSE,
  cache = NULL
)
```

## Arguments

- text:

  Character vector, one text per element. Empty strings are allowed;
  `NA` is not. Names become the row names of the result.

- model:

  A model from
  [`load_model()`](https://sonsoles.me/sbert/reference/load_model.md) or
  [`load_custom()`](https://sonsoles.me/sbert/reference/load_custom.md),
  the name of a pinned model from
  [`models()`](https://sonsoles.me/sbert/reference/models.md), or `NULL`
  (default) for `"all-MiniLM-L6-v2"`. A name is loaded once per session.
  A model that is not installed is downloaded only with consent: an
  interactive prompt, or `options(sbert.download = TRUE)` in a script.

- batch_size:

  Number of texts per model call (default 32).

- normalize:

  Scale each embedding to unit L2 length (default `TRUE`).

- prefix:

  Text prepended to every input. `NULL` (default) uses the model's
  pinned prefix (for example `"query: "` for E5 models); `""` uses none.

- sort_by_length:

  Batch texts of similar length together, which reduces computation over
  padding, most of all for segments of varying length (default `FALSE`).
  The rows keep input order, but the values can differ from an unsorted
  run by floating-point rounding, enough to change the assignment of a
  rare unit on a topic boundary.

- cache:

  `NULL` (default), or the path of an `.rds` file of stored embeddings.
  Texts already stored for the same model and settings are read from the
  file; the others are encoded once each (repeats within the call
  included) and added to it. A file that cannot be read, or was written
  for another embedding dimension, is rebuilt with a warning.

## Value

A numeric matrix with one row per text, in input order, and one column
per embedding dimension of the model (the `dimensions` column of
[`models()`](https://sonsoles.me/sbert/reference/models.md)). Row names
are `names(text)`. An empty `text` gives a matrix with no rows.

## Conditions

`sbert_unknown_model` when `model` names no pinned model;
`sbert_model_not_installed` when the model is not installed and its
download is declined or not permitted; `sbert_download_failed` or
`sbert_cache_invalid` when a permitted download fails or does not
verify; `sbert_cache_invalid` when installed files fail verification;
`sbert_runtime_missing` when ONNX Runtime is not installed;
`sbert_missing_package` when the static model is loaded without
jsonlite; `sbert_model_error` when the model cannot be loaded, or
inference fails or returns non-finite values. Warning
`sbert_cache_rebuilt` when the `cache` file is unusable.

## References

Reimers, N., & Gurevych, I. (2019). Sentence-BERT: Sentence embeddings
using Siamese BERT-networks. *Proceedings of the 2019 Conference on
Empirical Methods in Natural Language Processing and the 9th
International Joint Conference on Natural Language Processing
(EMNLP-IJCNLP)*, 3982-3992.
[doi:10.18653/v1/D19-1410](https://doi.org/10.18653/v1/D19-1410)

## See also

[`load_model()`](https://sonsoles.me/sbert/reference/load_model.md) and
[`models()`](https://sonsoles.me/sbert/reference/models.md) for the
models; [`segment()`](https://sonsoles.me/sbert/reference/segment.md) to
split documents first;
[`topic_similarity()`](https://sonsoles.me/sbert/reference/topic_similarity.md)
to compare embeddings;
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) to fit
topics on them.

## Examples

``` r
# The bundled embeddings are what encode() returns for 600 feedback
# messages: one row per text, one column per model dimension.
dim(feedback_embeddings)
#> [1] 600 384
topic_similarity(head(feedback_embeddings, 3))
#>            [,1]       [,2]       [,3]
#> [1,] 1.00000000 0.36132672 0.09539736
#> [2,] 0.36132672 1.00000000 0.09345878
#> [3,] 0.09539736 0.09345878 1.00000000

# \donttest{
if (interactive()) {
  model <- load_model()
  embeddings <- encode(c("A short sentence.", "Another sentence."), model)

  # Segment-level work benefits most, because segment lengths vary widely.
  segments <- with(head(covid, 50), segment(Abstract, level = "clause"))
  embeddings <- with(segments, encode(text, model, sort_by_length = TRUE))

  # Encode once, then re-run after editing the corpus: only changed rows cost
  # anything the second time.
  store <- file.path(tempdir(), "covid-embeddings.rds")
  embeddings <- with(covid, encode(Abstract, model, cache = store))
  embeddings <- with(covid, encode(Abstract, model, cache = store))
  unlink(store)
}
# }
```
