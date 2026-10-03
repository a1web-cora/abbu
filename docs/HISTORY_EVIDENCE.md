<!-- docs/HISTORY_EVIDENCE.md -->

# Contacts History: Evidence Before Events

Research date: 2026-10-01. Issue [#35](https://github.com/scarver2/abbu/issues/35).
Decision proposed for review: do not expose private save/edit-history fields
without reproducible storage evidence. This is a research boundary, not a
completed history parser or a claim that such records cannot exist.

## Three Different Questions

1. What timestamp does a record expose? ABBU already reads observed optional
   creation/modification fields; these are not a sequence of edits.
2. What changed between two observed snapshots? Future snapshot comparison can
   describe differences, not infer actions or exact times between observations.
3. What events does a supported history provider report? This requires its own
   evidence and semantics; it must not replace the original record timestamps.

No timestamp alone proves a human edit, an author, or an interaction with the
Contacts UI. Sync, migration and normalization are alternative hypotheses to
test, not asserted explanations for a given record.

## Primary Evidence

Apple documents [CNChangeHistoryFetchRequest](https://developer.apple.com/documentation/contacts/cnchangehistoryfetchrequest)
as a framework query for change history. Its overview says changes are coalesced
to eliminate redundant adds, updates and deletes. Therefore even this documented
surface must not be described as a complete keystroke or immutable audit log.

The documented [starting token](https://developer.apple.com/documentation/contacts/cnchangehistoryfetchrequest/startingtoken)
is opaque. A nil starting token requests a reset event and then add events for
current contacts/groups; those add events are not proof of original creation
times. Tokens are not dates, monotonically meaningful integers, or archive keys.

Apple's [unification option](https://developer.apple.com/documentation/contacts/cnchangehistoryfetchrequest/shouldunifyresults)
distinguishes unified from individual history. A future adapter must preserve
which mode it requested rather than silently treating the outputs identically.

Sources inspected on the research date. These documents do not specify private
SQLite history table layouts or mappings into an exported ABBU. No native API
calls, private live-store reads or personal database experiments were performed.

## Repository Evidence Audit

At accepted main `77eaeda`, the SQLite parser reads `ZCREATIONDATE` and
`ZMODIFICATIONDATE` as optional record timestamps. Synthetic fixture generation
and timestamp regressions exercise those fields. The schema inspector reports
unknown structure without interpreting it. The repository has no verified
save-history mapping with attributed macOS/Contacts build and controlled event
sequence. See [format evidence](ABBU.md) and the [compatibility matrix](FORMAT_COMPATIBILITY.md).

A table named like history, transaction, save or change does not establish
event semantics. Neither file modification times nor WAL page changes identify
the person who edited a contact. Third-party reverse engineering may supply
candidate observations, but is not an accepted mapping without reproduction.

## Required Experiment Before Implementation

- Use disposable, unsynced accounts and invented contacts, with explicit
  experiment approval. Record exact OS/Contacts builds and capture method.
- Establish a known initial state, then perform one controlled operation per
  observation: add, scalar edit, labeled-value edit, group membership change,
  delete, no-op save, and reopen. Separately test sync/migration if in scope.
- Capture original bytes and compare candidate records without modifying the
  source store. Record ordering, clock/time-zone assumptions, transaction
  grouping, retention/reset behavior and missing events. Do not guess epochs.
- Confirm relationships under duplicate names, source-local ID collisions,
  linked/unified contacts, and deletion of the referenced record. Keep old
  schema cases. Unknown layouts must remain unsupported, not empty history.
- Independently reproduce any external observation. Preserve raw values beside
  proposed interpretation and document counterexamples and alternative causes.

## Future Public Contract

History would be optional provenance evidence, never replacement `created_at`
or `modified_at`. Require explicit source/snapshot attribution, raw event data,
evidenced timestamp interpretation, ordering limits and unknown fields.
Distinguish unsupported backend, unavailable/permission failure, reset/truncated
history, and genuinely empty results from a capable provider. Never imply a
human actor without independent evidence. Define stable JSON and RBS only after
the source model is justified; no speculative API is shipped here.

Do not log contact values, identifiers, tokens or filesystem paths by default.
Archived evidence and tokens remain sensitive. A framework adapter would be a
separately reviewed, opt-in macOS boundary, not a mandatory portable-gem
dependency or a query against the current user's store when opening an archive.

The research outcome is insufficient evidence for a private parser. #35 can
close on this scoped boundary under the development-train directive; reopen
with a reproducible fixture/event sequence. #43/#44 snapshot work remains
independently useful but must not advertise unseen historical events.

Return to [README](../README.md), [roadmap](TODO.md), or [format evidence](ABBU.md).

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
