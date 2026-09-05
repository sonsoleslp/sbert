# Deprecated: Compare Topic Counts

\`select_topics()\` is the former name of \[compare_topics()\]. It never
selected a count, it compared them, so it was renamed in sbert 0.5.4.
This alias forwards every argument and warns once per session.

## Usage

``` r
select_topics(...)
```

## Arguments

- ...:

  Passed to \[compare_topics()\].

## Value

See \[compare_topics()\].
