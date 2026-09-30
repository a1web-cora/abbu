<!-- README.md -->

# abbu

Read and process Apple Contacts `.abbu` archives in Ruby.

## Features

- Parse ABBU (Apple Contacts export) bundles
- SQLite-backed contact extraction (modern macOS)
- Legacy plist `.abcdp` parsing (older macOS)
- Full Apple Contacts schema: names, nicknames, prefix/suffix, job title, department, phonetics, pronouns, and more
- Rich relational data: addresses, URLs, notes, related names, social profiles
- Export to CSV, JSON, vCard 3.0
- CLI + Ruby API
- Duplicate detection

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

contacts.first.full_name   # => "Honorable Stan \"Stretch\" Carver II"
contacts.first.emails      # => [{ address: "stan@example.com", label: "Work" }]
contacts.first.phones      # => [{ number: "555-1234", label: "Mobile" }]
contacts.first.job_title   # => "Engineer"
```

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

## CLI

```bash
# Export to CSV
abbu Contacts.abbu -f csv -o contacts.csv

# JSON to stdout (pipeable)
abbu Contacts.abbu -f json | jq .

# vCard export
abbu Contacts.abbu -f vcard -o contacts.vcf

# Stats
abbu Contacts.abbu --stats

# Find duplicates
abbu Contacts.abbu --dedupe

# Tab-separated search output: name, emails, phones, source-relative path
abbu Contacts.abbu --search stan
abbu Contacts.abbu --email stan@example.com
abbu Contacts.abbu --phone '(555) 123-4567'
```

CLI search exits successfully when at least one contact matches and exits with
status 1 without output when no contact matches, making it suitable for shell
conditionals and pipelines.

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
