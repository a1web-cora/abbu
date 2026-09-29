---
name: abbu-format
description: Apply abbu's evidence rules when changing Apple Contacts bundle discovery, SQLite or plist parsing, schema mappings, source handling, images, fixtures, or format documentation.
---

# ABBU Format

Read `AGENTS.md`, `docs/ABBU.md`, the relevant parser or resolver, and the
supporting fixtures before changing archive semantics.

## Evidence Standard

Never infer Apple Contacts storage semantics merely from Core Data table or
column names. Require observed fixture evidence, Apple documentation where
available, or reproducible verification, and record consequential discoveries
in `docs/ABBU.md`.

- Distinguish verified behavior, fixture observations, and hypotheses.
- Record the macOS or Contacts version when known; do not generalize an unknown
  version into a universal guarantee.
- Preserve raw evidence long enough to reproduce a conclusion, but commit only
  deterministic synthetic fixtures with no personal contact data.
- Document the fixture, query, plist key path, file bytes, or Apple reference
  that supports consequential schema and relationship decisions.

## Bundle And Source Boundaries

- Treat `.abbu` as a version-variable bundle, not a single stable schema.
- Discover supported SQLite and plist records recursively, including nested
  `Sources/<account>/` layouts, without assuming the root database is complete.
- Keep source context when it affects identity or resolution. Never silently
  choose among ambiguous image stems or other duplicate identifiers.
- Treat image names, stems, extensions, locations, and `ZIMAGEURI` relationships
  as evidence-driven mappings. Support a variant only after reproducing it.
- Tolerate absent optional tables or fields when evidence shows they vary, while
  keeping malformed or unsupported input behavior explicit.

## Normalization And Documentation

- Normalize SQLite and plist records into `Abbu::Contact` only where their
  semantics genuinely align.
- Preserve unknown or variant behavior rather than inventing a lossy mapping.
- Add a focused regression fixture and spec for each discovered schema, source,
  or image-layout variation.
- Update `docs/ABBU.md` with consequential evidence and `docs/CHANGELOG.md` when
  public parsing or export behavior changes.

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
