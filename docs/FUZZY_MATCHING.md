<!-- docs/FUZZY_MATCHING.md -->

# Explainable Fuzzy Name Matching

`Abbu::Utils::FuzzyMatcher.new(contact, candidates, threshold: 0.85).matches`
returns existing `Deduplicator::Match` objects in candidate order. The original
anchor object is skipped. Existing `Deduplicator#matches` remains unchanged.
Callers should supply distinct candidate objects. This API suggests comparisons;
it never selects a winner, collapses records or modifies source evidence.

## Algorithm And Evidence Boundary

ABBU uses normalized Levenshtein edit distance over Unicode codepoints:
`similarity = 1 - distance / maximum_name_length`. This local, dependency-free
algorithm exposes an integer edit count. Unlike prefix-boosted metrics, it adds
no assumption that a matching prefix is more identifying. It is an ABBU
convention, not an Apple Contacts storage or identity rule.

Names use NFC, downcasing, trimming and whitespace collapse only. Accents,
punctuation, scripts and compatibility characters remain distinct; no ASCII
transliteration, nickname expansion, initial expansion or token reordering is
performed. Canonically equivalent Unicode spellings compare equally. Original
names remain in evidence and in the contacts. Empty names supply no fuzzy signal.

Thresholds are inclusive, finite numeric values in `[0, 1]`. Comparison uses the
unrounded similarity. Each qualifying fuzzy signal exposes `algorithm`,
`distance`, `similarity`, both normalized names, both raw names and `contribution`.
Threshold 1 requires equality after the documented normalization, not raw equality.
Even exact normalized names alone remain ambiguous.

## Exact Evidence And Scores

Each pair is also checked by the existing provenance-aware exact matcher. Its
qualifying score and status take precedence; fuzzy evidence then contributes
zero, so similarity cannot inflate exact confidence. Exact signal contributions
follow existing weights, counted once per type and capped in evidence order at
the total score. Otherwise the fuzzy-only score is `0.15 * similarity`, rounded
to four decimals, with low confidence and ambiguous status. Scores are ranking
heuristics, never probabilities. Names are not global identifiers.

Two or more qualifying exact candidates for the anchor make every returned
suggestion ambiguous. Fuzzy suggestions alone do not demote a single exact
candidate. Candidate-to-candidate relationships are not evaluated; scope and
candidate selection remain the caller's responsibility. `Match#merge` still
requires an explicit caller-provided policy; review remains necessary.

## Resource And Privacy Boundaries

Defaults are 10,000 candidates and 128 normalized codepoints per name. Both
`max_candidates:` and `max_name_length:` require positive integers. Exceeding a
bound raises `ArgumentError`, never silent truncation. Candidate enumeration
reads at most limit+1 elements; names are validated during `matches`. Results
are buffered. Callers raising limits accept the additional cost.

For N candidates and bounded name length L, edit-distance work is O(N × L²)
with O(L) distance-row memory. Exact comparison also traverses contact identifier
collections, so these bounds do not bound arbitrary email/phone arrays. The
deterministic 1,000-candidate synthetic spec exercises this baseline without a
flaky wall-clock assertion or personal Contacts data. This is not a benchmark
claim for arbitrary archive sizes or real-world identity accuracy.

Returned contacts, raw names, exact evidence and source paths are sensitive;
do not publish match results as sanitized diagnostics. Parsing, exporters and
existing JSON contracts are unchanged. No private Apple schema assumptions or
new runtime dependencies are introduced.

[README](../README.md) · [Contributing](CONTRIBUTING.md)

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
