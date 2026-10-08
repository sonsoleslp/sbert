# Extract Keywords from Documents by Embedding Similarity

Ranks each document's own words and phrases by cosine similarity between
their embeddings and the document embedding, computed with the same
model, and selects the top \`n\` by maximal marginal relevance so the
keywords are relevant without being redundant (the KeyBERT design).

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

  A character vector of documents. Names, when present, are carried into
  the \`document_name\` column.

- model:

  A loaded sbert model, a pinned model name, or \`NULL\` for the session
  default.

- n:

  Maximum keywords returned per document. Default \`10\`.

- ngrams:

  Maximum phrase length in tokens. Default \`2\` (unigrams and bigrams).

- topic_diversity:

  Maximal-marginal-relevance trade-off in \`\[0, 1)\`: \`0\` ranks
  purely by similarity, larger values penalize keywords similar to ones
  already selected. Default \`0.3\`.

- stop_words:

  Words excluded from candidates. Defaults to \[stop_words()\].

- min_token_length:

  Minimum character length of a candidate token. Default \`3\`.

- batch_size:

  Number of texts encoded per model call. Default \`32\`.

## Value

A base data frame with one row per keyword and columns \`document_id\`,
\`document_name\`, \`rank\`, \`keyword\`, and \`topic_similarity\`
(cosine similarity between the keyword and its document).

## Details

Candidates are consecutive-token n-grams (lengths \`1\` to \`ngrams\`)
drawn from the document after stop-word removal, so a candidate phrase
never crosses a removed stop word silently: "analysis of networks"
yields the candidates "analysis", "networks", and "analysis networks".

## Examples

``` r
# Pinned models that can encode the text.
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
