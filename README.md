<!-- README.md -->

# abbu

Read-only Apple Contacts toolkit for `.abbu` archives and opt-in live macOS stores.
Version 0.4.0 adds querying, diagnostics, identity evidence, and safe image extraction
alongside CSV, JSON, and vCard export. The public API remains pre-1.0.

## Features

- Parse ABBU (Apple Contacts export) bundles
- Opt-in, read-only access to a local macOS Contacts store
- SQLite-backed contact extraction (modern macOS)
- Legacy plist `.abcdp` parsing (older macOS)
- Evidence-backed Apple Contacts fields: names, nicknames, prefix/suffix, job title, department, phonetics, pronouns, and more
- Rich relational data: addresses, URLs, notes, related names, social profiles
- Export to CSV, JSON, vCard 3.0
- CLI + Ruby API
- Source provenance and creation/modification timestamps
- Lossless raw labels alongside human-friendly normalization
- Schema introspection, tolerant diagnostics, and strict mode
- Chainable archive queries, exact identifier lookup, and TSV/JSON CLI search
- Provenance-aware duplicate suggestions without automatic merging
- Safe photo extraction with content detection and no destination overwrites

## Installation

```bash
gem install abbu
```

Or add to your `Gemfile`:

```ruby
gem "abbu"
```

## Usage

### Ruby API

```ruby
require "abbu"

archive = Abbu.open("Contacts.abbu")
contacts = archive.contacts
schema = archive.schema_report # Evidence-only SQLite schema diagnostics

contacts.first.full_name   # => "Honorable Stan \"Stretch\" Carver II"
contacts.first.emails      # => [{ address: "stan@example.com", label: "Work", raw_label: "_$!<Work>!$_" }]
contacts.first.phones      # => [{ number: "555-1234", label: "Mobile", raw_label: "Mobile" }]
contacts.first.job_title   # => "Engineer"

# Copy resolved photos using safe, content-derived filenames.
result = archive.extract_images("exported-photos")
result.files        # copied-file metadata, including source_path and media_type
result.diagnostics  # image errors or destination_exists; may contain contact identifiers

# Recover safe records and inspect non-fatal data loss.
archive.diagnostics.each { |diagnostic| warn diagnostic.to_h }

# Or fail on the first corrupt/unsupported optional input.
strict_contacts = Abbu.open("Contacts.abbu", strict: true).contacts
```

Live-store access is a separate, explicit API and never changes `Abbu.open` archive
validation:

```ruby
# Auto-discover the current macOS user's AddressBook directory
live_contacts = Abbu.open_live.contacts

# Or supply a directory for automation and platform-independent testing
live_contacts = Abbu.open_live("/path/to/AddressBook").contacts
```

Live databases are opened with SQLite's read-only mode. The process may require
Full Disk Access under **System Settings → Privacy & Security → Full Disk Access**.
Live inputs expose parser `diagnostics` and accept `strict: true` (CLI `--strict`).
The live CLI supports stats, deduplication, and exports; archive-only search, schema,
and image-extraction options are rejected explicitly.

Live access does not write Contacts databases. WAL/concurrent-writer consistency
remains unverified ([#28](https://github.com/scarver2/abbu/issues/28)).

Labeled values expose a normalized `label` for display and retain the source
value in `raw_label`. For example, `_$!<Mobile>!$_` becomes `Mobile` while the
original wrapper remains available in `raw_label`.

### Search and identifier lookup

```ruby
# Exact lookup normalizes email case/whitespace and phone punctuation.
archive.find_by_email("STAN@EXAMPLE.COM").each { |contact| puts contact.full_name }
archive.find_by_phone("(555) 123-4567").each { |contact| puts contact.full_name }

# Name and email search is case-insensitive and can be chained with `where`.
archive.where(company: "Acme Corp").search("stan").each do |contact|
  puts [contact.full_name, contact.source[:relative_path]].join("\t")
end
```

Lookup methods return every match as an `Abbu::Query`; they never silently pick
one contact when the same identifier appears in multiple sources. Returned
contacts retain their parser-provided source provenance.

### Export

```ruby
# CSV
Abbu::Exporters::CsvExporter.new(archive.contacts).to_file("contacts.csv")

# JSON
Abbu::Exporters::JsonExporter.new(archive.contacts).to_file("contacts.json")

# vCard
Abbu::Exporters::VcardExporter.new(archive.contacts).to_file("contacts.vcf")
```

### Duplicate Detection

```ruby
dupes = Abbu::Utils::Deduplicator.new(archive.contacts).duplicates
dupes.each do |email, contacts|
  puts "Duplicate: #{email}"
  contacts.each { |c| puts "  - #{c.full_name}" }
end
```

For provenance-aware suggestions, use `#matches`. Results preserve both contacts,
their source records, raw and normalized evidence, confidence, and ambiguity:

```ruby
matches = Abbu::Utils::Deduplicator.new(archive.contacts).matches
matches.each do |match|
  puts "#{match.confidence}: #{match.left.full_name} / #{match.right.full_name}"
  pp match.sources
  pp match.evidence
end

# Matching never mutates or collapses contacts. Merging requires a caller policy:
merged = matches.first.merge(policy: ->(left, right, evidence:) {
  MyContactMerge.call(left, right, evidence: evidence)
})
```

## CLI

```bash
# Export to CSV
abbu Contacts.abbu -f csv -o contacts.csv

# JSON to stdout (pipeable)
abbu Contacts.abbu -f json | jq .

# vCard export
abbu Contacts.abbu -f vcard -o contacts.vcf

# Copy contact photos to a selected directory
abbu Contacts.abbu --extract-images exported-photos

# Stats
abbu Contacts.abbu --stats

# Find duplicates
abbu Contacts.abbu --dedupe

# Read the current macOS user's live Contacts store
abbu --live --stats

# Read a caller-supplied AddressBook directory
abbu --live-path /path/to/AddressBook -f json

# Fail on the first corrupt or unsupported optional record/table.
abbu Contacts.abbu --stats --strict

# Inspect each SQLite schema without inferring undocumented semantics
abbu Contacts.abbu --schema

# Tab-separated search output: name, emails, phones, source-relative path
abbu Contacts.abbu --search stan
abbu Contacts.abbu --email stan@example.com
abbu Contacts.abbu --phone '(555) 123-4567'

# Stable structured search output using the regular contact JSON schema
abbu Contacts.abbu --search stan --json | jq .
```

CLI search defaults to tab-separated output and exits successfully when at least
one contact matches. A search with no matches exits with status 1; TSV mode emits
no output, while `--json` emits a valid empty array. This makes both modes
suitable for shell conditionals, pipelines, and agent integrations.

## Rake Tasks

```ruby
# In your Rakefile:
load "tasks/abbu.rake"
```

```bash
rake abbu:export[Contacts.abbu]
rake abbu:dedupe[Contacts.abbu]
rake abbu:stats[Contacts.abbu]
```

## ABBU File Format

See [`docs/ABBU.md`](docs/ABBU.md) for a full explanation of the archive structure,
SQLite table schema, and format history.

## Roadmap

See [`docs/TODO.md`](docs/TODO.md) for the full release schedule and feature checklist.

## Ruby Compatibility

`abbu` supports Ruby 3.3 and newer. CI exercises Ruby 3.3, 3.4, and 4.0;
Ruby 3.3 is the compatibility floor and designated lint/tooling job.

## Development

```bash
mise exec -- bundle install
bin/dev      # Guard feedback loop
bin/spec     # RSpec with the 100% coverage gate
bin/lint     # RuboCop
bin/package  # build and verify the gem in isolation
```

## Contributing

See [CONTRIBUTING.md](docs/CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).

---
Stan Carver II
Made in Texas 🤠
https://stancarver.com
