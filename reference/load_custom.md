# Load a Hugging Face embedding model outside the pinned list

`load_custom()` loads a Hugging Face embedding model that is not in the
pinned list, on a "trust on first use" basis. Many embedding models on
Hugging Face publish an ONNX export of their encoder and a
`tokenizer.json`; such a model can be used like a pinned one, but its
configuration is not vouched for by the package: there is no pinned
revision, no package-controlled hash, and no check that its embeddings
match the reference implementation. The caller is responsible for the
pooling rule, prefix and maximum length.

On first use it resolves the current revision (unless `revision` is
given), downloads the ONNX graph and tokenizer, and records their sizes,
hashes and the model's configuration in a local manifest; later loads
verify the files against that manifest. A later load with the same
`revision` given uses no network; with `revision = NULL` every call
first asks Hugging Face for the current revision. Pooling and maximum
length are read from the repository's Sentence-Transformers
configuration when it has one and must be given otherwise; the embedding
dimension is read from the ONNX graph.

The result is an `sbert_model` like the one
[`load_model()`](https://sonsoles.me/sbert/reference/load_model.md)
returns, so [`encode()`](https://sonsoles.me/sbert/reference/encode.md),
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) and every
other verb accept it. For the pinned, verified models use
[`load_model()`](https://sonsoles.me/sbert/reference/load_model.md).

## Usage

``` r
load_custom(
  id,
  revision = NULL,
  onnx_path = NULL,
  tokenizer_path = "tokenizer.json",
  pooling = NULL,
  prefix = NULL,
  max_length = NULL,
  cache_dir = default_cache_dir(),
  backend = "cpu",
  threads = 1L,
  verify = TRUE,
  quiet = FALSE
)
```

## Arguments

- id:

  Hugging Face repository id, for example `"thenlper/gte-small"`.

- revision:

  Commit hash to pin, or `NULL` (default) to resolve the current
  revision online on every call. Pin it for offline reuse.

- onnx_path:

  Path of the ONNX graph in the repository, or `NULL` (default) to use
  `onnx/model.onnx` or `model.onnx`.

- tokenizer_path:

  Path of the tokenizer in the repository (default `"tokenizer.json"`).

- pooling:

  `"mean"` or `"cls"`, or `NULL` (default) to read it from the
  repository's `1_Pooling/config.json`.

- prefix:

  Text prepended to every input by
  [`encode()`](https://sonsoles.me/sbert/reference/encode.md). `NULL`
  (default) keeps the recorded prefix (`""` on first use); `""` clears
  it.

- max_length:

  Maximum word pieces per input, or `NULL` (default) to read it from
  `sentence_bert_config.json`, else 512.

- cache_dir:

  Cache root (default
  [`cache_dir()`](https://sonsoles.me/sbert/reference/cache_dir.md)).

- backend:

  ONNX execution backend, as accepted by
  [`onnxr::onnx_model()`](http://corymccartan.com/onnxr/reference/onnx_model.md)
  (default `"cpu"`).

- threads:

  Number of inference threads (default 1).

- verify:

  Check recorded sizes and SHA-256 hashes when loading from the cache
  (default `TRUE`).

- quiet:

  Suppress the download message and progress (default `FALSE`).

## Value

An object of class `sbert_model` with the same fields as
[`load_model()`](https://sonsoles.me/sbert/reference/load_model.md)
returns; its `short_name` is `"custom:<id>"`.

## Conditions

`sbert_runtime_missing` when ONNX Runtime is not installed;
`sbert_missing_package` when jsonlite is not installed;
`sbert_download_failed` when repository metadata or files cannot be
downloaded or the revision cannot be resolved; `sbert_model_error` when
the repository has no ONNX graph at the expected path, the pooling rule
cannot be detected and was not given, or the graph lacks a
`last_hidden_state` output or needs unsupported inputs;
`sbert_cache_invalid` when cached files no longer match the recorded
manifest.

## See also

[`load_model()`](https://sonsoles.me/sbert/reference/load_model.md) for
the pinned models;
[`install_runtime()`](https://sonsoles.me/sbert/reference/install_runtime.md)
for ONNX Runtime;
[`encode()`](https://sonsoles.me/sbert/reference/encode.md) to use the
model; [`cache_dir()`](https://sonsoles.me/sbert/reference/cache_dir.md)
for where it is stored.

## Examples

``` r
# Custom models are stored under "custom" in this cache root.
cache_dir()
#> [1] "/home/runner/.cache/R/sbert"

# \donttest{
if (interactive()) {
  model <- load_custom("thenlper/gte-small")
  encode(c("one sentence", "another sentence"), model)
}
# }
```
