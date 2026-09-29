<!-- AGENTS.md -->

# abbu — Agent Onboarding

## What This Is

Ruby gem (v0.2.0) for reading and processing Apple Contacts `.abbu` archive bundles. Parses SQLite-backed and legacy plist-based contact records, exports to CSV/JSON/vCard, finds duplicates, ships with a CLI and Rake tasks.

## Project Layout

```
abbu.gemspec             # gem manifest
lib/abbu.rb              # Abbu.open(path) entry point
lib/abbu/version.rb      # VERSION constant
lib/abbu/archive.rb      # Bundle discovery, parser dispatch
lib/abbu/contact.rb      # Data model (flat + relational fields, smart full_name)
lib/abbu/parsers/        # SqliteParser, PlistParser → Array<Contact>
lib/abbu/exporters/      # CsvExporter, JsonExporter, VcardExporter
lib/abbu/utils/          # Deduplicator (group-by-first-email)
bin/abbu                 # CLI
tasks/abbu.rake          # Rake tasks (export, dedupe, stats)
spec/                    # RSpec suite (100% coverage target)
spec/fixtures/           # TestContacts.abbu (SQLite), PlistContacts.abbu (legacy)
docs/                    # ABBU.md, CHANGELOG.md, CONTRIBUTING.md, TODO.md
```

## Commands

```bash
mise exec -- bundle install        # install deps
mise exec -- bundle exec rspec     # run tests (100% coverage enforced)
mise exec -- bundle exec rubocop   # lint (rubocop-performance + rubocop-rake + rubocop-rspec)
mise exec -- bundle exec rubocop -A # autocorrect
mise exec -- bundle exec guard     # DX loop: auto-test + auto-lint
gem build abbu.gemspec             # build the .gem
mise exec -- bundle exec rake      # default task: rubocop + spec
```

## Core Domain

- `Abbu.open(path)` returns an `Archive`.
- `Archive#contacts` returns `Array<Contact>`. Dispatch: `**/*.abcddb` → `SqliteParser`; `**/*.abcdp` → `PlistParser`. Recursive glob picks up synced `Sources/<account>/AddressBook-v22.abcddb`.
- `Abbu::Contact` is a data class — no behavior beyond `full_name` (joins prefix / first / middle / "nickname" / last / suffix), `to_s`, `inspect`.
- Multi-value fields are **hash arrays**, not custom classes: `emails: [{address:, label:}]`, `phones: [{number:, label:}]`, `addresses: [{street:, city:, state:, zip:, country:, label:}]`.
- Exporters take `Array<Contact>` and implement `to_file(path)` + `to_stdout`.

## Adding a New Field

1. Add `attr_accessor` to `lib/abbu/contact.rb:6`.
2. Add column→attr entry in `lib/abbu/parsers/sqlite_parser.rb:11` (`RECORD_FIELD_MAP`) **or** new extraction method.
3. Add plist key→attr entry in `lib/abbu/parsers/plist_parser.rb:11` (`FIELD_MAP`) **or** new extraction method.
4. Wire extraction call into `assign_relational_fields` (SQLite) or `assign_multi_value_fields` (plist).
5. Update all three exporters (CSV header, JSON hash, vCard emit).
6. Add fixture data in `spec/fixtures/` and assertion in both parser specs.

## Adding a New Exporter

- Create `lib/abbu/exporters/<name>_exporter.rb` implementing `to_file(path)` and `to_stdout`.
- `require_relative` it in `lib/abbu.rb`.
- Add a CLI branch in `bin/abbu` under the format dispatch.
- Add a Rake task in `tasks/abbu.rake` (optional but consistent).
- Spec at `spec/abbu/exporters/<name>_exporter_spec.rb` — see existing exporters for shape.

## Adding a New Parser

- Create `lib/abbu/parsers/<name>_parser.rb` exposing `#contacts → Array<Contact>`.
- Wire into `lib/abbu/archive.rb#parser`.
- Use a frozen field-map constant for maintainability (see `RECORD_FIELD_MAP`, `FIELD_MAP`).
- Wrap optional-table queries in `rescue SQLite3::SQLException` to tolerate missing tables.

## Conventions

- Every `.rb` file: file-path prolog on line 1, `# frozen_string_literal: true` on line 2.
- No comments unless the user explicitly asks.
- RuboCop clean (target Ruby 3.2; gemspec requires `>= 3.2`).
- SimpleCov minimum coverage is 100% — both `spec_helper.rb` and `.simplecov` set it. New code must ship with full coverage.
- Specs go in `spec/abbu/**/*_spec.rb`; one spec per parser/exporter/utils unit.
- `require` standard libraries (e.g. `pathname`, `csv`, `json`, `sqlite3`, `plist`) inside the file that uses them, not globally in `lib/abbu.rb`. Prevents `NameError` when components are loaded in isolation.
- Use `Pathname` for filesystem paths; the `archive_require_spec` regression guard ensures `lib/abbu/archive.rb` loads with no pre-required stdlib.

## Current Roadmap

See `docs/TODO.md`. In order:

- **0.3.0** — Image extraction from `Images/` (UUID mapping, JPEG/PNG/HEIC, `--extract-images` CLI)
- **0.4.0** — Fuzzy dedup (Levenshtein, phone normalization, thresholds)
- **0.5.0** — Merge engine (`Contact#merge`, `Archive#deduplicate!`)
- **0.6.0** — Query API (`Archive#where(field: value)`)
- **0.7.0** — Write support (round-trip `.abbu` bundles)
- **1.0.0** — Sync adapters (Printavo, HubSpot), stable API

## References

- Format spec: `docs/ABBU.md` (SQLite tables, plist keys, bundle layout)
- Changelog: `docs/CHANGELOG.md` (add an `[Unreleased]` entry on every change)
- Contributing: `docs/CONTRIBUTING.md` (PR conventions, 100% coverage, RuboCop clean)

---

Stan Carver II
Made in Texas 🤠
https://stancarver.com
