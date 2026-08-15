# Load a Pinned Sentence-BERT Model

Loads already-downloaded model artifacts. The function never downloads
model files or native libraries. See \[models()\] for the available
pinned models.

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

  Name of a pinned model listed by \[models()\].

- cache_dir:

  Cache root returned by \[cache_dir()\].

- backend:

  ONNX execution backend accepted by \[onnxr::onnx_model()\].

- threads:

  Positive number of inference threads, or \`"auto"\` to use the
  machine's performance-core count. Inference is the dominant cost of
  \[encode()\] — about 88 that threads. The default \`1\` is deliberate:
  it keeps runs reproducible across machines and keeps the package
  within the two-core limit that check environments impose.

  Raising it is free of numerical consequence — output was
  \`identical()\` at 1, 2, 4, 6 and 8 threads across all 45 measured
  runs — but expect a modest gain, bounded by \*performance\* cores
  rather than logical ones. Over three repetitions at 200, 600 and 1,500
  documents on an Apple M4 (4 performance + 6 efficiency), median
  speedups against a single thread were 1.22x at two threads, 1.29x at
  four, 1.22x at six and 1.18x at eight. Four threads was fastest at the
  two larger sizes (1.34x at 1,500 documents); beyond that the
  efficiency cores add contention rather than throughput. Threaded
  timings are also noisy — run-to-run spread reached 26 under 3 Set
  \`threads = "auto"\` for the knee of that curve, or an integer to pin
  it.

- verify:

  Whether to verify file sizes and SHA-256 hashes before loading.

## Value

An object of class \`sbert_model\`.

## Examples

``` r
if (FALSE) { # \dontrun{
model <- load_model()
} # }
```
