# Print a prepared topic corpus

[`print()`](https://rdrr.io/r/base/print.html) shows what a corpus
prepared by
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)
holds: the number of documents and, for a segmented corpus, of segments
and their level; the embedding dimension; the embedding model; and the
minimum token length and whether tokens are stemmed.

## Usage

``` r
# S3 method for class 'sbert_topic_corpus'
print(x, ...)
```

## Arguments

- x:

  A corpus prepared by
  [`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md).

- ...:

  Ignored.

## Value

`x`, invisibly.

## See also

[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md);
[as.data.frame()](https://sonsoles.me/sbert/reference/as.data.frame.sbert_topic_corpus.md)
for the units.

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
print(topic_corpus(corpus, column = "translation",
                   embeddings = feedback_embeddings))
#> <sbert_topic_corpus>
#>   documents: 600 
#>   embedding dimension: 384 
#>   model: precomputed embeddings 
#>   tokenization: min_token_length = 2  
```
