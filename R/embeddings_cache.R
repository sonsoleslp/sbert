# Content-addressed embedding cache.
#
# Encoding is ~97% of the cost of every topic workflow, and corpora are usually
# edited rather than replaced: a few abstracts are corrected, a year is appended,
# rows are reordered. Keying each embedding by its own content means an edited
# corpus re-encodes only what actually changed. Changing 38 of 3,847 documents
# costs 0.59 s against 57 s for a full re-encode.
#
# A row is identified by everything that can change its value: the exact text
# handed to the tokenizer (so any prefix is already folded in) and the model
# configuration that produced it. Anything omitted from the key is a silent
# wrong-answer risk, which is far worse than a cache miss.

embedding_cache_keys <- function(text, model, normalize) {
  # The configuration digest is constant within a call, so it is computed once;
  # hashing the whole configuration per document would dominate the loop.
  configuration <- digest::digest(
    list(
      id = model$id,
      revision = model$revision,
      dimension = model$dimension,
      max_length = model$max_length,
      pooling = if (is.null(model$pooling)) "mean" else model$pooling,
      normalize = normalize
    ),
    algo = "sha256"
  )
  vapply(
    text,
    function(one) digest::digest(list(configuration, one), algo = "sha256"),
    character(1),
    USE.NAMES = FALSE
  )
}

empty_embedding_cache <- function(dimension) {
  list(
    version = 1L,
    key = character(),
    embeddings = matrix(numeric(), nrow = 0L, ncol = dimension)
  )
}

read_embedding_cache <- function(path, dimension) {
  if (!file.exists(path)) {
    return(empty_embedding_cache(dimension))
  }
  cached <- tryCatch(readRDS(path), error = function(error_condition) NULL)
  usable <- is.list(cached) &&
    identical(cached$version, 1L) &&
    is.character(cached$key) &&
    is.matrix(cached$embeddings) &&
    is.numeric(cached$embeddings) &&
    nrow(cached$embeddings) == length(cached$key) &&
    ncol(cached$embeddings) == dimension &&
    !anyDuplicated(cached$key)
  if (!usable) {
    # Discard rather than trust. A corrupt or foreign cache that still matches a
    # key returns silently wrong embeddings; recomputing merely costs time.
    warning(
      "Ignoring an unreadable or incompatible embedding cache; it will be rebuilt.",
      call. = FALSE
    )
    return(empty_embedding_cache(dimension))
  }
  cached
}

write_embedding_cache <- function(path, key, embeddings) {
  directory <- dirname(path)
  if (!dir.exists(directory)) {
    dir.create(directory, recursive = TRUE)
  }
  # Write to a process-specific temporary file and rename, so an interrupted or
  # concurrent save can never leave a half-written cache that a later run would
  # read as authoritative.
  temporary <- paste0(path, ".tmp", Sys.getpid())
  on.exit(unlink(temporary), add = TRUE)
  saveRDS(
    list(version = 1L, key = key, embeddings = embeddings),
    temporary,
    compress = FALSE
  )
  file.rename(temporary, path)
  invisible(path)
}

encode_with_cache <- function(
  model,
  input_text,
  batch_size,
  normalize,
  sort_by_length,
  cache
) {
  keys <- embedding_cache_keys(input_text, model, normalize)
  cached <- read_embedding_cache(cache, model$dimension)
  position <- match(keys, cached$key)

  # Encode each DISTINCT miss once. Real corpora repeat documents — 295 of the
  # 3,847 bundled covid abstracts are duplicates — and re-encoding a repeat
  # spends the one cost that dominates everything else.
  missing_keys <- unique(keys[is.na(position)])
  if (length(missing_keys) > 0L) {
    representatives <- match(missing_keys, keys)
    fresh <- encode_in_batches(
      model,
      input_text[representatives],
      batch_size = batch_size,
      normalize = normalize,
      sort_by_length = sort_by_length
    )
    cached$key <- c(cached$key, missing_keys)
    cached$embeddings <- rbind(cached$embeddings, fresh)
    write_embedding_cache(cache, cached$key, cached$embeddings)
    position <- match(keys, cached$key)
  }

  cached$embeddings[position, , drop = FALSE]
}
