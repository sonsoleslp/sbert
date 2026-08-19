# sbert roadmap

Gaps against the 2025–2026 state of the art (BERTopic feature set,
current embedding tooling), filtered by the package’s principles:
deterministic, base-R, Python-free, pinned models, tidy one-verb APIs.
Newest assessment 2026-08-12.

## Done (performance + docs round, 2026-08)

**O(k) centroid initializer** — rewrote the farthest-point seeding from
O(k^2) to O(k); fixes the large-corpus memory blowup that crashed the
session, ~24x faster init, bit-identical selections

**[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)**
— embed and tokenize a corpus once, reuse across many models;
[`select_topics()`](https://sonsoles.me/sbert/reference/select_topics.md)
shares it internally and no longer re-tokenizes per candidate (including
inside
[`coherence()`](https://sonsoles.me/sbert/reference/coherence.md))

**`cores` argument** — parallel tokenization, segmentation, and sweep
candidates on
[`topics()`](https://sonsoles.me/sbert/reference/topics.md),
[`select_topics()`](https://sonsoles.me/sbert/reference/select_topics.md),
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md),
[`coherence()`](https://sonsoles.me/sbert/reference/coherence.md),
[`segment()`](https://sonsoles.me/sbert/reference/segment.md),
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md);
byte-identical for any count

**`strsplit` tokenizer** — single-pass base-R tokenization, ~1.5x
faster, byte-identical, no new dependency

**`topic_gamma(dedupe_segments = )`** — encode distinct segments once
(opt-in; ~2x less encoding on repetitive corpora)

**`numbers = "keep"/"remove"`** — drop digit-only tokens (years, counts)
from topic terms on
[`topics()`](https://sonsoles.me/sbert/reference/topics.md),
[`select_topics()`](https://sonsoles.me/sbert/reference/select_topics.md),
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md),
[`terms()`](https://rdrr.io/r/stats/terms.html); recorded in settings so
[`coherence()`](https://sonsoles.me/sbert/reference/coherence.md) stays
consistent

**`roman_numerals` + `section_numbers` token filters** — drop
Roman-numeral chapter/list markers (bounded at 100 so `ml`/`mm`/`cc`
survive) and multi-level section indices (`1.2.3`); same verbs, recorded
in settings

**Custom stop words documented** — `stop_words(add = )` plus a bare
vector or [`character()`](https://rdrr.io/r/base/character.html) on any
topic verb; examples added

**`segment(max_tokens = , model = )`** — cap segment length so nothing
overruns an encoder window; re-splits at the finest punctuation first,
word-chops only as a fallback; counts words offline or exact model
tokens

**[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
dual input** — accepts raw documents or a
[`segment()`](https://sonsoles.me/sbert/reference/segment.md) data
frame, so segmentation options live in one place and supplied embeddings
always align; identical `gamma` when segmentation matches

**`covid` dataset + articles** — COVID-19 abstracts; a topic-modeling
article and a parallel/high-throughput article

## Done (this round)

[`keywords()`](https://sonsoles.me/sbert/reference/keywords.md) —
embedding-ranked keyword/phrase extraction with MMR diversification
(KeyBERT design)

`stop_words(add = , remove = )` — corpus-vocabulary exclusion

[`select_topics()`](https://sonsoles.me/sbert/reference/select_topics.md)
— coherence/diversity/separation sweep over candidate topic counts

[`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md) +
[`reduce_topics()`](https://sonsoles.me/sbert/reference/reduce_topics.md)
— topic dendrogram (cosine, deterministic) and tree-cut merging to fewer
topics

[`blend()`](https://sonsoles.me/sbert/reference/blend.md) —
context-blended segment embeddings (residual alpha-blend)

[`representatives()`](https://sonsoles.me/sbert/reference/representatives.md)
— margin-ranked evidence selection

**Static embeddings (Model2Vec)** — `potion-base-8M` pinned; token
lookup + mean in base R, ~10k sentences/s, parity 3.3e-08 vs Python

**Seeded / guided topics** — `topics(seeds = , fixed_seeds = )`;
seed-initialized or frozen centroids, seed-named labels

## Topic-model layer

**Dynamic topics** — prevalence and per-period c-TF-IDF over a time
variable, holding assignments fixed. Natural fit for the temporal
research line.

**Outlier awareness** — k-means forces every document into a topic; add
a distance-threshold outlier class (deterministic alternative to HDBSCAN
noise).

**MMR term diversification + bigrams for topic terms** — reuse
`mmr_select()` on term embeddings; extend `topic_term_scores()` to
n-grams.

**Embedding-based coherence** — mean pairwise term-embedding similarity
as a third
[`coherence()`](https://sonsoles.me/sbert/reference/coherence.md)
measure.

**Topic stability** — label-invariant agreement (ARI) across perturbed
refits (bootstrap resampling of documents).

**Multilingual stop words** — `stop_words(language = )` currently only
wires up `"en"`; the hook exists. Build vetted lists (e.g. Snowball via
`tm` at build time, no runtime dep) for users’ non-English corpora.
Deferred: every bundled modeled corpus is English, so no shipped example
needs it yet.

## Embedding layer

**More static models** — potion-base-32M (higher quality) and
potion-multilingual-128M (101 languages) once demand shows; the loader
already supports them.

**Matryoshka truncation** — `dimensions =` on
[`encode()`](https://sonsoles.me/sbert/reference/encode.md) (truncate +
renormalize); `nomic-embed-text-v1.5` is MRL-trained.

**Late chunking** — successor to
[`blend()`](https://sonsoles.me/sbert/reference/blend.md): pool unit
token spans from the contextualized document pass. Requires exact
char-to-token offset alignment, special-token exclusion, and
truncation-safe windowing (NOT a splice of a single truncated pass).

**Qwen3-Embedding-0.6B** — current top open model; needs last-token
pooling mode. EmbeddingGemma stays excluded while gated.

## Housekeeping

R CMD check –as-cran clean (kept clean through the 0.5.2 work)

Fold the analysis tutorials into the package vignette
(`levebee_vignette` ships; covid and parallel articles are pkgdown-only)

Decide whether
[`topics()`](https://sonsoles.me/sbert/reference/topics.md)’s built-in
representatives should use margin ranking (currently raw distance;
[`representatives()`](https://sonsoles.me/sbert/reference/representatives.md)
is the margin path)

## Deliberately out of scope

- LLM-in-the-loop topic naming (TopicGPT-style) — breaks determinism and
  the no-API principle
- Sparse/hybrid retrieval, cross-encoder reranking — retrieval-stack
  features, not topic modeling
