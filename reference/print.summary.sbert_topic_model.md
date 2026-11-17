# Print a topic model summary

[`print()`](https://rdrr.io/r/base/print.html) shows the overview of a
topic model summary (documents, segments, topics, model, between-topic
share of the variance, mean coherence, topic diversity, and a note when
k-means did not converge) followed by the table of topics.

## Usage

``` r
# S3 method for class 'summary.sbert_topic_model'
print(x, digits = 4L, ...)
```

## Arguments

- x:

  A summary returned by
  [summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_model.md).

- digits:

  Significant digits in the table of topics (default 4).

- ...:

  Ignored.

## Value

`x`, invisibly.

## See also

[`summary.sbert_topic_model()`](https://sonsoles.me/sbert/reference/summary.sbert_topic_model.md).

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings)
print(summary(topic_model), digits = 2)
#> Semantic topic model summary
#>   documents:            600
#>   topics:               6
#>   model:                precomputed embeddings
#>   between/total SS:     22.6%
#>   mean npmi  coherence:  -0.1044
#>   topic diversity:      0.917 (top 10 terms)
#> 
#>  topic                                                       label n_documents
#>      1   Where is the cow and the cake? Choose all the pictures...         223
#>      2            All the ones between the cat and the strawberry.         133
#>      3         What does “all the ones between the leaf and the...         131
#>      4 Are you sure you have fewer pictures in the red box than...          49
#>      5      In the top middle box, it means something is in the...          37
#>      6    It is not a person, does not have a hat, and is sitting.          27
#>  proportion coherence
#>       0.372     -0.24
#>       0.222     -0.42
#>       0.218     -0.26
#>       0.082      0.30
#>       0.062     -0.20
#>       0.045      0.18
```
