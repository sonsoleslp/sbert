# Models, the cache, and custom models

A sentence embedding is only as reproducible as the model that computed
it. Two analyses that both say they used “all-MiniLM-L6-v2” can disagree
if one downloaded the model a year later, after the repository was
updated, or if a file was truncated in transit. The choice of model also
shapes the result: models differ in the languages they were trained on,
in the length of text they read, and in the size of the vectors they
return, and each of these limits what an analysis can ask of the
embeddings.

`sbert` treats the model as part of the method. Each supported model is
pinned to an immutable revision of its Hugging Face repository and to
the size and SHA-256 hash of every file, downloads happen only when
asked for, and every file is verified before it is used. This guide
covers the registry of pinned models and how to choose among them,
installing the runtime and a model, the cache in which models are kept,
scripts that run without a person to answer a prompt, and models outside
the registry.

``` r

library(sbert)
#> sbert 0.5.14: Sentence-BERT embeddings and topic models in R.
#>   14 pinned models (see models()); default: all-MiniLM-L6-v2.
#>   A model is downloaded only on request, once, and verified by SHA-256.
```

## Data

The data of this guide is the registry of pinned models, returned by
[`models()`](https://sonsoles.me/sbert/reference/models.md). Reading it
needs no download and no network.

- **`model`:** the name passed to
  [`load_model()`](https://sonsoles.me/sbert/reference/load_model.md),
  [`encode()`](https://sonsoles.me/sbert/reference/encode.md) and the
  topic verbs.
- **`dimensions`:** the length of each embedding vector.
- **`max_tokens`:** the longest input the model reads, in its sub-word
  tokens; longer inputs are truncated.
- **`languages`:** the languages the model was trained for.
- **`size_mb`:** the download size in megabytes.

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

The registry pins 14 models. They return vectors of 256 to 1024
dimensions and take from 30.9 MB to 1,338 MB of disk. The default,
`all-MiniLM-L6-v2`, returns 384 dimensions, reads 256 tokens and takes
90.9 MB.

## Which model fits the corpus?

Three properties decide the choice: the languages of the texts, their
length, and the cost the analysis can bear. The language comes first: an
English model embeds text in other languages poorly, and texts in two
languages that mean the same thing are close only in a multilingual
model.

``` r

subset(models(), languages != "English")
#>                                    model dimensions max_tokens      languages size_mb
#> 5  paraphrase-multilingual-MiniLM-L12-v2        384        128  50+ languages     479
#> 7  paraphrase-multilingual-mpnet-base-v2        768        128  50+ languages    1119
#> 10                 multilingual-e5-small        384        512 100+ languages     487
```

Of the pinned models, 3 are multilingual. The two
`paraphrase-multilingual` models read 128 tokens, about a long sentence;
`multilingual-e5-small` reads 512. For an English corpus, length is the
next question.

``` r

subset(models(), max_tokens >= 512)
#>                          model dimensions max_tokens      languages size_mb
#> 4    multi-qa-MiniLM-L6-cos-v1        384        512        English    90.9
#> 8            bge-small-en-v1.5        384        512        English   133.8
#> 9             bge-base-en-v1.5        768        512        English   436.5
#> 10       multilingual-e5-small        384        512 100+ languages   487.4
#> 11       nomic-embed-text-v1.5        768       8192        English   548.0
#> 12 jina-embeddings-v2-small-en        512       8192        English   130.5
#> 13        mxbai-embed-large-v1       1024        512        English  1337.6
#> 14              potion-base-8M        256    1000000        English    30.9
```

Of the pinned models, 8 read 512 tokens or more, and
`nomic-embed-text-v1.5` and `jina-embeddings-v2-small-en` read 8,192,
more than a research abstract needs. `potion-base-8M` lists 1,000,000
because it has no window at all: it is a static model that looks up a
vector for each token and averages them, without a neural network. It is
the smallest model in the registry, needs no ONNX Runtime, and replaces
the transformer with a table lookup, but averaging ignores word order,
so “the teacher helped the student” and “the student helped the teacher”
get the same vector. A long-window model is one answer to long
documents; splitting them into sentences, covered in the [guide to
segmenting long
documents](https://sonsoles.me/sbert/articles/segmenting.md), is the
other, and it works with every model.

`models(detail = TRUE)` adds the technical settings that
[`encode()`](https://sonsoles.me/sbert/reference/encode.md) applies
automatically.

``` r

subset(models(detail = TRUE),
       select = c(model, pooling, prefix, engine, license))
#>                                    model pooling            prefix engine    license
#> 1                       all-MiniLM-L6-v2    mean                     onnx Apache-2.0
#> 2                      all-MiniLM-L12-v2    mean                     onnx Apache-2.0
#> 3                paraphrase-MiniLM-L3-v2    mean                     onnx Apache-2.0
#> 4              multi-qa-MiniLM-L6-cos-v1    mean                     onnx Apache-2.0
#> 5  paraphrase-multilingual-MiniLM-L12-v2    mean                     onnx Apache-2.0
#> 6                      all-mpnet-base-v2    mean                     onnx Apache-2.0
#> 7  paraphrase-multilingual-mpnet-base-v2    mean                     onnx Apache-2.0
#> 8                      bge-small-en-v1.5     cls                     onnx        MIT
#> 9                       bge-base-en-v1.5     cls                     onnx        MIT
#> 10                 multilingual-e5-small    mean           query:    onnx        MIT
#> 11                 nomic-embed-text-v1.5    mean search_document:    onnx Apache-2.0
#> 12           jina-embeddings-v2-small-en    mean                     onnx Apache-2.0
#> 13                  mxbai-embed-large-v1     cls                     onnx Apache-2.0
#> 14                        potion-base-8M    mean                   static        MIT
```

`pooling` is how token vectors become one text vector: the mean of all
tokens, or the vector of the first (`cls`) token, as each model was
trained. `prefix` is text that two models expect before every input
(`"query: "` for `multilingual-e5-small`, `"search_document: "` for
`nomic-embed-text-v1.5`);
[`encode()`](https://sonsoles.me/sbert/reference/encode.md) adds it, so
the caller passes the text alone. `engine` separates the transformer
models (`onnx`) from the static one. The licenses are Apache-2.0 or MIT.
The full Hugging Face id and the pinned revision are in the columns `id`
and `revision`.

Dimension has a cost: memory and k-means time grow with it. A corpus of
100,000 texts at 1,024 dimensions takes 819.2 MB as a matrix of doubles
(8 bytes per value), against 307.2 MB at 384. A larger model is worth
its cost when a comparison on the corpus, for example with
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md),
shows it separates the themes better (see [choosing the number of
topics](https://sonsoles.me/sbert/articles/choosing-topics.md)).

## What does a first run need?

A transformer model needs the native ONNX Runtime, which the `onnxr`
package installs on request. The model’s files are then downloaded once.
Neither step happens during installation or loading of `sbert`, and
neither is run in this guide.

``` r

install_runtime()                         # once per machine
model_download("all-MiniLM-L6-v2")        # once per model
model <- load_model("all-MiniLM-L6-v2")
embeddings <- encode(c("A first sentence.", "A second one."), model)
```

[`install_runtime()`](https://sonsoles.me/sbert/reference/install_runtime.md)
passes `cuda` to
[`onnxr::onnx_install()`](http://corymccartan.com/onnxr/reference/onnx_install.md):
`FALSE` asks for the portable CPU runtime, `TRUE` for CUDA where it is
supported, and `NULL` (the default) detects which.
[`model_download()`](https://sonsoles.me/sbert/reference/model_download.md)
fetches only the files that are missing or fail verification, writes
each to a temporary file, checks its size and SHA-256 hash, and moves it
into the cache only if both match.
[`load_model()`](https://sonsoles.me/sbert/reference/load_model.md)
never downloads: it loads files already in the cache, verifies them
again (`verify = TRUE`), and stops with an error of class
`sbert_model_not_installed` when a file is missing,
`sbert_cache_invalid` when one fails verification, and
`sbert_runtime_missing` when a transformer model is loaded without ONNX
Runtime. The static `potion-base-8M` is loaded without the runtime.

Verbs that take a model name, such as
`encode(text, model = "bge-small-en-v1.5")`, load it themselves and keep
it for the rest of the session. If it is not installed, an interactive
session asks once whether to download it, giving the size and license.

## Where are the models kept?

All models live in one cache per user, outside any project, at the
location R designates for the package’s cached files.

``` r

cache_dir()
#> [1] "/home/runner/.cache/R/sbert"
```

[`cache_dir()`](https://sonsoles.me/sbert/reference/cache_dir.md)
returns the path from `tools::R_user_dir("sbert", which = "cache")` and
creates nothing. Inside it, each pinned model has a directory named
after the model and its revision, so two revisions can never be mixed.
[`model_status()`](https://sonsoles.me/sbert/reference/model_status.md)
lists the files a model needs and checks them.

``` r

subset(model_status(model = "all-MiniLM-L6-v2"),
       select = c(file, exists, valid, expected_bytes, actual_bytes))
#>             file exists valid expected_bytes actual_bytes
#> 1     model.onnx   TRUE  TRUE       90405214     90405214
#> 2 tokenizer.json   TRUE  TRUE         466247       466247
subset(model_status(model = "potion-base-8M"),
       select = c(file, exists, valid, expected_bytes, actual_bytes))
#>                file exists valid expected_bytes actual_bytes
#> 1 model.safetensors  FALSE FALSE       30236760           NA
#> 2    tokenizer.json  FALSE FALSE         683666           NA
#> 3       config.json  FALSE FALSE            202           NA
```

The default model consists of `model.onnx` and `tokenizer.json`; the
static model of an embedding table (`model.safetensors`), a tokenizer
and a configuration file. On the machine that built this page no model
is installed, so every file is reported missing (`exists` is TRUE) and
invalid. `valid` is true only when the file has the pinned size and
hash;
[`model_status()`](https://sonsoles.me/sbert/reference/model_status.md)
only reads, so calling it is safe at any time. The `path` column, left
out here, gives where each file is expected.

``` r

cache_size()
#> [1] 90871461
```

[`cache_size()`](https://sonsoles.me/sbert/reference/cache_size.md) is
the number of bytes used by all files under the cache, here 9.087^{7}
because nothing has been downloaded. Models are kept until they are
removed, and
[`model_remove()`](https://sonsoles.me/sbert/reference/model_remove.md)
deletes the directory of one pinned model; other models and custom
models are untouched.

``` r

model_remove(model = "all-mpnet-base-v2")
```

Every one of these functions takes `cache_dir`, so a project can keep
its models elsewhere, for example on a shared drive, by passing the same
path to
[`model_download()`](https://sonsoles.me/sbert/reference/model_download.md),
[`model_status()`](https://sonsoles.me/sbert/reference/model_status.md)
and [`load_model()`](https://sonsoles.me/sbert/reference/load_model.md).

## Scripts that run unattended

A script run with `Rscript`, a scheduled job or a knitted report has no
one to answer the download prompt. In such a session a missing model is
an error of class `sbert_model_not_installed`, never a silent download.
There are two ways to allow the download.

``` r

# Either install explicitly, once, before the analysis runs ...
model_download("all-MiniLM-L6-v2", quiet = TRUE)

# ... or allow this script to download any model it needs.
options(sbert.download = TRUE)
embeddings <- encode(c("A first sentence.", "A second one."))
```

With `options(sbert.download = TRUE)`, a verb that needs a missing model
calls
[`model_download()`](https://sonsoles.me/sbert/reference/model_download.md)
itself, with the same verification as an explicit download. The explicit
call is the better choice for a shared or published analysis: the script
then states which models it depends on.

## Models outside the registry

[`load_custom()`](https://sonsoles.me/sbert/reference/load_custom.md)
loads any public Hugging Face repository that ships an ONNX export of an
encoder and a `tokenizer.json`. The result is an `sbert_model` like
those from
[`load_model()`](https://sonsoles.me/sbert/reference/load_model.md), so
[`encode()`](https://sonsoles.me/sbert/reference/encode.md),
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) and every
other verb accept it.

``` r

gte <- load_custom("thenlper/gte-small")
embeddings <- encode(c("A first sentence.", "A second one."), gte)

# Pin a revision, and state settings that cannot be detected
gte <- load_custom("thenlper/gte-small",
                   revision = "<commit hash>",
                   pooling = "mean", max_length = 512)
```

A custom model is trusted on first use. On the first call,
[`load_custom()`](https://sonsoles.me/sbert/reference/load_custom.md)
resolves the repository’s current revision (unless `revision` is given),
detects the pooling from the repository’s Sentence-Transformers
configuration and the maximum length from `sentence_bert_config.json`
(512 when that file is absent), downloads the two files, and records
their sizes and SHA-256 hashes in a local manifest. It stops with an
error when the pooling cannot be detected and is not given. A later call
with the same `revision` reads the manifest, verifies the files against
it, and does not use the network. A later call without `revision` first
asks Hugging Face for the repository’s current revision; if the
repository has changed, that revision is downloaded and recorded as a
new model, so an analysis that must not change pins `revision`. The
files are kept under `custom/` in the cache directory, one directory per
repository and revision, and
[`model_remove()`](https://sonsoles.me/sbert/reference/model_remove.md)
does not delete them. It needs the `jsonlite` package.

The difference from a pinned model is who vouches for it. The registry’s
hashes and settings were fixed by the package; a custom model’s were
recorded from whatever the repository held on first download, and the
package makes no claim that its embeddings match the original
implementation. Passing `revision` makes the analysis reproducible;
checking a few embeddings against the reference implementation, as the
[verification guide](https://sonsoles.me/sbert/articles/verification.md)
describes for the default model, makes it trustworthy.

## Which call for which task

- See the available models and their settings:
  [`models()`](https://sonsoles.me/sbert/reference/models.md),
  `models(detail = TRUE)`.
- Set up a machine:
  [`install_runtime()`](https://sonsoles.me/sbert/reference/install_runtime.md)
  once, then
  [`model_download()`](https://sonsoles.me/sbert/reference/model_download.md)
  for each model the analysis uses.
- Check an installation without loading it:
  [`model_status()`](https://sonsoles.me/sbert/reference/model_status.md);
  disk use:
  [`cache_size()`](https://sonsoles.me/sbert/reference/cache_size.md);
  free space:
  [`model_remove()`](https://sonsoles.me/sbert/reference/model_remove.md).
- Run a script unattended:
  [`model_download()`](https://sonsoles.me/sbert/reference/model_download.md)
  beforehand, or `options(sbert.download = TRUE)`.
- Use a model not in the registry:
  [`load_custom()`](https://sonsoles.me/sbert/reference/load_custom.md),
  with a pinned `revision`.
- Encode faster: `load_model(threads = "auto")` or the static
  `potion-base-8M` (see [parallel and high-throughput topic
  modeling](https://sonsoles.me/sbert/articles/parallel.md)).
