# Case study: multilingual feedback messages

Learning applications that generate feedback with a language model
produce large numbers of short messages in the language of each learner.
Two properties of such a corpus shape any analysis of what the feedback
says. First, it repeats itself: a generator produces the same hint for
many learners, and the same hint in many languages, so a count of rows
is not a count of distinct messages. Second, it is multilingual: a model
of the content can work on English translations, which puts every
message on one scale, or on the source texts, which keeps what the
learner actually read. The two choices measure different things, and a
study should know which one it reports.

This case study takes a corpus of AI-generated mathematics feedback with
English translations and asks four questions: how repetitive the
feedback is, and whether the repetition lies in the messages or in the
languages; what kinds of feedback exist once repetition is accounted
for; how a source-language message relates to the translation that is
modeled; and how the source languages can be modeled directly. The
vignette [Semantic topic modeling with
Sentence-BERT](https://sonsoles.me/sbert/articles/sbert.md) walks
through fitting, naming, and reading the topics of this corpus in depth;
this article uses its topics and concentrates on repetition and
language.

``` r

library(sbert)
#> sbert 0.5.14: Sentence-BERT embeddings and topic models in R.
#>   14 pinned models (see models()); default: all-MiniLM-L6-v2.
#>   A model is downloaded only on request, once, and verified by SHA-256.
```

## Data

`feedback_translations` holds 8,757 feedback messages shown to young
learners solving mathematics exercises in an educational application.
Each row is one message as it was shown.

- **Source text:** `feedback`, the message in the language the learner
  received it in. The source languages include Czech, Slovak, Polish,
  German, Hungarian, Romanian, Ukrainian, Russian, Mongolian, and
  Vietnamese, and some messages are in English.
- **Translation:** `translation`, the English translation, the text
  modeled below.

There is no column for the language, so the language of a message is
known only from its text. The rows and the distinct texts in each
column:

``` r

nrow(feedback_translations)
#> [1] 8757
nrow(dedupe(feedback_translations, column = "translation"))
#> [1] 8005
nrow(dedupe(feedback_translations, column = "feedback"))
#> [1] 8750
```

## How repetitive is the feedback?

The two columns give very different answers. 7 rows repeat a source text
that occurred earlier, but 752 repeat an English translation. Since the
source texts are almost all distinct, nearly every repeated translation
was reached from different source texts: the repetition lies less in the
messages than in the languages, with the same hint written in several
languages and translated back to one English sentence.

[`dedupe()`](https://sonsoles.me/sbert/reference/dedupe.md) keeps the
first occurrence of each distinct translation, with all its columns, and
adds `n`, the number of rows that share it. The number of translations
by how often they occur:

``` r

messages <- dedupe(feedback_translations, column = "translation")
table(repeats = with(messages, n))
#> repeats
#>    1    2    3    4    5    6    7   11 
#> 7438  455   72   24    8    3    4    1
subset(messages, n >= 6)
#>                                                               feedback
#> 127                                                    Спробуй ще раз.
#> 252  Скільки там було картинок? Зараз ти бачиш два. Скільки їх бракує?
#> 305 Скільки там було зображень? Зараз ти бачиш три. Скільки їх бракує?
#> 712                                                   Первую картинку.
#> 731                         Ändert sich die Anzahl der kleinen Bilder?
#> 790                                         Должен быть другой способ.
#> 815                यह आखिरी तस्वीर है। इसके पहले वाली सारी तस्वीरें कौन सी हैं?
#> 874         Kolik tam bylo obrázků? Teď vidíš jedno. Kolik jich chybí?
#>                                                                translation  n
#> 127                                                             Try again. 11
#> 252   How many pictures were there? Now you see two. How many are missing?  6
#> 305 How many pictures were there? Now you see three. How many are missing?  7
#> 712                                                     The first picture.  7
#> 731                              Does the number of small pictures change?  6
#> 790                                             There must be another way.  7
#> 815               This is the last picture. Which pictures come before it?  6
#> 874   How many pictures were there? Now you see one. How many are missing?  7
```

7,438 of the 8,005 distinct translations occur once and 567 occur more
than once, at most 11 times. The source text kept for each is the first
occurrence only, which is why the table shows one language per row; one
of them is in Hindi, a language the dataset’s documentation does not
list. All the rows behind the most repeated translation show where the
repetition comes from:

``` r

subset(feedback_translations, translation == "Try again.")
#>                    feedback translation
#> 127         Спробуй ще раз.  Try again.
#> 214             Thử lại đi.  Try again.
#> 1048               Thử lại.  Try again.
#> 1449 Have another go at it.  Try again.
#> 2356      Попробуй ещё раз.  Try again.
#> 2667     Дахиад оролдоорой.  Try again.
#> 3402      Încearcă din nou.  Try again.
#> 4485      Spróbuj ponownie.  Try again.
#> 4570             Try again.  Try again.
#> 7826      Próbáld meg újra.  Try again.
#> 7861   Spróbuj jeszcze raz.  Try again.
```

The eleven rows are eleven different source texts: two Vietnamese and
two Polish phrasings, Ukrainian, Russian, Mongolian, Romanian and
Hungarian versions, and two English ones, “Try again.” and “Have another
go at it.”. Translation therefore merges two kinds of repetition: the
same message in different languages, and different phrasings in one
language that mean the same.

Some source texts are already in English, or were left untranslated. The
rows whose source text is identical to its translation:

``` r

with(feedback_translations, sum(feedback == translation))
#> [1] 98
head(subset(feedback_translations, feedback == translation), 4)
#>                                                                           feedback
#> 493 Do you know which one is the second picture? Pick the picture right before it.
#> 494                                     Is the number of little pictures changing?
#> 569                                        All pictures between chestnut and corn.
#> 570                        What does "the one right before the last picture" mean?
#>                                                                        translation
#> 493 Do you know which one is the second picture? Pick the picture right before it.
#> 494                                     Is the number of little pictures changing?
#> 569                                        All pictures between chestnut and corn.
#> 570                        What does "the one right before the last picture" mean?
```

98 rows carry the same text in both columns. For these rows the
translation adds nothing, and for an English-only analysis they need no
special handling.

## What kinds of feedback are there?

The embeddings of the first 600 distinct translations ship with the
package as `feedback_embeddings`, so the topics below are computed
without a model download. Row *i* of the matrix is the embedding of row
*i* of `corpus`.

``` r

corpus <- head(messages, 600)
with(corpus, sum(n))
#> [1] 740
```

The 600 distinct messages stand for 740 rows of the corpus. Six topics
are fitted on the English embeddings and given the names established in
the [main vignette](https://sonsoles.me/sbert/articles/sbert.md), where
the representatives of each topic are read and the number of topics is
chosen:

``` r

topic_model <- topics(corpus, n_topics = 6, column = "translation",
                      embeddings = feedback_embeddings)
topic_model <- name_topics(topic_model, c(
  "Guiding question and instruction", "Short hint",
  "Question about meaning", "Correction", "Definition", "Negation"
))
topic_sizes(topic_model, weights = "n")
#>   topic                            label n_documents proportion n_weighted weighted_share
#> 1     1 Guiding question and instruction         223     0.3717        267         0.3608
#> 2     2                       Short hint         133     0.2217        162         0.2189
#> 3     3           Question about meaning         131     0.2183        138         0.1865
#> 4     4                       Correction          49     0.0817         76         0.1027
#> 5     5                       Definition          37     0.0617         57         0.0770
#> 6     6                         Negation          27     0.0450         40         0.0541
```

`n_documents` and `proportion` count each distinct message once;
`n_weighted` and `weighted_share` count every row it stands for.
Corrections are 8.2% of the distinct messages but 10.3% of the rows.
Averaging over the messages of each topic gives the share that recur and
the mean number of rows per message:

``` r

repetition <- aggregate(cbind(repeated = n > 1, n) ~ label,
                        data = as.data.frame(topic_model), FUN = mean)
repetition
#>                              label repeated    n
#> 1                       Correction   0.2653 1.55
#> 2                       Definition   0.2432 1.54
#> 3 Guiding question and instruction   0.1031 1.20
#> 4                         Negation   0.2963 1.48
#> 5           Question about meaning   0.0458 1.05
#> 6                       Short hint   0.2105 1.22
```

`repeated` is the share of a topic’s distinct messages that occur more
than once and `n` the mean number of rows each stands for. Corrections
stand for the most rows per message (1.55), and corrections, definitions
and negations recur most often (27%, 24% and 30% of their messages).
Questions about meaning (4.6%) and guiding questions (10%) recur least.
A correction such as “There should be two fewer in the red one than in
the blue one.” can be reused across exercises, while a question that
names the pictures of one exercise, such as “What does ‘all between the
plant and the princess’ mean?”, has fewer occasions to recur. The table
is descriptive: it shows which kinds of feedback the generator repeated,
not why.

## How does a source message relate to its translation?

The model is fitted on the translations, and every other column of
`corpus` rides along.
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) returns
one row per modeled message with its topic, the English text that was
modeled (`text`), and the source text (`feedback`) and count (`n`)
carried from
[`dedupe()`](https://sonsoles.me/sbert/reference/dedupe.md):

``` r

head(subset(as.data.frame(topic_model), label == "Correction"), 5)
#>    document_id document_name
#> 2            2              
#> 5            5              
#> 9            9              
#> 10          10              
#> 16          16              
#>                                                                                         text
#> 2                                      There should be two more in the red than in the blue.
#> 5                  There are five pictures in the gray box. Where is there one picture less?
#> 9  If there are supposed to be two more in the blue one, how many have to be in the red one?
#> 10                            There should be two fewer in the red one than in the blue one.
#> 16                There are eight pictures in the gray box. Where is there one picture less?
#>    topic      label distance
#> 2      4 Correction    0.217
#> 5      4 Correction    0.204
#> 9      4 Correction    0.225
#> 10     4 Correction    0.181
#> 16     4 Correction    0.185
#>                                                           feedback n
#> 2                       V červeném má být o dva více než v modrém. 3
#> 5     V šedém rámečku je pět obrázků. Kde je o jeden obrázek méně? 2
#> 9  Když v modrém má být o dva více, tak v červeném musí být kolik? 1
#> 10                      V červeném má být o dva méně než v modrém. 2
#> 16    V šedém rámečku je osm obrázků. Kde je o jeden obrázek méně? 1
```

Each row pairs a modeled English message with the source text of its
first occurrence. The topic is a property of the English text, and the
source text is attached to it, not modeled: when a translation stands
for several source texts (as “Try again.” does), only the first is
shown, and the topic says nothing about how well the other languages
were phrased. Two consequences follow. A topic analysis of the
translations measures what the feedback was meant to say, filtered
through the translation; and differences between languages, such as a
hint that is more direct in one language than in another, are invisible
to it.

## Modeling the source languages directly

To keep what the learners read, the source texts can be modeled with a
multilingual encoder. `paraphrase-multilingual-MiniLM-L12-v2` maps more
than 50 languages into one embedding space, trained so that a sentence
and its translation lie close together. The chunks below download that
model and encode the source texts; they are not run here, and no output
is shown.

The first step fits the same six topics to the `feedback` column of the
same 600 messages:

``` r

model_download("paraphrase-multilingual-MiniLM-L12-v2")
source_model <- topics(corpus, n_topics = 6, column = "feedback",
                       model = "paraphrase-multilingual-MiniLM-L12-v2")
topic_sizes(source_model, weights = "n")
```

Because both models are fitted on the rows of `corpus`, their documents
correspond one to one, and the two topic columns can be cross-tabulated:

``` r

languages <- merge(as.data.frame(topic_model), as.data.frame(source_model),
                   by = "document_id", suffixes = c("_english", "_source"))
xtabs(~ label_english + topic_source, data = languages)
```

Each row is an English topic and each column a source-language topic. If
the source-language model recovers the kinds of feedback, each row
concentrates in one column; a row split across columns marks a kind of
feedback whose source texts the multilingual model groups differently,
for example by language rather than by meaning. Two encoders are
compared here, so a difference can come from the language or from the
encoder. Fitting the multilingual model to the translations as well
separates the two:

``` r

translation_model <- topics(corpus, n_topics = 6, column = "translation",
                            model = "paraphrase-multilingual-MiniLM-L12-v2")
```

The closeness of a message to its own translation can be measured
directly. [`encode()`](https://sonsoles.me/sbert/reference/encode.md)
embeds the two columns with the multilingual model, and
[`topic_similarity()`](https://sonsoles.me/sbert/reference/topic_similarity.md)
with `tidy = TRUE` returns the cosine similarity of every source text
with every translation; a source and its own translation share a row
number:

``` r

multilingual <- load_model("paraphrase-multilingual-MiniLM-L12-v2")
source_embeddings <- with(corpus, encode(feedback, model = multilingual))
translation_embeddings <- with(corpus, encode(translation, model = multilingual))
similarity <- transform(
  topic_similarity(source_embeddings, translation_embeddings, tidy = TRUE),
  own_translation = from == to
)
aggregate(similarity ~ own_translation, data = similarity, FUN = median)
```

If the encoder places translations close together, the median similarity
of a message to its own translation is far above its median similarity
to the other messages, and the source-language topics can be read with
the English names.

## When to use which

- **Translations, deduplicated** (`dedupe(column = "translation")`): one
  row per distinct English message. Use it to find the kinds of
  feedback; weight topic sizes with `topic_sizes(weights = "n")` to
  count every row shown.
- **Source texts, deduplicated** (`dedupe(column = "feedback")`): almost
  every row is distinct, because one message in ten languages is ten
  texts. Use it with a multilingual encoder when what the learner read
  is the object of study.
- **Both, side by side:** the cross-tabulation of the two topic columns
  shows whether the kinds of feedback found in English survive in the
  source languages.

Related articles: [Semantic topic modeling with
Sentence-BERT](https://sonsoles.me/sbert/articles/sbert.md) for the full
walkthrough of this corpus; [Describing and naming
topics](https://sonsoles.me/sbert/articles/describing-topics.md);
[Models, the cache, and custom
models](https://sonsoles.me/sbert/articles/models-and-cache.md) for the
multilingual models and their downloads; [Case study: COVID-19 research
abstracts](https://sonsoles.me/sbert/articles/case-covid.md) for long
documents.
