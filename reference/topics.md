# Discover Semantic Topics in Documents

Performs deterministic document-level topic clustering with
Sentence-BERT embeddings. Supply either a loaded \`model\` or a
precomputed embedding matrix. Topics are summarized with representative
documents and class-based TF-IDF terms. This is embedding-based topic
discovery, not a probabilistic LDA model.

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
  min_content = 0
)
```

## Arguments

- text:

  Character vector containing one document per element.

- n_topics:

  Number of semantic topics. Must be at least two.

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

- iter_max:

  Maximum deterministic k-means iterations.

- n_terms:

  Maximum class-based TF-IDF terms returned per topic.

- n_representatives:

  Maximum representative documents per topic.

- stop_words:

  Character vector excluded from topic terms. Use \`character()\` to
  disable stop-word filtering.

- min_term_frequency:

  Minimum corpus-wide token frequency.

- min_token_length:

  Minimum Unicode character length for a topic token.

- weighting:

  Class-based term-weighting scheme. \`"ctfidf"\` (default) uses \`tf \*
  log(1 + A / f_x)\`; \`"bm25"\` uses the BM25 inverse-frequency variant
  \`tf \* log(1 + (A - f_x + 0.5) / (f_x + 0.5))\`, which more
  aggressively down-weights terms shared across topics (Mendonca and
  Figueira 2025).

- reduce_frequent_words:

  Whether to square-root the within-topic term frequency before
  weighting, damping very frequent words.

- stem:

  Whether to collapse inflected forms (for example \`animals\` and
  \`animal\`) onto a shared Porter stem before scoring, displaying the
  most frequent surface form of each stem. Requires the \`SnowballC\`
  package.

- keep_embeddings:

  Whether to retain normalized document embeddings in the returned
  object.

- seeds:

  Optional guided topics: a character vector (or list of character
  vectors, collapsed with spaces) of seed words or topic descriptions —
  one element per seeded topic. Seeds are embedded and become the first
  \`length(seeds)\` cluster centroids; remaining topics (up to
  \`n_topics\`) are initialized away from the seeds. Seeded topics keep
  their position — topic i is seed i, never reordered by size — and a
  named \`seeds\` vector names those topics' labels. With precomputed
  \`embeddings\`, supply \`seed_embeddings\` as well.

- seed_embeddings:

  Optional matrix of seed embeddings (one row per seed, same dimension
  as the document embeddings); required when \`seeds\` is used together
  with precomputed \`embeddings\`.

- fixed_seeds:

  When \`TRUE\`, seed centroids are frozen and documents are simply
  assigned to the nearest seed (zero-shot classification into the seeded
  topics; \`n_topics\` must equal the number of seeds, and topics may be
  empty). When \`FALSE\` (default), seeds only initialize the clustering
  and the data can move the centroids.

- cores:

  Number of forked worker processes used to tokenize documents for term
  scoring. Default \`1\` (serial). Values above one use
  \`parallel::mclapply\` on Unix-alikes and fall back to serial on
  Windows or for small corpora; the tokenization — and therefore every
  result — is identical regardless of the count. Ignored when a prepared
  \[topic_corpus()\] is supplied (its tokens are already computed).

- numbers:

  How to treat purely numeric tokens (years, counts) in topic terms.
  \`"keep"\` (default) keeps them; \`"remove"\` drops tokens made only
  of digits, while retaining alphanumerics such as \`covid19\`.

- roman_numerals:

  How to treat Roman-numeral tokens (chapter, section, and list markers
  such as \`ii\`, \`iv\`, \`xii\`). \`"keep"\` (default) keeps them;
  \`"remove"\` drops canonical Roman numerals up to 100. The bound is
  deliberate: larger Roman numerals collide with common abbreviations
  that are also valid numerals (\`ml\`, \`mm\`, \`cc\`, \`ci\`, \`cv\`),
  which are always kept. A few small numerals that are also words
  (\`iv\`, \`vi\`, \`xl\`) are removed when this is on.

- section_numbers:

  How to treat section, reference, and list numbering. \`"keep"\`
  (default) keeps it; \`"remove"\` strips, before tokenizing, both
  multi-level indices (\`1.2.3\`, \`4.5.6.7\` — three or more
  dot-separated groups) and enumeration or list markers (\`1.\`, \`2.\`,
  \`figure 12.\` — a standalone one- or two-digit number followed by a
  period). Decimals (\`3.14\`), four-digit years (\`2020.\`), hyphenated
  numbers (\`covid-19.\`), and larger counts are left untouched, so
  genuine values survive even when \`numbers = "keep"\`. These filter
  only the topic terms; the document text and its embedding are
  untouched. To clean the source text itself — list markers, reference
  noise, junk characters — before encoding, see \[clean_corpus()\].

- segment:

  The unit the model is fitted on. \`"document"\` (default) embeds each
  document whole. \`"sentence"\`, \`"clause"\`, or \`"phrase"\` first
  splits every document with \[segment()\] at that level and fits the
  topics on the segments, so long documents are modelled in full instead
  of being truncated to the encoder's context window, and a document can
  span several topics. The fitted \`\$documents\` then has one row per
  segment with its parent \`document_id\` and \`segment\` position;
  \[topic_sizes()\] counts by segment or by document, \[topic_gamma()\]
  recovers each document's topic mixture from the stored segments, and
  \[predict()\] segments new text the same way. A precomputed
  \`embeddings\` matrix must then have one row per segment, aligned with
  \`segment(text, level = segment, ...)\`.

- max_tokens:

  Optional cap on segment length, passed to \[segment()\]. When a
  \`model\` is used, the budget counts that model's exact tokens; with
  precomputed \`embeddings\` it counts words. Only with a segmented fit.

- merge_below:

  Re-join segments shorter than this many words into their neighbour,
  passed to \[segment()\]. Only with a segmented fit.

- min_content:

  Minimum alphabetic-content ratio for a segment to be kept, passed to
  \[segment()\]. Only with a segmented fit.

## Value

An object of class \`sbert_topic_model\` containing unit assignments
(\`\$documents\`, one row per document or per segment), topic summaries,
ranked terms, representatives, centers, clustering diagnostics, and the
\`\$settings\` the fit was made with.

## Details

Topic labels are arbitrary cluster identifiers. Interpret them with the
ranked \`terms\` and \`representatives\` tables. Term scores use the
class-based TF-IDF weighting \`tf \* log(1 + A / f_x)\`, where \`tf\` is
the frequency of a term normalized within its topic, \`f_x\` is the
term's frequency across all topics, and \`A\` is the mean topic length
(a real number, matching Mendonca and Figueira (2025), Eq. 1). Set
\`weighting = "bm25"\` and/or \`reduce_frequent_words = TRUE\` for the
BM25 and square-root variants (their Eq. 2 to 4). The built-in tokenizer
preserves Unicode alphanumeric tokens and internal apostrophes, but does
not perform language-specific word segmentation for unspaced CJK text.

## Examples

``` r
text <- c(
  "Cats chase mice", "Dogs chase balls",
  "Stocks and bonds trade", "Markets price shares"
)
embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
topics <- topics(text, 2, embeddings = embeddings)
topics$topics
#>   topic                   label n_documents proportion    withinss
#> 1     1    chase / balls / cats           2        0.5 0.006116265
#> 2     2 bonds / markets / price           2        0.5 0.006116265

# Fit on sentences: each document is split first, and the segments are
# what the topics are made of (the embeddings here are one row per
# sentence, so no model download is needed).
documents <- c(
  "Cats chase mice. Stocks and bonds trade.",
  "Dogs chase balls. Markets price shares."
)
sentence_model <- topics(
  documents, 2,
  segment = "sentence",
  embeddings = rbind(c(1, 0), c(0, 1), c(0.9, 0.1), c(0.1, 0.9))
)
sentence_model$documents
#>   document_id document_name segment                    text topic
#> 1           1                     1        Cats chase mice.     1
#> 2           1                     2 Stocks and bonds trade.     2
#> 3           2                     1       Dogs chase balls.     1
#> 4           2                     2   Markets price shares.     2
#>                     label    distance
#> 1    chase / balls / cats 0.001530237
#> 2 bonds / markets / price 0.001530237
#> 3    chase / balls / cats 0.001530237
#> 4 bonds / markets / price 0.001530237
topic_sizes(sentence_model, by = "document")
#>   topic                   label n_documents proportion
#> 1     1    chase / balls / cats           2          1
#> 2     2 bonds / markets / price           2          1
```
