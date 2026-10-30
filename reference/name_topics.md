# Name the Topics of a Fitted Model

Replaces each topic's label with a name you choose after reading its
representative texts, for example the kind of message a topic holds
(\`"Correction"\`, \`"Short hint"\`). The names replace the \`label\`
column of every table keyed by topic (\`\$topics\`, \`\$documents\`,
\`terms()\`, \`representatives\`), so they appear in \[summary()\],
\[topic_sizes()\], \[predict()\], \[topic_hierarchy()\], and every plot.
Nothing is refitted.

## Usage

``` r
name_topics(object, labels)
```

## Arguments

- object:

  A fitted \[topics()\] model.

- labels:

  Character vector with one distinct, non-empty name per topic, in topic
  order (topic 1 first).

## Value

The model with its labels replaced: an \`sbert_topic_model\` whose
\`\$settings\$topic_names\` records the names. \[reduce_topics()\]
merges topics, so it drops the names and labels the merged topics
afresh.

## Errors

Raises a condition of class \`sbert_bad_topic_names\` when \`labels\` is
not a character vector with one distinct, non-empty, non-missing name
per topic.

## Examples

``` r
text <- c(
  "Cats chase mice", "Dogs chase balls",
  "Stocks and bonds trade", "Markets price shares"
)
embeddings <- rbind(c(1, 0), c(0.9, 0.1), c(0, 1), c(0.1, 0.9))
fitted <- topics(text, 2, embeddings = embeddings)
named <- name_topics(fitted, c("Pets", "Finance"))
topic_sizes(named)
#>   topic   label n_documents proportion
#> 1     1    Pets           2        0.5
#> 2     2 Finance           2        0.5
```
