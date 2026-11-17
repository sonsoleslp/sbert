# Preparing and cleaning a corpus

A sentence encoder represents everything in a text, including what an
analyst would not count as content. A copyright notice at the end of an
abstract, a list marker, a URL or a broken character moves the text’s
embedding, and when the same noise recurs across many texts it can draw
them together into a topic of its own, grouped by publisher or
formatting rather than by meaning. Repetition has a similar effect: a
text that occurs two hundred times enters k-means two hundred times and
pulls a center toward itself. Corpus preparation therefore precedes
encoding, and every step changes the data that are modeled, so each one
should be stated and its effect counted.

This guide prepares the `covid` abstracts in the order the steps should
be applied: removing records without text, removing duplicates,
repairing and cleaning the text, and checking how much of each unit is
prose. Every step runs without a model. Choosing the words that describe
topics, which is done after fitting and does not change the text, is
covered at the end.

``` r

library(sbert)
#> sbert 0.6.0: Sentence-BERT embeddings and topic models in R.
#>   14 pinned models (see models()); default: all-MiniLM-L6-v2.
#>   A model is downloaded only on request, once, and verified by SHA-256.
```

## Data

`covid` holds 4,170 records of research on COVID-19 and education,
children, schools and society, published from 2020 to 2024.

- **`Abstract`:** the text of the abstract; the text to be modeled.
- **`Year`:** the year of publication; carried along with each abstract.

The feedback messages of `feedback_translations` are used where a step
is better shown on short texts.

## Which records have no text?

Bibliographic exports fill a missing abstract with a placeholder. In
`covid` it is the string `"[No abstract available]"`:

``` r

nrow(covid)
#> [1] 4170
nrow(subset(covid, Abstract == "[No abstract available]"))
#> [1] 323
```

323 of the 4,170 records have no abstract. The placeholder is a
well-formed English phrase, so no cleaning step would remove it, and
kept, it would become 323 copies of one text, a topic about nothing. It
is removed first:

``` r

abstracts <- subset(covid, Abstract != "[No abstract available]")
nrow(abstracts)
#> [1] 3847
```

## How much of the corpus repeats?

[`dedupe()`](https://sonsoles.me/sbert/reference/dedupe.md) keeps the
first occurrence of every distinct text and counts its occurrences in a
new column, `n`. Given a data frame and the name of its text column, it
keeps all columns of the first occurrence:

``` r

abstracts <- dedupe(abstracts, column = "Abstract")
nrow(abstracts)
#> [1] 3670
with(abstracts, table(n))
#> n
#>    1    2    4 
#> 3495  174    1
```

The 3,847 records hold 3,670 distinct abstracts: 3,495 occur once, 174
twice, and one four times, records indexed more than once. Had the
placeholder been kept,
[`dedupe()`](https://sonsoles.me/sbert/reference/dedupe.md) would have
reduced it to a single row carrying its count:

``` r

subset(dedupe(covid, column = "Abstract"), n > 4, select = c(Year, n))
#>    Year   n
#> 73 2023 323
```

Given a character vector,
[`dedupe()`](https://sonsoles.me/sbert/reference/dedupe.md) returns the
columns `text` and `n`. Repetition is far heavier in the feedback
messages, which a generator writes from templates:

``` r

messages <- with(feedback_translations, dedupe(translation))
nrow(feedback_translations)
#> [1] 8757
nrow(messages)
#> [1] 8005
head(messages, 3)
#>                                                    text n
#> 1                    Do you know what “one more” means? 2
#> 2 There should be two more in the red than in the blue. 3
#> 3               If it’s not a person, what could it be? 2
```

The 8,757 messages hold 8,005 distinct texts. Modeling the distinct
texts keeps repeated templates from dragging the topic centers, and the
counts are not lost: after fitting, `topic_sizes(weights = "n")` reports
every topic’s share of all occurrences beside its share of distinct
texts. On the first 600 distinct messages, whose embeddings are bundled:

``` r

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
#> 1     0.3717        267         0.3608
#> 2     0.2217        162         0.2189
#> 3     0.2183        138         0.1865
#> 4     0.0817         76         0.1027
#> 5     0.0617         57         0.0770
#> 6     0.0450         40         0.0541
```

`n_documents` and `proportion` count distinct messages; `n_weighted` and
`weighted_share` count occurrences. The topic of corrections (topic 4)
holds 8.2% of the distinct messages and 10.3% of the occurrences,
because its messages were repeated more often than the others.

## What does clean_corpus() repair?

[`clean_corpus()`](https://sonsoles.me/sbert/reference/clean_corpus.md)
gathers the text-level cleaning that should happen before encoding, so
that the same clean text feeds the encoder, the topic terms and the
representative texts. Some repairs are always applied: HTML tags and
entities are decoded or removed; URLs, DOIs, e-mail addresses and
bracketed numeric citations such as `[12]` are removed; curly quotes,
dashes and bullets are normalized; and control, zero-width and
replacement characters are dropped. Removing list and section numbering
is on by default and can be switched off. Four invented texts show the
effect:

``` r

examples <- c("<p>Teachers &amp; parents</p> reported higher stress [12].",
              "Data are available at https://doi.org/10.1000/xyz123 for reuse.",
              "1. Aims. 2. Methods. 3. Results.",
              "Section 2.3.1 describes the sample.")
clean_corpus(examples)
#> [1] "Teachers & parents reported higher stress."
#> [2] "Data are available at for reuse."          
#> [3] "Aims. Methods. Results."                   
#> [4] "Section describes the sample."
```

The markup, the citation, the URL, the list markers and the section
number are gone, and the words are kept.

Abstracts also carry text that the generic repairs cannot recognize. In
`covid` almost every abstract ends with a publisher’s copyright notice:

``` r

with(abstracts, sum(grepl("©", Abstract)))
#> [1] 3655
```

3,655 of the 3,670 abstracts contain the copyright sign. The `remove`
argument takes regular expressions, matched case-insensitively, whose
matches are deleted before the other steps. The pattern below deletes a
notice at the end of an abstract that starts with “©”, “Copyright ©” or
“Copyright” and a year, and leaves abstracts that discuss copyright as a
subject untouched. Given a data frame and a `column`,
[`clean_corpus()`](https://sonsoles.me/sbert/reference/clean_corpus.md)
cleans that column and keeps the other columns aligned:

``` r

cleaned <- clean_corpus(abstracts, column = "Abstract",
                        remove = "(copyright:?\\s*(©|\\d{4})|©).{0,1000}$")
nrow(cleaned)
#> [1] 3670
with(cleaned, sum(grepl("©", Abstract)))
#> [1] 0
with(cleaned, sum(grepl("copyright", Abstract, ignore.case = TRUE)))
#> [1] 2
```

All 3,670 abstracts are kept, none still contains the copyright sign,
and the two that still contain the word “copyright” use it as a subject
(accessibility and copyright in online teaching; open educational
resources free from copyright issues). The cleaning shortens the
abstracts:

``` r

with(abstracts, summary(nchar(Abstract)))
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>     171    1022    1315    1352    1640    5285
with(cleaned, summary(nchar(Abstract)))
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>     117     975    1261    1300    1583    5243
```

The median abstract loses 54 characters, about the length of a copyright
line.

## Should numbers be removed from the text?

`numbers = TRUE` and `roman_numerals = TRUE` remove stand-alone numeric
and Roman-numeral tokens from the text. Both are off by default, because
the result is no longer a well-formed sentence:

``` r

clean_corpus("In 2020, 45 schools closed during phase ii.",
             numbers = TRUE, roman_numerals = TRUE)
#> [1] "In, schools closed during phase."
```

The sentence loses its year, its count and its phase, and the encoder
sees a fragment. Numbers rarely decide what a text is about, but they do
clutter the words that describe topics. That is better handled after
fitting, with the `numbers = "remove"` and `roman_numerals = "remove"`
arguments of [`topics()`](https://sonsoles.me/sbert/reference/topics.md)
and [`terms()`](https://rdrr.io/r/stats/terms.html), which filter the
terms and leave the text and its embedding intact (see [Describing and
naming
topics](https://sonsoles.me/sbert/articles/describing-topics.md)).

## Which list markers are removed?

[`strip_list_markers()`](https://sonsoles.me/sbert/reference/strip_list_markers.md),
which
[`clean_corpus()`](https://sonsoles.me/sbert/reference/clean_corpus.md)
applies by default, removes enumeration markers that stand alone: `1.`,
`(i)`, `(a)`, `(1)` and Roman-numeral section markers such as `II.`. It
keeps numbers and parentheses that carry content:

``` r

strip_list_markers(c("The aims were (i) access and (ii) equity.",
                     "1. Background 2. Methods 3. Results",
                     "The student ranks in the top 20. Good work.",
                     "Smith v. Jones, cited by V. Nabokov in (2020), with (n=100)."))
#> [1] "The aims were access and equity."                            
#> [2] "Background Methods Results"                                  
#> [3] "The student ranks in the top 20. Good work."                 
#> [4] "Smith v. Jones, cited by V. Nabokov in (2020), with (n=100)."
```

The markers of the first two texts are removed. A number that ends a
sentence (“top 20.”), a year or a count in parentheses, a lower-case
“v.” and a mid-sentence initial are kept. In the abstracts,
parenthesized markers such as `(i)`, `(1)` or `(a)` occur in 193 texts
before cleaning and in none after:

``` r

marker <- "(^|\\s)\\((i|1|a)\\)\\s"
with(abstracts, sum(grepl(marker, Abstract, perl = TRUE)))
#> [1] 193
with(cleaned, sum(grepl(marker, Abstract, perl = TRUE)))
#> [1] 0
```

## How much of each unit is prose?

[`content_ratio()`](https://sonsoles.me/sbert/reference/content_ratio.md)
is the share of a text’s non-space characters that are letters. Prose
scores near 1; references, page ranges, tables of numbers and
identifiers score low:

``` r

content_ratio(c("A real sentence here.",
                "OJ No L 297, 24.11.1979, p. 1.",
                "doi:10.1007/s10639-021-10557-6"))
#> [1] 0.944 0.250 0.133
with(cleaned, summary(content_ratio(Abstract)))
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>   0.794   0.962   0.969   0.966   0.975   0.992
```

Every abstract is mostly prose: the lowest ratio is 0.794. The check
matters for smaller units. Split into sentences with
[`segment()`](https://sonsoles.me/sbert/reference/segment.md), the
abstracts yield fragments that are not prose at all:

``` r

sentences <- with(cleaned, segment(Abstract, level = "sentence"))
nrow(sentences)
#> [1] 28515
knitr::kable(subset(sentences, content_ratio(text) < 0.5,
                    select = c(document_id, text)))
```

|  | document_id | text |
|:---|---:|:---|
| 319 | 44 | 2006\. |
| 4374 | 550 | 1999\. |
| 4379 | 550 | Ylä-Kotola, 679 - 718. |
| 10130 | 1220 | 2021;60(9):534-537.\]. |
| 16883 | 2048 | 26.. |
| 17050 | 2070 | The significantly predicted equations were as follows: In term of raw scores: Y/ = 75.425 + (-5.180) (X4) + 3.816 (X3) + (-3.465) (X5) + (-2.689) (X7) In term of standard scores: Z/Y = (-0.324) (Z X 4) + 0.280 (Z X 3) + (-0.225) (Z X3) + (-0.165) Z X 7). |
| 19107 | 2330 | 2021 |
| 19139 | 2333 | 2021 |

Eight of the 28,515 sentences fall below one half: years, page ranges,
the remains of a citation, and a regression equation. Each would be
embedded as a unit and could join a topic. `min_content` drops them:
`clean_corpus(min_content = )` drops whole documents below the ratio,
and `segment(min_content = )` and `topics(min_content = )` drop
segments. Splitting documents is covered in [Segmenting long
documents](https://sonsoles.me/sbert/articles/segmenting.md).

## Which words are ignored when topics are described?

Stop words do not change the text or the embeddings. They are removed
only when the words that describe each topic are computed.
[`stop_words()`](https://sonsoles.me/sbert/reference/stop_words.md)
returns the default English list, and `add` and `remove` adapt it to a
corpus:

``` r

length(stop_words())
#> [1] 125
head(stop_words(), 10)
#>  [1] "a"       "about"   "after"   "again"   "against" "all"     "am"      "an"     
#>  [9] "and"     "any"
covid_stop_words <- stop_words(add = c("covid", "pandemic"))
length(covid_stop_words)
#> [1] 127
```

The default list has 125 words. In a corpus selected for COVID-19, the
words *covid* and *pandemic* occur in most texts and describe no topic,
so they are added. The list is passed as `topics(stop_words = )` or
`terms(stop_words = )`.

## The preparation in one sequence

The full preparation of the abstracts, in order, ends with an encoding
step that needs a downloaded model and is not run here:

``` r

abstracts <- subset(covid, Abstract != "[No abstract available]")
abstracts <- dedupe(abstracts, column = "Abstract")
abstracts <- clean_corpus(abstracts, column = "Abstract",
                          remove = "(copyright:?\\s*(©|\\d{4})|©).{0,1000}$",
                          min_content = 0.5)
model_download()
topic_model <- topics(abstracts, n_topics = 10, column = "Abstract",
                      stop_words = stop_words(add = c("covid", "pandemic")),
                      numbers = "remove")
topic_sizes(topic_model, weights = "n")
```

| Problem | Verb |
|----|----|
| Placeholder or empty records | [`subset()`](https://rdrr.io/r/base/subset.html) before anything else |
| Repeated texts | [`dedupe()`](https://sonsoles.me/sbert/reference/dedupe.md), then `topic_sizes(weights = "n")` |
| Markup, URLs, citations, broken characters | [`clean_corpus()`](https://sonsoles.me/sbert/reference/clean_corpus.md) |
| Boilerplate such as copyright notices | `clean_corpus(remove = )` |
| List and section numbering | [`clean_corpus()`](https://sonsoles.me/sbert/reference/clean_corpus.md), [`strip_list_markers()`](https://sonsoles.me/sbert/reference/strip_list_markers.md) |
| Units that are not prose | [`content_ratio()`](https://sonsoles.me/sbert/reference/content_ratio.md), `min_content =` |
| Uninformative words in topic terms | `stop_words(add = )`, `numbers = "remove"` |

The prepared abstracts are modeled in [Case study: COVID-19 research
abstracts](https://sonsoles.me/sbert/articles/case-covid.md), and
choosing the unit of analysis is discussed in [Choosing the number of
topics and the
granularity](https://sonsoles.me/sbert/articles/choosing-topics.md).
