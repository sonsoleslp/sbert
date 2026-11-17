# Assigning new documents and topic mixtures

A fitted topic model is a set of topic centers in an embedding space,
and it can be used beyond the texts it was fitted on. New texts
collected after the analysis can be placed in the existing topics, so
that a coding scheme derived from one sample is applied to the next
without refitting it. A text that lies between two topics can be
described by its degree of membership in each, rather than by one topic.
A document made of several units, such as a session of messages or an
abstract of several sentences, can be described by the mixture of topics
among its units. And when the categories are known in advance, they can
be supplied as seeds and the texts assigned to them.

This guide shows these four uses on the feedback messages. It also
states how assigning a new text differs from the assignment made during
fitting, and how often the two disagree.

``` r

library(sbert)
#> sbert 0.6.0: Sentence-BERT embeddings and topic models in R.
#>   14 pinned models (see models()); default: all-MiniLM-L6-v2.
#>   A model is downloaded only on request, once, and verified by SHA-256.
```

## Data

The first 500 of the 600 distinct feedback messages with bundled
embeddings are used to fit the model, and the last 100 are held out as
new messages. [`head()`](https://rdrr.io/r/utils/head.html) and
[`tail()`](https://rdrr.io/r/utils/head.html) split the data frame and
the embedding matrix in the same way, so row *i* of each part still
embeds message *i* of that part.

- **`translation`:** the English text of each message; the modeled text.
- **`n`:** the number of times the message occurs in the full corpus.
- **`feedback_embeddings`:** one 384-dimensional `all-MiniLM-L6-v2`
  embedding per message.

``` r

corpus <- head(dedupe(feedback_translations, column = "translation"), 600)
training <- head(corpus, 500)
training_embeddings <- head(feedback_embeddings, 500)
held_out <- tail(corpus, 100)
held_out_embeddings <- tail(feedback_embeddings, 100)
```

The model is fitted with six topics on the training messages:

``` r

topic_model <- topics(training, n_topics = 6, column = "translation",
                      embeddings = training_embeddings)
topic_sizes(topic_model)
#>   topic                                                       label n_documents
#> 1     1   Where is the cow and the cake? Choose all the pictures...         142
#> 2     2          What does “all the ones between the dog and the...         126
#> 3     3            All the ones between the cat and the strawberry.         109
#> 4     4             Which one comes right after the eighth picture?          51
#> 5     5 Are you sure you have fewer pictures in the red box than...          44
#> 6     6               It’s a person, has a hat, and isn’t standing.          28
#>   proportion
#> 1      0.284
#> 2      0.252
#> 3      0.218
#> 4      0.102
#> 5      0.088
#> 6      0.056
```

The six topics hold 142, 126, 109, 51, 44 and 28 of the 500 messages:
guiding questions with an instruction, questions about meaning, short
hints, questions about the position of a picture, corrections, and
negations.

## Which topic does a new message belong to?

[`predict()`](https://rdrr.io/r/stats/predict.html) assigns each new
text to the topic whose center is most similar to it by cosine
similarity. The model is not changed. `text` takes a character vector,
so [`with()`](https://rdrr.io/r/base/with.html) passes the column of the
held-out data frame; with a downloaded model,
[`predict()`](https://rdrr.io/r/stats/predict.html) would encode the
texts itself, and here the bundled embeddings are passed:

``` r

predicted <- with(held_out, predict(topic_model, translation,
                                    embeddings = held_out_embeddings))
head(predicted, 4)
#>   document_id document_name
#> 1           1              
#> 2           2              
#> 3           3              
#> 4           4              
#>                                                                                      text
#> 1          Where is the leaf and the watermelon? Choose the picture that is between them.
#> 2      Where is the lollipop and the tram? Choose all the pictures that are between them.
#> 3                               All the pictures between the mosquito and the teddy bear.
#> 4 Where is the cucumber and the ice cream? Choose all the pictures that are between them.
#>   topic                                                     label distance
#> 1     1 Where is the cow and the cake? Choose all the pictures...    0.247
#> 2     1 Where is the cow and the cake? Choose all the pictures...    0.328
#> 3     1 Where is the cow and the cake? Choose all the pictures...    0.367
#> 4     1 Where is the cow and the cake? Choose all the pictures...    0.269
with(predicted, table(label))
#> label
#>            All the ones between the cat and the strawberry. 
#>                                                          16 
#> Are you sure you have fewer pictures in the red box than... 
#>                                                           6 
#>               It’s a person, has a hat, and isn’t standing. 
#>                                                           3 
#>          What does “all the ones between the dog and the... 
#>                                                          29 
#>   Where is the cow and the cake? Choose all the pictures... 
#>                                                          40 
#>             Which one comes right after the eighth picture? 
#>                                                           6
```

The result has one row per new message, with its topic, the topic’s
label, and `distance`, the cosine distance to the assigned center. The
100 new messages fall into all six topics, most often the guiding
questions (40) and the questions about meaning (29). The distance tells
how well a new message fits its topic:

``` r

with(predicted, summary(distance))
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>   0.174   0.282   0.335   0.342   0.378   0.655
with(as.data.frame(topic_model), summary(distance))
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>   0.114   0.251   0.304   0.328   0.377   0.753
```

The new messages lie at a median distance of 0.335 from their centers,
against 0.304 for the training messages, so the held-out messages fit
the topics almost as well as the messages that formed them. A new
message at a large distance (the largest here is 0.655) is one the
topics do not describe well, and a cluster of such messages is a sign
that the new data contain a kind of text the model has not seen.

## Does predict() reproduce the fitted topics?

Not exactly. [`topics()`](https://sonsoles.me/sbert/reference/topics.md)
forms the topics with k-means (Lloyd, 1982), which assigns each
embedding to the nearest center by Euclidean distance, and its centers
are the means of the (unit-length) embeddings of each topic, which are
shorter than unit length.
[`predict()`](https://rdrr.io/r/stats/predict.html) assigns by cosine
similarity to the centers normalized to unit length. The two rules agree
for nearly every text but can differ for a text that lies on the
boundary between two topics. Predicting the training messages and
cross-tabulating the result against their fitted topics shows how often:

``` r

repredicted <- with(training, predict(topic_model, translation,
                                      embeddings = training_embeddings))
assignments <- merge(as.data.frame(topic_model), repredicted,
                     by = "document_id", suffixes = c("_fit", "_predict"))
with(assignments, table(topic_fit, topic_predict))
#>          topic_predict
#> topic_fit   1   2   3   4   5   6
#>         1 142   0   0   0   0   0
#>         2   0 124   0   0   0   2
#>         3   0   0 109   0   0   0
#>         4   0   0   0  50   1   0
#>         5   0   0   0   0  44   0
#>         6   0   0   0   0   0  28
```

Three of the 500 messages change topic, all of them far from every
center:

``` r

subset(assignments, topic_fit != topic_predict,
       select = c(text_fit, topic_fit, topic_predict, distance_predict))
#>                                                                             text_fit
#> 8                                              If it’s sitting, what does that mean?
#> 70  Having a beak means having a hard, pointy thing on your head instead of a mouth.
#> 125                       Train cars with the same number must be on the same train.
#>     topic_fit topic_predict distance_predict
#> 8           2             6            0.540
#> 70          2             6            0.621
#> 125         4             5            0.658
```

Each of the three lies more than 0.5 from its nearest center, where the
two rules can rank two centers differently. For new texts the cosine
rule is the one applied, so a topic count from
[`predict()`](https://rdrr.io/r/stats/predict.html) can differ from the
fitted count by such boundary cases. For the fitted messages, use the
fitted topics (`as.data.frame(topic_model)` or
[`topic_sizes()`](https://sonsoles.me/sbert/reference/topic_sizes.md)).

## How strongly does a message belong to each topic?

A hard assignment hides how close a message came to another topic.
[`topic_membership()`](https://sonsoles.me/sbert/reference/topic_membership.md)
gives every message a probability for every topic, computed from its
cosine distances to all centers as in fuzzy c-means (Bezdek, 1981), and
ranks the topics within each message:

``` r

membership <- topic_membership(topic_model)
head(membership, 6)
#>   document_id topic probability rank
#> 1           1     2     0.87862    1
#> 2           1     5     0.09172    2
#> 3           1     4     0.02165    3
#> 4           1     3     0.00397    4
#> 5           1     6     0.00296    5
#> 6           1     1     0.00109    6
```

The probabilities sum to one within each message. Their spread is set by
`sharpness`, the fuzzifier: the closer it is to 1, the crisper the
memberships. The default, 1.15, is low because distances between
sentence embeddings are concentrated, and the textbook value of 2 pulls
every message toward an even split. The probability of each message’s
strongest topic under both values:

``` r

with(subset(membership, rank == 1), summary(probability))
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>   0.314   0.984   0.999   0.959   1.000   1.000
with(subset(topic_membership(topic_model, sharpness = 2), rank == 1),
     summary(probability))
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>   0.197   0.368   0.462   0.467   0.543   0.867
```

With the default, the median message gives 0.999 of its membership to
one topic, and the least decided message 0.314. With `sharpness = 2` the
median falls to 0.462. The ranking of the topics within a message does
not depend on `sharpness`; the magnitudes do, so they are compared
across messages at one fixed value. The messages whose strongest
membership is low are the ones to read when the boundary between two
topics matters.

New messages take their embeddings through `embeddings =`. Their
strongest topic is the topic
[`predict()`](https://rdrr.io/r/stats/predict.html) assigns:

``` r

new_membership <- topic_membership(topic_model, embeddings = held_out_embeddings)
strongest <- merge(subset(new_membership, rank == 1), predicted,
                   by = "document_id", suffixes = c("_membership", "_predict"))
with(strongest, table(topic_membership, topic_predict))
#>                 topic_predict
#> topic_membership  1  2  3  4  5  6
#>                1 40  0  0  0  0  0
#>                2  0 29  0  0  0  0
#>                3  0  0 16  0  0  0
#>                4  0  0  0  6  0  0
#>                5  0  0  0  0  6  0
#>                6  0  0  0  0  0  3
```

## What mix of topics does a document contain?

When a document is made of several units,
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
assigns every unit to a topic and reports the share of each topic among
the document’s units. The feedback data do not record which messages a
learner saw together, so for illustration the 100 held-out messages are
grouped, in their order, into ten blocks of ten that stand in for
sessions.
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
accepts a data frame with a `document_id` and a `text` column, one row
per unit, with one embedding row per unit:

``` r

sessions <- with(held_out, data.frame(document_id = rep(seq_len(10), each = 10),
                                      text = translation))
topic_gamma(topic_model, sessions, embeddings = held_out_embeddings, top = 2)
#>    document_id rank topic gamma n_segments
#> 1            1    1     1   0.9         10
#> 2            1    2     2   0.1         10
#> 3            2    1     1   0.8         10
#> 4            2    2     2   0.2         10
#> 5            3    1     2   0.4         10
#> 6            3    2     1   0.3         10
#> 7            4    1     2   0.5         10
#> 8            4    2     1   0.4         10
#> 9            5    1     1   0.3         10
#> 10           5    2     2   0.3         10
#> 11           6    1     1   0.3         10
#> 12           6    2     4   0.3         10
#> 13           7    1     1   0.4         10
#> 14           7    2     2   0.3         10
#> 15           8    1     2   0.4         10
#> 16           8    2     3   0.4         10
#> 17           9    1     2   0.4         10
#> 18           9    2     3   0.4         10
#> 19          10    1     1   0.3         10
#> 20          10    2     2   0.2         10
```

With `top = 2`, each block lists its two largest topic shares. The first
two blocks are dominated by guiding questions (0.9 and 0.8 of their
messages); in each later block no kind of feedback exceeds half of the
messages. Without `top`, every topic of every document is listed, and
the shares of a document sum to one.

The usual case is a document split into sentences. The example below is
invented to show the steps: three short documents, each mixing pets and
finance, with made-up two-dimensional embeddings, one row per sentence,
in which the first coordinate stands for pets and the second for
finance. [`segment()`](https://sonsoles.me/sbert/reference/segment.md)
shows the sentences the embeddings must follow:

``` r

documents <- c("Cats chase mice. Stocks and bonds trade.",
               "Dogs chase balls. Markets price shares.",
               "Kittens nap in the sun. Banks report profit. Puppies play.")
segment(documents, level = "sentence")
#>   document_id document_name segment                    text
#> 1           1                     1        Cats chase mice.
#> 2           1                     2 Stocks and bonds trade.
#> 3           2                     1       Dogs chase balls.
#> 4           2                     2   Markets price shares.
#> 5           3                     1 Kittens nap in the sun.
#> 6           3                     2    Banks report profit.
#> 7           3                     3           Puppies play.
sentence_embeddings <- rbind(c(1, 0), c(0, 1), c(0.9, 0.1), c(0.1, 0.9),
                             c(0.95, 0.05), c(0.05, 0.95), c(0.8, 0.2))
```

A model fitted with `segment = "sentence"` models the sentences and
keeps, for each, the document it came from, so
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
needs no text:

``` r

sentence_model <- topics(documents, n_topics = 2, segment = "sentence",
                         embeddings = sentence_embeddings)
topic_gamma(sentence_model)
#>   document_id topic gamma n_segments
#> 1           1     1 0.500          2
#> 2           1     2 0.500          2
#> 3           2     1 0.500          2
#> 4           2     2 0.500          2
#> 5           3     1 0.667          3
#> 6           3     2 0.333          3
topic_sizes(sentence_model, by = "document")
#>   topic                label n_documents proportion
#> 1     1    Dogs chase balls.           3          1
#> 2     2 Banks report profit.           3          1
```

Each of the first two documents is half pets and half finance; the
third, with two sentences about pets and one about finance, is two
thirds pets. `topic_sizes(by = "document")` counts the documents with at
least one sentence in a topic, so every document is counted in both
topics here. To place new documents in a sentence-level model, pass them
to `topic_gamma(model, text)` or `predict(model, text)`: they are split
with the fitted segmentation settings, and the embeddings must follow
the same sentences. Choosing and tuning the segmentation is covered in
[Segmenting long
documents](https://sonsoles.me/sbert/articles/segmenting.md).

## Can topics be defined in advance?

When the categories are known before the analysis, they can be given to
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) as `seeds`,
one per category. Each seed is a text, such as a short description of
the category, whose embedding becomes the center of its topic. With
`fixed_seeds = TRUE` the centers stay where the seeds put them and every
text joins its nearest seed: a zero-shot classification into the given
categories, with no topics discovered. With a downloaded model, the seed
descriptions are encoded with the texts; this chunk is not run here:

``` r

model_download()
zero_shot <- topics(training, n_topics = 3, column = "translation",
                    seeds = c(meaning = "What does this phrase mean?",
                              correction = "There should be more in the red box.",
                              negation = "It is not a person."),
                    fixed_seeds = TRUE)
```

Without a model, a seed can be given a prototype embedding instead: the
mean embedding of a few texts that clearly belong to the category. Here
five kinds of feedback are identified by how their messages begin or
what they contain, and each prototype is the column mean of the matching
rows of the training embeddings.
[`subset()`](https://rdrr.io/r/base/subset.html) selects the rows of the
matrix:

``` r

prototype <- function(pattern) {
  with(training, colMeans(subset(training_embeddings, grepl(pattern, translation))))
}
seed_embeddings <- rbind(prototype("^Where is"), prototype("^All the ones between"),
                         prototype("^What does"), prototype("^There should be"),
                         prototype("not a person"))
dim(seed_embeddings)
#> [1]   5 384
```

The names of `seeds` become the labels of the topics, and
`seed_embeddings` supplies their vectors in the same order:

``` r

feedback_seeds <- c(instruction = "Guiding question and instruction",
                    hint = "Short hint", meaning = "Question about meaning",
                    correction = "Correction", negation = "Negation")
zero_shot <- topics(training, n_topics = 5, column = "translation",
                    embeddings = training_embeddings, seeds = feedback_seeds,
                    seed_embeddings = seed_embeddings, fixed_seeds = TRUE)
topic_sizes(zero_shot)
#>   topic       label n_documents proportion
#> 1     1 instruction         183      0.366
#> 2     2        hint         121      0.242
#> 3     3     meaning         130      0.260
#> 4     4  correction          37      0.074
#> 5     5    negation          29      0.058
```

Every message is placed in one of the five categories, the instructions
being the largest (183 messages). The cross-tabulation against the
unsupervised six-topic model shows where the two agree:

``` r

comparison <- merge(as.data.frame(topic_model), as.data.frame(zero_shot),
                    by = "document_id", suffixes = c("_unsupervised", "_seeded"))
with(comparison, table(topic_unsupervised, topic_seeded))
#>                   topic_seeded
#> topic_unsupervised   1   2   3   4   5
#>                  1 141   1   0   0   0
#>                  2   0   1 122   1   2
#>                  3   0 108   1   0   0
#>                  4  33  10   6   2   0
#>                  5   9   1   0  34   0
#>                  6   0   0   1   0  27
```

Five of the six unsupervised topics map onto one category each: 141 of
142 guiding questions, 122 of 126 questions about meaning, 108 of 109
hints, 34 of 44 corrections and 27 of 28 negations. The sixth
unsupervised topic, the 51 questions about the position of a picture,
had no seed, and a zero-shot classification cannot create a category:
its messages are spread over instructions (33), hints (10), questions
about meaning (6) and corrections (2). Fixed seeds therefore suit a
coding scheme that is complete; a kind of text without a seed is forced
into the nearest one, and only its `distance` shows that it fits badly.

With `fixed_seeds = FALSE` (the default), the seeds are starting
centers: k-means moves them, and `n_topics` may exceed the number of
seeds, the remaining topics being found in the data. This guides the
topics toward known categories while leaving room for new ones:

``` r

guided <- topics(training, n_topics = 6, column = "translation",
                 embeddings = training_embeddings, seeds = feedback_seeds,
                 seed_embeddings = seed_embeddings)
topic_sizes(guided)
#>   topic                      label n_documents proportion
#> 1     1                instruction         185      0.370
#> 2     2                       hint         117      0.234
#> 3     3                    meaning         130      0.260
#> 4     4                 correction          36      0.072
#> 5     5                   negation          30      0.060
#> 6     6 That was first-class work!           2      0.004
```

The five seeded topics keep their seeds’ labels and stay close to the
zero-shot sizes, and the one free topic holds only 2 messages, so it did
not recover the 51 questions about position. Seeds guide the analysis
toward the given categories; whether the data hold others is still
answered by an unsupervised fit.

## When to use which

| Question | Verb |
|----|----|
| Which topic does a new text belong to? | `predict(model, text)` |
| How well does it fit? | the `distance` column of [`predict()`](https://rdrr.io/r/stats/predict.html) |
| How strongly does a text belong to each topic? | `topic_membership(sharpness = )` |
| What mix of topics is in a document? | [`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md), `topic_gamma(top = )` |
| How many documents touch each topic? | `topic_sizes(by = "document")` |
| Classify into known categories | `topics(seeds = , fixed_seeds = TRUE)` |
| Guide topics toward known categories | `topics(seeds = )` |

How the topics were chosen and described is covered in [Choosing the
number of topics and the
granularity](https://sonsoles.me/sbert/articles/choosing-topics.md) and
[Describing and naming
topics](https://sonsoles.me/sbert/articles/describing-topics.md); the
complete analysis is in [Semantic topic modeling with
Sentence-BERT](https://sonsoles.me/sbert/articles/sbert.md).

## References

Bezdek, J. C. (1981). *Pattern recognition with fuzzy objective function
algorithms*. Plenum Press. <https://doi.org/10.1007/978-1-4757-0450-1>

Lloyd, S. P. (1982). Least squares quantization in PCM. *IEEE
Transactions on Information Theory*, *28*(2), 129–137.
<https://doi.org/10.1109/TIT.1982.1056489>
