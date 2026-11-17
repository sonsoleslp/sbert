# Convert a topic model to a data frame

[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) returns
one of the tables of a fitted topic model as a base data frame. The
default, `what = "documents"`, gives one row per modeled unit with its
topic, so that the topic of every document (or segment) can be joined to
other data, filtered with
[`subset()`](https://rdrr.io/r/base/subset.html), or tabulated.

The other tables are the topic sizes (`"topics"`), the stored terms
(`"terms"`), and the stored representative units (`"representatives"`),
as kept when the model was fitted. To compute terms under other
settings, use
[terms()](https://sonsoles.me/sbert/reference/terms.sbert_topic_model.md);
to rank representatives in another way, use
[`representatives()`](https://sonsoles.me/sbert/reference/representatives.md).

## Usage

``` r
# S3 method for class 'sbert_topic_model'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  ...,
  what = c("documents", "topics", "terms", "representatives")
)
```

## Arguments

- x:

  A topic model fitted by
  [`topics()`](https://sonsoles.me/sbert/reference/topics.md).

- row.names, optional:

  Ignored; present for compatibility with the generic.

- ...:

  Ignored.

- what:

  Which table: `"documents"` (default), `"topics"`, `"terms"`, or
  `"representatives"`.

## Value

A base data frame:

- `"documents"`: one row per modeled unit, with `document_id`,
  `document_name`, `segment` (segmented fits only), `text`, `topic`,
  `label`, `distance` (cosine distance to the topic center), and the
  columns carried from a data frame input.

- `"topics"`: one row per topic, with `topic`, `label`, `n_documents`,
  `proportion`, and `withinss` (within-topic sum of squares).

- `"terms"`: one row per topic and term, with `topic`, `label`, `term`,
  `rank`, `score`, and `frequency`.

- `"representatives"`: one row per topic and representative unit, with
  `topic`, `label`, `rank`, `document_id`, `document_name`, `segment`
  (segmented fits only), `text`, and `distance`.

## See also

[`topic_sizes()`](https://sonsoles.me/sbert/reference/topic_sizes.md),
[terms()](https://sonsoles.me/sbert/reference/terms.sbert_topic_model.md),
[`representatives()`](https://sonsoles.me/sbert/reference/representatives.md),
[predict()](https://sonsoles.me/sbert/reference/predict.sbert_topic_model.md).

## Examples

``` r
corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings)
head(as.data.frame(topic_model))
#>   document_id document_name
#> 1           1              
#> 2           2              
#> 3           3              
#> 4           4              
#> 5           5              
#> 6           6              
#>                                                                        text
#> 1                                        Do you know what “one more” means?
#> 2                     There should be two more in the red than in the blue.
#> 3                                   If it’s not a person, what could it be?
#> 4                            What does “everyone after the first one” mean?
#> 5 There are five pictures in the gray box. Where is there one picture less?
#> 6                                            How do the pictures alternate?
#>   topic                                                       label  distance
#> 1     3         What does “all the ones between the leaf and the... 0.5466974
#> 2     4 Are you sure you have fewer pictures in the red box than... 0.2167227
#> 3     6    It is not a person, does not have a hat, and is sitting. 0.2611759
#> 4     3         What does “all the ones between the leaf and the... 0.5208701
#> 5     4 Are you sure you have fewer pictures in the red box than... 0.2039145
#> 6     1   Where is the cow and the cake? Choose all the pictures... 0.5020354
#>                                                       feedback n
#> 1                                Víš, co znamená o jeden více? 2
#> 2                   V červeném má být o dva více než v modrém. 3
#> 3                     Když to není člověk, tak co to může být? 2
#> 4                                Co znamená všechny za prvním? 1
#> 5 V šedém rámečku je pět obrázků. Kde je o jeden obrázek méně? 2
#> 6                              Podle čeho se obrázky střídají? 1
as.data.frame(topic_model, what = "topics")
#>   topic                                                       label n_documents
#> 1     1   Where is the cow and the cake? Choose all the pictures...         223
#> 2     2            All the ones between the cat and the strawberry.         133
#> 3     3         What does “all the ones between the leaf and the...         131
#> 4     4 Are you sure you have fewer pictures in the red box than...          49
#> 5     5      In the top middle box, it means something is in the...          37
#> 6     6    It is not a person, does not have a hat, and is sitting.          27
#>   proportion  withinss
#> 1 0.37166667 127.08741
#> 2 0.22166667  70.67752
#> 3 0.21833333  73.43997
#> 4 0.08166667  23.03144
#> 5 0.06166667  26.59845
#> 6 0.04500000  12.53809
subset(as.data.frame(topic_model), topic == 6 & n > 2)
#>     document_id document_name
#> 84           84              
#> 166         166              
#> 268         268              
#>                                                              text topic
#> 84  It’s not an animal, it doesn’t have a hat, and it’s standing.     6
#> 166                    If it’s an animal, then it’s not a person.     6
#> 268                            If it’s a person, who could it be?     6
#>                                                        label  distance
#> 84  It is not a person, does not have a hat, and is sitting. 0.2112950
#> 166 It is not a person, does not have a hat, and is sitting. 0.2196640
#> 268 It is not a person, does not have a hat, and is sitting. 0.3510618
#>                                        feedback n
#> 84  Це не тварина, без капелюха, і вона стоїть. 4
#> 166       Když je to zvíře, tak to není člověk. 4
#> 268        Коли це людина, то хто це може бути? 3
```
