# Precomputed embeddings of 600 feedback messages

`feedback_embeddings` is a matrix of Sentence-BERT embeddings of the
first 600 distinct English translations of
[feedback_translations](https://sonsoles.me/sbert/reference/feedback_translations.md),
in order of first appearance. They let topic models be fitted, compared,
and inspected without downloading a model, and they are the embeddings
used by the examples and articles of the package.

Row `i` is the embedding of row `i` of
`head(dedupe(feedback_translations, column = "translation"), 600)`. Pass
the matrix as `embeddings =` to
[`topics()`](https://sonsoles.me/sbert/reference/topics.md),
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md),
or
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)
together with that data frame.

## Usage

``` r
feedback_embeddings
```

## Format

A numeric matrix with 600 rows (messages) and 384 columns (embedding
dimensions). Rows are L2-normalized and rounded to four decimals.

## Source

Encoded with the pinned `sentence-transformers/all-MiniLM-L6-v2` model
(revision `1110a243fdf4706b3f48f1d95db1a4f5529b4d41`) by
`data-raw/feedback_embeddings.R`. Encoding the same messages with
[`encode()`](https://sonsoles.me/sbert/reference/encode.md) gives the
same embeddings up to the rounding.

## See also

[feedback_translations](https://sonsoles.me/sbert/reference/feedback_translations.md),
[`topics()`](https://sonsoles.me/sbert/reference/topics.md),
[`encode()`](https://sonsoles.me/sbert/reference/encode.md).

## Examples

``` r
dim(feedback_embeddings)
#> [1] 600 384

corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings)
topic_sizes(topic_model, weights = "n")
#>   topic                                                       label n_documents
#> 1     1   Where is the cow and the cake? Choose all the pictures...         223
#> 2     2            All the ones between the cat and the strawberry.         133
#> 3     3         What does “all the ones between the leaf and the...         131
#> 4     4 Are you sure you have fewer pictures in the red box than...          49
#> 5     5      In the top middle box, it means something is in the...          37
#> 6     6    It is not a person, does not have a hat, and is sitting.          27
#>   proportion n_weighted weighted_share
#> 1 0.37166667        267     0.36081081
#> 2 0.22166667        162     0.21891892
#> 3 0.21833333        138     0.18648649
#> 4 0.08166667         76     0.10270270
#> 5 0.06166667         57     0.07702703
#> 6 0.04500000         40     0.05405405
```
