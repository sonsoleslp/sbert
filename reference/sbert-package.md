# sbert: Topic modeling with Sentence-BERT embeddings

`sbert` fits topic models of texts from their sentence embeddings. A
sentence embedding places a text in a space where texts with similar
meaning lie close together, whatever words they use (Reimers and
Gurevych 2019), so topics found in that space group texts by what they
mean rather than by the words they share. Each topic is described by its
most typical texts and by its distinctive terms, scored with class-based
TF-IDF (Grootendorst 2022). Topics can be fitted to whole documents or
to their sentences, clauses, or phrases, compared across numbers of
topics by coherence and diversity, and used to assign new texts and give
each document a mixture of topics.

The embeddings come from pretrained models, each fixed to one version
(see [`models()`](https://sonsoles.me/sbert/reference/models.md)). A
model is downloaded only when it is first needed, with
[`model_download()`](https://sonsoles.me/sbert/reference/model_download.md)
or after a prompt in an interactive session, and is stored in the user
cache
([`cache_dir()`](https://sonsoles.me/sbert/reference/cache_dir.md));
nothing is downloaded when the package is installed or loaded. The
bundled
[feedback_embeddings](https://sonsoles.me/sbert/reference/feedback_embeddings.md)
let every topic-model function run without any download.

## Models and embeddings

Texts are tokenized by the 'tok' package and encoded on the ONNX Runtime
through 'onnxr'; pooling, normalization, and all of the topic modeling
are done in R. Each model is fixed to one revision and its files are
checked by SHA-256, so every user encodes with the same model.

- [`install_runtime()`](https://sonsoles.me/sbert/reference/install_runtime.md)
  installs the ONNX Runtime library.

- [`models()`](https://sonsoles.me/sbert/reference/models.md),
  [`model_status()`](https://sonsoles.me/sbert/reference/model_status.md),
  [`model_download()`](https://sonsoles.me/sbert/reference/model_download.md),
  [`load_model()`](https://sonsoles.me/sbert/reference/load_model.md),
  and
  [`load_custom()`](https://sonsoles.me/sbert/reference/load_custom.md)
  list, download, and load models;
  [`cache_dir()`](https://sonsoles.me/sbert/reference/cache_dir.md),
  [`cache_size()`](https://sonsoles.me/sbert/reference/cache_size.md),
  and
  [`model_remove()`](https://sonsoles.me/sbert/reference/model_remove.md)
  manage the cache.

- [`encode()`](https://sonsoles.me/sbert/reference/encode.md) embeds
  texts; [`pool()`](https://sonsoles.me/sbert/reference/pool.md) pools
  token embeddings;
  [`topic_similarity()`](https://sonsoles.me/sbert/reference/topic_similarity.md)
  gives cosine similarities between embeddings;
  [`blend()`](https://sonsoles.me/sbert/reference/blend.md) combines
  segment embeddings with their document's.

## Preparing a corpus

- [`clean_corpus()`](https://sonsoles.me/sbert/reference/clean_corpus.md),
  [`strip_list_markers()`](https://sonsoles.me/sbert/reference/strip_list_markers.md),
  and
  [`content_ratio()`](https://sonsoles.me/sbert/reference/content_ratio.md)
  clean the texts.

- [`dedupe()`](https://sonsoles.me/sbert/reference/dedupe.md) collapses
  repeated texts and counts them.

- [`segment()`](https://sonsoles.me/sbert/reference/segment.md) splits
  documents into sentences, clauses, or phrases;
  [`abbreviations()`](https://sonsoles.me/sbert/reference/abbreviations.md)
  lists the abbreviations that do not end a sentence.

- [`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)
  segments, embeds, and tokenizes a corpus once.

## Fitting and choosing topic models

- [`topics()`](https://sonsoles.me/sbert/reference/topics.md) fits a
  topic model.

- [`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
  compares numbers of topics and segmentation levels.

- [`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md)
  and
  [`reduce_topics()`](https://sonsoles.me/sbert/reference/reduce_topics.md)
  relate and merge topics.

The fits are deterministic: k-means starts from fixed farthest-point
centers, so no random seed is involved and the same input gives the same
topics.

## Describing topics

- [`topic_sizes()`](https://sonsoles.me/sbert/reference/topic_sizes.md),
  [terms()](https://sonsoles.me/sbert/reference/terms.sbert_topic_model.md),
  [`representatives()`](https://sonsoles.me/sbert/reference/representatives.md),
  and
  [as.data.frame()](https://sonsoles.me/sbert/reference/as.data.frame.sbert_topic_model.md)
  give the tables of a model;
  [`name_topics()`](https://sonsoles.me/sbert/reference/name_topics.md)
  names its topics.

- [summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_model.md),
  [`coherence()`](https://sonsoles.me/sbert/reference/coherence.md), and
  [`topic_diversity()`](https://sonsoles.me/sbert/reference/topic_diversity.md)
  evaluate it;
  [`keywords()`](https://sonsoles.me/sbert/reference/keywords.md) gives
  keywords of single documents;
  [`stop_words()`](https://sonsoles.me/sbert/reference/stop_words.md)
  sets the words left out of the terms.

- [plot()](https://sonsoles.me/sbert/reference/plot.sbert_topic_model.md)
  draws sizes, terms, representatives, a fit report, and a map;
  [`topic_palette()`](https://sonsoles.me/sbert/reference/topic_palette.md)
  gives its colors.

## Assigning topics to texts

- [predict()](https://sonsoles.me/sbert/reference/predict.sbert_topic_model.md)
  assigns new texts to topics.

- [`topic_membership()`](https://sonsoles.me/sbert/reference/topic_membership.md)
  gives soft memberships, and
  [`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
  the mixture of topics in each document.

## References

Reimers, N. and Gurevych, I. (2019). Sentence-BERT: Sentence embeddings
using Siamese BERT-networks. *Proceedings of EMNLP-IJCNLP 2019*,
3982–3992.
[doi:10.18653/v1/D19-1410](https://doi.org/10.18653/v1/D19-1410)

Grootendorst, M. (2022). BERTopic: Neural topic modeling with a
class-based TF-IDF procedure. arXiv:2203.05794.

## See also

Useful links:

- <https://sonsoles.me/sbert/>

- <https://github.com/sonsoleslp/sbert>

- Report bugs at <https://github.com/sonsoleslp/sbert/issues>

## Author

**Maintainer**: Sonsoles López-Pernas <sonsoles.lopez@uef.fi>
([ORCID](https://orcid.org/0000-0002-9621-1392)) \[copyright holder\]

Authors:

- Sonsoles López-Pernas <sonsoles.lopez@uef.fi>
  ([ORCID](https://orcid.org/0000-0002-9621-1392)) \[copyright holder\]

- Mohammed Saqr <mohammed.saqr@uef.fi>
  ([ORCID](https://orcid.org/0000-0001-5881-3109)) \[copyright holder\]
