# Load an installed pinned model

`load_model()` reads an installed pinned model from the cache, verifies
its files against the pinned sizes and hashes, and returns the model
ready for inference: the tokenizer and the ONNX session (or, for the
static `potion-base-8M`, its embedding table). An embedding model is
defined by its network weights, its tokenizer, and the rules applied
around them (pooling, input prefix, maximum input length); the package
pins each supported model to an immutable Hugging Face revision with
known file sizes and SHA-256 hashes, so that the same name always means
the same model and the same text always receives the same embedding.

It never downloads anything; the files must first be installed with
[`model_download()`](https://sonsoles.me/sbert/reference/model_download.md),
and transformer models also need ONNX Runtime from
[`install_runtime()`](https://sonsoles.me/sbert/reference/install_runtime.md).
The result is an object of class `sbert_model`.

Most verbs accept a model name and load it themselves, keeping it for
the rest of the session, so an explicit `load_model()` is needed mainly
to set `backend` or `threads`. For a model outside the pinned list, use
[`load_custom()`](https://sonsoles.me/sbert/reference/load_custom.md).

## Usage

``` r
load_model(
  model = "all-MiniLM-L6-v2",
  cache_dir = default_cache_dir(),
  backend = "cpu",
  threads = 1L,
  verify = TRUE
)
```

## Arguments

- model:

  Name of a pinned model, as listed by
  [`models()`](https://sonsoles.me/sbert/reference/models.md) (default
  `"all-MiniLM-L6-v2"`).

- cache_dir:

  Cache root (default
  [`cache_dir()`](https://sonsoles.me/sbert/reference/cache_dir.md)).

- backend:

  ONNX execution backend: `"cpu"` (default), `"coreml"`, `"cuda"`,
  `"xnnpack"` or `"openvino"`, as accepted by
  [`onnxr::onnx_model()`](http://corymccartan.com/onnxr/reference/onnx_model.md).

- threads:

  Number of inference threads, or `"auto"` for the machine's
  performance-core count (default 1). Results do not depend on the
  thread count; the gain in speed is modest and bounded by the number of
  performance cores. The default of one keeps runs within the two-core
  limit of check environments.

- verify:

  Check file sizes and SHA-256 hashes before loading (default `TRUE`).

## Value

An object of class `sbert_model` (class
`c("sbert_static_model", "sbert_model")` for `potion-base-8M`): a list
holding the model's identity (`id`, `short_name`, `revision`), its
encoding settings (`dimension`, `max_length`, `pooling`, `prefix`), the
`backend` and `threads` it runs with, and the loaded tokenizer and
model. Pass it to the `model` argument of
[`encode()`](https://sonsoles.me/sbert/reference/encode.md) and of the
topic verbs; its print method shows the identity.

## Conditions

`sbert_unknown_model` when `model` names no pinned model;
`sbert_model_not_installed` when its files are missing;
`sbert_cache_invalid` when they fail size or hash verification;
`sbert_runtime_missing` when ONNX Runtime is not installed (transformer
models only); `sbert_missing_package` when the static model is loaded
without jsonlite; `sbert_model_error` when the tokenizer or model cannot
be loaded.

## See also

[`models()`](https://sonsoles.me/sbert/reference/models.md) for the
pinned models;
[`model_download()`](https://sonsoles.me/sbert/reference/model_download.md)
and
[`install_runtime()`](https://sonsoles.me/sbert/reference/install_runtime.md)
to install them;
[`model_status()`](https://sonsoles.me/sbert/reference/model_status.md)
to check an installation;
[`load_custom()`](https://sonsoles.me/sbert/reference/load_custom.md)
for other Hugging Face models;
[`encode()`](https://sonsoles.me/sbert/reference/encode.md) to use the
model.

## Examples

``` r
# The pinned models that load_model() accepts.
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

# \donttest{
if (interactive()) {
  model <- load_model()
  model
}
# }
```
