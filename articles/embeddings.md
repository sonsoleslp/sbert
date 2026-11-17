# Sentence embeddings without Python

A sentence embedding is a fixed-length vector that represents the
meaning of a whole text. Sentence-BERT (Reimers & Gurevych, 2019)
obtains such vectors from a pretrained transformer that is fine-tuned in
a siamese arrangement: pairs of sentences pass through the same network,
and the network is trained so that the cosine similarity of their pooled
vectors tracks how similar the sentences are in meaning. The result is a
space in which “Choose the pictures between the cat and the dog” and
“Pick all the images that lie between them” are neighbors although they
share few words, so that similarity search, clustering and topic
modeling can operate on meaning rather than on vocabulary.

In R, sentence embeddings have usually been computed by calling the
Python `sentence-transformers` library, which brings a second language
runtime, a deep-learning framework and its version conflicts into an R
analysis. The `sbert` package computes the same embeddings in R. It
tokenizes with each model’s own Hugging Face tokenizer through the `tok`
package, runs the transformer as an ONNX graph through the `onnxr`
package, and pools and normalizes the result in base R. Models are
pinned to fixed revisions and verified by checksum, and nothing is
downloaded unless it is requested.

Computing an embedding needs a downloaded model, so the encoding steps
below are shown and not run. Everything that runs uses the embeddings
bundled with the package, which were computed by those same steps.

``` r

library(sbert)
#> sbert 0.5.14: Sentence-BERT embeddings and topic models in R.
#>   14 pinned models (see models()); default: all-MiniLM-L6-v2.
#>   A model is downloaded only on request, once, and verified by SHA-256.
```

## Data

- **`feedback_translations`:** AI-generated feedback messages from a
  mathematics learning application, with the source-language text in
  `feedback` and the English translation in `translation`.
- **`feedback_embeddings`:** the embeddings of the first 600 distinct
  translations, computed with the pinned `all-MiniLM-L6-v2` model. Row
  *i* is the embedding of row *i* of `corpus` below.

``` r

corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
dim(feedback_embeddings)
#> [1] 600 384
```

Each of the 600 messages is a vector of 384 numbers, one per dimension
of the model.

## How is a sentence turned into a vector?

[`encode()`](https://sonsoles.me/sbert/reference/encode.md) takes a
character vector and returns a matrix with one row per text. Between the
two, each batch of texts passes through four steps:

1.  **Tokenization.** The model’s `tokenizer.json` is loaded with `tok`
    and splits each text into subword tokens, adds the model’s special
    tokens, truncates at the model’s maximum length, and pads the batch
    to its longest member. It returns the token ids and an attention
    mask that is 1 for real tokens and 0 for padding.
2.  **Inference.** The ONNX graph, run by `onnxr`, maps the token ids to
    one contextual vector per token: an array of texts by tokens by
    dimensions.
3.  **Pooling.** The token vectors of each text are combined into one
    vector. Mean pooling averages the vectors of the real tokens,
    $`e = \sum_t m_t h_t / \sum_t m_t`$, where $`h_t`$ is the vector of
    token $`t`$ and $`m_t`$ its mask value; CLS pooling takes the vector
    of the first token. Each model uses the pooling it was trained with.
4.  **Normalization.** Each vector is divided by its Euclidean length,
    so that the dot product of two embeddings is their cosine
    similarity.

Steps 3 and 4 are plain R arithmetic, exported as
[`pool()`](https://sonsoles.me/sbert/reference/pool.md). A small example
with two texts, three token positions and two dimensions shows what they
compute. In the mask below, the third token position of the first text
is padding:

``` r

token_vectors <- array(1:12, dim = c(2, 3, 2))
mask <- matrix(c(1, 1, 0,
                 1, 1, 1), nrow = 2, byrow = TRUE)
pool(token_vectors, mask, normalize = FALSE)
#>      [,1] [,2]
#> [1,]    2    8
#> [2,]    4   10
```

The first text has the token vectors (1, 7), (3, 9) and (5, 11), and its
third token is masked, so its mean is (2, 8). The second text has three
real tokens, (2, 8), (4, 10) and (6, 12), with mean (4, 10). The masked
token is excluded from the average, which is why padding a batch to its
longest member does not change any text’s embedding. CLS pooling returns
the first token of each text, and normalization rescales each row to
length 1:

``` r

pool(token_vectors, mask, normalize = FALSE, method = "cls")
#>      [,1] [,2]
#> [1,]    1    7
#> [2,]    2    8
pool(token_vectors, mask)
#>       [,1]  [,2]
#> [1,] 0.243 0.970
#> [2,] 0.371 0.928
```

The bundled embeddings were normalized in the same way; their row
lengths are 1 up to the four-decimal rounding of the stored values:

``` r

summary(sqrt(rowSums(feedback_embeddings^2)))
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>       1       1       1       1       1       1
```

## Which models can be used?

[`models()`](https://sonsoles.me/sbert/reference/models.md) lists the
pinned models. It reads the registry inside the package and needs no
network:

``` r

models()
#>                                    model dimensions max_tokens      languages size_mb
#> 1                       all-MiniLM-L6-v2        384        256        English    90.9
#> 2                      all-MiniLM-L12-v2        384        128        English   133.6
#> 3                paraphrase-MiniLM-L3-v2        384        128        English    69.5
#> 4              multi-qa-MiniLM-L6-cos-v1        384        512        English    90.9
#> 5  paraphrase-multilingual-MiniLM-L12-v2        384        128  50+ languages   479.4
#> 6                      all-mpnet-base-v2        768        384        English   436.3
#> 7  paraphrase-multilingual-mpnet-base-v2        768        128  50+ languages  1119.2
#> 8                      bge-small-en-v1.5        384        512        English   133.8
#> 9                       bge-base-en-v1.5        768        512        English   436.5
#> 10                 multilingual-e5-small        384        512 100+ languages   487.4
#> 11                 nomic-embed-text-v1.5        768       8192        English   548.0
#> 12           jina-embeddings-v2-small-en        512       8192        English   130.5
#> 13                  mxbai-embed-large-v1       1024        512        English  1337.6
#> 14                        potion-base-8M        256    1000000        English    30.9
```

The registry holds 14 models, from 30.9 MB to 1,337.6 MB on disk, with
256 to 1,024 dimensions. Most are English; two `paraphrase-multilingual`
models cover more than 50 languages and `multilingual-e5-small` more
than 100. The default, `all-MiniLM-L6-v2`, is the model of the bundled
embeddings. `detail = TRUE` adds the settings that
[`encode()`](https://sonsoles.me/sbert/reference/encode.md) applies for
each model:

``` r

subset(models(detail = TRUE), select = c(model, pooling, prefix, engine))
#>                                    model pooling            prefix engine
#> 1                       all-MiniLM-L6-v2    mean                     onnx
#> 2                      all-MiniLM-L12-v2    mean                     onnx
#> 3                paraphrase-MiniLM-L3-v2    mean                     onnx
#> 4              multi-qa-MiniLM-L6-cos-v1    mean                     onnx
#> 5  paraphrase-multilingual-MiniLM-L12-v2    mean                     onnx
#> 6                      all-mpnet-base-v2    mean                     onnx
#> 7  paraphrase-multilingual-mpnet-base-v2    mean                     onnx
#> 8                      bge-small-en-v1.5     cls                     onnx
#> 9                       bge-base-en-v1.5     cls                     onnx
#> 10                 multilingual-e5-small    mean           query:    onnx
#> 11                 nomic-embed-text-v1.5    mean search_document:    onnx
#> 12           jina-embeddings-v2-small-en    mean                     onnx
#> 13                  mxbai-embed-large-v1     cls                     onnx
#> 14                        potion-base-8M    mean                   static
```

Three models use CLS pooling and the rest mean pooling. Two require a
text prefix, which
[`encode()`](https://sonsoles.me/sbert/reference/encode.md) adds
automatically (`"query: "` for `multilingual-e5-small` and
`"search_document: "` for `nomic-embed-text-v1.5`). `potion-base-8M` is
a static model: its embedding is a lookup and average of token vectors
in R, with no ONNX Runtime involved, intended for corpora too large to
encode with a transformer.

## Where are models stored, and when are they downloaded?

Models are stored in a per-user cache directory, located through
[`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html).
[`cache_dir()`](https://sonsoles.me/sbert/reference/cache_dir.md)
returns that path and creates nothing:

``` r

cache_dir()
#> [1] "/home/runner/.cache/R/sbert"
```

[`model_status()`](https://sonsoles.me/sbert/reference/model_status.md)
reports, for each file of a model, whether it is in the cache and
whether it passes its pinned byte-size and SHA-256 checks:

``` r

status <- model_status()
subset(status, select = c(file, exists, valid, expected_bytes))
#>             file exists valid expected_bytes
#> 1     model.onnx   TRUE  TRUE       90405214
#> 2 tokenizer.json   TRUE  TRUE         466247
```

On the machine that built this page, the default model is installed and
valid. The two files a transformer model needs are the ONNX graph
(90,405,214 bytes for `all-MiniLM-L6-v2`) and the tokenizer.

Nothing is downloaded when the package is installed, loaded, tested or
when this vignette is built. Two downloads are explicit and happen once:
the native ONNX Runtime used by `onnxr`, and each model. The chunk below
is not run here:

``` r

install_runtime()
model_download("all-MiniLM-L6-v2")
```

After that, [`encode()`](https://sonsoles.me/sbert/reference/encode.md)
computes embeddings. The bundled matrix was computed this way from the
600 messages of `corpus` and then rounded to four decimals. The first
use of a model that is not yet installed asks before downloading it in
an interactive session; scripts opt in with
`options(sbert.download = TRUE)` or call
[`model_download()`](https://sonsoles.me/sbert/reference/model_download.md)
first.
[`load_model()`](https://sonsoles.me/sbert/reference/load_model.md)
loads a model explicitly, for example to choose the number of inference
threads, and the loaded model is passed to
[`encode()`](https://sonsoles.me/sbert/reference/encode.md):

``` r

embeddings <- with(corpus, encode(translation))

model <- load_model("all-MiniLM-L6-v2", threads = 4)
embeddings <- with(corpus, encode(translation, model = model))
```

## How similar are two messages?

Because the rows are normalized, the cosine similarity of two messages
is the dot product of their embeddings.
[`topic_similarity()`](https://sonsoles.me/sbert/reference/topic_similarity.md)
computes it for every pair of rows, and `tidy = TRUE` returns one row
per pair. The first four messages of the corpus are:

``` r

head(corpus, 4)
#>                                     feedback
#> 1              Víš, co znamená o jeden více?
#> 2 V červeném má být o dva více než v modrém.
#> 3   Když to není člověk, tak co to může být?
#> 4              Co znamená všechny za prvním?
#>                                             translation n
#> 1                    Do you know what “one more” means? 2
#> 2 There should be two more in the red than in the blue. 3
#> 3               If it’s not a person, what could it be? 2
#> 4        What does “everyone after the first one” mean? 1
```

Their pairwise similarities, each pair once:

``` r

pairs <- topic_similarity(head(feedback_embeddings, 4), tidy = TRUE)
subset(pairs, from < to)
#>    from to similarity
#> 5     1  2     0.3613
#> 9     1  3     0.0954
#> 10    2  3     0.0935
#> 13    1  4     0.4894
#> 14    2  4     0.2236
#> 15    3  4     0.2177
```

Messages 1 and 4 are the most similar pair (0.489): both ask the learner
what a phrase means (“one more”, “everyone after the first one”).
Message 3, about whether something is a person, is the least similar to
messages 1 and 2 (0.095 and 0.094), while messages 1 and 2, both about a
difference in quantity, reach 0.361. Similarity follows what a message
does and what it is about, not the words it shares.

## Which messages are closest to a given message?

Similarity search scores every text of a corpus against one query. The
query here is the second message, a correction about the counts in two
boxes. Its embedding is taken from the bundled matrix, its similarity to
every message is added to the corpus as a column, and the messages above
0.8 are kept:

``` r

query_text <- "There should be two more in the red than in the blue."
query <- subset(feedback_embeddings, with(corpus, translation == query_text))
neighbors <- transform(corpus,
                        similarity = topic_similarity(feedback_embeddings, query))
subset(neighbors, similarity > 0.8, select = c(translation, similarity))
#>                                                                                   translation
#> 2                                       There should be two more in the red than in the blue.
#> 9   If there are supposed to be two more in the blue one, how many have to be in the red one?
#> 10                             There should be two fewer in the red one than in the blue one.
#> 32                                                  There should be more in blue than in red.
#> 96          If there should be more in the blue one, how many should there be in the red one?
#> 456                                There should be fewer in the red one than in the blue one.
#> 469                             There should be two more in the red box than in the blue box.
#> 475                            There should be two fewer in the blue one than in the red one.
#>     similarity
#> 2        1.000
#> 9        0.870
#> 10       0.898
#> 32       0.859
#> 96       0.825
#> 456      0.843
#> 469      0.860
#> 475      0.898
```

The query matches itself with similarity 1, and the closest other
messages are corrections of the same exercise, phrased with “more” or
“fewer”, “box” or “one”, and as statements or questions. The list also
shows what embeddings do not separate well: “There should be two fewer
in the red one than in the blue one” scores 0.898, as high as any other
message, although it asks for the opposite arrangement, and “There
should be more in blue than in red” scores 0.859. Sentence embeddings
capture topic and structure more reliably than the direction of a
comparison or a negation, so a search that must respect such
distinctions needs a check on the text itself.

To search with a new text rather than a message of the corpus, the query
is encoded with the same model (not run here):

``` r

query <- encode("Count the pictures in each box again.")
neighbors <- transform(corpus,
                        similarity = topic_similarity(feedback_embeddings, query))
```

## When to use which

| Task | Function |
|----|----|
| List the pinned models and their settings | [`models()`](https://sonsoles.me/sbert/reference/models.md), `models(detail = TRUE)` |
| Install the runtime and a model, once | [`install_runtime()`](https://sonsoles.me/sbert/reference/install_runtime.md), [`model_download()`](https://sonsoles.me/sbert/reference/model_download.md) |
| Check or locate the cache | [`model_status()`](https://sonsoles.me/sbert/reference/model_status.md), [`cache_dir()`](https://sonsoles.me/sbert/reference/cache_dir.md), [`cache_size()`](https://sonsoles.me/sbert/reference/cache_size.md), [`model_remove()`](https://sonsoles.me/sbert/reference/model_remove.md) |
| Load a model with chosen threads or backend | [`load_model()`](https://sonsoles.me/sbert/reference/load_model.md) |
| Load an ONNX model outside the registry | [`load_custom()`](https://sonsoles.me/sbert/reference/load_custom.md) |
| Compute embeddings | [`encode()`](https://sonsoles.me/sbert/reference/encode.md) |
| Pool token vectors yourself | [`pool()`](https://sonsoles.me/sbert/reference/pool.md) |
| Compare embeddings | [`topic_similarity()`](https://sonsoles.me/sbert/reference/topic_similarity.md) |
| Group texts into topics | [`topics()`](https://sonsoles.me/sbert/reference/topics.md), [`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md) |

The [main vignette](https://sonsoles.me/sbert/articles/sbert.html) fits
topic models on the bundled embeddings, and the guide to [models, the
cache, and custom
models](https://sonsoles.me/sbert/articles/models-and-cache.html) covers
the cache, custom models and inference settings in detail.
[Verification: Python parity and
determinism](https://sonsoles.me/sbert/articles/verification.html)
compares the embeddings with those of the Python library.

## References

Reimers, N., & Gurevych, I. (2019). Sentence-BERT: Sentence embeddings
using Siamese BERT-networks. *Proceedings of EMNLP-IJCNLP 2019*,
3982–3992. <https://doi.org/10.18653/v1/D19-1410>
