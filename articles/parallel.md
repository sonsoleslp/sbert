# Parallel and High-Throughput Topic Modeling

A topic model in **sbert** is built in three stages, and each scales
differently:

1.  **Encode** — text becomes Sentence-BERT vectors, through the ONNX
    model.
2.  **Tokenize** — text becomes terms, for the topic labels and
    coherence.
3.  **Cluster** — vectors become topics, through deterministic k-means.

The largest speed-ups come from two ideas: **do the corpus-level work
once** (encoding and tokenization depend on the corpus, not on the
number of topics), and **spread that work across cores**. Crucially,
neither changes the output — every result below is byte-identical to a
plain single-threaded run.

## Do the expensive work once

Encoding is almost always the most expensive stage, and tokenization is
the next after it once the corpus is large. Both depend only on the
documents, so computing them once and reusing them is the single biggest
lever when you fit more than one model — a topic-count sweep, a
comparison of term settings, or any loop over `n_topics`.

**Pass precomputed embeddings.** Encode once, then hand the matrix to
every fit:

``` r

model <- load_model("all-MiniLM-L6-v2", threads = 8)
embeddings <- encode(corpus$text, model, batch_size = 64)

# topics()/select_topics() now skip encoding entirely
m <- topics(corpus$text, n_topics = 8, embeddings = embeddings)
```

**Prepare a corpus once, fit many.**
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)
goes further: it caches *both* the embeddings and the tokenization, so a
sweep or loop repeats neither.

``` r

prepared <- topic_corpus(corpus$text, embeddings = embeddings)

sweep <- select_topics(prepared, n_topics = c(6, 8, 10, 12, 15))
model8 <- fitted(sweep, n_topics = 8)   # chosen without refitting
```

[`select_topics()`](https://sonsoles.me/sbert/reference/select_topics.md)
already shares one prepared corpus across all candidates internally, so
even `select_topics(corpus$text, ...)` no longer re-tokenizes per
candidate. Passing a prepared `topic_corpus` on top lets you reuse it
across *several* sweeps or manual loops.

## The two parallel knobs

### `threads` — parallel encoding

`load_model(threads = N)` sets the number of ONNX inference threads.
Every [`encode()`](https://sonsoles.me/sbert/reference/encode.md) call
that uses the loaded model then runs multithreaded:

``` r

model <- load_model("all-MiniLM-L6-v2", threads = 8)
embeddings <- encode(text, model)     # inference spread over 8 threads
```

### `cores` — parallel tokenization, segmentation, and sweeps

`cores` is available on
[`topics()`](https://sonsoles.me/sbert/reference/topics.md),
[`select_topics()`](https://sonsoles.me/sbert/reference/select_topics.md),
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md),
[`coherence()`](https://sonsoles.me/sbert/reference/coherence.md),
[`segment()`](https://sonsoles.me/sbert/reference/segment.md), and
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md).
Above one it forks worker processes to:

- **tokenize** the corpus in parallel (documents split across workers),
- in
  [`select_topics()`](https://sonsoles.me/sbert/reference/select_topics.md),
  **fit the independent candidates** in parallel, and
- in [`segment()`](https://sonsoles.me/sbert/reference/segment.md) /
  [`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md),
  **split documents** in parallel.

``` r

# tokenization runs in parallel; the corpus is prepared once
prepared <- topic_corpus(corpus$text, embeddings = embeddings, cores = 8)

# candidates are fitted across cores, tokenization already cached
sweep <- select_topics(prepared, n_topics = c(6, 8, 10, 12, 15), cores = 8)
```

**Platform notes.** `cores` uses
[`parallel::mclapply`](https://rdrr.io/r/parallel/mclapply.html), which
forks — available on Linux and macOS, and **falls back to serial on
Windows**. Forking has overhead, so parallel work only engages for
corpora of **2,000 documents or more**; smaller inputs run serially by
design. A good default is `cores = parallel::detectCores() - 1`.

## Sentence-level `topic_gamma()`

[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
reports each document’s *mixture* of topics by splitting it into
sentences (or clauses), embedding every segment, and pooling the
assignments. It has three cost stages, each with its own lever:

1.  **Segmenting** the documents — parallelize with `cores`.
2.  **Encoding** every segment — the dominant cost; multithread with
    `load_model(threads =)`, and optionally deduplicate (below).
3.  **Pooling** into per-document mixtures — already negligible.

``` r

model <- load_model("all-MiniLM-L6-v2", threads = 8)
gamma <- topic_gamma(
  topic_model, documents,
  model = model,
  level = "sentence",
  cores = 8               # split documents across cores
)
```

### Reuse the segment embeddings

Encoding is the dominant stage, so the largest — and fully reproducible
— win is to *not encode twice*. If you already have the segment
embeddings, pass them and
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
skips encoding entirely, dropping to just segmentation and pooling.
Supply one row per segment, aligned to `segment(text, level)$text`:

``` r

# segment and encode once, deterministically
segments <- segment(documents, level = "sentence", cores = 8)
segment_embeddings <- encode(segments$text, model)

# every downstream call reuses them — no re-encoding
gamma <- topic_gamma(
  topic_model, documents,
  embeddings = segment_embeddings,
  level = "sentence",
  cores = 8
)
```

This is what pays off when you run several sentence-level steps on one
corpus —
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md),
sentence-level
[`representatives()`](https://sonsoles.me/sbert/reference/representatives.md),
or a [`blend()`](https://sonsoles.me/sbert/reference/blend.md) that
carries document context into each sentence — since they can all share a
single encode.
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
re-segments internally with the same `level`, so the order is
deterministic and the rows line up. The result is byte-identical to
letting it encode; only encoded-once-versus-twice changes.

### Deduplicating repeated segments

A long corpus repeats many segments — boilerplate sentences, short stock
clauses — and a real corpus is often close to half duplicates.
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
normally encodes every occurrence; `dedupe_segments = TRUE` encodes each
*distinct* segment once and expands the result by position, which can
roughly halve the encoding cost:

``` r

gamma <- topic_gamma(
  topic_model, documents,
  model = model,
  level = "sentence",
  cores = 8,
  dedupe_segments = TRUE
)
```

**One-time shift, not free reproducibility.** Deduplication is **off by
default** because encoding a smaller batched set perturbs the embeddings
at the ~1e-7 level, which can flip a rare borderline segment’s
assignment — the same trade-off as changing `batch_size`. With the
static `potion-base-8M` model, whose encoding has no batch effect, the
result is identical either way.

## The maximum-speed recipe

Putting it together for the common case — one corpus, several models:

``` r

library(sbert)
install_runtime()

# 1. Multithreaded encoding, once
model <- load_model("all-MiniLM-L6-v2", threads = 8)
embeddings <- encode(corpus$text, model, batch_size = 64)

# 2. Prepare the corpus once (encode + tokenize cached), tokenizing in parallel
prepared <- topic_corpus(corpus$text, embeddings = embeddings, cores = 8)

# 3. Sweep across cores, then pick a model with no refit
sweep <- select_topics(prepared, n_topics = c(6, 8, 10, 12, 15), cores = 8)
model8 <- fitted(sweep, n_topics = 8)
```

For a corpus so large that encoding dominates and some quality can be
traded for throughput, the static `potion-base-8M` model embeds around
10,000 sentences per second in pure R, with no ONNX Runtime involved:

``` r

fast <- load_model("potion-base-8M")   # 31 MB, Model2Vec token lookup
embeddings <- encode(corpus$text, fast)
```

## What to expect

Measured on a 10-core Apple Silicon machine (macOS, Accelerate BLAS, R
4.5) with precomputed embeddings. Wall-clock carries some machine-load
variance; the speed-ups grow with the number of models fitted and with
document length.

| Workload | Baseline | Serial | 8 cores |
|----|---:|---:|---:|
| Sweep, 5 counts, 15k short docs | 163.5 s | 12.2 s (13×) | **6.9 s (24×)** |
| Sweep, 3 counts, 5k long docs (~8k chars) | 321.1 s | 56.0 s (5.7×) | **10.3 s (31×)** |
| Tokenization, 15k short docs | — | 11.7 s | **3.1 s (3.8×)** |
| Tokenization, 5k long docs | — | 52.5 s | **8.6 s (6.1×)** |

The “baseline” column is the pre-reuse path that re-encoded and
re-tokenized on every model. Two patterns stand out: longer documents
make parallel tokenization pay off *more* (6.1× vs 3.8×), and the
corpus-reuse win scales with the number of models — roughly 3.5× at five
models and 4× at ten.

Memory improves independently of document length, because clustering
works on the embeddings, not the raw text: at 40 topics, peak memory for
a 40,000-document run dropped from about 2,195 MB to 1,053 MB.

## Reproducibility

**`cores` and `threads` change speed, never results.** Tokenization is
split by document and recombined in order, and sweep candidates are
independent and deterministic, so the output is identical for any core
or thread count. There is no random seed anywhere in the topic pipeline.

The proof runs offline — the same model, fitted single-threaded and
across four cores, is byte-identical:

``` r

set.seed(1)
n <- 2500L
text <- paste(
  "document", seq_len(n),
  sample(c("alpha beta gamma", "delta epsilon zeta", "eta theta iota"), n, TRUE)
)
# clustered stand-in embeddings, so no model download is needed
centers <- matrix(rnorm(8L * 64L), 8L, 64L)
embeddings <- centers[sample(8L, n, replace = TRUE), ] +
  matrix(rnorm(n * 64L, sd = 0.6), n, 64L)

serial   <- topics(text, n_topics = 6, embeddings = embeddings, cores = 1)
parallel <- topics(text, n_topics = 6, embeddings = embeddings, cores = 4)

identical(
  serial[c("documents", "topics", "terms", "representatives", "centers")],
  parallel[c("documents", "topics", "terms", "representatives", "centers")]
)
#> [1] TRUE
```

**One knob is not free: `batch_size`.** Larger batches speed up ONNX
encoding, but batch composition perturbs the embeddings at roughly the
1e-7 level, which can flip a rare cluster assignment. Pick a
`batch_size` and keep it — results are reproducible for a fixed value,
just not necessarily across different ones.

## Checklist

- **Fitting many models on one corpus?** Use
  [`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)
  (or precompute `embeddings`) so encoding and tokenization happen once.
  This is where the order-of-magnitude wins are.
- **Encoding is the bottleneck?** Raise `load_model(threads = N)` and
  `batch_size`, or switch to the `potion-base-8M` static model.
- **On Linux or macOS with a big corpus (≥ 2,000 docs)?** Add
  `cores = detectCores() - 1` to
  [`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)
  /
  [`select_topics()`](https://sonsoles.me/sbert/reference/select_topics.md).
- **On Windows, or a small corpus?** `cores` safely no-ops to serial;
  rely on reuse and `threads` instead.
- **Need exact reproducibility?** `cores` and `threads` are safe at any
  value; fix `batch_size` once and leave it.
