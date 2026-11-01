# Qualitative Color Palette for Topics

The qualitative palette the package plots use to tell topics apart: `n`
colors from the qualitative HCL palette `"Dark 3"`
([`grDevices::hcl.colors()`](https://rdrr.io/r/grDevices/palettes.html)),
which vary only in hue at fixed lightness and chroma, so no topic looks
more prominent than another. Pass your own vector to the `colors`
argument of
[`plot.sbert_topic_model()`](https://sonsoles.me/sbert/reference/plot.sbert_topic_model.md)
to override it.

## Usage

``` r
topic_palette(n)
```

## Arguments

- n:

  Number of colors to return.

## Value

A character vector of `n` hex colors.

## Examples

``` r
topic_palette(4)
#> [1] "#E16A86" "#909800" "#00AD9A" "#9183E6"
```
