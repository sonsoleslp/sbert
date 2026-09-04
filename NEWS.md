# sbert 0.5.3

- Topic term plots no longer fail with "need finite 'ylim' values" when a
  topic has no terms left after the stop-word, token-length, and frequency
  filters (`plot(type = "terms")`, `plot(type = "fit")`, and the per-topic
  figures). Such a topic now draws an empty, labelled panel. A device too small
  to stack one row per topic in `plot(type = "fit")` raises a classed
  `sbert_plot_too_small` error naming the remedies (`per_topic = TRUE`, a
  `topics = ` subset, or a taller device) instead of the opaque base-graphics
  "invalid graphics state" message.

# sbert 0.5.2

- Added `clean_corpus()`, one place for the text-level cleaning that should
  happen before encoding, so the same clean text feeds the encoder, the topic
  terms, and the representatives. It repairs junk and strips non-content markup
  — HTML entities and tags, URLs, DOIs, email addresses, bracketed numeric
  citations (`[12]`), page references (`p. 1`, `pp. 15-30`), curly quotes,
  dashes, bullets, control, zero-width, BOM and replacement characters, and
  non-breaking spaces — then strips list markers (`1.`, `(i)`, `(a)`, `(109)`,
  and bare Roman-numeral section markers such as `IV.` and a leading `V.`) and
  section/reference numbering (`1.2.3`, and alphanumeric indices such as `II.2`
  and `AA.2`), applies any custom `remove` patterns
  (the extension point for domain-specific noise the generic cleaners leave, for
  example `remove = "OJ No L?\\s*\\d+"`), optionally removes numeric and
  Roman-numeral tokens, and drops
  documents below a `min_content` alphabetic-density floor — citation lists,
  reference footnotes, number tables — carrying a data frame's other columns
  along so metadata stays aligned. Supporting helpers `strip_list_markers()` and
  `content_ratio()` are exported too. `content_ratio()` is the fraction of a
  string's non-space characters that are letters, a domain-agnostic measure of
  prose versus reference noise (real sentences score near 1; "OJ No L 297,
  24.11.1979, p. 1." scores about 0.25), and `min_content` judges it on the
  repaired text before the number strips so a stripped reference cannot slip
  through. Because Sentence-BERT tolerates a little noise, this targets broken
  text and non-content rows rather than scrubbing every token.
- The `numbers`, `roman_numerals`, and `section_numbers` term filters stay on
  `topics()`, `select_topics()`, `topic_corpus()`, and `terms()`: they tidy the
  topic *labels* without touching the document text or its embedding, which is
  the point of keeping them separate from `clean_corpus()`. Text-level cleaning
  that would change the embedding lives in `clean_corpus()`.
- `representatives()` and a fitted model's built-in representatives now return
  distinct texts. A representative list of the same string repeated is never
  useful, and duplicates are common once documents are segmented.
- `segment()` splits a run-together sentence boundary — a lower-case letter, a
  period, then an upper-case letter, as in "results.The next" — rather than
  treating it as an acronym; genuine acronyms ("U.S.") and decimals ("3.14") are
  left intact.

- `topic_gamma()` now accepts either raw documents (segmented internally, as
  before) or the data frame returned by `segment()`, used as-is. Passing your
  own segmentation keeps every segment option — `level`, `max_tokens`,
  `merge_below` — in `segment()` and means a supplied `embeddings` matrix always
  lines up with the segments, instead of having to match an internal
  re-segmentation. The two paths give identical `gamma` when the segmentation
  matches.
- `segment()` gains `max_tokens`, a cap so no segment overruns an encoder's
  context window and is silently truncated. An over-long segment is re-split at
  the finest logical boundaries — clause hinges, `;`, `:`, ` - `, and commas —
  and the pieces are packed back up to the budget, so splits land on punctuation
  wherever possible. A run with no such boundary is chopped further, but even
  then the break is placed just before a function word (a coordinator,
  preposition, article, or relative pronoun) near the budget edge rather than
  mid-phrase — so "the schools" is kept together instead of stranding "the".
  By default the budget counts whitespace words (offline,
  deterministic). Passing a loaded `model` counts that model's exact sub-word
  tokens instead, so `max_tokens` can be the model's real limit; token-counted
  segmentation runs serially since the tokenizer is not forked. `NULL` (default)
  leaves segments uncapped, byte-identical to before.

- `encode()` gains a `cache` argument: a path to a content-addressed embedding
  store. Each document is keyed by a SHA-256 digest of its own text together
  with the model identity, revision, dimension, maximum length, pooling method
  and `normalize` setting, so only documents with no matching entry are encoded
  and the file is updated with whatever was newly computed. Corpora are usually
  edited rather than replaced, and encoding is about 97% of the cost of a topic
  workflow, so reuse dominates: re-running an unchanged 3,847-abstract corpus
  cost 0.07 s against 36.59 s (**515x**, output `identical()`), and re-running it
  after editing 38 documents cost 0.41 s (**89x**) with unchanged rows identical
  to the previous run and changed rows identical to a fresh encode. Reordering
  or subsetting a cached corpus encodes nothing at all. Duplicate documents
  within one call are encoded once and expanded by position — 295 of the 3,847
  bundled `covid` abstracts are duplicates.

  The key deliberately excludes `batch_size` and `sort_by_length`, which move
  embeddings by around 1e-7 through batch composition alone; cached values are
  therefore stable to whatever computed them first rather than bit-identical to
  a fresh encode under different batching. A cache that cannot be read, or was
  written for a different embedding dimension, is discarded with a warning and
  rebuilt rather than trusted, and writes go to a temporary file and are renamed
  so an interrupted save cannot leave a half-written cache behind.

- `load_model()` accepts `threads = "auto"`, which asks the platform for its
  performance-core count instead of its logical one. ONNX inference is about
  88% of a batch and the only threaded part of the package, but it scales with
  performance cores only. Measured over three repetitions at 200, 600 and 1,500
  documents on an Apple M4 (4 performance + 6 efficiency), median speedups
  against a single thread were 1.22x at two threads, **1.29x at four**, 1.22x
  at six and 1.18x at eight; four threads was fastest at both larger sizes
  (1.34x at 1,500 documents), after which the efficiency cores contribute
  contention rather than throughput. `"auto"` selects that knee and is capped
  at 8 so a library never seizes a whole machine uninvited. Raising the thread
  count has **no numerical consequence**: output was `identical()` in all 45
  runs. The default stays `1` so results remain reproducible across machines
  and within the two-core limit that check environments impose. Note that
  threaded timings are noisy — run-to-run spread reached 26% at the smallest
  size against under 3% single-threaded — so a single timing run is not
  sufficient evidence for tuning.
- Mask-aware mean pooling is about 6.3x faster, and `encode()` about 1.18x
  faster end to end, with identical output on platforms whose `sum()` and
  `rowsum()` accumulate in the same precision. `pool()` built a second
  24 MB copy of every batch with `sweep()` and then summed it with
  `apply(., c(1, 3), sum)`, an R-level loop over a 3-D array. Because an R
  array is column-major and its first two margins are adjacent, the batch
  re-dimensions to `(batch * sequence) x hidden` without moving any data, so
  masking becomes one recycled multiply and the per-document sum becomes a
  single C-level `rowsum()`. Verified as `identical()` against the previous
  formulation across 60,000+ shape, mask, method and normalization combinations
  and on real ONNX output.

  One caveat, and it is a real one: R's `sum()` accumulates into a long double
  while `rowsum()` accumulates into a double. On builds with extended-precision
  long doubles — common x86-64 Linux and Windows builds, where
  `.Machine$sizeof.longdouble` is 16 — the two can therefore differ in the last
  bits on inputs with heavy cancellation. Equality was confirmed on arm64 macOS,
  where `sizeof.longdouble` is 8 and the question does not arise; on
  extended-precision builds expect agreement to around 1e-16 rather than to the
  bit. Embedding values of that magnitude do not change any topic assignment.

  The element-scanning part of `pool()`'s validation is now skipped on the
  internal encoding path, where the mask has already been validated by the
  tokenizer step. The *structural* checks are kept — dimension agreement is
  O(1) and its removal would have let a wrongly shaped ONNX output recycle
  silently into the wrong number of rows. Finiteness is now checked on the
  pooled result rather than the raw batch: the same guarantee at roughly 1/256
  the cost, since any non-finite token value must surface there (an unmasked
  `Inf` sums to `Inf`, a masked one becomes `Inf * 0 = NaN`). `pool()` itself is
  unchanged for direct callers and still validates in full.
- `encode()` and `topic_gamma()` gain `sort_by_length` (default `FALSE`).
  Every sequence in a batch is padded to the longest member, so a batch costs
  the model its maximum length rather than its mean. Grouping inputs of similar
  length into the same batch shrinks that padding: at clause level 60.1% of all
  token work is padding in input order against 1.6% when sorted, measured at
  1.89x faster for `topic_gamma(level = "clause")` and 1.08x for whole
  documents, which vary less in length. The permutation is inverted before
  returning, so row order always matches the input. Off by default because
  regrouping changes batch composition, which moves embeddings by about 1e-7 —
  the same trade-off already documented for `dedupe_segments`. On the bundled
  `covid` corpus that drift changed no `gamma` value and no document's dominant
  topic, but it is opt-in rather than assumed.
- `topics()`, `select_topics()`, `topic_corpus()`, and `terms()` gain
  `roman_numerals` and `section_numbers`, two independent token filters
  alongside `numbers`. `roman_numerals = "remove"` drops chapter/section/list
  markers written as Roman numerals (`ii`, `iv`, `xii`), bounded at 100 so that
  common abbreviations that are also valid numerals — `ml`, `mm`, `cc`, `ci`,
  `cv` — are always kept. `section_numbers = "remove"` strips both multi-level
  section and reference indices (`1.2.3`, `4.5.6.7`) and enumeration or list
  markers (`1.`, `2.`, `figure 12.` — a standalone one- or two-digit number
  followed by a period) before tokenizing; decimals, four-digit years
  (`2020.`), hyphenated numbers (`covid-19.`), and larger counts survive, so
  genuine values are kept even under `numbers = "keep"`. Both default to
  `"keep"` (byte-identical to before) and are recorded on the model so
  `coherence()` stays consistent.
- `topics()`, `select_topics()`, and `topic_corpus()` gain a `numbers` argument.
  `"keep"` (default, unchanged) keeps numeric tokens; `"remove"` drops tokens
  made only of digits — years, counts — from topic terms while retaining
  alphanumerics such as `covid19`. The setting is recorded on the model so
  `coherence()` stays consistent. Custom stop words already compose through the
  `stop_words` argument of these verbs and `keywords()`; `stop_words(add =)`
  keeps the defaults plus your terms, a bare vector replaces the list, and
  `character()` disables filtering. Documented with examples.
- The topic tokenizer is about 1.5x faster: a single-pass base-R `strsplit`
  split replaces the previous `gregexpr` + `regmatches` pair. Output is
  byte-identical (same token grammar, verified across Unicode, apostrophe, and
  empty-document edge cases) and no dependency is added. This speeds up
  `topics()`, `select_topics()`, `topic_corpus()`, and `coherence()`, and stacks
  with the `cores` argument.
- `segment()` and `topic_gamma()` gain a `cores` argument. Splitting documents
  into sentences or clauses is the dominant non-encoding cost of sentence-level
  `topic_gamma()`, and it is per-document independent, so forking it across
  cores gives a several-fold speed-up (about 4-5x on eight cores) with
  byte-identical output. Encoding is parallelized separately via
  `load_model(threads =)`.
- `topic_gamma()` gains `dedupe_segments` (default `FALSE`). Real corpora often
  repeat many segments (boilerplate sentences, short clauses); enabling this
  encodes each distinct segment once and expands by position, roughly halving
  the encoding cost on such corpora. Off by default because encoding a smaller
  batched set can shift a rare borderline assignment at the ~1e-7 level; with
  the static `potion-base-8M` model the result is identical.
- `topics()`, `select_topics()`, `topic_corpus()`, and `coherence()` gain a
  `cores` argument for parallel tokenization; `select_topics()` also fits its
  independent candidates in parallel. Because document tokenization and
  per-candidate fitting are deterministic and order-preserving, results are
  byte-identical for any core count — `cores` changes only speed, never output.
  Parallelism uses `parallel::mclapply` on Unix-alikes and falls back to serial
  on Windows and for small corpora; the default is `cores = 1`. On an 8-core
  machine a five-count sweep on 15,000 documents drops from about 12 s to 7 s.
- Added `topic_corpus()`: prepare a corpus once — embedding every document and
  tokenizing it for term scoring — and reuse it across many models. `topics()`
  and `select_topics()` accept the prepared corpus in place of raw text and
  skip both the encoding and the tokenization, which previously repeated on
  every call. A sweep or hand-written loop over topic counts now costs one
  tokenization (and one encoding) plus the per-model clustering, rather than
  repeating the whole corpus pass per model; the speedup grows with the number
  of models fitted. Results are byte-identical to preparing the corpus inside
  each call, and `select_topics()` now shares one prepared corpus across all
  candidates internally.
- `select_topics()` no longer re-tokenizes the corpus inside `coherence()` on
  every candidate — the dominant cost of a sweep. `coherence()` gains an
  optional `token_lists` argument so the shared corpus tokenization is reused;
  scores are byte-identical. Combined with the corpus reuse above, a five-count
  sweep on 15,000 documents dropped from about 164 s to 12 s (~13x) with no
  change to any result.
- `topics()` (and `select_topics()`, which calls it per candidate) no longer
  exhausts memory or stalls on large corpora. The farthest-point centroid
  initializer was rewritten from an O(n_topics^2 * n * d) recompute-everything
  pass — which repeatedly allocated full document-by-dimension matrices and
  could crash the R session — to an incremental O(n_topics * n * d) pass that
  keeps a running nearest-centroid distance (about 24x faster at 20k documents,
  with a fraction of the peak memory). The expensive up-front distinct-row
  dedup was dropped in favour of an exact in-loop check, and per-document
  centroid cosines are now vectorized. Topic assignments, terms, and
  representatives are bit-identical to previous versions.
- Added the `covid` dataset: 4,170 COVID-19 research abstracts (2020-2024) on
  education, children, schools, and society, each with a publication year.
  Editorial notices (retractions, corrections, errata) are removed during
  preparation; 323 records carry a `"[No abstract available]"` placeholder and
  3,671 abstracts are distinct. A companion pkgdown article, "Topic Modeling
  COVID-19 Research Abstracts", walks the full sweep-fit-read workflow.
- Added `plot(topic_model, type = "representatives")`, a per-topic ranked text
  list of the centroid-nearest documents (with their cosine similarity to the
  centroid), an `n_representatives` argument, and `type = "fit"`, a per-topic
  report placing all three term views (count, TF-IDF, beta) alongside the
  representative documents, one row per topic. Term bar panels now annotate
  each bar with its value.
- `plot(type = "terms")` gains a `by` argument selecting one or more of
  `"score"` (class-based TF-IDF, the default), `"beta"` (generative word
  probability), and `"frequency"` (within-topic count); several metrics draw
  one row per topic with a column each. A new `topics` argument restricts
  `"terms"`, `"representatives"`, and `"fit"` to chosen topic numbers, and
  `per_topic = TRUE` draws a separate figure for each topic instead of one
  gridded figure.
- README updated for the 0.5 API: data-frame input to `topics()`, the
  retained-model sweep with `fitted()`, and `terms()` retuning without a
  refit. Adds a pointer to the tutorial vignette.
- Repaired README prose damaged by the 0.5.0 rename, where the English words
  "membership" and "diversity" had been rewritten as function names.
- Corrected the model count in the README from thirteen to fourteen.
- Named the `n_topics` argument in the README's `reduce_topics()` example, and
  stopped shadowing `topic_hierarchy()` with a variable of the same name.

# sbert 0.5.1

- `R CMD check --as-cran` is clean: 0 errors, 0 warnings, 0 notes.
- Documented the `column` argument of `topics()`.
- Repaired a malformed `\eqn` macro in the `terms()` documentation.
- Qualified `graphics::par()` in the topic-hierarchy plot method.
- Declared `withr` in Suggests; the session tests use it.
- Excluded `.DS_Store`, `TODO.md` and knitr caches from the package build.

# sbert 0.5.0

## Breaking: the `sbert_` prefix is gone

Every exported function lost its prefix. The package has never been released,
so the old names were removed outright rather than deprecated:

`sbert_topics()` is now `topics()`, `sbert_encode()` `encode()`,
`sbert_segment()` `segment()`, `sbert_blend()` `blend()`,
`sbert_keywords()` `keywords()`, `sbert_dedupe()` `dedupe()`,
`sbert_coherence()` `coherence()`, `sbert_select_topics()`
`select_topics()`, `sbert_representatives()` `representatives()`,
`sbert_load_model()` `load_model()`, `sbert_models()` `models()`, and so on
for the cache and runtime verbs.

Six names are qualified because the bare form collides with a package this
audience is likely to have attached — `igraph`, `quanteda`, `purrr`:

- `sbert_membership()` -> `topic_membership()`
- `sbert_diversity()` -> `topic_diversity()`
- `sbert_hierarchy()` -> `topic_hierarchy()`
- `sbert_similarity()` -> `topic_similarity()`
- `sbert_reduce()` -> `reduce_topics()`
- `sbert_stopwords()` -> `stop_words()`

Two are qualified because the bare form would mask base R:
`sbert_gamma()` -> `topic_gamma()`, `sbert_palette()` -> `topic_palette()`.

Class names keep the prefix (`sbert_topic_model`, `sbert_model`), so S3
methods read `terms.sbert_topic_model()`.

## New: `terms()` retunes without refitting

Topic terms depend only on the fitted assignments and the document text, so
every term setting can now be changed without repeating the clustering or the
encoding:

```r
terms(fit, n = 12, weighting = "bm25", stem = TRUE)
terms(fit, n = 8, sort_by = "beta")     # words a topic uses most
terms(fit, n = 8)                        # words that distinguish it
```

`sort_by` chooses between the class-based weight (distinctive terms, the
default) and raw `p(term | topic)`. `n` is applied after ordering. The
returned frame carries `beta`, which absorbs the removed `sbert_beta()`.

## Verbs take your data frame and keep what they compute

- `topics()` accepts a data frame plus `column =` naming the text column.
  Remaining columns ride along into `$documents`. Rows whose text is missing,
  blank, or a `[NO ABSTRACT AVAILABLE]` placeholder are dropped once, and any
  supplied `embeddings` are subset to match.
- `keep_embeddings` now defaults to `TRUE`. `topic_membership()`,
  `reduce_topics()` and `plot(type = "map")` previously failed on a freshly
  fitted model and told the user to refit — which meant re-encoding.
- `label` is carried into `$documents`, `$terms` and `$representatives`, so
  joining it back by hand is never necessary.
- `representatives(fit)` defaults to the fitted corpus and its stored
  embeddings.

## `select_topics()` keeps every model it fits

The sweep no longer discards the models it built. `fitted(sweep, n_topics =)`
returns one without refitting, and the result gains `print`, `plot` and
`as.data.frame` methods while remaining a plain data frame with the same
columns.

## Other

- New tutorial vignette, "Topic Modeling: A Tutorial", running end to end on
  the bundled `feedback_translations` data with precomputed embeddings, so it
  builds without any download.
- Removed `sbert_beta()` (now the `beta` column of `terms()`).
- Fixed two documentation blocks that could not run: an example passed a cache
  directory where a model name belongs, and the README referenced an
  unassigned `model` object.

# sbert 0.4.0

## Static embeddings (instant-speed tier)

- New pinned model `potion-base-8M` (Model2Vec static embeddings, MIT):
  encoding is a token-lookup and mean in pure base R — no ONNX session —
  which makes it roughly two orders of magnitude faster than transformer
  models (10,000 sentences in under a second) at a modest quality cost.
  Loaded through the same verbs (`sbert_model_download()`,
  `sbert_load_model("potion-base-8M")`, `sbert_encode()`); the safetensors
  weight matrix is read with a minimal base-R reader and verified by
  SHA-256 like every other artifact. `sbert_models(detail = TRUE)` gains
  an `engine` column ("onnx" or "static"). Numerical parity with Python
  `model2vec`: max abs diff 3.3e-08.

## Seeded (guided) topics

- `sbert_topics()` gains `seeds`, `seed_embeddings`, and `fixed_seeds`:
  supply seed words or topic descriptions and they become the first
  cluster centroids. Seeded topics keep their position (topic i is seed i,
  never reordered by size) and take the seed's name as their label when
  `seeds` is named. Remaining topics up to `n_topics` are initialized
  deterministically away from the seeds. With `fixed_seeds = TRUE` the
  centroids never move — documents are zero-shot assigned to the nearest
  seed, and seeded topics may legitimately be empty.

## Analysis utilities

- New `sbert_keywords()`: embedding-based keyword and phrase extraction
  (the KeyBERT design) — each document's own unigrams and n-grams are
  embedded with the same model, ranked by cosine similarity to the
  document, and selected by maximal marginal relevance (`diversity`
  argument) so keywords are relevant without being redundant.
- `sbert_stopwords()` gains `add` and `remove`: exclude a corpus-wide
  vocabulary from topic terms and keyword candidates, or un-list built-in
  entries.
- New `sbert_select_topics()`: fits the model across candidate topic
  counts on one shared embedding matrix and returns coherence, diversity,
  and between-topic variance share per count — granularity chosen by
  numbers, not habit.
- New `sbert_hierarchy()`: deterministic agglomerative merge tree of the
  topic centroids (cosine distance) with a tidy merge table, labeled
  dendrogram plot, and readable print.
- New `sbert_reduce()`: cuts the hierarchy at a target count and rebuilds
  a full `sbert_topic_model` (merged assignments, recomputed centroids,
  terms, labels, sizes, representatives) — every downstream verb works on
  the reduced model unchanged.

## Context-blended segment embeddings

- New `sbert_blend()`: context-aware embeddings for segments — each segment
  keeps `alpha` of its context-orthogonal residual and inherits the rest of
  its direction from the parent document embedding, renormalized. Blending
  the residual (rather than the raw segment vector) avoids the
  near-collinearity of a segment with its own document. Accepts a
  `sbert_segment()` data frame plus the original documents (encoding both),
  or precomputed embedding matrices. Output drops into `sbert_topics()`,
  `sbert_representatives()`, and `predict()` unchanged. This is the
  package's supported way to "mix" granularities: per unit, never by pooling
  units of different levels into one training set.

## Representative selection and segmentation

- New `sbert_representatives()`: evidence selection by distinctiveness
  margin (distance to the second-best centroid minus distance to the own
  centroid) instead of raw closeness, which systematically favors long
  units. `rank = "distance"` restores the old behavior.
- `"ETC."` removed from the default abbreviation gazetteer: sentence
  boundaries only fire at period-space-word, and mid-sentence "etc." always
  carries trailing punctuation, so protecting it could only glue true
  sentence ends together.

## Multi-model registry

- Added six modern embedding models to the registry: `bge-small-en-v1.5` and
  `bge-base-en-v1.5` (BAAI, CLS pooling), `multilingual-e5-small` (100+
  languages, automatic `"query: "` prefix), `nomic-embed-text-v1.5` and
  `jina-embeddings-v2-small-en` (8,192-token context), and
  `mxbai-embed-large-v1` (1,024 dimensions). The encoder now supports CLS
  pooling (`sbert_pool(method = "cls")`) and per-model input prefixes
  (`sbert_encode(prefix = ...)` overrides the pinned default). Parity vs
  Python: at or below 2.9e-7 for the BGE/E5/nomic models, 8e-8 cross-runtime
  for jina; mxbai agrees to cosine 0.9996 with its float16-distributed
  reference (the pinned ONNX is the full-precision float32 artifact).

- Added a registry of pinned, SHA-256-verified models. Besides the default
  `all-MiniLM-L6-v2`, the package now supports six further models:
  `all-MiniLM-L12-v2` (deeper English MiniLM), `paraphrase-MiniLM-L3-v2`
  (the smallest and fastest, 69 MB), `multi-qa-MiniLM-L6-cos-v1` (semantic
  search, 512-token inputs), `paraphrase-multilingual-MiniLM-L12-v2`
  (384 dimensions, 50+ languages), `all-mpnet-base-v2` (768 dimensions,
  higher-quality English), and `paraphrase-multilingual-mpnet-base-v2`
  (768 dimensions, 50+ languages). `sbert_models()` lists them tidily. Every
  model remains locked to an immutable revision with byte-size and SHA-256
  verification, and every MiniLM addition was verified numerically identical
  to Python `SentenceTransformers` output (max difference below 3e-7).
- `sbert_model_download()` and `sbert_load_model()` now take the model name
  as their first argument (`sbert_load_model("all-mpnet-base-v2")`);
  `sbert_model_status()` and `sbert_model_remove()` gained a trailing `model`
  argument. Calls that passed `cache_dir` positionally to
  `sbert_model_download()`/`sbert_load_model()` must now name it.
- The encoder adapts to each model's input signature: MPNet- and
  XLM-RoBERTa-based graphs receive two ONNX inputs (no `token_type_ids`) and
  are padded with their own pad token; every model uses its published
  maximum sequence length.

## Generic loader

- Added `sbert_load_custom()`: loads any public Hugging Face repository that
  ships an ONNX encoder export and a `tokenizer.json`, with
  trust-on-first-use pinning (revision, byte sizes, and SHA-256 recorded in
  a local manifest on first download and verified on every later load).
  Pooling, maximum length, and the pad token are auto-detected from the
  repository's Sentence-Transformers configuration and tokenizer; the input
  signature and embedding dimension are read from the ONNX graph itself.
  Returns a regular `sbert_model`, so every downstream verb works
  unchanged. Requires the `jsonlite` package (Suggests). Unlike registry
  models, no parity certificate is implied.

## One-verb usage

- Every verb that takes a model now accepts a pinned model name or nothing
  at all: `sbert_encode(text)` uses the default `all-MiniLM-L6-v2`,
  `sbert_encode(text, model = "bge-small-en-v1.5")` switches by name, and
  `sbert_topics()`, `predict()`, and `sbert_gamma()` resolve models the
  same way. Loaded models are kept in a session cache and reused.
- Missing models are never downloaded silently: interactive sessions get a
  one-time yes/no prompt (size and license shown); scripts must opt in via
  `sbert_model_download()` or `options(sbert.download = TRUE)`.
- Attaching the package now prints a one-line orientation message with the
  model count, the default model, and the `sbert_models()` menu pointer.

## Corpus verbs

- Added `sbert_dedupe()`: collapses a corpus to its distinct non-blank texts
  (first-appearance order) with occurrence counts, so repeated templates
  cannot dominate the clustering geometry while frequencies remain available
  as weights.
- Added `sbert_topic_sizes()`: topic sizes on the distinct and weighted
  scales in one call; the gap between `proportion` and `weighted_share`
  measures how template-driven each topic is.

## Inferential layer

- Added `predict()` for `sbert_topic_model`: assigns unseen documents to the
  nearest fitted centroid under cosine distance, returning a tidy data frame
  with topics, labels, and distances.
- Added `sbert_membership()`: fuzzy-c-means soft topic probabilities on the
  stored centroids with a `sharpness` fuzzifier (default 1.15; the textbook
  value 2 degenerates toward uniform membership in high-dimensional
  embedding spaces). The within-document topic ranking is
  sharpness-invariant.
- Added `sbert_beta()`: the generative multinomial `p(term | topic)` from
  within-topic token counts with optional Laplace smoothing — the frequent-
  words view that complements (and must not be confused with) the
  discriminative class-based TF-IDF terms.
- Added `sbert_gamma()`: per-document topic distributions obtained by
  segmenting each document with `sbert_segment()` and assigning each segment
  to its nearest centroid — parameter-free mixed membership.

# sbert 0.3.0

- Added the `feedback_translations` dataset: 8,757 multilingual AI-generated
  mathematics feedback messages from the Levebee educational application
  paired with their English translations (8,005 distinct translations, template
  repetition preserved), giving every example and
  vignette a realistic offline corpus for the embedding, segmentation, and
  topic-modeling workflow.
- Added `sbert_segment()`, deterministic rule-based text segmentation at
  sentence, clause (default), or phrase granularity. Sentence boundaries are
  guarded by a word-boundary-anchored, case-insensitive abbreviation gazetteer
  (`sbert_abbreviations()`), a decimal-number guard, and a parenthetical
  guard; clause level adds splits at semicolons, colons, spaced dashes, and
  subordinating hinges while keeping comma enumerations whole. Returns a tidy
  one-row-per-segment data frame and preserves letter case. Promoted from the
  benchmarked analysis module (F1 0.999 on realistic abbreviation-rich
  abstracts versus 0.80-0.82 for ICU and NLTK Punkt references).

# sbert 0.2.0

- Fixed topic tokenization to normalize the curly apostrophe (U+2019) to the
  straight apostrophe, so contractions such as `it's` and `it’s` are one token.
- Added optional Porter stemming to `sbert_topics()` (`stem = TRUE`, using
  `SnowballC`) that collapses inflected forms while displaying the most
  frequent surface form of each stem, giving cleaner, deduplicated topic terms.
- Made NPMI coherence exact at the co-occurrence limits (terms that always or
  never co-occur now score 1 and -1 instead of a non-finite value).
- Added intrinsic topic-model evaluation: `sbert_coherence()` (UMass and NPMI)
  and `sbert_diversity()`, with a `summary()` method that reports cluster
  separation, coherence, and diversity alongside a tidy per-topic table.
- Added deterministic base-graphics visualizations via a `plot()` method for
  topic models (`type = "sizes"`, `"terms"`, `"map"`) and the `sbert_palette()`
  colour helper. The document map uses classical MDS on cosine distance.
- Added `weighting = "bm25"` and `reduce_frequent_words` options to
  `sbert_topics()`, implementing the BM25 and square-root class-based TF-IDF
  variants of Mendonca and Figueira (2025).
- Fixed the class-based TF-IDF average topic length to be real-valued rather
  than integer-truncated, matching the published formula (Eq. 1).

# sbert 0.1.0

- Added Python-free `all-MiniLM-L6-v2` inference through `tok` and `onnxr`.
- Added revision-pinned, SHA-256-verified model download and cache management.
- Added mask-aware mean pooling, L2 normalization, and cosine similarity.
- Added deterministic semantic topic modeling with representative documents,
  Unicode tokenization, and BERTopic-style class TF-IDF term summaries.
- Added offline unit tests and optional official-model numerical parity tests.
