# Parallel and High-Throughput Topic Modeling

A topic model in **sbert** is built in three stages:

1.  **Encode**: each text becomes an embedding, computed by the ONNX
    model.
2.  **Tokenize**: each text is split into words, which label the topics
    and measure their coherence.
3.  **Cluster**: the embeddings are grouped into topics by k-means.

Encoding takes far longer than the other two stages. A large corpus is
therefore fast to model mainly when it is encoded as few times as
possible. This article shows how, in order of how much time each step
saves:

1.  Encode a corpus once and reuse the result, within a session and
    across sessions.
2.  Use several processor cores and threads.
3.  Avoid wasted work when encoding sentences.

None of these steps changes the topics, except three settings that are
flagged below.

Only the last code chunk runs when this article is built. The others
need a downloaded model, so they are shown but not run. They use the
`covid` abstracts that ship with the package:

``` r

abstracts <- subset(covid, Abstract != "[No abstract available]")
```

## Encode once, fit many times

[`topics()`](https://sonsoles.me/sbert/reference/topics.md) and
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
encode the text themselves. If you fit several models to the same
corpus, encode it once with
[`encode()`](https://sonsoles.me/sbert/reference/encode.md) and pass the
result as `embeddings`:

``` r

embeddings <- encode(abstracts$Abstract)

model_8 <- topics(abstracts, column = "Abstract", n_topics = 8, embeddings = embeddings)
model_12 <- topics(abstracts, column = "Abstract", n_topics = 12, embeddings = embeddings)
```

[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)
goes one step further. It stores both the embeddings and the tokenized
words, so later fits repeat neither:

``` r

prepared <- topic_corpus(abstracts, column = "Abstract", embeddings = embeddings)

sweep <- compare_topics(prepared, n_topics = c(6, 8, 10, 12))
model_8 <- fitted(sweep, n_topics = 8)
```

[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
already prepares the corpus once for all the counts it compares. A
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)
object is useful when you run several sweeps, or your own loop, on the
same text.

## Reuse embeddings across sessions

`encode(cache = )` saves embeddings to a file and reads them back the
next time. Each text is stored under a SHA-256 digest of the text and
the model’s settings, so only texts that are not yet in the file are
encoded:

``` r

store <- file.path(tools::R_user_dir("sbert", "cache"), "covid_embeddings.rds")

embeddings <- encode(abstracts$Abstract, cache = store)  # encodes everything
embeddings <- encode(abstracts$Abstract, cache = store)  # encodes nothing
```

Because each text has its own entry, the cache also works when the
corpus changes. If you correct some abstracts, add new ones, reorder the
rows, or take a subset, only the new or changed texts are encoded.
Repeated texts are encoded once per call.

The digest covers the text exactly as the model sees it (including any
`prefix`) and the model’s name, revision, dimension, maximum length,
pooling, and `normalize`. Change any of these and the texts are encoded
again; a different model never reuses another model’s embeddings.

`batch_size` and `sort_by_length` are not part of the digest. They
change embeddings only by about 1e-7, and including them would make the
cache miss every time the batch size changed. A cached embedding is
therefore the one computed the first time, whatever the batch size of
later calls.

## Use several threads and cores

### `threads`: encoding

`load_model(threads = )` sets how many threads the ONNX model uses to
encode. `threads = "auto"` uses the number of performance cores on Apple
Silicon and half the logical cores elsewhere. Encoding speeds up only up
to the number of performance cores; more threads than that can make it
slower.

``` r

model <- load_model("all-MiniLM-L6-v2", threads = "auto")
embeddings <- encode(abstracts$Abstract, model)
```

The number of threads never changes the embeddings.

### `cores`: tokenizing, splitting, and comparing

`cores` is an argument of
[`topics()`](https://sonsoles.me/sbert/reference/topics.md),
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md),
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md),
[`coherence()`](https://sonsoles.me/sbert/reference/coherence.md),
[`segment()`](https://sonsoles.me/sbert/reference/segment.md), and
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md).
With more than one core, these functions tokenize and split documents in
parallel, and
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
fits its topic counts in parallel.

``` r

prepared <- topic_corpus(
  abstracts, column = "Abstract", embeddings = embeddings, cores = 4
)
sweep <- compare_topics(prepared, n_topics = c(6, 8, 10, 12), cores = 4)
```

`cores` uses
[`parallel::mclapply()`](https://rdrr.io/r/parallel/mclapply.html),
which works on Linux and macOS. On Windows, and for inputs of fewer than
2,000 texts, the work runs on one core, because starting extra processes
would cost more than it saves.

## Encoding sentences efficiently

Splitting documents into sentences multiplies the number of texts to
encode. Two settings reduce that cost.

`sort_by_length = TRUE` encodes texts of similar length together. Every
text in a batch is padded to the length of the longest one, so a batch
of mixed lengths spends much of its time on padding. The more the
lengths vary, as they do for sentences and clauses, the more this saves.

`dedupe_segments = TRUE` in
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
encodes each distinct sentence only once. How much it saves depends on
how often sentences repeat in your corpus.

``` r

gamma <- topic_gamma(
  model_8, abstracts$Abstract,
  model = model,
  level = "sentence",
  sort_by_length = TRUE,
  dedupe_segments = TRUE,
  cores = 4
)
```

Both settings are off by default, because they change which texts share
a batch and therefore move the embeddings by about 1e-7. That can,
rarely, move a sentence that lies on the border between two topics.

The cheapest route is to fit the model on sentences in the first place.
`topics(segment = "sentence")` splits, encodes, and stores every
sentence with its abstract, so
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
needs no further encoding:

``` r

sentence_model <- topics(
  abstracts,
  column = "Abstract",
  n_topics = 8,
  segment = "sentence",
  model = model,
  cores = 4
)
topic_gamma(sentence_model)
```

## The static model

`potion-base-8M` is a static model: it looks up a vector for each word
and averages them, without a neural network and without the ONNX
Runtime. It encodes much faster than `all-MiniLM-L6-v2`, but it ignores
word order. Whether its topics are as good depends on the corpus, so
compare the two with
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
before you switch.

``` r

fast <- load_model("potion-base-8M")
embeddings <- encode(abstracts$Abstract, fast)
```

## Results do not depend on cores or threads

Tokenization is split by document and put back together in order, and
every topic count is fitted independently, so `cores` never changes the
result. The topic model itself uses no random numbers. The chunk below
runs when the article is built: it fits the same model on one core and
on four and compares the results. It uses random vectors in place of
real embeddings, so it needs no download.

``` r

set.seed(1)
n <- 2500L
text <- paste(
  "document", seq_len(n),
  sample(c("alpha beta gamma", "delta epsilon zeta", "eta theta iota"), n, TRUE)
)
centers <- matrix(rnorm(8L * 64L), 8L, 64L)
embeddings <- centers[sample(8L, n, replace = TRUE), ] +
  matrix(rnorm(n * 64L, sd = 0.6), n, 64L)

one_core <- topics(text, n_topics = 6, embeddings = embeddings, cores = 1)
four_cores <- topics(text, n_topics = 6, embeddings = embeddings, cores = 4)

all.equal(terms(one_core), terms(four_cores))
#> [1] TRUE
all.equal(topic_sizes(one_core), topic_sizes(four_cores))
#> [1] TRUE
```

On Windows both fits run on one core, so the comparison is trivially
true there.

## Summary

- Fitting several models to one corpus: pass `embeddings`, or use
  [`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md).
- Running the same corpus again later: use `encode(cache = )`.
- Encoding is slow: use `load_model(threads = "auto")`, or try the
  `potion-base-8M` model.
- Large corpus on Linux or macOS: set `cores`.
- Sentence-level models: use `sort_by_length = TRUE`, or fit with
  `segment = "sentence"`.
- Exact reproducibility: `cores`, `threads`, and `cache` never change
  results. Keep `batch_size`, `sort_by_length`, and `dedupe_segments`
  fixed once chosen.
