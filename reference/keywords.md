# Extract the keywords of documents

`keywords()` extracts the keywords of each document: the words and short
phrases that best express what it is about. Embedding-based keyword
extraction compares the meaning of each candidate phrase with the
meaning of the whole document, and a phrase whose embedding is close to
the document's embedding summarizes it well; because picking the closest
phrases alone tends to return near-synonyms, the selection also rewards
phrases that differ from those already chosen, by maximal marginal
relevance (Carbonell and Goldstein 1998), as in KeyBERT (Grootendorst
2020).

The candidates are the words and phrases of up to `ngrams` consecutive
words of each document after stop words are removed; the documents and
the candidates are encoded with the same model, and up to `n` keywords
per document are selected. The result is a data frame with one row per
keyword. `keywords()` describes single documents; to describe topics,
use
[terms()](https://sonsoles.me/sbert/reference/terms.sbert_topic_model.md),
which compares the words of a topic with those of the other topics.

`keywords()` encodes text, so it needs a downloaded model.

## Usage

``` r
keywords(
  text,
  model = NULL,
  n = 10L,
  ngrams = 2L,
  topic_diversity = 0.3,
  stop_words = default_stop_words(),
  min_token_length = 3L,
  batch_size = 32L
)
```

## Arguments

- text:

  Documents: a character vector. Names, if any, are carried into
  `document_name`.

- model:

  The encoder: a model from
  [`load_model()`](https://sonsoles.me/sbert/reference/load_model.md), a
  pinned model name, or `NULL` (default) for the default model.

- n:

  Maximum number of keywords per document (default 10).

- ngrams:

  Maximum length of a candidate phrase, in words (default 2).

- topic_diversity:

  Trade-off between relevance and diversity, in `[0, 1)`: 0 ranks by
  similarity to the document alone, and larger values penalize
  candidates similar to those already chosen (default 0.3).

- stop_words:

  Words excluded from the candidates; default
  [`stop_words()`](https://sonsoles.me/sbert/reference/stop_words.md).

- min_token_length:

  Minimum length of a candidate word, in characters (default 3).

- batch_size:

  Texts encoded per model call (default 32).

## Value

A base data frame with one row per keyword and columns `document_id`,
`document_name`, `rank`, `keyword`, and `topic_similarity` (the cosine
similarity between the keyword and its document).

## Conditions

An error of class `sbert_no_terms` when no candidate is left after stop
words and short words are removed; the errors of
[`load_model()`](https://sonsoles.me/sbert/reference/load_model.md) and
[`encode()`](https://sonsoles.me/sbert/reference/encode.md).

## References

Carbonell, J. and Goldstein, J. (1998). The use of MMR, diversity-based
reranking for reordering documents and producing summaries. *Proceedings
of SIGIR 1998*, 335–336.
[doi:10.1145/290941.291025](https://doi.org/10.1145/290941.291025)

Grootendorst, M. (2020). KeyBERT: Minimal keyword extraction with BERT.
[doi:10.5281/zenodo.4461265](https://doi.org/10.5281/zenodo.4461265)

## See also

[terms()](https://sonsoles.me/sbert/reference/terms.sbert_topic_model.md)
for the terms of topics;
[`stop_words()`](https://sonsoles.me/sbert/reference/stop_words.md);
[`model_download()`](https://sonsoles.me/sbert/reference/model_download.md)
to download a model.

## Examples

``` r
# Pinned models that can encode the text
models()
#>                                    model dimensions max_tokens      languages
#> 1                       all-MiniLM-L6-v2        384        256        English
#> 2                      all-MiniLM-L12-v2        384        128        English
#> 3                paraphrase-MiniLM-L3-v2        384        128        English
#> 4              multi-qa-MiniLM-L6-cos-v1        384        512        English
#> 5  paraphrase-multilingual-MiniLM-L12-v2        384        128  50+ languages
#> 6                      all-mpnet-base-v2        768        384        English
#> 7  paraphrase-multilingual-mpnet-base-v2        768        128  50+ languages
#> 8                      bge-small-en-v1.5        384        512        English
#> 9                       bge-base-en-v1.5        768        512        English
#> 10                 multilingual-e5-small        384        512 100+ languages
#> 11                 nomic-embed-text-v1.5        768       8192        English
#> 12           jina-embeddings-v2-small-en        512       8192        English
#> 13                  mxbai-embed-large-v1       1024        512        English
#> 14                        potion-base-8M        256    1000000        English
#>    size_mb
#> 1     90.9
#> 2    133.6
#> 3     69.5
#> 4     90.9
#> 5    479.4
#> 6    436.3
#> 7   1119.2
#> 8    133.8
#> 9    436.5
#> 10   487.4
#> 11   548.0
#> 12   130.5
#> 13  1337.6
#> 14    30.9

# \donttest{
if (interactive()) {
  keywords(
    "Transition network analysis models learning event sequences.",
    n = 5
  )
}
# }
```
