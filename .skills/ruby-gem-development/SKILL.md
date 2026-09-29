---
name: ruby-gem-development
description: Apply abbu's Ruby gem conventions when changing library code, public APIs, parsers, exporters, the CLI, dependencies, packaging, or developer workflows.
---

# Ruby Gem Development

## Development Contract

- Support Ruby 3.3 and newer through `mise`; `.mise.toml`, the gemspec, and CI
  define the supported contract.
- Use `bin/spec`, `bin/lint`, and `bin/package` as the canonical checks.
- Preserve the `Abbu` namespace, `abbu` gem identity, and `bin/abbu` executable.
- Keep the library independent of Rails and other application frameworks.
- Prefer small objects, explicit dependencies, and instance-owned state. Do not
  introduce global mutable configuration.

## Public Compatibility

- Treat `Abbu.open`, contact fields and normalized collections, parser results,
  exporter output, CLI behavior, and documented errors as public API.
- Preserve compatibility unless a reviewed SemVer change explicitly authorizes
  a break.
- Keep runtime dependencies minimal. Document the concrete need for each new
  dependency and prefer the Ruby standard library when it fits.
- Update `docs/CHANGELOG.md`, examples, and relevant docs with public behavior or
  compatibility changes.

## Component Boundaries

- Parsers translate evidence-backed SQLite or plist structures into contacts.
- Exporters consume contacts and own format serialization, not archive parsing.
- The CLI coordinates public APIs and remains thin; reusable behavior belongs in
  library objects.
- Use `.skills/abbu-format/SKILL.md` whenever a change encodes Apple Contacts
  storage semantics.

## Source And Verification

- Start source files with their repository-relative path prolog and put
  `# frozen_string_literal: true` on line 2 of Ruby files.
- Keep requires alphabetized within logical groups unless load order requires an
  adjacent explanation.
- Add RSpec coverage for behavior changes and keep RuboCop clean.
- Run `bin/package` for gemspec, packaged-file, executable, dependency, version,
  or other release-facing changes.

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
