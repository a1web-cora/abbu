<!-- docs/SNAPSHOT_DIFF.md -->

# Snapshot Comparison

`Abbu::SnapshotDiff.new(before, after).to_h` compares two Archive/LiveStore
objects or ordered contact Enumerables. `abbu Before.abbu --diff After.abbu
--json` emits the same versioned JSON object. Omit `--json` for count summaries.
The first CLI input may use explicit read-only live input selection; the second
is an archive. `--strict` applies to both. The command exits 0 for a completed
comparison even when differences or ambiguities exist, and 2 for argument/parse
errors (live-store errors retain exit 1). Diagnostics remain on stderr.
JSON mode follows the [machine error contract](MACHINE_JSON.md): one structured
error document, with filesystem/access failures exiting 1. Only input selection,
`--strict`, and optional `--json` may accompany `--diff`; other operations,
export formats, output paths, and calendar metadata are rejected before reading
either input. Comparison-input diagnostics are summarized on stderr.

## Identity Boundary

Comparison uses the existing exact/provenance-aware identity engine, not Apple
record keys or fuzzy matching. Every cross-snapshot pair is evaluated. Only
one-to-one candidates at the engine's probable threshold become comparisons.
Competing candidates and weaker qualifying evidence remain `ambiguous`; their
records are excluded from added/removed so ambiguity is not presented as loss.
No contact is merged or modified. A probable match is still an evidence-based
suggestion, not a declaration of identity truth.

No qualifying evidence means unmatched: an email/name/phone change that removes
all qualifying evidence may appear as removed plus added. A name alone does not
establish continuity. Source moves remain visible through provenance changes.
Identical nameless/no-signal records are not silently paired by array position.

## JSON Contract (Schema Version 1)

Top-level keys: `schema_version`, `added`, `removed`, `changed`, `unchanged`,
`ambiguous`. Unmatched entries contain side-local `index` and a full `contact`
snapshot. Compared/ambiguous entries contain `before_index`, `after_index`,
`score`, exact-engine `evidence`, and full `before`/`after` snapshots. Compared
entries additionally contain `fields`: changed field names mapped to original
`before` and `after` values. Unchanged comparisons have empty `fields`.

Snapshots cover the explicit `SnapshotDiff::FIELDS` public contact attributes,
including raw labels, all multivalues, group membership, source, image paths and
timestamps. Nulls are retained. Array order is significant; reordering is a
reported change, not an inferred semantic equivalence. Paths become strings;
times use ISO 8601 with nine fractional digits. Image bytes are not compared:
matching paths do not prove identical photos. No unknown private columns are
reconstructed. The detached result is deeply frozen; source contacts remain
mutable and unchanged.

Ordering follows the supplied input order and cross-product traversal. Results
are deterministic for equivalent ordered inputs, not canonically sorted across
permutations. Indices are positions in that comparison, not persistent IDs.
No dates of edits, authors or events between snapshots are inferred.

## Resource and Privacy Limits

Both inputs are materialized. The O(before × after) candidate pass is capped at
100,000 pairs by default; API callers can explicitly set positive `max_pairs`.
Oversized comparisons fail before pair evaluation. This is not streaming or an
enterprise-scale benchmark claim. Live input is read through its existing
read-only API and consistency limitations, not an atomic historical snapshot.

JSON intentionally includes full contact values, raw identity evidence, paths,
source identifiers and verification codes already held by the supplied models.
Treat stdout/results as sensitive; do not send them to untrusted logs or agents.
Human summaries disclose counts only. Original source archives are never written.

Return to [README](../README.md), [format evidence](ABBU.md), or [API stability](API_STABILITY.md).

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
