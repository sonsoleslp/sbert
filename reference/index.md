# Package index

## Overview

- [`sbert`](https://sonsoles.me/sbert/reference/sbert-package.md)
  [`sbert-package`](https://sonsoles.me/sbert/reference/sbert-package.md)
  : sbert: Topic modeling with Sentence-BERT embeddings

## Encoding text

Turn text into Sentence-BERT embeddings and compare them.

- [`encode()`](https://sonsoles.me/sbert/reference/encode.md) : Encode
  texts as sentence embeddings
- [`pool()`](https://sonsoles.me/sbert/reference/pool.md) : Pool token
  embeddings into sentence embeddings
- [`topic_similarity()`](https://sonsoles.me/sbert/reference/topic_similarity.md)
  : Compute cosine similarity between embeddings

## Models and runtime

Install the ONNX Runtime, download revision-pinned models, load custom
Hugging Face exports, and manage the on-disk cache.

- [`models()`](https://sonsoles.me/sbert/reference/models.md) : List the
  pinned models
- [`model_download()`](https://sonsoles.me/sbert/reference/model_download.md)
  : Download a pinned model
- [`load_model()`](https://sonsoles.me/sbert/reference/load_model.md) :
  Load an installed pinned model
- [`load_custom()`](https://sonsoles.me/sbert/reference/load_custom.md)
  : Load a Hugging Face embedding model outside the pinned list
- [`model_status()`](https://sonsoles.me/sbert/reference/model_status.md)
  : Check the installed files of a model
- [`model_remove()`](https://sonsoles.me/sbert/reference/model_remove.md)
  : Remove a pinned model from the cache
- [`install_runtime()`](https://sonsoles.me/sbert/reference/install_runtime.md)
  : Install ONNX Runtime
- [`cache_dir()`](https://sonsoles.me/sbert/reference/cache_dir.md) :
  Locate the model cache
- [`cache_size()`](https://sonsoles.me/sbert/reference/cache_size.md) :
  Measure the disk space of the model cache

## Preparing a corpus

Deduplicate, clean, segment, and context-blend documents before
modeling.

- [`dedupe()`](https://sonsoles.me/sbert/reference/dedupe.md) : Collapse
  repeated texts and count them
- [`clean_corpus()`](https://sonsoles.me/sbert/reference/clean_corpus.md)
  : Clean a corpus before encoding
- [`strip_list_markers()`](https://sonsoles.me/sbert/reference/strip_list_markers.md)
  : Remove list and enumeration markers from text
- [`content_ratio()`](https://sonsoles.me/sbert/reference/content_ratio.md)
  : Compute the share of letters in text
- [`segment()`](https://sonsoles.me/sbert/reference/segment.md) : Split
  documents into sentences, clauses, or phrases
- [`abbreviations()`](https://sonsoles.me/sbert/reference/abbreviations.md)
  : List the abbreviations protected from sentence splitting
- [`blend()`](https://sonsoles.me/sbert/reference/blend.md) : Blend
  segment embeddings with their document context
- [`stop_words()`](https://sonsoles.me/sbert/reference/stop_words.md) :
  Get and adjust the stop-word list

## Fitting topic models

Prepare a corpus once, fit topics, compare topic counts, and merge
topics.

- [`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)
  : Prepare a corpus once for several topic models
- [`topics()`](https://sonsoles.me/sbert/reference/topics.md) : Fit
  semantic topics to documents
- [`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
  : Compare numbers of topics and segmentation levels
- [`fitted(`*`<sbert_topic_sweep>`*`)`](https://sonsoles.me/sbert/reference/fitted.sbert_topic_sweep.md)
  : Extract a fitted model from a topic-count comparison
- [`reduce_topics()`](https://sonsoles.me/sbert/reference/reduce_topics.md)
  : Merge the topics of a model into fewer topics

## Describing topics

Distinctive terms, representative texts, names, sizes, and keywords.

- [`terms(`*`<sbert_topic_model>`*`)`](https://sonsoles.me/sbert/reference/terms.sbert_topic_model.md)
  : Compute the terms of each topic
- [`representatives()`](https://sonsoles.me/sbert/reference/representatives.md)
  : Select representative texts for each topic
- [`name_topics()`](https://sonsoles.me/sbert/reference/name_topics.md)
  : Name the topics of a fitted model
- [`topic_sizes()`](https://sonsoles.me/sbert/reference/topic_sizes.md)
  : Compute the size of each topic
- [`keywords()`](https://sonsoles.me/sbert/reference/keywords.md) :
  Extract the keywords of documents

## Assigning topics

Assign new documents and recover soft memberships and topic mixtures.

- [`predict(`*`<sbert_topic_model>`*`)`](https://sonsoles.me/sbert/reference/predict.sbert_topic_model.md)
  : Assign new documents to fitted topics
- [`topic_membership()`](https://sonsoles.me/sbert/reference/topic_membership.md)
  : Compute graded topic membership
- [`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
  : Compute document-topic mixtures from segments

## Evaluating topics

Coherence, diversity, and the hierarchy of topic centers.

- [`coherence()`](https://sonsoles.me/sbert/reference/coherence.md) :
  Score the coherence of topics
- [`topic_diversity()`](https://sonsoles.me/sbert/reference/topic_diversity.md)
  : Measure the diversity of topic terms
- [`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md)
  : Build the hierarchy of the topics of a model
- [`summary(`*`<sbert_topic_model>`*`)`](https://sonsoles.me/sbert/reference/summary.sbert_topic_model.md)
  : Summarize a topic model
- [`summary(`*`<sbert_topic_sweep>`*`)`](https://sonsoles.me/sbert/reference/summary.sbert_topic_sweep.md)
  : Summarize a topic-count comparison
- [`summary(`*`<sbert_topic_hierarchy>`*`)`](https://sonsoles.me/sbert/reference/summary.sbert_topic_hierarchy.md)
  : Summarize a topic hierarchy

## Plots

Deterministic base-graphics displays of models, comparisons, and
hierarchies.

- [`plot(`*`<sbert_topic_model>`*`)`](https://sonsoles.me/sbert/reference/plot.sbert_topic_model.md)
  : Plot a fitted topic model
- [`plot(`*`<sbert_topic_sweep>`*`)`](https://sonsoles.me/sbert/reference/plot.sbert_topic_sweep.md)
  : Plot a topic-count comparison
- [`plot(`*`<sbert_topic_hierarchy>`*`)`](https://sonsoles.me/sbert/reference/plot.sbert_topic_hierarchy.md)
  : Plot a topic hierarchy as a dendrogram
- [`topic_palette()`](https://sonsoles.me/sbert/reference/topic_palette.md)
  : Get colors that distinguish topics in plots

## Results

Tidy tables of result objects, and their print methods.

- [`as.data.frame(`*`<sbert_topic_model>`*`)`](https://sonsoles.me/sbert/reference/as.data.frame.sbert_topic_model.md)
  : Convert a topic model to a data frame
- [`as.data.frame(`*`<sbert_topic_sweep>`*`)`](https://sonsoles.me/sbert/reference/as.data.frame.sbert_topic_sweep.md)
  : Convert a topic-count comparison to a data frame
- [`as.data.frame(`*`<sbert_topic_hierarchy>`*`)`](https://sonsoles.me/sbert/reference/as.data.frame.sbert_topic_hierarchy.md)
  : Convert a topic hierarchy to a data frame
- [`as.data.frame(`*`<sbert_topic_corpus>`*`)`](https://sonsoles.me/sbert/reference/as.data.frame.sbert_topic_corpus.md)
  : Convert a prepared topic corpus to a data frame
- [`print(`*`<sbert_model>`*`)`](https://sonsoles.me/sbert/reference/print.sbert_model.md)
  : Print a loaded model
- [`print(`*`<sbert_topic_corpus>`*`)`](https://sonsoles.me/sbert/reference/print.sbert_topic_corpus.md)
  : Print a prepared topic corpus
- [`print(`*`<sbert_topic_model>`*`)`](https://sonsoles.me/sbert/reference/print.sbert_topic_model.md)
  : Print a topic model
- [`print(`*`<sbert_topic_hierarchy>`*`)`](https://sonsoles.me/sbert/reference/print.sbert_topic_hierarchy.md)
  : Print a topic hierarchy
- [`print(`*`<sbert_topic_sweep>`*`)`](https://sonsoles.me/sbert/reference/print.sbert_topic_sweep.md)
  : Print a topic-count comparison
- [`print(`*`<summary.sbert_topic_model>`*`)`](https://sonsoles.me/sbert/reference/print.summary.sbert_topic_model.md)
  : Print a topic model summary
- [`print(`*`<summary.sbert_topic_sweep>`*`)`](https://sonsoles.me/sbert/reference/print.summary.sbert_topic_sweep.md)
  : Print a topic-count comparison summary
- [`print(`*`<summary.sbert_topic_hierarchy>`*`)`](https://sonsoles.me/sbert/reference/print.summary.sbert_topic_hierarchy.md)
  : Print a topic hierarchy summary

## Data

Bundled corpora and precomputed embeddings for offline examples.

- [`feedback_translations`](https://sonsoles.me/sbert/reference/feedback_translations.md)
  : AI-generated mathematics feedback with English translations
- [`feedback_embeddings`](https://sonsoles.me/sbert/reference/feedback_embeddings.md)
  : Precomputed embeddings of 600 feedback messages
- [`covid`](https://sonsoles.me/sbert/reference/covid.md) : COVID-19
  research abstracts
