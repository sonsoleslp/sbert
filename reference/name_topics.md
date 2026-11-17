# Name the topics of a fitted model

`name_topics()` replaces the label of every topic of a fitted model with
the names given, in topic order. The labels that
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) gives are
drawn from the data (the most central text of each topic, or its most
distinctive terms); once the representative texts of each topic have
been read, a short name for what the topic is about, such as the kind of
message it holds, communicates the result better.

The names then appear in every table and figure that refers to a topic,
including
[summary()](https://sonsoles.me/sbert/reference/summary.sbert_topic_model.md),
[`topic_sizes()`](https://sonsoles.me/sbert/reference/topic_sizes.md),
[terms()](https://sonsoles.me/sbert/reference/terms.sbert_topic_model.md),
[`representatives()`](https://sonsoles.me/sbert/reference/representatives.md),
[predict()](https://sonsoles.me/sbert/reference/predict.sbert_topic_model.md),
[`topic_hierarchy()`](https://sonsoles.me/sbert/reference/topic_hierarchy.md),
and
[plot()](https://sonsoles.me/sbert/reference/plot.sbert_topic_model.md).
The model is not refitted; the result is the topic model with its labels
replaced.

[`reduce_topics()`](https://sonsoles.me/sbert/reference/reduce_topics.md)
drops the names, because merged topics need new ones.

## Usage

``` r
name_topics(object, labels)
```

## Arguments

- object:

  A topic model fitted by
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md).

- labels:

  Character vector of distinct, non-empty names, one per topic, in topic
  order (topic 1 first).

## Value

The topic model with its labels replaced; an object of class
`sbert_topic_model`.

## Conditions

An error of class `sbert_bad_topic_names` when `labels` is not a
character vector of distinct, non-empty, non-missing names, one per
topic.

## See also

[`representatives()`](https://sonsoles.me/sbert/reference/representatives.md)
to read each topic before naming it;
[`topics()`](https://sonsoles.me/sbert/reference/topics.md).

## Examples

``` r
text <- c(
  "Cats chase mice", "Dogs chase balls",
  "Stocks and bonds trade", "Markets price shares"
)
embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
topic_model <- topics(text, n_topics = 2, embeddings = embeddings)
named <- name_topics(topic_model, c("Pets", "Finance"))
topic_sizes(named)
#>   topic   label n_documents proportion
#> 1     1    Pets           2        0.5
#> 2     2 Finance           2        0.5
```
