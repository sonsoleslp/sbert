# Parallel and High-Throughput Topic Modeling

A topic model in **sbert** is built in three stages, and each scales
differently:

1.  **Encode** — text becomes Sentence-BERT vectors, through the ONNX
    model.
2.  **Tokenize** — text becomes terms, for the topic labels and
    coherence.
3.  **Cluster** — vectors become topics, through deterministic k-means.

Encoding dominates everything else. On the bundled `covid` abstracts it
costs **16.7 ms per document against 0.4 ms for the entire clustering,
term-weighting and labelling stage** — roughly 97% of the total. Within
a batch, ONNX inference is 88% and everything R does is the remaining
12%. So the question is never “how do I make the topic model faster”; it
is “how do I encode less”.

There are three answers, in descending order of payoff: **don’t encode
the same text twice** (across sessions, with `cache`; within one, with
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)),
**don’t encode padding** (`sort_by_length`), and **spread the work
across cores** (`threads`, `cores`). The first is worth two orders of
magnitude; the others are worth tens of percent.

Nothing here changes what you get. `cache`, `cores` and `threads` are
exactly reproducible; the three knobs that are not are flagged where
they appear.

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

## Reuse across sessions: `encode(cache =)`

Everything above reuses work *within* one R session. `cache` reuses it
across sessions, across scripts, and — crucially — across **edits to the
corpus**.

Give [`encode()`](https://sonsoles.me/sbert/reference/encode.md) a file
path and each document is stored under a digest of its own text plus the
model configuration. On the next call, only documents with no matching
entry are encoded:

``` r

store <- "embeddings/covid.rds"

embeddings <- encode(covid$Abstract, model, cache = store)   # cold: full price
embeddings <- encode(covid$Abstract, model, cache = store)   # warm: no encoding
```

Because the key is per document rather than per corpus, an *edited*
corpus reuses everything that did not change. Correct a few abstracts,
append this year’s records, reorder the rows, or take a subset — only
genuinely new text is encoded:

``` r

corrected <- fix_a_few_records(covid$Abstract)

# encodes only the records whose text actually changed
embeddings <- encode(corrected, model, cache = store)
```

Measured on the bundled 3,847-abstract `covid` corpus:

| Call                       |               Time | Versus a full encode |
|----------------------------|-------------------:|---------------------:|
| Cold — builds the cache    |            36.59 s |                    — |
| Warm — nothing changed     |         **0.07 s** |             **515×** |
| After editing 38 documents |         **0.41 s** |              **89×** |
| Reordered or subset corpus | no encoding at all |                    — |

Repeated documents are also encoded only once per call and expanded by
position: 295 of those 3,847 abstracts are duplicates of another, so a
cold run already skips 7.7% of the work.

**What is in the key.** The document text as the tokenizer sees it (so
any `prefix` is included), plus the model id, revision, dimension,
maximum length, pooling method, and `normalize`. Change any of them and
you get a miss, not a stale hit — a second model never reuses the first
model’s rows.

**Stable to first computation, not to every batching.** `batch_size` and
`sort_by_length` are deliberately *not* in the key, because they move
embeddings only at the ~1e-7 level and including them would destroy
reuse whenever you changed a batch size. Cached rows therefore reproduce
whatever computed them first, rather than being bit-identical to a fresh
encode under different batching. A cache that cannot be read, or that
was written for a different embedding dimension, is discarded with a
warning and rebuilt rather than trusted.

## The two parallel knobs

### `threads` — parallel encoding

`load_model(threads = N)` sets the number of ONNX inference threads, and
every [`encode()`](https://sonsoles.me/sbert/reference/encode.md) call
using that model runs multithreaded. Use `"auto"` to get the machine’s
performance-core count:

``` r

model <- load_model("all-MiniLM-L6-v2", threads = "auto")
embeddings <- encode(text, model)
```

Expect a modest gain, and do not simply raise it to the core count.
Inference scales with *performance* cores, not logical ones. Median of
three repetitions at 200, 600 and 1,500 documents on an Apple M4 (4
performance + 6 efficiency cores, so `detectCores()` reports 10):

| Threads |  Speed-up |                                           |
|--------:|----------:|-------------------------------------------|
|       1 |     1.00× |                                           |
|       2 |     1.22× |                                           |
|   **4** | **1.29×** | best — matches the performance-core count |
|       6 |     1.22× | efficiency cores add contention           |
|       8 |     1.18× | slower still                              |

Past four threads the wall clock gets *worse* while CPU time climbs
steeply. `threads = "auto"` picks that knee for you.

**Threads never change results.** Output was
[`identical()`](https://rdrr.io/r/base/identical.html) at every thread
count across all 45 measured runs. Unlike `batch_size`, this knob is
numerically free.

**Benchmark threaded code with repetition.** Run-to-run spread reached
26% at the smallest corpus size, against under 3% single-threaded. A
single timing run is not evidence.

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
2.  **Encoding** every segment — the dominant cost; group by length with
    `sort_by_length`, multithread with `load_model(threads =)`, and
    optionally deduplicate (below).
3.  **Pooling** into per-document mixtures — already negligible.

Measured at clause level on 300 abstracts, the split is stark:
**encoding 91.2%, segmenting 8.5%, pooling 0.2%**.
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md) is
expensive because of fan-out — those 300 documents become 3,621 clauses,
twelve units to encode for every one that
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) handles.

``` r

model <- load_model("all-MiniLM-L6-v2", threads = "auto")
gamma <- topic_gamma(
  topic_model, documents,
  model = model,
  level = "sentence",
  cores = 8               # split documents across cores
)
```

### `sort_by_length` — the single biggest lever here

Every sequence in a batch is padded to the longest member, so a batch
costs the model its *maximum* length, not its mean. Segments vary
enormously in length — a three-word clause batched beside a 119-token
one pays for 119 tokens. Grouping similar lengths together removes most
of that waste:

| Ordering                  | Token work that is pure padding |
|---------------------------|--------------------------------:|
| Input order, clause level |                       **60.1%** |
| Sorted by length          |                            1.6% |

``` r

gamma <- topic_gamma(
  topic_model, documents,
  model = model,
  level = "clause",
  sort_by_length = TRUE     # 1.89x measured at clause level
)
```

Whole documents gain far less (1.08×) because abstracts are already of
similar length. This is a segment-level optimization. Row order is
always restored, so the result lines up with your input regardless.

**Off by default, same ~1e-7 reason.** Regrouping changes batch
composition, so embeddings move at the 1e-7 level — the same trade-off
as `dedupe_segments`. On the bundled `covid` corpus that drift changed
**no** `gamma` value and **no** document’s dominant topic, but it is
opt-in rather than assumed.

### Segment once, reuse everywhere

Encoding is the dominant stage, so the largest — and fully reproducible
— win is to *not encode twice*. Segment the corpus once, encode those
segments, then hand both the segments **and** their embeddings to
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md):
it uses your segmentation as-is and skips encoding entirely, dropping to
just pooling.

``` r

# segment and encode once, deterministically
segments <- segment(documents, level = "sentence", cores = 8)
segment_embeddings <- encode(segments$text, model)

# pass the segment() frame itself, not raw documents — the rows already align
gamma <- topic_gamma(topic_model, segments, embeddings = segment_embeddings)
```

[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
accepts either raw documents (which it segments internally) or the data
frame [`segment()`](https://sonsoles.me/sbert/reference/segment.md)
returns. Passing the frame means there is no second, internal
segmentation to disagree with your embeddings — the rows line up by
construction. That matters the moment you segment with anything other
than the defaults, for example capping segment length so nothing is
truncated:

``` r

segments <- segment(documents, level = "sentence", max_tokens = 256, model = model)
gamma <- topic_gamma(topic_model, segments, embeddings = encode(segments$text, model))
```

One segmentation, one encode, reused across every sentence-level step —
this
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md),
sentence-level
[`representatives()`](https://sonsoles.me/sbert/reference/representatives.md),
or a [`blend()`](https://sonsoles.me/sbert/reference/blend.md) that
carries document context into each sentence.

### Deduplicating repeated segments

A long corpus repeats segments — boilerplate sentences, short stock
clauses — and `dedupe_segments = TRUE` encodes each *distinct* segment
once, expanding the result by position. How much this saves depends
entirely on how repetitive your corpus is, so measure before reaching
for it:

``` r

segments <- segment(documents, level = "clause")
1 - length(unique(segments$text)) / nrow(segments)   # duplicate fraction
```

The bundled `covid` abstracts are only 15% duplicated at clause level
and 8% at sentence level, so deduplication adds about 3% there on top of
`sort_by_length`. A corpus of templated or boilerplate-heavy text will
do far better.

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

# 1. Multithreaded encoding, once, cached to disk for every future session
model <- load_model("all-MiniLM-L6-v2", threads = "auto")
embeddings <- encode(corpus$text, model, cache = "embeddings/corpus.rds")

# 2. Prepare the corpus once (encode + tokenize cached), tokenizing in parallel
prepared <- topic_corpus(corpus$text, embeddings = embeddings, cores = 8)

# 3. Sweep across cores, then pick a model with no refit
sweep <- select_topics(prepared, n_topics = c(6, 8, 10, 12, 15), cores = 8)
model8 <- fitted(sweep, n_topics = 8)
```

Re-run that script tomorrow, or after editing a handful of records, and
step 1 costs almost nothing.

### The static model

For a corpus so large that encoding dominates, the static
`potion-base-8M` model embeds with no transformer and no ONNX Runtime at
all — measured **45× faster** than `all-MiniLM-L6-v2`:

``` r

fast <- load_model("potion-base-8M")   # 31 MB, Model2Vec token lookup
embeddings <- encode(corpus$text, fast)
```

**Not simply “faster but worse” — test it on your corpus.** On the
`covid` abstracts it scored *better* than `all-MiniLM-L6-v2` on NPMI,
UMass and topic diversity at 4 of 5 topic counts. On the bundled
`feedback_translations` it lost on 2 of 5, 1 of 5 and 0 of 5
respectively. The advantage is corpus-specific and does not generalize,
which is exactly why it is not the default. Sweep both with
[`select_topics()`](https://sonsoles.me/sbert/reference/select_topics.md)
and compare
[`coherence()`](https://sonsoles.me/sbert/reference/coherence.md) before
committing.

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

**Three knobs shift results at the ~1e-7 level:** `batch_size`,
`sort_by_length`, and `dedupe_segments`. All three work by changing
which documents share a batch, and batch composition perturbs embeddings
slightly. Pick your settings and keep them — results are reproducible
for a fixed combination, just not necessarily across different ones.
`cores`, `threads` and `cache` are all free of this.

Do not bother tuning `batch_size` for speed. Across 640 and 3,847
documents, sizes from 8 to 128 differed by less than the run-to-run
noise, and an apparent gain at one corpus size did not survive at
another.

## Checklist

- **Running the same corpus more than once, ever?** Add
  `encode(cache = "path.rds")`. Re-runs cost essentially nothing, and
  edited corpora re-encode only what changed. This is the largest single
  win available.
- **Fitting many models on one corpus in a session?** Use
  [`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)
  (or precompute `embeddings`) so encoding and tokenization happen once.
- **Encoding is the bottleneck?** Set `load_model(threads = "auto")` —
  but expect ~1.3×, not linear scaling. For a much larger jump, evaluate
  the `potion-base-8M` static model on *your* corpus.
- **Using sentence- or clause-level
  [`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)?**
  Add `sort_by_length = TRUE`. Nearly 2× at clause level, because 60% of
  the token work is otherwise padding.
- **On Linux or macOS with a big corpus (≥ 2,000 docs)?** Add
  `cores = detectCores() - 1` to
  [`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)
  /
  [`select_topics()`](https://sonsoles.me/sbert/reference/select_topics.md).
- **On Windows, or a small corpus?** `cores` safely no-ops to serial;
  rely on `cache`, reuse and `threads` instead.
- **Need exact reproducibility?** `cores`, `threads` and `cache` are
  safe at any value; fix `batch_size`, `sort_by_length` and
  `dedupe_segments` once and leave them.
- **Benchmarking any of this yourself?** Repeat every measurement.
  Threaded timings vary by up to 26% run to run, and a single sample
  will mislead you.
