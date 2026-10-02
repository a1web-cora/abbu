<!-- docs/TODO.md -->

# Abbu Roadmap & TODO

Feature checklist organized by release version.

---

## v0.1.x — Foundation (Released)

### v0.1.0 — Initial Release
- [x] `Abbu.open(path)` entry point returning an `Archive`
- [x] `Archive#contacts` — reads contacts from SQLite
- [x] `Archive#sqlite?` — detects modern `.abcddb` bundles
- [x] `Contact` model with `first_name`, `last_name`, `emails`, `phones`, `company`
- [x] `Parsers::SqliteParser` — queries `ZABCDRECORD`, `ZABCDEMAILADDRESS`, `ZABCDPHONENUMBER`
- [x] `Parsers::PlistParser` — stub with warning
- [x] `Exporters::CsvExporter` — `to_file` and `to_stdout`
- [x] `Exporters::JsonExporter` — `to_file` and `to_stdout`
- [x] `Exporters::VcardExporter` — `to_file` and `to_stdout` (vCard 3.0)
- [x] `Utils::Deduplicator` — groups contacts by first email
- [x] `bin/abbu` CLI with `--format`, `--output`, `--stats`, `--dedupe`, `--version`
- [x] Rake tasks: `abbu:export`, `abbu:dedupe`, `abbu:stats`
- [x] `docs/ABBU.md` — file format reference
- [x] RSpec test suite with 100% coverage target
- [x] Guard + RuboCop DX loop
- [x] GitHub Actions CI (Ruby 3.2 + 3.3)

### v0.1.1 — Pathname Fix
- [x] Fix missing `require 'pathname'` in `archive.rb`
- [x] Regression guard spec for file require isolation

### v0.1.2 — Full Apple Contacts Schema
- [x] Nickname, prefix (`Title`), suffix fields
- [x] Smart `full_name` formatting: `Honorable Stan "Stretch" Carver II`
- [x] Job title, department, maiden name
- [x] Phonetic first/last name, phonetic company
- [x] Pronouns, ringtone, texttone
- [x] Hash-based emails/phones preserving custom labels
- [x] Address parsing from `ZABCDPOSTALADDRESS`
- [x] Group membership from `Z_ABCDCONTACTGROUP`
- [x] URL parsing from `ZABCDURLADDRESS`
- [x] Notes from `ZABCDNOTE`
- [x] Related names from `ZABCDRELATEDNAME`
- [x] Social profiles from `ZABCDSOCIALPROFILE` (Twitter, etc.)
- [x] CSV export with all fields (addresses, groups, URLs, notes, related names, social profiles)
- [x] JSON export with all contact fields
- [x] vCard 3.0 export with `ADR`, `URL`, `NICKNAME`, `TITLE`, `NOTE`, `X-SOCIALPROFILE`
- [x] `rubocop-rspec` plugin integration
- [x] SqliteParser refactored with `RECORD_FIELD_MAP` constant
- [x] CsvExporter refactored into `core_fields` / `extended_fields`

---

## v0.2.0 — Plist Parser (Released)

- [x] `PlistParser` — parse legacy `.abcdp` plist contact files
- [x] Full field extraction matching SqliteParser output shape
- [x] `FIELD_MAP` constant for flat-field mapping
- [x] Multi-value field extraction (emails, phones, addresses, URLs, notes, related names, social profiles)
- [x] Flexible input: directory path or array of file paths
- [x] `Archive` scans `**/*.abcdp` across entire bundle tree
- [x] `plist` gem (~> 3.7) runtime dependency
- [x] Plist fixture files for integration testing
- [x] Birthday / anniversary date parsing (plist `Birthday` key)
- [x] Lunar birthday support
- [x] Middle name extraction
- [x] Instant messaging addresses (AIM, Jabber, etc.)
- [x] Verification code field support

---

## v0.2.1 — Date Fields

- [x] `dates` attribute on `Contact` (array of hashes: `{ label:, date: }`)
- [x] SqliteParser: parse `ZABCDDATECOMPONENTS` (year/month/day separate columns)
- [x] PlistParser: parse `Birthday` key
- [x] Anniversary and custom date labels
- [x] Lunar birthday handling
- [x] CSV/JSON/vCard export of date fields (`BDAY`, `ANNIVERSARY` in vCard)

---

## v0.2.2 — Instant Messaging & Verification

- [x] `instant_messages` attribute on `Contact`
- [x] SqliteParser: parse `ZABCDMESSAGINGADDRESS`
- [x] PlistParser: parse `InstantMessage` key
- [x] Verification code field
- [x] CSV/JSON/vCard export (`IMPP` in vCard)

---

## v0.2.3 — Middle Name & Completeness

- [x] `middle_name` attribute on `Contact`
- [x] Update `full_name` to include middle name
- [x] SqliteParser: `ZMIDDLENAME` column
- [x] PlistParser: `Middle` key
- [x] Phonetic middle name support
- [x] vCard `N` field with middle name component

---

## v0.3.0 — Image Resolution (Released)

- [x] Resolve contact photos through observed `ZIMAGEURI` relationships
- [x] `Contact#image_uri` and `Contact#image_path` accessors
- [x] Root and nested source image discovery
- [x] CSV / JSON image paths and vCard PHOTO file URI references

---

## v0.4.0 — Read-only Contacts Toolkit

Implemented in the accepted #19–#25 tranche and earlier prerequisites; publication
is gated by [release issue #27](https://github.com/scarver2/abbu/issues/27),
Deputy exact-head review, and Sheriff release authority.

- [x] Evidence-safe schema introspection and `--schema`
- [x] Lossless Apple label normalization with `raw_label` and anniversary vCard fidelity
- [x] Creation/modification timestamps and source provenance
- [x] Tolerant structured diagnostics, per-database/table deduplication, and strict mode
- [x] Provenance-aware identity suggestions, phone comparison, and explicit merge-policy boundary
- [x] Source-aware duplicate image-stem resolution
- [x] First-class image extraction with content detection, safe filenames, and no destination overwrites
- [x] Chainable query API, exact email/phone lookup, and partial name/email search
- [x] TSV and stable JSON CLI search output
- [x] Explicit read-only live macOS Contacts input through `--live` / `--live-path PATH`
- [x] Ruby 3.3 minimum and lint/tooling gate; Ruby 3.4 and 4.0 CI
- [x] Pull-request CI plus canonical-main pushes, without duplicate feature-branch runs
- [x] `AGENTS.md`, local skills, and canonical spec/lint/package workflows

## Pre-1.0 Backlog — Not Included in 0.4.0

These remain future work; no implementation is authorized by release preparation.
Version assignments below 1.0 are intentionally deferred until scopes are accepted.

- [ ] [#28](https://github.com/scarver2/abbu/issues/28): synthetic WAL, sidecar, and concurrent-writer validation
- [ ] [#29](https://github.com/scarver2/abbu/issues/29): stronger Apple-compatible vCard fidelity and round trips
- [ ] [#30](https://github.com/scarver2/abbu/issues/30): embedded vCard photos (currently file URI references)
- [ ] [#31](https://github.com/scarver2/abbu/issues/31): first-class read-only source objects
- [ ] [#32](https://github.com/scarver2/abbu/issues/32): first-class groups and membership queries
- [x] [#33](https://github.com/scarver2/abbu/issues/33): [My Card research — private mapping remains unsupported](MY_CARD_EVIDENCE.md)
- [ ] [#34](https://github.com/scarver2/abbu/issues/34): modified-since and date-range queries
- [ ] [#35](https://github.com/scarver2/abbu/issues/35): evidence-backed save/edit history
- [ ] [#36](https://github.com/scarver2/abbu/issues/36): alternate-calendar and lunar metadata research
- [ ] [#37](https://github.com/scarver2/abbu/issues/37): explainable fuzzy names and configurable thresholds
- [ ] [#38](https://github.com/scarver2/abbu/issues/38): merge plans, side-by-side evidence, and safe built-in policies
- [ ] [#39](https://github.com/scarver2/abbu/issues/39): broader machine-readable JSON CLI contract
- [ ] [#40](https://github.com/scarver2/abbu/issues/40): streaming contact iteration/export and large-store performance
- [ ] [#41](https://github.com/scarver2/abbu/issues/41): portable SQLite export
- [ ] [#42](https://github.com/scarver2/abbu/issues/42): birthday/anniversary iCalendar export
- [ ] [#43](https://github.com/scarver2/abbu/issues/43): identity-aware snapshot diffs
- [ ] [#44](https://github.com/scarver2/abbu/issues/44): history across snapshot directories
- [ ] [#45](https://github.com/scarver2/abbu/issues/45): optional MCP/agent adapter over read-only interfaces
- [ ] [#46](https://github.com/scarver2/abbu/issues/46): evidence-backed new-ABBU writer research
- [ ] [#47](https://github.com/scarver2/abbu/issues/47): public API stability checklist
- [ ] Thumbnail/full-size image selection after reproducible format evidence
- [ ] Region filtering and an explicit CLI filter grammar

Previous in-place `Archive#deduplicate!` / source-archive mutation proposals are
superseded. Merge plans must preserve originals; any future writer targets a new
output bundle and requires evidence-backed round-trip validation. Writing live
Contacts databases is not part of the roadmap.

## v1.0.0 — Future Stable API

The [API stability gate](API_STABILITY.md) defines the evidence required below;
its existence does not mean those checks are complete or authorize a 1.0 release.

- [ ] Complete the API-stability checklist and acceptance evidence before promising stability
- [ ] Comprehensive public API documentation
- [ ] Benchmarks for large archives (10k+ contacts)
- [ ] Optional external CRM adapters (Printavo, HubSpot, generic webhook/API), separately scoped

See [README](../README.md) and [CHANGELOG](CHANGELOG.md) for current behavior
and historical releases.

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
