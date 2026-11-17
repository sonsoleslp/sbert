#' sbert: Topic modeling with Sentence-BERT embeddings
#'
#' @description
#' `sbert` fits topic models of texts from their sentence embeddings. A
#' sentence embedding places a text in a space where texts with similar
#' meaning lie close together, whatever words they use (Reimers and Gurevych
#' 2019), so topics found in that space group texts by what they mean rather
#' than by the words they share. Each topic is described by its most typical
#' texts and by its distinctive terms, scored with class-based TF-IDF
#' (Grootendorst 2022). Topics can be fitted to whole documents or to their
#' sentences, clauses, or phrases, compared across numbers of topics by
#' coherence and diversity, and used to assign new texts and give each
#' document a mixture of topics.
#'
#' The embeddings come from pretrained models, each fixed to one version (see
#' [models()]). A model is downloaded only when it is first needed, with
#' [model_download()] or after a prompt in an interactive session, and is
#' stored in the user cache ([cache_dir()]); nothing is downloaded when the
#' package is installed or loaded. The bundled [feedback_embeddings] let every
#' topic-model function run without any download.
#'
#' @section Models and embeddings:
#' Texts are tokenized by the 'tok' package and encoded on the ONNX Runtime
#' through 'onnxr'; pooling, normalization, and all of the topic modeling are
#' done in R. Each model is fixed to one revision and its files are checked by
#' SHA-256, so every user encodes with the same model.
#'
#' * [install_runtime()] installs the ONNX Runtime library.
#' * [models()], [model_status()], [model_download()], [load_model()], and
#'   [load_custom()] list, download, and load models; [cache_dir()],
#'   [cache_size()], and [model_remove()] manage the cache.
#' * [encode()] embeds texts; [pool()] pools token embeddings;
#'   [topic_similarity()] gives cosine similarities between embeddings;
#'   [blend()] combines segment embeddings with their document's.
#'
#' @section Preparing a corpus:
#' * [clean_corpus()], [strip_list_markers()], and [content_ratio()] clean
#'   the texts.
#' * [dedupe()] collapses repeated texts and counts them.
#' * [segment()] splits documents into sentences, clauses, or phrases;
#'   [abbreviations()] lists the abbreviations that do not end a sentence.
#' * [topic_corpus()] segments, embeds, and tokenizes a corpus once.
#'
#' @section Fitting and choosing topic models:
#' * [topics()] fits a topic model.
#' * [compare_topics()] compares numbers of topics and segmentation levels.
#' * [topic_hierarchy()] and [reduce_topics()] relate and merge topics.
#'
#' The fits are deterministic: k-means starts from fixed farthest-point
#' centers, so no random seed is involved and the same input gives the same
#' topics.
#'
#' @section Describing topics:
#' * [topic_sizes()], [terms()][terms.sbert_topic_model],
#'   [representatives()], and [as.data.frame()][as.data.frame.sbert_topic_model]
#'   give the tables of a model; [name_topics()] names its topics.
#' * [summary()][summary.sbert_topic_model], [coherence()], and
#'   [topic_diversity()] evaluate it; [keywords()] gives keywords of single
#'   documents; [stop_words()] sets the words left out of the terms.
#' * [plot()][plot.sbert_topic_model] draws sizes, terms, representatives,
#'   a fit report, and a map; [topic_palette()] gives its colors.
#'
#' @section Assigning topics to texts:
#' * [predict()][predict.sbert_topic_model] assigns new texts to topics.
#' * [topic_membership()] gives soft memberships, and [topic_gamma()] the
#'   mixture of topics in each document.
#'
#' @references
#' Reimers, N. and Gurevych, I. (2019). Sentence-BERT: Sentence embeddings
#' using Siamese BERT-networks. *Proceedings of EMNLP-IJCNLP 2019*,
#' 3982--3992. \doi{10.18653/v1/D19-1410}
#'
#' Grootendorst, M. (2022). BERTopic: Neural topic modeling with a class-based
#' TF-IDF procedure. arXiv:2203.05794.
"_PACKAGE"
