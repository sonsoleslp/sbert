# List the pinned models

`models()` lists the pinned embedding models as a table: by default the
columns needed to choose a model, and with `detail = TRUE` also the
settings the package applies when encoding (pooling rule and input
prefix), the inference engine, the license, and the repository and
revision. Embedding models differ in the languages they cover, the
length of input they read, the size of their vectors, and the disk and
time they cost.

The package supports a fixed set of models, each pinned to an immutable
Hugging Face revision and verified by file size and SHA-256 hash, so a
model name identifies exactly one model. The result has one row per
pinned model.

Pass a value of the `model` column to any argument that takes a model,
for example `encode(text, model = "bge-small-en-v1.5")`, or to
[`load_model()`](https://sonsoles.me/sbert/reference/load_model.md) and
[`model_download()`](https://sonsoles.me/sbert/reference/model_download.md).
For a model outside the list, see
[`load_custom()`](https://sonsoles.me/sbert/reference/load_custom.md).

## Usage

``` r
models(detail = FALSE)
```

## Arguments

- detail:

  `FALSE` (default) for the columns `model`, `dimensions`, `max_tokens`,
  `languages` and `size_mb`; `TRUE` adds `pooling` (`"mean"` or
  `"cls"`), `prefix` (text prepended by
  [`encode()`](https://sonsoles.me/sbert/reference/encode.md)), `engine`
  (`"onnx"` or `"static"`), `license`, `id` and `revision`.

## Value

A base data frame with one row per pinned model and the columns
described under `detail`. `size_mb` is the download size in megabytes.

## See also

[`load_model()`](https://sonsoles.me/sbert/reference/load_model.md) and
[`model_download()`](https://sonsoles.me/sbert/reference/model_download.md)
to use a model;
[`model_status()`](https://sonsoles.me/sbert/reference/model_status.md)
to check an installation;
[`load_custom()`](https://sonsoles.me/sbert/reference/load_custom.md)
for other models.

## Examples

``` r
models()
#>                                    model dimensions max_tokens      languages
#> 1                       all-MiniLM-L6-v2        384        256        English
#> 2                      all-MiniLM-L12-v2        384        128        English
#> 3                paraphrase-MiniLM-L3-v2        384        128        English
#> 4              multi-qa-MiniLM-L6-cos-v1        384        512        English
#> 5  paraphrase-multilingual-MiniLM-L12-v2        384        128  50+ languages
#> 6                      all-mpnet-base-v2        768        384        English
#> 7  paraphrase-multilingual-mpnet-base-v2        768        128  50+ languages
#> 8                      bge-small-en-v1.5        384        512        English
#> 9                       bge-base-en-v1.5        768        512        English
#> 10                 multilingual-e5-small        384        512 100+ languages
#> 11                 nomic-embed-text-v1.5        768       8192        English
#> 12           jina-embeddings-v2-small-en        512       8192        English
#> 13                  mxbai-embed-large-v1       1024        512        English
#> 14                        potion-base-8M        256    1000000        English
#>    size_mb
#> 1     90.9
#> 2    133.6
#> 3     69.5
#> 4     90.9
#> 5    479.4
#> 6    436.3
#> 7   1119.2
#> 8    133.8
#> 9    436.5
#> 10   487.4
#> 11   548.0
#> 12   130.5
#> 13  1337.6
#> 14    30.9
models(detail = TRUE)
#>                                    model dimensions max_tokens      languages
#> 1                       all-MiniLM-L6-v2        384        256        English
#> 2                      all-MiniLM-L12-v2        384        128        English
#> 3                paraphrase-MiniLM-L3-v2        384        128        English
#> 4              multi-qa-MiniLM-L6-cos-v1        384        512        English
#> 5  paraphrase-multilingual-MiniLM-L12-v2        384        128  50+ languages
#> 6                      all-mpnet-base-v2        768        384        English
#> 7  paraphrase-multilingual-mpnet-base-v2        768        128  50+ languages
#> 8                      bge-small-en-v1.5        384        512        English
#> 9                       bge-base-en-v1.5        768        512        English
#> 10                 multilingual-e5-small        384        512 100+ languages
#> 11                 nomic-embed-text-v1.5        768       8192        English
#> 12           jina-embeddings-v2-small-en        512       8192        English
#> 13                  mxbai-embed-large-v1       1024        512        English
#> 14                        potion-base-8M        256    1000000        English
#>    pooling            prefix engine size_mb    license
#> 1     mean                     onnx    90.9 Apache-2.0
#> 2     mean                     onnx   133.6 Apache-2.0
#> 3     mean                     onnx    69.5 Apache-2.0
#> 4     mean                     onnx    90.9 Apache-2.0
#> 5     mean                     onnx   479.4 Apache-2.0
#> 6     mean                     onnx   436.3 Apache-2.0
#> 7     mean                     onnx  1119.2 Apache-2.0
#> 8      cls                     onnx   133.8        MIT
#> 9      cls                     onnx   436.5        MIT
#> 10    mean           query:    onnx   487.4        MIT
#> 11    mean search_document:    onnx   548.0 Apache-2.0
#> 12    mean                     onnx   130.5 Apache-2.0
#> 13     cls                     onnx  1337.6 Apache-2.0
#> 14    mean                   static    30.9        MIT
#>                                                             id
#> 1                       sentence-transformers/all-MiniLM-L6-v2
#> 2                      sentence-transformers/all-MiniLM-L12-v2
#> 3                sentence-transformers/paraphrase-MiniLM-L3-v2
#> 4              sentence-transformers/multi-qa-MiniLM-L6-cos-v1
#> 5  sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
#> 6                      sentence-transformers/all-mpnet-base-v2
#> 7  sentence-transformers/paraphrase-multilingual-mpnet-base-v2
#> 8                                       BAAI/bge-small-en-v1.5
#> 9                                        BAAI/bge-base-en-v1.5
#> 10                              intfloat/multilingual-e5-small
#> 11                              nomic-ai/nomic-embed-text-v1.5
#> 12                          jinaai/jina-embeddings-v2-small-en
#> 13                          mixedbread-ai/mxbai-embed-large-v1
#> 14                                    minishlab/potion-base-8M
#>                                    revision
#> 1  1110a243fdf4706b3f48f1d95db1a4f5529b4d41
#> 2  a50ef00143b4d5391434df20ae11632588ac25be
#> 3  4ca70771034acceecb2e72475f72050fcdde4ddc
#> 4  b207367332321f8e44f96e224ef15bc607f4dbf0
#> 5  e8f8c211226b894fcb81acc59f3b34ba3efd5f42
#> 6  e8c3b32edf5434bc2275fc9bab85f82640a19130
#> 7  4328cf26390c98c5e3c738b4460a05b95f4911f5
#> 8  5c38ec7c405ec4b44b94cc5a9bb96e735b38267a
#> 9  a5beb1e3e68b9ab74eb54cfd186867f64f240e1a
#> 10 614241f622f53c4eeff9890bdc4f31cfecc418b3
#> 11 e9b6763023c676ca8431644204f50c2b100d9aab
#> 12 44e7d1d6caec8c883c2d4b207588504d519788d0
#> 13 b33106f585b9ce46904ad7443a3b52b7a63e231c
#> 14 bf8b056651a2c21b8d2565580b8569da283cab23
```
