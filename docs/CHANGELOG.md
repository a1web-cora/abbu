<!-- CHANGELOG.md -->

# Changelog

All notable changes to `abbu` are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added — planned 0.13.0

- Identity-evidence snapshot comparison through `SnapshotDiff` and `--diff`,
  with raw field changes, provenance, explicit ambiguity and stable JSON output.
- Snapshot JSON uses the machine dispatcher and structured error contract;
  conflicting machine operations and calendar metadata fail before input reads.

### Added — planned 0.12.0

- Deterministic iCalendar birthday/anniversary reminders through a Ruby exporter
  and `--format icalendar`. Explicit recurrence year, revision time, and calendar
  namespace avoid fabricated metadata. Unknown years remain unknown; invalid and
  alternate-calendar dates are diagnosed and omitted. Existing exports are unchanged.
- Machine JSON rejects calendar metadata before opening inputs, rather than
  silently ignoring export-only options.

## [0.11.0] - 2026-10-02

### Added — machine JSON

- First-class `--json` for contacts, statistics, schema, sources/groups, duplicate
  groups, identity matches, and image extraction. New `--diagnostics` and
  `--matches` are JSON-only operations. Public `JsonExporter#payload` and
  machine serializers reuse the unchanged contact JSON representation.
- Documented machine stdout, stderr, exit codes, privacy, and SemVer contract.

### Changed — machine JSON

- JSON-mode errors now emit a single `{ "error": { "code", "message" } }`
  document instead of empty stdout or a Ruby exception trace. Invalid inputs
  and conflicting options exit 2; unavailable live inputs and filesystem errors
  exit 1. JSON callers must check exit status before treating stdout as data.
- Bare `--json` lists contacts. JSON combinations are validated before reading
  or writing, rather than silently prioritizing one operation. Human modes and
  successful existing contact/source/group/schema JSON shapes are unchanged.

### Added — fuzzy matching

- Opt-in bounded, explainable fuzzy name suggestions using Unicode-preserving
  Levenshtein distance. Exact identity evidence retains precedence; fuzzy-only
  suggestions remain ambiguous and never merge contacts automatically.

### Added — embedded photos

- Opt-in embedded JPEG/PNG/GIF vCard photos via `photo_mode: :embedded` and
  `--photo-mode embedded`. URI mode remains the default. Missing, unreadable,
  or unsupported image evidence fails before output; HEIC embedding is deferred.

## [0.8.1] - 2026-10-01

### Fixed

- Package verification reuses Bundler-installed dependency paths in CI while
  loading the built ABBU gem from an isolated installation. CI now exercises
  this check before a release tag is created.

## [0.8.0] - 2026-10-01

This release includes the previously unreleased 0.5.0–0.7.0 development milestones.

### Added — vCard fidelity

- vCard fidelity layer with raw-label-preserving grouped repeated properties,
  public exporter RBS, and deterministic SQLite/plist-to-vCard regression tests.

### Changed — vCard fidelity

- vCard output now uses CRLF, escaped TEXT/structured components, UTF-8-safe
  75-octet folding, and URI-specific encoding. Consumers must unfold and decode
  rather than parse ungrouped literal output lines.
- Custom labels use grouped `X-ABLABEL` rather than arbitrary TYPE parameters;
  only standard exact ASCII labels become TYPE. Removed invented anniversary
  preference and unlabeled-address HOME. Existing method signatures remain.
- Invalid text/control bytes and unsafe service tokens/schemes fail before
  output rather than emitting malformed records. Apple-specific support limits
  and migration guidance are explicit; no Contacts import certification claimed.

### Added — groups

- First-class observed groups scoped by file provenance and SQLite record key,
  with source/input enumeration, reverse membership lookup, and chainable
  `Query#in_group` filtering without merging same-name groups.
- Lossless `Contact#group_memberships` evidence alongside unchanged legacy group
  labels and contact exports; immutable group snapshots and public RBS.
- JSON-only `--groups` listing for archives and read-only live stores, preserving
  raw names, nulls, diagnostics, and explicit unsupported empty/plist-group boundaries.

### Added — sources

- Read-only source containers through `Archive#sources` and `LiveStore#sources`,
  preserving raw file provenance, unknown providers, queryable contacts, and
  observed group membership labels without conflating source-local identifiers.
- JSON-only `--sources` listing for archive/live inputs, including empty sources;
  public RBS, immutable metadata and deterministic source/file ordering.

### Added — timestamp queries

- Chainable created/modified-since and half-open timestamp range queries with
  timezone-explicit ISO 8601 bounds, missing-timestamp exclusion, and Query RBS.
- Archive CLI timestamp filters with existing TSV/JSON results and exit contracts.

## [0.4.0] - 2026-09-30

### Fixed

- Live CLI input uses distinct `--live` auto-discovery and `--live-path PATH` forms;
  mixed modes and unexpected live positional arguments are rejected.

- Deduplication recognizes international phone prefixes from trimmed raw input, not
  punctuation-stripped digits, keeping national-looking `(001)` values source-local.

- Image extraction exclusively creates destination files and reports `destination_exists`
  rather than overwriting existing files, symlinks, or hard links. Output directory aliases
  are resolved before extraction; extraction diagnostic privacy is documented.

### Added

- Explicit, read-only live Contacts access through `Abbu.open_live` and
  `abbu --live` / `abbu --live-path PATH`, with root and `Sources/*` database discovery
- Actionable live-store errors for missing databases, unsupported automatic
  discovery, and macOS Full Disk Access restrictions
- Platform-independent synthetic coverage for live-store discovery, source
  provenance, SQLite read-only enforcement, and CLI behavior
- Provenance-aware `Utils::Deduplicator#matches` suggestions with normalized email,
  international/source-local phone, Unicode name, and organization evidence
- Match confidence, ambiguity status, original source records, and raw evidence, plus an
  explicit callable merge-policy boundary that never silently collapses contacts

- `Archive#extract_images` and `Abbu::ImageExtractor` for copying contact photos to a
  caller-selected directory with structured missing, unreadable, and unsupported-image
  diagnostics
- `--extract-images DIR` CLI support with content-aware JPEG, PNG, GIF, and HEIC extension
  selection and safe, Unicode-preserving, collision-resistant filenames
- Source-local resolution for duplicate image stems in nested account directories without
  guessing when provenance cannot disambiguate candidates

- Structured tolerant-parsing diagnostics with strict API/CLI mode for corrupt
  plist records, missing optional SQLite data, and unresolved image references
- Missing optional SQLite tables emit one non-PII diagnostic per database and
  table instead of repeating schema-level warnings for every contact
- Evidence-safe SQLite schema diagnostics through `Archive#schema_report` and
  `abbu <archive> --schema`, including unknown tables/columns, absent recognized
  schema elements, and owner/contact-style relationship candidates
- Deterministic schema-variation coverage for missing optional tables, unknown
  contact-linked tables, and column drift
- Normalized Apple standard labels with the original source value preserved as
  `raw_label` on labeled contact values
- Chainable `Abbu::Query` and `Archive#where` APIs for contact filtering
- Exact normalized email and phone lookup that returns all matches across sources
- Case-insensitive partial name and email search through Ruby and tab-separated CLI output
- Stable `--json` search output using the regular contact JSON schema
- Contact creation and modification timestamps from optional SQLite `ZCREATIONDATE` and `ZMODIFICATIONDATE` columns
- Provenance metadata identifying each contact's source database or plist and its location within the ABBU bundle
- Creation, modification, and source metadata in JSON exports
- Repository constitution and focused local skills for ABBU format evidence,
  Ruby gem development, testing, and Sheriff-gated releases
- Canonical `bin/spec` and `bin/package` workflows, with CI reusing project-local
  `bin/spec` and `bin/lint` instead of duplicating their commands

### Changed

- CI now runs the Ruby matrix once for pull requests and on pushes to canonical `main`, avoiding duplicate feature-branch push and pull-request runs
- SQLite parsing now tolerates absent established email, phone, and postal-address
  tables and returns empty collections while retaining the variation in schema diagnostics;
  unexpected column drift and other SQL errors on present tables continue to surface
- vCard anniversary export now prefers the original `raw_label` so Apple and
  custom source representations survive parse-and-export round trips
- Minimum supported Ruby and RuboCop target are now 3.3; CI covers Ruby 3.3,
  3.4, and 4.0, with Ruby 3.3 as the designated lint/tooling job
- Agent guidance is consolidated in `AGENTS.md`; the redundant `CLAUDE.md` has
  been removed
- Gem packaging now includes only the public `bin/abbu` executable instead of
  repository-only developer commands

## [0.3.0] - 2026-09-29

### Added

- `Contact#image_uri` and `Contact#image_path` accessors
- `Parsers::SqliteParser` extracts `ZIMAGEURI` from `ZABCDRECORD`
- `Utils::ImageResolver` builds an index of every image file under the bundle's `**/Images/` directories (jpg, jpeg, png, heic — case-insensitive) and resolves a contact's `image_uri` to a `Pathname` within the bundle
- `Archive#contacts` automatically resolves `image_path` for any contact that has a non-nil `image_uri`
- CSV export: new `ImagePath` column (last column)
- JSON export: `image_uri` and `image_path` fields (omitted via `.compact` when blank)
- vCard export: `PHOTO;VALUE=URI:file://<absolute path>` line, emitted when `image_path` is present
- `spec/fixtures/TestContacts.abbu/Images/stan-photo.jpg` stub image, regenerated by `spec/support/fixture_generator.rb`

### Notes

- PlistParser does not extract images — legacy `.abcdp` contacts typically embed image data inline, which is a separate extraction path
- vCard `PHOTO` references the absolute bundle path; base64 embedding and the `--extract-images` CLI flag are tracked for follow-up

### Fixed

- vCard `PHOTO` file URIs now percent-encode spaces, reserved characters, and non-ASCII bytes in image paths
- `abbu:export` Rake task wrote hash literals (e.g. `{:address=>"…", :label=>"…"}`) into the `Email` and `Phone` CSV columns. Now correctly extracts the first address and number from each contact's multi-value field.

## [0.2.0] - 2026-05-03

### Added

- `Parsers::PlistParser` — full implementation of legacy `.abcdp` plist contact parsing, replacing the previous stub
- `PlistParser::FIELD_MAP` constant for flat-field mapping
- Multi-value field extraction for emails, phones, addresses, URLs, notes, related names, and social profiles
- `Archive` recursively scans `**/*.abcdp` across the entire bundle tree
- `plist` gem (~> 3.7) runtime dependency
- Plist fixture files (`spec/fixtures/PlistContacts.abbu/`) for integration testing
- `middle_name` attribute on `Contact`; `ZMIDDLENAME` / `Middle` plist key
- `dates` attribute on `Contact` (array of `{ year:, month:, day:, label: }` hashes)
- `birthday`, `anniversary`, and `lunar_birthday` accessor methods derived from the dates list
- `instant_messages` attribute (AIM, Jabber, Skype, etc.); `ZABCDMESSAGINGADDRESS` / `InstantMessage` key
- `verification_code` attribute on `Contact`; `ZVERIFICATIONCODE` column / `VerificationCode` plist key
- `phonetic_middle_name` attribute; `ZPHONETICMIDDLENAME` column / `PhoneticMiddle` plist key
- `ZABCDDATECOMPONENTS` parsing (year/month/day split columns)
- `BDAY`, `X-LUNAR-BDAY`, `X-ABDATE`, `X-ABLABEL` vCard fields
- `IMPP` vCard field for instant messaging
- Birthday, anniversary, lunar birthday, instant messages, and verification code in CSV and JSON exports
- Plist fixture for testing all the above (`spec/fixtures/PlistContacts.abbu/`)

### Changed

- `Contact#full_name` now includes middle name (`Honorable Stan The Man "Stretch" Carver II`)
- vCard `N` field includes middle name component
- `SqliteParser::RECORD_FIELD_MAP` extended with the new column → attr mappings
- `JsonExporter#contact_hash` includes all new fields; blank fields are dropped via `.compact`
- `CsvExporter` extended-field section now exports lunar birthday and verification code

## [0.1.2] - 2026-04-26

### Added

- Full Apple Contacts schema support: job title, department, maiden name, phonetic names, pronouns, ringtone, texttone
- Relational table parsing: URLs, notes, related names (family/business), social profiles (Twitter, etc.)
- Nickname, prefix, and suffix fields with smart `full_name` formatting
- Hash-based email/phone data preserving custom labels (e.g. "Direct Line", "Work")
- Address, group, URL, notes, related names, and social profiles in CSV export
- Comprehensive JSON export with all contact fields
- vCard 3.0 export with ADR, URL, NICKNAME, TITLE, NOTE, X-SOCIALPROFILE
- `rubocop-rspec` plugin integration
- 100% line coverage across all 44 specs

### Changed

- Refactored `SqliteParser` to use `RECORD_FIELD_MAP` constant for maintainability
- Refactored `CsvExporter` into `core_fields`/`extended_fields` for cleaner ABC metrics
- All specs comply with rubocop-rspec conventions

## [0.1.1] - 2026-04-23

### Fixed

- `require 'pathname'` missing in `archive.rb` causing `NameError` in isolation
- Added regression guard spec for file require isolation


## [0.1.0] - 2026-04-12

### Added

- `Abbu.open(path)` entry point returning an `Archive`
- `Archive#contacts` — reads contacts from SQLite or falls back to plist stub
- `Archive#sqlite?` — detects modern `.abcddb` bundles
- `Contact` object with `first_name`, `last_name`, `emails`, `phones`, `company`, `full_name`
- `Parsers::SqliteParser` — queries `ZABCDRECORD`, `ZABCDEMAILADDRESS`, `ZABCDPHONENUMBER`
- `Parsers::PlistParser` — stub with warning (legacy `.abcdp` support in v0.2)
- `Exporters::CsvExporter` — `to_file` and `to_stdout`
- `Exporters::JsonExporter` — `to_file` and `to_stdout`
- `Exporters::VcardExporter` — `to_file` and `to_stdout` (vCard 3.0)
- `Utils::Deduplicator` — groups contacts by first email, returns duplicates hash
- `bin/abbu` CLI with `--format`, `--output`, `--stats`, `--dedupe`, `--version`
- Rake tasks: `abbu:export`, `abbu:dedupe`, `abbu:stats`
- Example scripts: CSV, JSON, vCard, API, CRM sync, stats, dedupe
- `docs/ABBU.md` — file format reference
- RSpec test suite with 100% coverage target
- Guard + RuboCop DX loop
- GitHub Actions CI (Ruby 3.2 + 3.3)

---
Stan Carver II
Made in Texas 🤠
https://stancarver.com
