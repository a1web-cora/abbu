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

## v0.2.0 — Plist Parser (In Progress)

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

## v0.3.0 — Image Extraction (In Progress)

- [x] Extract contact photos from `Images/` directory
- [x] Map image UUIDs to contacts via `ZIMAGEURI` (SqliteParser)
- [x] `Contact#image_uri` and `Contact#image_path` accessors
- [x] Support JPEG, PNG, HEIC formats (case-insensitive)
- [x] Image resolution across nested `Sources/<account>/Images/` directories
- [x] CSV / JSON / vCard export of image paths
- [ ] CLI: `--extract-images` flag to export photos alongside contacts
- [ ] Thumbnail vs. full-size image handling
- [ ] vCard PHOTO base64 embedding (currently references absolute path)

---

## v0.4.0 — Fuzzy Deduplication

- [ ] Levenshtein distance matching for name-based deduplication
- [ ] Phone number normalization (strip formatting, compare digits)
- [ ] Configurable similarity thresholds
- [ ] `Deduplicator#fuzzy_duplicates` method
- [ ] CLI: `--dedupe --fuzzy` flag
- [ ] Merge suggestions output (side-by-side diff)

---

## v0.5.0 — Merge Engine

- [ ] `Contact#merge(other)` — combine two contacts preserving all data
- [ ] Conflict resolution strategies (keep-first, keep-last, keep-both)
- [ ] `Archive#deduplicate!` — in-place merge with backup
- [ ] CLI: `--merge` interactive mode
- [ ] Export merged results to new `.abbu` bundle

---

## v0.6.0 — Filtering & Querying

- [ ] `Archive#where(field: value)` query API
- [ ] Filter by region (state, city, country)
- [ ] Filter by group membership
- [ ] Filter by date range (created, modified)
- [ ] CLI: `--filter` flag with key=value syntax
- [ ] Chainable query interface

---

## v0.7.0 — Write Support

- [ ] Create new `.abbu` bundles from Contact objects
- [ ] Write SQLite databases with correct schema
- [ ] Write `.abcdp` plist files
- [ ] Round-trip: read → modify → write
- [ ] `Archive#save(path)` method

---

## v1.0.0 — Sync Adapters & Stable API

- [ ] Adapter interface for external CRM sync
- [ ] Printavo adapter
- [ ] HubSpot adapter
- [ ] Generic webhook/API adapter
- [ ] Stable public API guarantee
- [ ] Comprehensive API documentation (YARD)
- [ ] Performance benchmarks for large archives (10k+ contacts)

---

Stan Carver II
Made in Texas 🤠
https://stancarver.com
