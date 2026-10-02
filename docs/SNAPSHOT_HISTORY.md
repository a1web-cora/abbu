<!-- docs/SNAPSHOT_HISTORY.md -->

# Snapshot History

`Abbu::SnapshotHistory.new(paths, strict: false, retention: 2, limits: {}).each`
streams one transition per supplied archive path. Explicit list order is
authoritative. `from_directory(path)` selects only immediate directory children
whose names end in `.abbu`, sorted lexically. Directory names are ordering
labels, not verified capture times; choose sortable names or supply an ordered
list. Duplicate expanded paths are rejected; symlink aliases are not resolved.

History uses the public [SnapshotDiff](SNAPSHOT_DIFF.md) contract. Only unique
probable exact-evidence matches connect observations. Raw labels, source paths,
all modeled field changes and ambiguity are retained; fuzzy matching is not
identity. Each connected timeline records first/last observed snapshot references
and a numeric ID local to this analysis. Re-enumeration starts a fresh analysis.

## Continuity And Gaps

- `first_seen`: first observation in this analysis or after previous evidence
  was forgotten. It does **not** prove that the contact was newly created.
- `observed`: an adjacent unique probable comparison. `changes` may be empty.
- `absent`: previously observed contact has no qualifying candidate in this
  snapshot. Reported once per absence, not proof of deletion from Apple Contacts.
- `reappeared`: unique probable match after an observed gap within retention.
  This means observed again; it does not prove deletion/recreation between files.
- `ambiguous_start`: competing/weak evidence breaks prior continuity and starts
  explicitly flagged new timelines. The ambiguous pairs identify prior timeline
  IDs. Broken old timelines are not kept in the dormant pool for later reconnection.

`retention` is the nonnegative maximum number of absent snapshots to retain a
contact for possible reappearance matching. Default 2 permits up to two empty
observations between appearances; 0 discards an absent record immediately.
After expiry, a return receives a new ID and `first_seen`. The analysis cannot
distinguish a genuinely new record from forgotten identity evidence. A later
unambiguous link from an ambiguous-start timeline never repairs its earlier break.

Matching includes current and retained dormant candidates together. Competing
evidence cannot silently select the active or most recent one. This is an
observation stream, not a complete contact-index database; consumers can group
observations by ID to build a per-contact index. Do not coalesce IDs by names.

## JSON Lines Contract

`abbu snapshots-directory --history [--strict]` emits one JSON object per line,
with `schema_version: 1`, `snapshot`, `observations`, `absent`, `ambiguous` and
`diagnostics`. `snapshot` has zero-based `index` and expanded `path`.
Observations expose `timeline_id`, `first_seen`, `last_seen`, `event`, full
`contact`, field `changes`, `compared_with` (previous observed snapshot or null)
and `match` (score/evidence or null). Absences carry timeline metadata and
`observed_at`. Ambiguous pairs retain SnapshotDiff before/after payloads plus
`before_timeline_id`; their indices refer to that transition's comparison pool,
not permanent contact identifiers. Observation order follows parser order.

Other CLI modes (including `--json` and live input) are rejected. No snapshots
emits no lines and exits 0. Argument/parse failures exit 2 through existing CLI
handling. Diagnostics are included in each transition, not hidden or printed as
non-JSON stdout. A later failure may leave earlier valid JSON lines: consumers
must check exit status and must not label a partial stream complete.

## Bounded Strategy And Privacy

Default `limits: { snapshots: 100, contacts: 10_000, pairs: 100_000 }` bounds path
count, current-plus-retained contact count and each comparison's cross-product.
Unknown keys, nonpositive limits and overflows raise explicitly, never truncate.
The snapshot count is checked before loading; contact/pool bounds are checked
after the parser has materialized a single archive. Thus this is not a bound on
individual archive parsing, contact field sizes or directory listing size.

The reader holds the current archive, bounded current/dormant records and one
detached transition, not all archives. Consuming `each` incrementally avoids
accumulating all results; calling `to_a` intentionally retains them. Large sets
can raise configured limits explicitly, accepting the resulting memory/work cost.
Synthetic tests cover deterministic order, expiry, reappearance, ambiguity and
bound failures; no real-world performance or historical completeness is claimed.

Output includes complete personal contact data, labels, source identifiers,
image paths, verification codes and diagnostic locations. Treat streams as
sensitive backups, not telemetry. Source archives remain read-only. No edit
authors, real event timestamps or events between snapshots are reconstructed.

[README](../README.md) · [Snapshot Diff](SNAPSHOT_DIFF.md)

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
