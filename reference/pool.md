# Pool token embeddings into sentence embeddings

`pool()` reduces the token embeddings of each text to one sentence
embedding, by mean or CLS pooling. A transformer encoder returns one
vector per word piece of a text, whereas a sentence embedding is one
vector per text, and the pooling rule is part of the model's definition:
Sentence-BERT models average the token vectors over the positions that
hold real tokens (mean pooling; Reimers and Gurevych, 2019), while the
BGE and mxbai families take the vector of the first, classification
token (CLS pooling).

It applies either rule to an array of token embeddings and its attention
mask, and by default scales each pooled vector to unit Euclidean (L2)
length, the form in which cosine similarity is a dot product. It returns
a matrix with one row per text. It is the step
[`encode()`](https://sonsoles.me/sbert/reference/encode.md) runs after
the ONNX model, exposed for checking the arithmetic or for pooling token
embeddings computed elsewhere.

To embed text, use
[`encode()`](https://sonsoles.me/sbert/reference/encode.md), which
tokenizes, runs the model, and pools with the rule pinned for that
model; `models(detail = TRUE)` lists each model's rule.

## Usage

``` r
pool(
  token_embeddings,
  attention_mask,
  normalize = TRUE,
  method = c("mean", "cls")
)
```

## Arguments

- token_embeddings:

  Numeric array of token embeddings, shaped texts x tokens x hidden
  dimensions.

- attention_mask:

  Numeric matrix shaped texts x tokens: 1 for a real token, 0 for
  padding.

- normalize:

  Scale each pooled vector to unit L2 length (default `TRUE`).

- method:

  `"mean"` (default), the average over positions with mask 1, or
  `"cls"`, the first token.

## Value

A numeric matrix with one row per text and one column per hidden
dimension, without dimnames.

## References

Reimers, N., & Gurevych, I. (2019). Sentence-BERT: Sentence embeddings
using Siamese BERT-networks. *Proceedings of the 2019 Conference on
Empirical Methods in Natural Language Processing and the 9th
International Joint Conference on Natural Language Processing
(EMNLP-IJCNLP)*, 3982-3992.
[doi:10.18653/v1/D19-1410](https://doi.org/10.18653/v1/D19-1410)

## See also

[`encode()`](https://sonsoles.me/sbert/reference/encode.md) for
embeddings of text;
[`models()`](https://sonsoles.me/sbert/reference/models.md) for the
pooling rule of each pinned model.

## Examples

``` r
# Two texts, three token positions, two hidden dimensions; the first text
# has two real tokens, the second one.
hidden <- array(1:12, dim = c(2, 3, 2))
mask <- matrix(c(1, 1, 0, 1, 0, 0), nrow = 2, byrow = TRUE)
pool(hidden, mask)
#>           [,1]      [,2]
#> [1,] 0.2425356 0.9701425
#> [2,] 0.2425356 0.9701425
pool(hidden, mask, method = "cls")
#>           [,1]      [,2]
#> [1,] 0.1414214 0.9899495
#> [2,] 0.2425356 0.9701425
pool(hidden, mask, normalize = FALSE)
#>      [,1] [,2]
#> [1,]    2    8
#> [2,]    2    8
```
