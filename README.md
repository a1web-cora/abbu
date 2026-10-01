<!-- README.md -->

# abbu

Read-only Apple Contacts toolkit for `.abbu` archives and opt-in live macOS stores.
Development version 0.8.0 strengthens vCard serialization alongside source-scoped groups, timestamp
queries, diagnostics, identity evidence, image extraction, and CSV/JSON/vCard export.
The public API remains pre-1.0.

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
The live CLI supports source/group listing, stats, deduplication, and exports; archive-only search, schema,
and image-extraction options are rejected explicitly.

Live access does not write Contacts databases. Synthetic WAL tests verify committed
data visibility and read-only access, but a read is **not an atomic snapshot**:
separate contact/relationship queries can observe different commits, and databases
are read independently. A LiveStore caches its first contact result; reopen it to
refresh. See [live-store consistency evidence](docs/ABBU.md#wal-and-concurrent-writer-evidence).

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

### Timestamp queries

```ruby
archive.query.modified_since('2026-09-01T00:00:00Z').search('stan')
archive.query.date_range(:created_at, since: '2026-09-01T00:00:00Z',
                         before: '2026-10-01T00:00:00Z')
# Also works with explicitly opened live data:
Abbu::Query.new(Abbu.open_live.contacts).created_since(Time.utc(2026, 9, 1))
```

Bounds accept `Time` or full ISO 8601 strings with seconds and an explicit `Z`
or numeric offset. Start (`since`) is inclusive; end (`before`) is exclusive.
At least one bound is required, and start must precede end. Invalid bounds raise
`ArgumentError`, including on empty queries. Missing timestamps never match.
Filters preserve source records and compose with other Query criteria. These are
observed storage timestamps, not proof of human edits or a complete change feed;
deletions and changes without timestamps cannot be discovered this way.

```bash
abbu Contacts.abbu --modified-since 2026-09-01T00:00:00Z --json
abbu Contacts.abbu --created-since 2026-09-01T00:00:00Z --created-before 2026-10-01T00:00:00Z --search stan --json
```

All four `--created-since`, `--created-before`, `--modified-since`, and
`--modified-before` filters can be combined (AND). They use existing search
TSV/JSON output: status 0 for matches, 1 for no matches, and 2 for invalid bounds
or incompatible output options. Diagnostics stay on stderr. CLI timestamp queries
are archive-only, like existing search; use the Ruby Query API for live inputs.
Do not combine timestamp queries with export, stats, schema, dedupe, or extraction.

### Sources

```ruby
sources = archive.sources # Frozen Array<Abbu::Source>, sorted by relative_path
source = sources.first
source.relative_path # "." for root, or "Sources/<observed identifier>"
source.identifier    # Raw directory identifier, or nil for root
source.provider      # nil: never inferred from paths or identifier spelling
source.files         # Frozen file-level provenance descriptors
source.contacts.search('stan') # Query over original contacts, no automatic deduplication
source.group_names   # Sorted unique observed membership labels, not group identities
source.to_h          # Metadata, files, contact_count, group_names; no contact payload

Abbu.open_live('/path/to/AddressBook').sources # Same API, read-only connections
```

Sources are observed input containers, not verified Apple account identities.
Existing `contact.source` hashes are unchanged. Membership is based on the exact
file provenance path; repeated contact IDs and filenames in different sources
never merge. Files from the same observed source directory form one container.
An empty discovered database still appears; an empty archive returns `[]`.
Plist records outside `Sources/` form the root container. Archives retain their
existing SQLite-first parser selection: ignored plist files are not listed.

Source metadata, file descriptors, membership arrays, and group-name strings are
frozen snapshots. Contacts remain the original mutable objects. `sources` eagerly
parses contacts, honors diagnostics/strict mode, and is cached; reopen the input to
refresh. It does not add live-store atomic snapshot guarantees. Group names cover
observed contact memberships only, not empty groups or same-name group identity.

```bash
abbu Contacts.abbu --sources
abbu --live-path /path/to/AddressBook --sources --json
```

`--sources` always emits a JSON array to stdout; `--json` is optional. Each object
has `path`, `relative_path`, `kind`, `identifier`, `provider`, `files`,
`contact_count`, and `group_names`; unknown `provider` and root `identifier` are
explicit JSON nulls. `files` uses the existing four-key contact provenance schema.
Source/file ordering is by relative path; contact order is parser order within
those sorted files. Listings exit 0 even when empty. Conflicting operations or
strict parse failures exit 2, live input/access failures exit 1, and diagnostics
stay on stderr. Only `--strict` and `--json` may accompany this operation besides
input selection. Paths, raw identifiers, and group names may be sensitive;
do not publish source listings as sanitized logs.

### Groups

```ruby
group = archive.groups.first # Frozen Array<Abbu::Group>
group.record_id              # Observed SQLite group key, local to group.source[:path]
group.name                   # Original name, including whitespace/Unicode; may be nil
group.source                 # Frozen file-level provenance, including source identifier
group.contacts.search('stan') # Query over the original mutable contacts
archive.groups_for(archive.contacts.first) # Reverse lookup, without changing Contact#groups
archive.sources.first.groups # Same objects, scoped to that source
archive.query.where(company: 'Acme Corp').in_group(group)
Abbu.open_live('/path/to/AddressBook').groups # Same API, read-only
```

Groups are identified by database path plus observed record key, never by name.
Same-name groups within a file and repeated keys across files/sources remain
distinct. `Contact#groups` remains the original array of labels (including duplicate
or null names); `Contact#group_memberships` additionally retains `{ record_id:, name: }`
for each observed join row, including duplicates. Group contacts list each original
contact once. Existing contact JSON/CSV/vCard output is unchanged.

Only groups reached by supported contact membership joins are listed. Empty or
unreferenced groups, dangling joins, and legacy plist group relationships are not
enumerated; no semantics are inferred for them. Missing optional membership tables
retain tolerant diagnostics and strict-mode errors. Ordering is source relative
path, file relative path, then numeric record key; contacts retain parser order.

Metadata and membership snapshots are frozen when sources/groups are first built;
contacts themselves remain mutable. Later edits to contact labels/evidence do not
rewrite these snapshots. `groups_for` and `Query#in_group` use original contact
object identity: a contact freshly parsed by another input instance does not
belong to this snapshot, even for the same path. Reopen to refresh; live reads
retain the consistency limitations described above.

```bash
abbu Contacts.abbu --groups
abbu --live-path /path/to/AddressBook --groups --json
```

`--groups` emits a JSON array of `record_id` (integer), `name` (string or null),
`source` (the four-key file provenance hash), and `contact_count` (integer).
`Group#to_h` uses the same schema. Names are never normalized. Empty results exit 0;
strict failures and conflicting operations exit 2; live access failures exit 1.
Only input selection, `--strict`, and optional `--json` may accompany this mode;
`--sources` and `--groups` cannot be combined. Diagnostics stay on stderr.
Group names, IDs and source paths may be sensitive; this is not sanitized logging.

### Export

```ruby
# CSV
Abbu::Exporters::CsvExporter.new(archive.contacts).to_file("contacts.csv")

# JSON
Abbu::Exporters::JsonExporter.new(archive.contacts).to_file("contacts.json")

# vCard
Abbu::Exporters::VcardExporter.new(archive.contacts).to_file("contacts.vcf")
```

vCard output uses UTF-8, CRLF endings (including the final line), escaped TEXT
values, and folding at no more than 75 bytes without splitting UTF-8 characters.
Repeated fields retain order. `N` and `ADR` escape each component independently.
Text newline variants become vCard `\\n`; URL/IM URI values use percent encoding
instead of TEXT escaping. Empty contact input emits no bytes.

Labeled emails, phones, addresses, URLs, IM handles, and anniversaries pair with
`itemN.X-ABLABEL` using the same per-card `itemN` group. The original `raw_label`
wins over the display `label`, including empty strings. Custom labels no longer
become arbitrary `TYPE` parameters. Only exact ASCII standard type names are
recognized, case-insensitively; email/phone defaults are `INTERNET`/`VOICE`.
For example, `Mobile` is preserved as a label, not guessed to mean `CELL`.
No preference is invented for anniversaries. Existing photo file URIs remain;
embedded photos are separate work.

Migration from 0.7: consumers must unfold CRLF continuations before parsing,
decode TEXT escapes, and accept grouped property names rather than matching
literal lines such as `EMAIL;TYPE=Work`. The exporter signatures are unchanged.
Unsupported controls, invalid UTF-8, unsafe social-service parameter tokens,
or invalid IM service schemes fail explicitly before writing output; export
does not sanitize or mutate Contact evidence. Other encoding conversions may
raise Ruby encoding errors. Existing files are overwritten on a successful
`to_file`, as before; this is not an atomic/no-clobber writer.

See [vCard evidence and compatibility limits](docs/ABBU.md#vcard-serialization-evidence)
for the standards basis and Apple-specific audit. Synthetic round-trip tests
are not proof of import fidelity in every Apple Contacts release.

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

The [compatibility regression matrix](docs/FORMAT_COMPATIBILITY.md) protects
legacy XML and varied SQLite layouts in every CI run, and distinguishes tested
synthetic shapes from unverified macOS/Contacts releases.

## Roadmap

ABBU remains read-only for source archives and live stores. The
[writer research decision](docs/WRITER_DECISION.md) explains why generating
Apple-private bundles is not supported and what evidence could change that.

See [`docs/TODO.md`](docs/TODO.md) for the full release schedule and feature checklist.
The [pre-1.0 API stability gate](docs/API_STABILITY.md) inventories supported
surfaces, evidence gaps, compatibility policy, and required release-readiness checks.

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
