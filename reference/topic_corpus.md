# Prepare a Corpus Once to Fit Many Topic Models

Runs the corpus-level work that does not depend on the number of topics
— embedding every document and tokenizing it for term scoring — a single
time, so that fitting many models (a \[select_topics()\] sweep, a manual
loop over topic counts, or repeated \[topics()\] calls) reuses it
instead of repeating it. Pass the returned object to \[topics()\] or
\[select_topics()\] in place of the raw \`text\`.

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
  cores = 1L
)
```

## Arguments

- text:

  Character vector containing one document per element.

- column:

  When \`text\` is a data frame, the name of the column holding the
  documents to model. Every other column is carried into
  \`\$documents\`, and rows whose text is missing, blank, or a
  bibliographic placeholder are dropped. Leave \`NULL\` for a character
  vector.

- model:

  A loaded \[sbert_model\]\[load_model()\], a pinned model name from
  \[models()\], or \`NULL\` for the default model. Ignored when
  \`embeddings\` are supplied.

- embeddings:

  Optional numeric matrix with one row per document; when supplied, no
  model is loaded or used.

- batch_size:

  Batch size passed to \[encode()\] when \`model\` is used.

- stop_words:

  Character vector excluded from topic terms. Use \`character()\` to
  disable stop-word filtering.

- min_token_length:

  Minimum Unicode character length for a topic token.

- stem:

  Whether to collapse inflected forms (for example \`animals\` and
  \`animal\`) onto a shared Porter stem before scoring, displaying the
  most frequent surface form of each stem. Requires the \`SnowballC\`
  package.

- cores:

  Number of forked worker processes used to tokenize documents for term
  scoring. Default \`1\` (serial). Values above one use
  \`parallel::mclapply\` on Unix-alikes and fall back to serial on
  Windows or for small corpora; the tokenization — and therefore every
  result — is identical regardless of the count. Ignored when a prepared
  \[topic_corpus()\] is supplied (its tokens are already computed).

## Value

An object of class \`sbert_topic_corpus\`: a list with the prepared
\`text\`, carried \`metadata\`, document \`embeddings\`, cached
\`token_lists\`, \`model\` information, and the fixed tokenization
\`settings\`.

## Details

The results are byte-identical to calling \[topics()\] on the raw text:
the corpus only \*caches\* the embedding and tokenization steps, it does
not change them. The corpus fixes the embedding source (\`model\` or
\`embeddings\`) and the tokenization settings (\`stop_words\`,
\`min_token_length\`, \`stem\`); \[topics()\] then refuses conflicting
overrides for those, while per-model settings (\`n_topics\`,
\`n_terms\`, \`min_term_frequency\`, \`weighting\`,
\`reduce_frequent_words\`, \`seeds\`, ...) are still chosen per call.

## See also

\[topics()\], \[select_topics()\]

## Examples

``` r
text <- c(
  "Cats chase mice", "Dogs chase balls",
  "Stocks and bonds trade", "Markets price shares"
)
embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
corpus <- topic_corpus(text, embeddings = embeddings)
topics(corpus, n_topics = 2)$topics
#>   topic                   label n_documents proportion    withinss
#> 1     1    chase / balls / cats           2        0.5 0.006116265
#> 2     2 bonds / markets / price           2        0.5 0.006116265
select_topics(corpus, n_topics = 2:3)
#> <sbert_topic_sweep> 2 candidates, coherence measure: npmi
#>  n_topics  coherence topic_diversity explained
#>         2 -0.1000000       1.0000000 0.9931506
#>         3  0.3777778       0.9166667 0.9965753
#> 
#> Fitted models retained: fitted(x, n_topics = 3)
```
