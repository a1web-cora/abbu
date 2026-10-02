<!-- docs/MERGE_PLANS.md -->

# Safe Merge Plans

`Abbu::MergePlan.new(left, right, policy: nil, source: nil)` creates a detached,
frozen review artifact. A plan does not assert that the records identify the
same person. `to_h` exposes policy, sources, both complete input snapshots,
per-field selected values and alternatives, conflicts, reasons and a
`materializable` flag. The caller remains responsible for identity decisions.

## Explicit Policies

All policies union multivalues by exact Ruby equality, retaining left order then
unseen right values. Raw labels are never normalized or discarded. Same address
with different raw labels remains two entries. Arrays include emails, phones,
addresses, groups, URLs, notes, related names, social profiles, dates and IMs.

- No policy: preview only; conflicting scalars remain unresolved.
- `union_multivalues`: materialize only when scalars have no unresolved conflict.
- `prefer_newer`: prefer the input with the later observed `modified_at` Time.
  Missing/non-Time/equal values do not choose a winner. This is caller policy,
  not proof of human edit history or field-level freshness.
- `prefer_source`: `source:` must equal the file-level `relative_path` of exactly
  one input; source directory/provider names are not identity shortcuts.
- `prefer_more_complete`: prefer the input with more populated scalar fields
  and nonempty multivalue collections, one point per field; timestamps and images
  are excluded. Ties do not choose a winner. This is a heuristic, not truth.

Nonconflicting scalar evidence fills missing values regardless of preferred
record. Empty strings are considered absent; whitespace-only strings are not
stripped. Conflicts keep both alternatives even when a policy selects a value.
Image URI and path are one atomic selection, never a cross-record combination.
No implicit field normalization, date conversion or image copying occurs.

`materialize` requires an explicit policy and rejects unresolved conflicts. It
returns a fresh mutable Contact, independent of the frozen plan and originals.
Its `source` is nil and `group_memberships` is empty: a derived record cannot
claim a single original file or merge source-local group keys. Original sources
and full group membership evidence remain in `to_h[:inputs]`; keep the plan with
the derived contact for provenance. Display group labels are unioned normally.
Existing contact exporter schemas remain unchanged.

Snapshots accept nil, booleans, symbols, numbers, strings, Time/Date, arrays and
hashes; unsupported caller objects raise rather than being frozen in place.
Plans are eager in-memory artifacts, not streaming stores.

## CLI Preview And Privacy

`abbu Contacts.abbu --merge-preview` emits a JSON array of plans for the existing
exact identity engine's candidate pairs. Optional `--merge-policy POLICY` and
`--prefer-source PATH` choose preview preferences. `--strict` and live input
selection are supported; other operations, including `--json`, are rejected.
JSON is intrinsic to this preview. Empty previews exit 0; argument or strict
parse errors exit 2; existing live input errors retain exit 1. Diagnostics remain
on stderr. Policies validate even when there are no candidates. A source selector
that does not uniquely identify one member of a candidate pair fails explicitly.

There is no CLI apply, file output or source mutation path. Exact matching is
currently all-pairs and results/plans are buffered: scope inputs in the Ruby API
for large datasets. A plan contains sensitive raw values, labels, image paths,
identifiers and source paths; it is not redacted telemetry. It should be stored
and transported with the same protection as the original address book.

This feature uses existing Contact evidence only and asserts no new Apple
storage semantics. Legacy parser and exporter contracts remain unchanged.

[README](../README.md) · [Contributing](CONTRIBUTING.md)

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
