<!-- AGENTS.md -->

# Agent Execution Contract

This is the repository constitution for automated contributors working on
`abbu`. It supplements machine-wide policy and applies to the entire repository.

## Read Before Changing Behavior

Read this file, the applicable skill under `.skills/`, `README.md`,
`docs/CONTRIBUTING.md`, and the relevant implementation before changing public
behavior. For archive semantics, also read `docs/ABBU.md` and inspect the
evidence that supports the behavior.

## Apple Contacts Evidence Boundary

Never infer Apple Contacts storage semantics merely from Core Data table or
column names. Require observed fixture evidence, Apple documentation where
available, or reproducible verification, and record consequential discoveries
in `docs/ABBU.md`.

- Treat table names, column names, entity numbers, relationships, UUID shapes,
  directory names, and file extensions as observations until verified.
- Preserve macOS and Contacts-version variance. Do not turn one fixture's shape
  into an unconditional format guarantee.
- Keep synthetic fixtures deterministic and identify the evidence represented by
  each schema variation.
- Treat contact archives and real address-book exports as sensitive. Do not
  commit personal contacts, photos, account identifiers, or unsanitized bundles.

## Product And Architecture

- Support Ruby 3.2 and newer through `.mise.toml`, the gemspec, and CI.
- Keep the gem framework-independent and free of Rails-only runtime code.
- Preserve `Abbu.open(path)` as the archive entry point, `Abbu::Contact` as the
  normalized contact model, and explicit parser/exporter boundaries.
- Keep SQLite and plist parsing distinct when their evidence differs. Share only
  normalized behavior whose semantics are demonstrated across both formats.
- Keep runtime dependencies minimal and justify additions with a concrete public
  requirement.
- Treat documented contact fields, normalized hashes, exporter output, CLI
  behavior, and error behavior as public API governed by SemVer.

## Canonical Workflows

Project-local commands are authoritative:

- `bin/spec [arguments]` runs RSpec;
- `bin/lint [arguments]` runs RuboCop;
- `bin/package` builds and verifies the gem package; and
- `bin/dev` runs the Guard development loop.

CI must call these commands instead of recreating their implementation. Add a
new canonical workflow under `bin/` before teaching CI a separate sequence.

## Tests And Fixtures

- Use RSpec 3 and keep full-suite SimpleCov line coverage at 100%.
- Add regression coverage for every discovered Apple schema or bundle-layout
  variation before changing parser assumptions when practical.
- Keep SQLite databases, plists, image files, and generated bundle layouts
  deterministic and synthetic.
- Keep RuboCop clean and Guard usable for the local feedback loop.
- Focused specs may fail the repository-wide coverage gate; the full suite is
  the authoritative coverage signal.

## Source, Documentation, And Compatibility

- Start source files with their repository-relative path prolog. Ruby files put
  `# frozen_string_literal: true` on line 2.
- Keep requires alphabetized within logical groups unless documented load order
  is necessary.
- Update `docs/CHANGELOG.md` and relevant public documentation for public or
  compatibility changes.
- Preserve the MIT license, ownership, backlinks, and documentation footer.

## Git And Release Authority

- `main` is the canonical branch. Work on purpose-named branches and use pull
  requests.
- Never bypass hooks, CI, review, or branch protection.
- Green checks, `bin/package`, and any future release dry run are evidence, not
  authorization to publish.
- Never create or push a release tag, publish or yank a gem, approve a protected
  release environment, or otherwise authorize publication without explicit
  Sheriff approval for that specific release.

## Repository Skills

- `.skills/abbu-format/SKILL.md` for bundle and storage evidence.
- `.skills/ruby-gem-development/SKILL.md` for implementation and compatibility.
- `.skills/testing/SKILL.md` for specs, coverage, and fixtures.
- `.skills/releasing/SKILL.md` for package verification and Sheriff-gated
  publication.

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
