# Implementation notes for `?topic_palette` (2026-11-17)

- Returns `grDevices::hcl.colors(n, palette = "Dark 3")`. SBERT/CLAUDE.md
  says the plots use the Okabe-Ito palette via `topic_palette()`; that is
  false for the code as of 2026-11-17. Whether to switch is an owner
  decision; the help page documents the current behaviour and shows how to
  pass Okabe-Ito colours.
