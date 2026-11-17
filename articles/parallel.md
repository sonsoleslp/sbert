# Parallel and high-throughput topic modeling

A topic model in `sbert` is built in three stages. Each text is encoded
into an embedding by a neural model; each text is tokenized into words,
which label the topics and measure their coherence; and the embeddings
are clustered into topics by k-means. Encoding is by far the most
expensive of the three, because it runs a transformer over every text,
while tokenization and clustering are base-R operations on data already
in memory. A large corpus is therefore fast to model mainly when it is
encoded as few times as possible, and only then when the remaining work
uses the processor cores the machine has.

Speed is worth little if it changes the answer. A setting that makes a
fit faster but moves a document to another topic would make results
depend on the machine they were computed on. This guide covers, in order
of the time they save, reusing embeddings within and across sessions,
threads and cores, and the settings that reduce the cost of encoding
sentences, and for each it states whether the result can change.

``` r

library(sbert)
#> sbert 0.6.0: Sentence-BERT embeddings and topic models in R.
#>   14 pinned models (see models()); default: all-MiniLM-L6-v2.
#>   A model is downloaded only on request, once, and verified by SHA-256.
```

## Data

Two corpora are used. The steps that need no model run on the feedback
messages, whose embeddings are bundled; the steps that encode are shown
on the COVID-19 abstracts and are not run, because they need a
downloaded model (see [models and the
cache](https://sonsoles.me/sbert/articles/models-and-cache.md)).

- **`corpus`:** the first 600 distinct English feedback messages
  (`translation`), with their source-language text (`feedback`) and
  number of occurrences (`n`). Their `all-MiniLM-L6-v2` embeddings are
  the bundled matrix `feedback_embeddings`, one row per message.
- **`abstracts`:** the `covid` abstracts with an abstract (`Abstract`).

``` r

corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
abstracts <- subset(covid, Abstract != "[No abstract available]")
c(messages = nrow(corpus), abstracts = nrow(abstracts))
#>  messages abstracts 
#>       600      3847
```

The feedback corpus has 600 messages and the abstracts 3,847 texts.

## Encode once, fit many times

[`topics()`](https://sonsoles.me/sbert/reference/topics.md) and
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
encode the texts themselves when given a model. An analysis rarely fits
one model, so the first saving is to encode once with
[`encode()`](https://sonsoles.me/sbert/reference/encode.md) and pass the
matrix as `embeddings` to every fit.

``` r

model <- load_model("all-MiniLM-L6-v2")
embeddings <- with(abstracts, encode(Abstract, model))

model_8 <- topics(abstracts, column = "Abstract", n_topics = 8,
                  embeddings = embeddings)
model_12 <- topics(abstracts, column = "Abstract", n_topics = 12,
                   embeddings = embeddings)
```

Each fit still tokenizes the texts.
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)
goes one step further: it stores the embeddings and the tokenized words
together, so that later fits repeat neither. On the feedback messages:

``` r

prepared <- topic_corpus(corpus, column = "translation",
                         embeddings = feedback_embeddings)
prepared
#> <sbert_topic_corpus>
#>   documents: 600 
#>   embedding dimension: 384 
#>   model: precomputed embeddings 
#>   tokenization: min_token_length = 2
direct <- topics(corpus, n_topics = 6, column = "translation",
                 embeddings = feedback_embeddings)
from_corpus <- topics(prepared, n_topics = 6)
identical(as.data.frame(direct), as.data.frame(from_corpus))
#> [1] TRUE
identical(terms(direct), terms(from_corpus))
#> [1] TRUE
```

The prepared corpus holds 600 documents with 384-dimensional embeddings.
The model fitted to it is identical to the model fitted to the raw
texts, in its document table and in its terms: the corpus saves work and
changes nothing. It also fixes the segmentation and tokenization
settings, so a later call that asks for different ones is refused with
an error rather than silently re-tokenized.

[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
prepares a corpus itself, once for all the counts it compares. A
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)
object is useful when several comparisons, or fits one at a time, are
run on the same texts.

## Reuse embeddings across sessions

`encode(cache = )` writes embeddings to a file and reads them back the
next time. Each text is stored under a SHA-256 digest of the text and
the model’s settings, so only texts that are not yet in the file are
encoded.

``` r

store <- file.path(cache_dir(), "covid_embeddings.rds")
embeddings <- with(abstracts, encode(Abstract, model, cache = store))  # encodes all
embeddings <- with(abstracts, encode(Abstract, model, cache = store))  # encodes none
```

Because each text has its own entry, the cache also serves a corpus that
changes. If some abstracts are corrected, new ones added, rows reordered
or a subset taken, only the new or changed texts are encoded. Texts
repeated within one call are encoded once.

The digest covers the text exactly as the model sees it, including any
`prefix`, and the model’s name, revision, dimension, maximum length,
pooling and `normalize`. Change any of these and the texts are encoded
again; a different model never reuses another model’s embeddings.

`batch_size` and `sort_by_length` are not part of the digest. They
change which texts share a batch, which moves embeddings by about 1e-7,
and including them would make the cache miss whenever the batch size
changed. A cached embedding is therefore the one computed the first
time, whatever the batch settings of later calls. A cache file that
cannot be read, or was written for another embedding dimension, is
rebuilt with a warning of class `sbert_cache_rebuilt`.

## Threads: encoding

`load_model(threads = )` sets how many threads ONNX Runtime uses to
encode. Encoding is the only part of the package that uses threads. The
default is one thread, which keeps runs comparable across machines.

``` r

model <- load_model("all-MiniLM-L6-v2", threads = "auto")
embeddings <- with(abstracts, encode(Abstract, model))
```

`threads = "auto"` uses the number of performance cores on Apple Silicon
and half the logical cores elsewhere, at most eight. Encoding gains from
threads only up to the number of performance cores; efficiency cores add
contention rather than speed. The gain depends on the machine and is
noisy from run to run, so a thread count is best chosen by timing a few
repeated encodes of the corpus at hand.
[`?load_model`](https://sonsoles.me/sbert/reference/load_model.md)
reports the package’s own measurements, including that the embeddings
were identical at every thread count measured.

## Cores: tokenizing, splitting and comparing

`cores` is an argument of
[`topics()`](https://sonsoles.me/sbert/reference/topics.md),
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md),
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md),
[`coherence()`](https://sonsoles.me/sbert/reference/coherence.md),
[`segment()`](https://sonsoles.me/sbert/reference/segment.md) and
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md).
With more than one core, these functions tokenize and split documents in
forked worker processes, and
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
also fits its candidate numbers of topics in parallel. Forking uses
[`parallel::mclapply()`](https://rdrr.io/r/parallel/mclapply.html),
which is available on Linux and macOS; on Windows everything runs on one
core.

Tokenizing and splitting run on one core when there are fewer than 2,000
texts, because starting processes would cost more than it saves. Fitting
the candidates of
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
has no such threshold: each candidate is a separate k-means fit, so with
`cores = 2` two candidates are fitted at once even on a small corpus.
The result is the same either way.

``` r

one_core <- compare_topics(prepared, n_topics = c(4, 6, 8, 10), cores = 1)
two_cores <- compare_topics(prepared, n_topics = c(4, 6, 8, 10), cores = 2)
one_core
#> <sbert_topic_sweep> 4 candidates, coherence measure: npmi
#>  n_topics coherence topic_diversity explained converged
#>         4    -0.207           0.925     0.123      TRUE
#>         6    -0.104           0.917     0.226      TRUE
#>         8    -0.118           0.900     0.243      TRUE
#>        10    -0.187           0.860     0.256      TRUE
#> 
#> Fitted models retained: fitted(x, n_topics = 6)
identical(as.data.frame(one_core), as.data.frame(two_cores))
#> [1] TRUE
identical(as.data.frame(fitted(one_core, n_topics = 8)),
          as.data.frame(fitted(two_cores, n_topics = 8)))
#> [1] TRUE
```

The comparison tables are identical, and so are the fitted eight-topic
models taken from them. Every candidate is fitted independently and
deterministically, and no random numbers are drawn in a fit, so the
order in which the workers finish cannot matter.

Splitting is parallel only above 2,000 texts, so the abstracts show it.

``` r

serial <- with(abstracts, segment(Abstract, level = "sentence", cores = 1))
forked <- with(abstracts, segment(Abstract, level = "sentence", cores = 2))
nrow(forked)
#> [1] 35151
identical(serial, forked)
#> [1] TRUE
```

The 3,847 abstracts are split into 35,151 sentences on one core and, on
Linux and macOS, on two worker processes, with identical results: each
document is split independently and the pieces are put back in input
order. On Windows both calls run on one core, and the comparison is
identical trivially.

For a large corpus on Linux or macOS, the full set of cores is set once
and reused.

``` r

prepared_abstracts <- topic_corpus(abstracts, column = "Abstract",
                                   embeddings = embeddings, cores = 4)
sweep <- compare_topics(prepared_abstracts, n_topics = c(6, 8, 10, 12),
                        cores = 4)
```

## Encoding sentences efficiently

Splitting documents into sentences, as described in [segmenting long
documents](https://sonsoles.me/sbert/articles/segmenting.md), multiplies
the number of texts to encode. Two settings reduce that cost.

`sort_by_length = TRUE` (in
[`encode()`](https://sonsoles.me/sbert/reference/encode.md) and
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md))
encodes texts of similar length together. Every text in a batch is
padded to the length of the longest one, so a batch of mixed lengths
spends much of its work on padding. The more the lengths vary, as they
do for sentences and clauses, the more sorting saves.
`dedupe_segments = TRUE` in
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
encodes each distinct segment once; the saving depends on how often
segments repeat.

``` r

gamma <- with(abstracts, topic_gamma(
  model_8, Abstract,
  model = model,
  level = "sentence",
  sort_by_length = TRUE,
  dedupe_segments = TRUE,
  cores = 4
))
```

Both settings are off by default because they change which texts share a
batch, which moves embeddings by about 1e-7. That can, rarely, move a
segment that lies on the border between two topics. Once chosen, they
should be kept fixed for the whole analysis.

The cheapest route is to fit the model to sentences in the first place.
`topics(segment = "sentence")` splits, encodes and stores every sentence
with its abstract, so
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
needs no further encoding:

``` r

sentence_model <- topics(abstracts, column = "Abstract", n_topics = 8,
                         segment = "sentence", max_tokens = 256,
                         model = model, cores = 4)
topic_gamma(sentence_model)
```

## The static model

`potion-base-8M` is a static model: it looks up a vector for each token
and averages them, with no neural network and no ONNX Runtime. Encoding
is therefore far cheaper than with `all-MiniLM-L6-v2`, but the average
ignores word order. Whether its topics are as good depends on the
corpus, so the two are best compared with
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
before switching.

``` r

fast <- load_model("potion-base-8M")
fast_embeddings <- with(abstracts, encode(Abstract, fast))
compare_topics(abstracts, n_topics = c(6, 8, 10, 12), column = "Abstract",
               embeddings = fast_embeddings)
```

## Which setting for which bottleneck

- Several models on one corpus: pass `embeddings`, or prepare a
  [`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)
  once.
- The same corpus in a later session, or an edited corpus:
  `encode(cache = )`.
- Slow encoding: `load_model(threads = "auto")`, or the static
  `potion-base-8M`.
- A large corpus, or many candidate counts, on Linux or macOS: `cores`.
- Sentence-level models: `sort_by_length = TRUE`, or fit with
  `segment = "sentence"`.
- Exact reproducibility: `cores` and `cache` do not change results, and
  [`?load_model`](https://sonsoles.me/sbert/reference/load_model.md)
  reports none from `threads`; `batch_size`, `sort_by_length` and
  `dedupe_segments` can move embeddings by about 1e-7, so they are fixed
  once chosen. The [verification
  guide](https://sonsoles.me/sbert/articles/verification.md) shows how
  determinism is tested.
