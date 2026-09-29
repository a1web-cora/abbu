---
name: testing
description: Apply abbu's RSpec, SimpleCov, RuboCop, Guard, and deterministic Apple Contacts fixture rules when adding, changing, or debugging tests.
---

# Testing

## Required Stack

- Write RSpec 3, not Minitest.
- Run specs through `bin/spec [arguments]` and lint through
  `bin/lint [arguments]`.
- Keep full-suite SimpleCov line coverage at 100%. Focused runs may fail the
  global coverage gate and are not a substitute for the full suite.
- Keep Guard working as the local spec-and-lint feedback loop.
- Test observable contracts and meaningful failure paths, not implementation
  trivia.

## ABBU Fixtures

- Use deterministic synthetic `.abbu` bundles, SQLite databases, binary or XML
  plists, and image bytes.
- Never commit real contacts, contact photos, account identifiers, or other
  personal address-book data.
- Every newly discovered Apple schema, relationship, version, source layout, or
  image convention requires a focused regression fixture and spec.
- Preserve source/version context in fixture documentation when known. Do not
  make a fixture prove more than the observed evidence supports.
- Keep fixture generation reproducible. Update generators and generated
  artifacts together when a committed binary fixture changes.

## Test Shape

- Keep support helpers deterministic and narrowly scoped.
- Prefer assertions through `Abbu.open`, contacts, exporters, or another public
  boundary; test private parsing details only when they are the relevant contract.
- Add regression coverage before fixing a defect when practical.
- Use `.skills/abbu-format/SKILL.md` whenever a test encodes Apple Contacts
  storage semantics.
- Run the entire suite and RuboCop before handoff; report any skipped runtime or
  verification explicitly.

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
