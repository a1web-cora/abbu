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
```

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

`abbu` supports Ruby 3.3 and newer. CI exercises Ruby 3.3, 3.4, and 4.0; Ruby 3.3 is the compatibility-floor and designated lint/tooling job.

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
