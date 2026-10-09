# Print a Prepared Topic Corpus

Shows what the corpus holds and can be reused for: document and unit
counts, the segmentation level, and whether embeddings are attached.

## Usage

``` r
# S3 method for class 'sbert_topic_corpus'
print(x, ...)
```

## Arguments

- x:

  An \`sbert_topic_corpus\` object.

- ...:

  Ignored.

## Value

The corpus object, invisibly.

## Examples

``` r
text <- c(
  "Cats chase mice", "Dogs chase balls",
  "Stocks and bonds trade", "Markets price shares"
)
embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
print(topic_corpus(text, embeddings = embeddings))
#> <sbert_topic_corpus>
#>   documents: 4 
#>   embedding dimension: 2 
#>   model: precomputed embeddings 
#>   tokenization: min_token_length = 2  
```
