<!-- docs/MY_CARD_EVIDENCE.md -->

# My Card: Evidence Boundary

Research date: 2026-10-01. Issue: [#33](https://github.com/scarver2/abbu/issues/33).
Proposed decision, effective when merged: private-store evidence is insufficient
for ABBU to identify My Card. No detector, `me` method or `--me` flag is added.

## What Is Documented

Apple's [My Card guide](https://support.apple.com/guide/contacts/set-up-your-my-card-adrb3525ca49/mac)
describes selecting a different card as My Card and sharing/export controls.
Designation is not equivalent to the first contact, the local account name,
an email domain, or the most complete record.

Apple's public [CNContactStore API](https://developer.apple.com/documentation/contacts/cncontactstore)
includes `unifiedMeContactWithKeys(toFetch:)`. This is a supported framework
surface, not documentation of an ABBU table, column, key, or archive mapping.
Its existence prevents the stronger, incorrect conclusion that macOS has no
supported way to retrieve My Card.

The [unified contact API](https://developer.apple.com/documentation/contacts/cncontactstore/unifiedcontact%28withidentifier%3Akeystofetch%3A%29)
also documents that unification can return a different identifier than requested.
Do not assume framework identifiers equal file-local SQLite record keys, or
that a unified live contact identifies one historical archive record.

These primary sources were inspected on the research date. No framework call,
permission prompt, real Contacts access, or import experiment was performed.

## Repository Audit

The current parser models, fixtures and documentation contain no verified
My Card designation mapping. The existing [compatibility matrix](FORMAT_COMPATIBILITY.md)
tests synthetic read behavior without attributed macOS/Contacts builds. It
does not prove an archived designation is present, absent, unique or retained
across account changes. Group/source provenance is not identity designation.

Audit scope: `lib/`, `spec/` and `docs/`, including parser field mappings and
the synthetic fixture corpus at accepted main `77eaeda`. This is an audit of
this repository's evidence, not an exhaustive claim about every Apple schema.
Third-party findings and suggestive column names would be hypotheses pending
independent, sanitized reproduction.

## Agent-Safe Outcome

Current archive and direct read-only live-store inputs are **unsupported for
My Card identification**, not “no My Card exists.” Consumers must not substitute
the first record, logged-in user's name, matching email, image, or source folder.
There is no new JSON shape or misleading always-nil API in this docs-only change.

A future implementation must distinguish these states in a reviewed public
contract before coding:

| State | Required meaning |
| --- | --- |
| Unsupported | The input/backend has no verified designation capability. |
| Unavailable | A capable backend could not retrieve designation, including permission errors; not proof of absence. |
| Absent | A verified capable backend explicitly reports no designation. |
| Found | Exactly one evidenced designation with provenance; never heuristic confidence. |
| Ambiguous | Multiple unresolved designations; preserve candidates without selecting a winner. |

State names here are design requirements, not shipped enum names. Structured
results must be deterministic and preserve ambiguity. Do not emit contact
names, paths, identifiers, or values in diagnostic logs by default. Returning
the designated contact is itself sensitive and requires explicit user intent.

## Reopening Gate

For archive support, use disposable local accounts and invented contacts with
known designation changes. Record macOS and Contacts builds, export settings,
source membership, before/after evidence, and the verified relationship from
designation to record. Test zero/one/multiple/unsupported inputs, same-name and
same-email decoys, cross-source collisions, and legacy XML separately. Keep
unrelated fields constant so a correlated change is not assumed causal.

For a public-framework adapter, propose a separate opt-in macOS boundary with
permission handling and no mandatory native dependency for the portable gem.
Do not silently query the current user's Contacts while opening an unrelated
archive. Prove any identifier mapping independently; preserve framework
unification provenance rather than inventing one archive source.

Either path needs sanitized reproducible fixtures, exact-version scope, raw
evidence preservation, RBS/API/CLI contracts, regression coverage and review.
This issue permits an insufficient-evidence conclusion; no runtime feature or
version bump is claimed. Reopen with concrete evidence, not a guessed mapping.

Return to [README](../README.md), [roadmap](TODO.md), or [format evidence](ABBU.md).

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
