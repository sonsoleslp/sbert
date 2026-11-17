# Segmenting long documents

A sentence encoder reads a bounded window of text. Every model in
`sbert` has a maximum input length, counted in the sub-word tokens of
its tokenizer, and anything beyond it is cut off before the model sees
it. For the default `all-MiniLM-L6-v2` the window is 256 tokens. Short
texts such as feedback messages, survey answers or titles fit within it.
Research abstracts, open-ended essays and reports do not: the embedding
of a long document then describes its opening only, and whatever the
document says after the cut plays no part in its topic.

A second problem remains even when a document fits. A topic model
assigns each modeled unit to one topic, so a document that discusses two
things, for example a study design and a policy recommendation, is
forced into one of them. Splitting documents into sentences or clauses
addresses both problems: every unit fits the window, and a document
takes part in as many topics as its parts do. This guide shows how
[`segment()`](https://sonsoles.me/sbert/reference/segment.md) splits
text, how its options control the length and quality of the units, and
how a segmented topic model reports results per segment and per
document.

``` r

library(sbert)
#> sbert 0.6.0: Sentence-BERT embeddings and topic models in R.
#>   14 pinned models (see models()); default: all-MiniLM-L6-v2.
#>   A model is downloaded only on request, once, and verified by SHA-256.
```

## Data

`covid` holds 4,170 abstracts of educational research published during
the COVID-19 pandemic.

- **`Abstract`:** the text that is segmented. Some records carry the
  placeholder `"[No abstract available]"` and are removed first.
- **`Year`:** year of publication. Not used here.

The topic models in this guide need sentence embeddings, which are not
bundled for these abstracts. Segmentation itself needs no model, so
every segmentation below runs on the real abstracts; the segmented topic
models are shown on a small toy example with hand-written embeddings,
and the corresponding code for the abstracts is shown but not run.

``` r

abstracts <- subset(covid, Abstract != "[No abstract available]")
nrow(abstracts)
#> [1] 3847
```

3,847 abstracts remain. A word count is the measure of length used
throughout; `n_words()` counts the whitespace-separated words of each
text.

``` r

n_words <- function(text) lengths(strsplit(text, "\\s+"))
with(abstracts, summary(n_words(Abstract)))
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>      23     149     192     196     237     755
with(abstracts, sum(n_words(Abstract) > 200))
#> [1] 1704
```

The median abstract has 192 words and the longest 755. A tokenizer
produces more tokens than there are words, because rare words, numbers
and punctuation are split into several pieces, so 200 words is already
close to the 256-token window. 1,704 abstracts (44%) exceed 200 words,
and the end of each of them would be cut off if it were encoded whole.

## How finely should a document be split?

[`segment()`](https://sonsoles.me/sbert/reference/segment.md) splits
each document at one of three levels. `"sentence"` splits at `.`, `?`
and `!`; `"clause"` also splits at semicolons, colons, spaced dashes and
subordinating words such as “which” and “where”; `"phrase"` also splits
at commas. One invented sentence pair shows the difference.

``` r

example_text <- paste(
  "Engagement rose by 2.5 points (see Fig. 3, i.e. the second panel).",
  "Dr. Smith et al. argue the effect is small; others disagree, which",
  "matters for policy. Students who used the tool, especially in large",
  "classes, reported higher satisfaction."
)
segment(example_text, level = "sentence")
#>   document_id document_name segment
#> 1           1                     1
#> 2           1                     2
#> 3           1                     3
#>                                                                                     text
#> 1                     Engagement rose by 2.5 points (see Fig. 3, i.e. the second panel).
#> 2 Dr. Smith et al. argue the effect is small; others disagree, which matters for policy.
#> 3 Students who used the tool, especially in large classes, reported higher satisfaction.
segment(example_text, level = "clause")
#>   document_id document_name segment
#> 1           1                     1
#> 2           1                     2
#> 3           1                     3
#> 4           1                     4
#> 5           1                     5
#>                                                                                     text
#> 1                     Engagement rose by 2.5 points (see Fig. 3, i.e. the second panel).
#> 2                                            Dr. Smith et al. argue the effect is small;
#> 3                                                                       others disagree,
#> 4                                                              which matters for policy.
#> 5 Students who used the tool, especially in large classes, reported higher satisfaction.
segment(example_text, level = "phrase")
#>   document_id document_name segment
#> 1           1                     1
#> 2           1                     2
#> 3           1                     3
#> 4           1                     4
#> 5           1                     5
#> 6           1                     6
#> 7           1                     7
#>                                                                 text
#> 1 Engagement rose by 2.5 points (see Fig. 3, i.e. the second panel).
#> 2                        Dr. Smith et al. argue the effect is small;
#> 3                                                   others disagree,
#> 4                                          which matters for policy.
#> 5                                        Students who used the tool,
#> 6                                       especially in large classes,
#> 7                                      reported higher satisfaction.
```

The result has one row per segment: `document_id` (the position of the
document in the input), `document_name` (its name, empty here),
`segment` (the position within the document) and `text`. At sentence
level the example gives three segments. Neither the decimal point in
“2.5”, nor the periods of “Fig.”, “i.e.”, “Dr.” and “et al.”, nor the
comma inside the parentheses ends a segment: numbers, a gazetteer of
abbreviations and parentheticals are protected. The clause level splits
the second sentence at the semicolon and before “which”, and leaves the
third whole, because its commas set off an aside rather than a new
clause. The phrase level splits the third sentence at its two commas as
well.

Across the corpus, the level sets the number and length of the units.
`segment_profile()` summarizes one segmentation.

``` r

segment_profile <- function(segments, level) {
  with(segments, data.frame(
    level = level,
    segments = length(text),
    per_abstract = length(text) / length(unique(document_id)),
    median_words = median(n_words(text)),
    max_words = max(n_words(text))
  ))
}
sentences <- with(abstracts, segment(Abstract, level = "sentence"))
clauses <- with(abstracts, segment(Abstract, level = "clause"))
phrases <- with(abstracts, segment(Abstract, level = "phrase"))
rbind(
  segment_profile(sentences, "sentence"),
  segment_profile(clauses, "clause"),
  segment_profile(phrases, "phrase")
)
#>      level segments per_abstract median_words max_words
#> 1 sentence    35151         9.14           20       201
#> 2   clause    44316        11.52           16       117
#> 3   phrase    77914        20.25            8        93
```

The sentence level turns the abstracts into 35,151 segments, about 9 per
abstract, with a median of 20 words. The clause level gives 44,316 and
the phrase level 77,914. A sentence is the natural unit for academic
prose: it usually makes one claim and is long enough to carry meaning on
its own. Phrases are often fragments (“especially in large classes,”)
whose embeddings say little, so the finer levels are worth their cost
only when sentences regularly combine several ideas. The [guide to
choosing the number of
topics](https://sonsoles.me/sbert/articles/choosing-topics.md) compares
the levels on the quality of the resulting topics with
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md).

## Do some segments still overrun the window?

Splitting at sentence boundaries does not bound the length of a
sentence.

``` r

with(sentences, sum(n_words(text) > 100))
#> [1] 16
long_sentences <- subset(sentences, n_words(text) > 100)
head(long_sentences, 1)
#>     document_id document_name segment
#> 272          32                     6
#>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           text
#> 272 Points of interest The COVID-19 pandemic has significantly disrupted education for most learners; There is good evidence to suggest this impact is felt more keenly by students with disability, because there is disability discrimination in the Australian education system; This paper reports survey responses from over 700 families of students with disability exploring the impact of COVID-19 on education; Many families report being left behind and that students found it difficult to learn away from the school campus, which for many students and families led to poorer wellbeing and mental health; Our results suggest that supporting students to have social contact with peers made the biggest impact on students with disability feeling engaged with learning during this time.
```

16 sentences exceed 100 words and the longest has 201. The first of them
is a list of bullet points joined by semicolons, which the sentence
level does not split. `max_tokens` caps the length of every segment: a
segment over the budget is re-split at the finest punctuation it
contains (clause boundaries, semicolons, colons, dashes, then commas),
and the pieces are packed back up to the budget.

``` r

capped_example <- with(head(long_sentences, 1),
                       segment(text, level = "sentence", max_tokens = 40))
capped_example
#>   document_id document_name segment
#> 1           1                     1
#> 2           1                     2
#> 3           1                     3
#>                                                                                                                                                                                                                                                                              text
#> 1 Points of interest The COVID-19 pandemic has significantly disrupted education for most learners; There is good evidence to suggest this impact is felt more keenly by students with disability, because there is disability discrimination in the Australian education system;
#> 2                         This paper reports survey responses from over 700 families of students with disability exploring the impact of COVID-19 on education; Many families report being left behind and that students found it difficult to learn away from the school campus,
#> 3              which for many students and families led to poorer wellbeing and mental health; Our results suggest that supporting students to have social contact with peers made the biggest impact on students with disability feeling engaged with learning during this time.
```

The bulleted sentence becomes 3 segments of 39, 39, 40 words: the first
ends at a semicolon, the second at a comma, and the third at the end of
the sentence. Without a model, `max_tokens` counts words, a
deterministic offline proxy; because a tokenizer emits more tokens than
words, the budget is set below the model’s window, for example 200 words
for a 256-token model, or 100 words for the 128-token multilingual
models. With a loaded model, `segment(..., model = model)` counts that
model’s exact tokens instead, and `max_tokens` can be the window itself.

``` r

capped <- with(abstracts, segment(Abstract, level = "sentence", max_tokens = 100))
segment_profile(capped, "sentence, max_tokens = 100")
#>                        level segments per_abstract median_words max_words
#> 1 sentence, max_tokens = 100    35168         9.14           20       100
```

With a budget of 100 words, the corpus has 35,168 sentence segments
instead of 35,151, and none is longer than 100 words. Only the over-long
sentences change.

[`topics()`](https://sonsoles.me/sbert/reference/topics.md),
[`topic_corpus()`](https://sonsoles.me/sbert/reference/topic_corpus.md)
and
[`compare_topics()`](https://sonsoles.me/sbert/reference/compare_topics.md)
take the same `max_tokens`, `merge_below` and `min_content` options as
[`segment()`](https://sonsoles.me/sbert/reference/segment.md), so the
segmentation used to encode and the one used to fit can be made to
agree.

## Which abbreviations end a sentence?

A period after an abbreviation is the most common cause of a wrong
sentence split.
[`abbreviations()`](https://sonsoles.me/sbert/reference/abbreviations.md)
returns the built-in gazetteer.

``` r

abbreviations()
#>  [1] "APPROX." "B.SC."   "CF."     "DR."     "E.G."    "EQ."     "EQS."    "ET AL." 
#>  [9] "FIG."    "FIGS."   "I.E."    "M.SC."   "NO."     "NOS."    "PH.D."   "PP."    
#> [17] "PROF."   "REF."    "REFS."   "ST."     "U.K."    "U.S."    "VOL."    "VS."
```

The gazetteer holds 24 abbreviations common in academic writing.
Matching ignores case and starts at a word boundary, so “St.” in
“St. Petersburg” is protected but the end of “cost.” is not. An
abbreviation that is missing splits a sentence in the wrong place:

``` r

segment("Results are reported in Sect. 4. The model fits well.",
        level = "sentence")
#>   document_id document_name segment                          text
#> 1           1                     1 Results are reported in Sect.
#> 2           1                     2                            4.
#> 3           1                     3          The model fits well.
segment("Results are reported in Sect. 4. The model fits well.",
        level = "sentence", abbreviations = c(abbreviations(), "SECT."))
#>   document_id document_name segment                             text
#> 1           1                     1 Results are reported in Sect. 4.
#> 2           1                     2             The model fits well.
```

With the default gazetteer, “Sect.” ends a sentence and “4.” becomes a
segment of its own. Adding `"SECT."` to the gazetteer gives the two
correct sentences. A domain with its own abbreviations (law, medicine, a
non-English source) needs its own additions.

## How are fragments and reference noise handled?

Abstracts and full texts contain material that is not prose: copyright
lines, citations, page ranges and numbered lists. At clause level these
become segments of their own.

``` r

noisy <- paste(
  "Teachers adapted quickly to remote teaching. (2020), 12(3), 45-67.",
  "doi:10.1000/xyz 2021; 14: 1-9. Most reported fatigue."
)
noisy_segments <- segment(noisy, level = "clause")
noisy_segments
#>   document_id document_name segment                                         text
#> 1           1                     1 Teachers adapted quickly to remote teaching.
#> 2           1                     2                        (2020), 12(3), 45-67.
#> 3           1                     3                        doi:10.1000/xyz 2021;
#> 4           1                     4                                          14:
#> 5           1                     5                                         1-9.
#> 6           1                     6                       Most reported fatigue.
with(noisy_segments, content_ratio(text))
#> [1] 0.974 0.000 0.300 0.000 0.000 0.950
```

[`content_ratio()`](https://sonsoles.me/sbert/reference/content_ratio.md)
is the share of a segment’s characters that belong to alphabetic words.
The two sentences of prose score above 0.9; the citation fragments score
0.3 or less. `min_content` drops every segment below a floor.

``` r

segment(noisy, level = "clause", min_content = 0.5)
#>   document_id document_name segment                                         text
#> 1           1                     1 Teachers adapted quickly to remote teaching.
#> 2           1                     2                       Most reported fatigue.
```

A floor of 0.5 keeps the two prose sentences and removes the four
fragments. On the abstracts:

``` r

with(clauses, sum(content_ratio(text) < 0.5))
#> [1] 790
head(subset(clauses, content_ratio(text) < 0.5), 4)
#>     document_id document_name segment         text
#> 99            9                    16   © 2022, W.
#> 166          16                     5 © 2021 ASPE.
#> 185          18                    13 © 2021 ASPE.
#> 223          21                    17 © 2021 ASPE.
```

790 of the 44,316 clauses fall below 0.5, among them copyright lines
that publishers append to abstracts. Left in, such fragments tend to
gather into a topic of their own that describes the publisher, not the
research.

`merge_below` handles short fragments that are prose: a segment with
fewer words than the threshold is joined to its neighbor.

``` r

segment(example_text, level = "phrase", merge_below = 4)
#>   document_id document_name segment
#> 1           1                     1
#> 2           1                     2
#> 3           1                     3
#> 4           1                     4
#> 5           1                     5
#>                                                                 text
#> 1 Engagement rose by 2.5 points (see Fig. 3, i.e. the second panel).
#> 2       Dr. Smith et al. argue the effect is small; others disagree,
#> 3                                          which matters for policy.
#> 4                                        Students who used the tool,
#> 5         especially in large classes, reported higher satisfaction.
with(clauses, sum(n_words(text) < 4))
#> [1] 4600
merged <- with(abstracts, segment(Abstract, level = "clause", merge_below = 4))
nrow(merged)
#> [1] 39716
```

With `merge_below = 4`, “others disagree,” (two words) is joined to the
segment before it, and “reported higher satisfaction.” (three words) to
the one before that. In the abstracts, 4,600 clauses have fewer than
four words, and merging reduces the clause count from 44,316 to 39,716.
Merging changes the units the model is fitted to, so it is a choice to
state and keep fixed, like the level.

## How does a topic model use segments?

[`topics()`](https://sonsoles.me/sbert/reference/topics.md) takes the
same options through `segment`, `max_tokens`, `merge_below` and
`min_content`: it segments every document, embeds every segment, and
clusters the segments. The example below is a toy: four short course
reviews of two sentences each, with three-dimensional embeddings written
by hand so that the result can be followed. The first dimension stands
for teaching quality, the second for workload and assessment.

``` r

reviews <- c(
  course_a = "The lectures were clear. Overall it was fine.",
  course_b = "The exam was far too long. Overall it was fine.",
  course_c = "The teacher explained every step. The slides helped.",
  course_d = "The workload was heavy. Grading felt unfair."
)
review_sentences <- segment(reviews, level = "sentence")
review_sentences
#>   document_id document_name segment                              text
#> 1           1      course_a       1          The lectures were clear.
#> 2           1      course_a       2              Overall it was fine.
#> 3           2      course_b       1        The exam was far too long.
#> 4           2      course_b       2              Overall it was fine.
#> 5           3      course_c       1 The teacher explained every step.
#> 6           3      course_c       2                The slides helped.
#> 7           4      course_d       1           The workload was heavy.
#> 8           4      course_d       2              Grading felt unfair.
```

The four reviews give eight sentences. The toy embeddings have one row
per sentence, in the order
[`segment()`](https://sonsoles.me/sbert/reference/segment.md) returns
them. The sentence “Overall it was fine.” appears in two reviews and
gets the same, ambiguous vector both times, as it would from a real
encoder, which sees only the sentence.

``` r

sentence_embeddings <- rbind(
  c(0.95, 0.05, 0.10), c(0.50, 0.50, 0.40),
  c(0.05, 0.95, 0.10), c(0.50, 0.50, 0.40),
  c(0.90, 0.10, 0.15), c(0.85, 0.15, 0.10),
  c(0.10, 0.90, 0.15), c(0.15, 0.85, 0.10)
)
sentence_model <- topics(reviews, n_topics = 2, segment = "sentence",
                         embeddings = sentence_embeddings, n_terms = 3)
sentence_model
#> <sbert_topic_model>
#>   documents: 4 
#>   segments: 8 (sentence level) 
#>   topics: 2
#>   model: precomputed embeddings
#>   algorithm: deterministic k-means (Lloyd)
#>   topic sizes: 5, 3
#>   between/total SS: 74.3%
as.data.frame(sentence_model, what = "documents")
#>   document_id document_name segment                              text topic
#> 1           1      course_a       1          The lectures were clear.     1
#> 2           1      course_a       2              Overall it was fine.     1
#> 3           2      course_b       1        The exam was far too long.     2
#> 4           2      course_b       2              Overall it was fine.     1
#> 5           3      course_c       1 The teacher explained every step.     1
#> 6           3      course_c       2                The slides helped.     1
#> 7           4      course_d       1           The workload was heavy.     2
#> 8           4      course_d       2              Grading felt unfair.     2
#>                     label distance
#> 1      The slides helped. 0.062464
#> 2      The slides helped. 0.098453
#> 3 The workload was heavy. 0.002053
#> 4      The slides helped. 0.098453
#> 5      The slides helped. 0.037540
#> 6      The slides helped. 0.032403
#> 7 The workload was heavy. 0.000647
#> 8 The workload was heavy. 0.001979
```

The model has one row per segment, not per document: the document table
carries `document_id`, `document_name` and `segment` next to each
sentence’s topic. The teaching sentences form one topic and the workload
sentences the other; both copies of “Overall it was fine.” join the
teaching topic, including the one in `course_b`, a review about the
exam.

Segment-level and document-level counts answer different questions.

``` r

topic_sizes(sentence_model)
#>   topic                   label n_documents proportion
#> 1     1      The slides helped.           5      0.625
#> 2     2 The workload was heavy.           3      0.375
topic_sizes(sentence_model, by = "document")
#>   topic                   label n_documents proportion
#> 1     1      The slides helped.           3       0.75
#> 2     2 The workload was heavy.           2       0.50
```

By segment, the teaching topic holds 5 of the 8 sentences. By document,
a review counts once for every topic it reaches, so the proportions are
shares of the 4 reviews and add to more than one: the teaching topic
reaches 3 reviews and the workload topic 2.
[`topic_gamma()`](https://sonsoles.me/sbert/reference/topic_gamma.md)
gives each review’s mixture, the share of its segments in each topic.

``` r

topic_gamma(sentence_model)
#>   document_id topic gamma n_segments
#> 1           1     1   1.0          2
#> 2           1     2   0.0          2
#> 3           2     1   0.5          2
#> 4           2     2   0.5          2
#> 5           3     1   1.0          2
#> 6           3     2   0.0          2
#> 7           4     1   0.0          2
#> 8           4     2   1.0          2
topic_gamma(sentence_model, top = 1)
#>   document_id rank topic gamma n_segments
#> 1           1    1     1   1.0          2
#> 2           2    1     1   0.5          2
#> 3           3    1     1   1.0          2
#> 4           4    1     2   1.0          2
```

`course_b` is split half and half; the other three reviews fall wholly
in one topic. `top = 1` keeps each document’s dominant topic, with the
first topic winning a tie. No encoding happens here: a segmented model
stores the topic of every segment, so its mixtures are counts.

## Can a segment borrow context from its document?

The ambiguous sentence shows the price of segmenting: a short segment
can be ambiguous on its own, and identical segments in different
documents get identical vectors.
[`blend()`](https://sonsoles.me/sbert/reference/blend.md) mixes each
segment’s vector with that of its parent document. It keeps `alpha` of
what the segment says beyond its document (the part of the segment
vector orthogonal to the document vector) and `1 - alpha` of the
document direction, and normalizes the result to unit length. The toy
document embeddings below point toward teaching for `course_a` and
`course_c` and toward workload for `course_b` and `course_d`.

``` r

document_embeddings <- rbind(
  c(0.85, 0.30, 0.20), c(0.30, 0.85, 0.20),
  c(0.95, 0.10, 0.10), c(0.10, 0.95, 0.10)
)
contextual <- blend(review_sentences, alpha = 0.5,
                    embeddings = sentence_embeddings,
                    document_embeddings = document_embeddings)
round(contextual, 3)
#>       [,1]  [,2]  [,3]
#> [1,] 0.992 0.064 0.110
#> [2,] 0.658 0.590 0.467
#> [3,] 0.064 0.992 0.110
#> [4,] 0.590 0.658 0.467
#> [5,] 0.981 0.109 0.163
#> [6,] 0.978 0.172 0.115
#> [7,] 0.109 0.981 0.163
#> [8,] 0.172 0.978 0.115
```

The two copies of “Overall it was fine.” (rows 2 and 4) now differ: the
one in `course_a` leans toward the first dimension, the one in
`course_b` toward the second. Fitting the topics to the blended vectors:

``` r

blended_model <- topics(reviews, n_topics = 2, segment = "sentence",
                        embeddings = contextual, n_terms = 3)
topic_gamma(blended_model)
#>   document_id topic gamma n_segments
#> 1           1     1     1          2
#> 2           1     2     0          2
#> 3           2     1     0          2
#> 4           2     2     1          2
#> 5           3     1     1          2
#> 6           3     2     0          2
#> 7           4     1     0          2
#> 8           4     2     1          2
```

Each copy of the ambiguous sentence now joins the topic of its own
review, and every review falls wholly in one topic. `alpha = 0` would
replace every segment with its document, and `alpha = 1` would keep only
what the segment adds to its document; the default 0.5 balances the two.
Blending suits corpora in which short segments are common and their
meaning depends on the document. The blended matrix must be built from
the same segmentation that
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) applies,
which here means the same `level` and the same segmentation options.

## The same analysis on the abstracts

With a downloaded model, the analysis above runs on the abstracts. The
code is not run here because it needs the model (see the [guide to
models and the
cache](https://sonsoles.me/sbert/articles/models-and-cache.md)).

``` r

model <- load_model("all-MiniLM-L6-v2")
sentence_model <- topics(abstracts, column = "Abstract", n_topics = 8,
                         segment = "sentence", max_tokens = 256,
                         min_content = 0.5, model = model)
summary(sentence_model)
topic_sizes(sentence_model, by = "document")
topic_gamma(sentence_model, top = 3)
```

With a model and `max_tokens`,
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) counts the
model’s own tokens, so the budget can be the 256-token window. To blend,
the segments are taken from
[`segment()`](https://sonsoles.me/sbert/reference/segment.md) with a
word budget, because
[`blend()`](https://sonsoles.me/sbert/reference/blend.md) and
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) must see the
same segmentation and precomputed embeddings make
[`topics()`](https://sonsoles.me/sbert/reference/topics.md) count words:

``` r

covid_sentences <- with(abstracts, segment(Abstract, level = "sentence",
                                           max_tokens = 200))
contextual <- with(abstracts, blend(covid_sentences, documents = Abstract,
                                    model = model, alpha = 0.5))
blended_model <- topics(abstracts, column = "Abstract", n_topics = 8,
                        segment = "sentence", max_tokens = 200,
                        embeddings = contextual)
topic_gamma(blended_model, top = 3)
```

## When to segment, and how

- Documents that fit the model’s window and make one point (feedback
  messages, short answers, titles): no segmentation; see [the main
  article](https://sonsoles.me/sbert/articles/sbert.md).
- Documents longer than the window, or documents that discuss several
  themes: `segment = "sentence"`, with `max_tokens` set to the window
  (with a model) or somewhat below it in words.
- Text with citations, copyright lines or lists: add
  `min_content = 0.5`, or clean the documents first (see [preparing a
  corpus](https://sonsoles.me/sbert/articles/preparing-corpus.md)).
- Short, context-dependent segments:
  [`blend()`](https://sonsoles.me/sbert/reference/blend.md) the segment
  and document vectors before fitting.
- Unsure which level: compare them with
  `compare_topics(segment = c(...))` (see [choosing the number of
  topics](https://sonsoles.me/sbert/articles/choosing-topics.md));
  mixtures of new documents are covered in [assigning
  topics](https://sonsoles.me/sbert/articles/assigning-topics.md).
