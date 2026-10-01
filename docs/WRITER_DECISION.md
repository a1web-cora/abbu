<!-- docs/WRITER_DECISION.md -->

# Decision: Do Not Generate Apple-Private ABBU Bundles

Date: 2026-10-01. Scope: research issue [#46](https://github.com/scarver2/abbu/issues/46).
Status: proposed for review; effective when merged. No runtime API or version change.

## Decision

Do not implement an ABBU bundle writer with the evidence currently available.
Keep source archives and live stores read-only. Do not add `deduplicate!`,
in-place repair, private SQLite writes, or an archive reconstruction API from
normalized Contact objects. Continue to offer vCard as the documented contact
interchange path, with its field limitations explicit. Keep original archives
as evidence; neither vCard nor normalized JSON is a complete archive backup.

This is a decision about this project's evidence, not a claim that creating
valid archives is impossible or that no private-format research exists.

## Evidence and Limits

- Apple's [import guide](https://support.apple.com/en-gb/guide/contacts/adrbk1457/mac)
  documents vCard and ABBU import and warns that archive import replaces current
  contact information. Its UI instructions are not a bundle-construction schema.
- Apple's [export guide](https://support.apple.com/guide/contacts/export-or-archive-contacts-adrbdcfd32e6/mac)
  distinguishes selected-contact vCards from full Contacts archives. Photo and
  note inclusion can be controlled for vCard exports. This does not establish
  the fidelity of ABBU's own serializer.
- Both pages were inspected on 2026-10-01. No Contacts import experiment was
  performed for this decision; no personal address book was opened or modified.
- The [compatibility matrix](FORMAT_COMPATIBILITY.md) has synthetic layouts with
  unknown macOS/Contacts builds. Successful parsing proves those read contracts,
  not that Contacts accepts a database produced from them.
- [Format evidence](ABBU.md) describes observed fields and explicit gaps.
  Unknown private metadata, identifiers, relationships, account state and
  alternate calendars must not be manufactured from table/column names.

Inference: current read fixtures and public UI documentation are insufficient
to justify a safe, version-scoped private writer. Renaming exported SQLite to
`.abcddb` or packaging normalized contacts into an `.abbu` directory would not
meet the import-evidence requirement.

## Preservation Requirements Before Reconsideration

| Evidence | Required proof, not an assumption |
| --- | --- |
| Labels and multivalues | Raw labels, duplicates, order where significant, Unicode, empty and absent values survive; normalization does not replace originals. |
| Photos | Original bytes and source identity remain available; image relationships and supported encodings are demonstrated. No inferred thumbnail/full-size preference. |
| Groups and sources | Membership remains source-local; same-name groups and colliding record keys remain distinct. Account/sync identities are never fabricated. |
| Dates | Unknown years remain unknown; custom labels, alternate calendars and leap metadata remain raw until their semantics are demonstrated. |
| Provenance | Original snapshot/file identity remains separately traceable; destination keys are not presented as original identities or human-edit timestamps. |
| Unsupported fields | Every omission has an explicit loss report; unknown private fields cannot silently disappear behind a “lossless” claim. |

Current vCard output does not reconstruct sources/groups/private provenance or
every date collection. URI photos depend on external paths. Optional embedding
is separately tracked by [#30](https://github.com/scarver2/abbu/issues/30); it does
not establish whole-archive fidelity. Retain original bytes and use available
JSON evidence for inspection, not as an assumed reconstruction format.

## Gate for a Future Proposal

1. Obtain explicit approval for isolated import experiments. Use a disposable
   macOS user or VM with no real contacts or synced accounts; never a user's
   everyday Contacts store. A backup alone does not make replacement harmless.
2. Record exact macOS and Contacts builds, export settings, initial synthetic
   data and schema fingerprints. Record unknowns honestly. Preserve old cases.
3. Demonstrate a minimal generated bundle importing successfully, then inspect
   and re-export it. Verify field-level values, raw evidence and losses against
   the table above; counts alone are insufficient. Repeat for every claimed
   supported version. Negative/unsupported versions must fail explicitly.
4. Require a new destination outside every source tree. Stage on the same
   filesystem and publish atomically with no overwrite, rejecting symlink/path
   aliases and existing destinations. Test interruption, failures, cleanup and
   races. Never update a live Contacts database or reuse input files as staging.
5. Independently review sanitized fixtures, import observations, preservation
   reports and the safety implementation before introducing a public writer.

These are future acceptance gates, not implemented guarantees. Existing vCard
`to_file` is not an atomic/no-overwrite archive writer. This decision adds no
writer, no import automation, no mutation API and no new format claims. Issue
#46 can close on the explicitly allowed no-writer outcome; new evidence should
open a new scoped proposal rather than silently reversing this boundary.

Return to [README](../README.md), [roadmap](TODO.md), or [format evidence](ABBU.md).

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
