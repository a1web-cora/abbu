<!-- docs/PORTABLE_SQLITE.md -->

# Portable Normalized SQLite

`Abbu::Exporters::SqliteExporter.new(contacts).to_file(path)` creates a separate
SQLite artifact from an `Enumerable<Abbu::Contact>`. It returns the canonical
destination path as a String. It has no stdout or source-writing API. The CLI is
`abbu Contacts.abbu --format sqlite --output contacts.sqlite`; explicit live-store
input is also supported, without adding snapshot guarantees.

This is an embedded/local export, not a server database. SQLite is deliberately
used for portability; no PostgreSQL service or Rails dependency is appropriate.
Schema definitions use fixed ABBU-owned SQL identifiers through the existing
sqlite3 library, and every contact value is a bound parameter. No user text is
interpolated into SQL identifiers or expressions. No new dependency is added.

## Schema Version 1

`SqliteExporter::SCHEMA_VERSION`, `PRAGMA user_version`, and the single `metadata`
row all report 1. Metadata also records `generator_version` (the gem version),
not a wall-clock timestamp. A schema change needs explicit versioning; readers
must reject unknown versions rather than assume compatibility. There is no
in-place migration command; recreate derived artifacts from retained inputs.

| Table | Queryable facts and relationships |
| --- | --- |
| `metadata` | `schema_version`, `generator_version` |
| `contacts` | Sequential `id`, nullable `source_id`, all supported flat name/organization/phonetic/pronoun/tone/verification/image fields, `created_at`, `modified_at`, flat-field `evidence_json` |
| `sources` | File-level observed `path`, `relative_path`, `kind`, `identifier`, complete `evidence_json` |
| `emails` | `contact_id`, `position`, `address`, `label`, `raw_label`, `evidence_json` |
| `phones` | Same identity/order columns, `number`, labels, evidence |
| `addresses` | Same identity/order columns, `street`, `city`, `state`, `zip`, `country`, labels, evidence |
| `urls` | Same identity/order columns, `url`, labels, evidence |
| `related_names` | Same identity/order columns, `name`, labels, evidence |
| `social_profiles` | Same identity/order columns, `service`, `username`, evidence |
| `instant_messages` | Same identity/order columns, `address`, `service`, labels, evidence |
| `notes`, `group_labels` | `contact_id`, `position`, nullable display `value`, original `evidence_json`, including duplicates |
| `dates` | `contact_id`, `field`, `position`, `year`, `month`, `day`, labels, evidence |
| `groups` | Sequential `id`, nullable `source_id`, observed `record_id`, raw `name`, evidence |
| `group_memberships` | `contact_id`, `position`, `group_id`, retaining duplicate observations |

Collection primary keys preserve contact-local order. Foreign keys link children
to contacts, contacts/groups to source files, and memberships to groups. Indexes
support source and reverse group lookup. Foreign keys are enabled during export;
downstream writers must enable them on their own connections. Derived IDs are
1-based insertion IDs, not Apple identities; collection positions are zero-based.

For example, ordinary SQL clients can query `contacts JOIN emails ON
contacts.id = emails.contact_id` without knowing any Apple table name. Contact
name components remain separate, rather than hiding queryable facts in JSON.
`evidence_json` duplicates each structured entry's complete public hash, including
unknown extra keys, nulls, raw labels and nested primitive data. It distinguishes
missing keys from explicit nulls where fixed relational columns cannot. Hash keys
are canonically sorted; array order is preserved. Source date/calendar evidence
is copied without interpreting it or fabricating missing years. Flat fields,
notes and group-label values also retain original JSON primitives in evidence:
their TEXT columns are query/display conveniences, not authoritative original
types. For example, a plist integer name/note remains an integer in evidence
even though its text column is a string. Pathname objects are represented by
their path strings; arbitrary Ruby object serialization is not promised.

`dates.field` distinguishes `birthday`, `anniversary`, `lunar_birthday`, and
`dates`. Direct fields and collection entries are intentionally both retained;
they are not deduplicated. Dates are stored as observed components, not validated
or converted into a guessed calendar. Timestamps use ISO 8601 with nine fractional
digits and their original offset; absent timestamps remain NULL. Image URI/path
references are text only: no image files are read or embedded.

## Sources And Groups

Sources are file-provenance hashes observed on the supplied contacts, deduplicated
by complete canonical evidence. They are not inferred account/provider identities.
Empty sources and unreferenced groups cannot be discovered from the contact input
and are not fabricated. For those catalogs, retain the original archive or use
the public Source/Group listing APIs separately.

Groups deduplicate only identical membership evidence within the same complete
source descriptor. Repeated keys across sources remain separate. Conflicting names
or extra evidence yield separate observations, not silent reconciliation. With no
source descriptor, groups remain contact-local. `group_labels` independently keeps
the complete `Contact#groups` array; names are not treated as group identities.

## Determinism And Round-Trip Evaluation

The exporter materializes the contact enumerable; it is not a constant-memory
streaming implementation. It iterates contacts and collections in supplied order,
and assigns IDs in first-occurrence order. Equivalent ordered input and generator
version produce identical relational contents; tests additionally establish byte
equality with the same SQLite library. Byte identity across SQLite versions is
not promised. Reordering input or changing generator version changes the artifact.

Regression tests reconstruct normalized collections and dates from the persisted
rows/evidence, compare flat fields and timestamps, and preserve duplicate/null
labels and membership observations. Both legacy XML and SQLite sources are tested.
This evaluates the normalized interchange boundary only: no public re-import API,
private Apple schema writer, Apple import certification, account identity mapping,
or byte-for-byte original archive restoration is provided. JSON primitive evidence
is preserved; arbitrary custom Ruby object graphs are outside the contact contract.

## Publication And Source Safety

The destination parent must already exist. A temporary SQLite file is created
in that resolved directory with mode 0600. Data insertion uses a transaction;
the completed database is closed before an atomic same-filesystem hard link
publishes the final name. This operation fails if any destination already exists,
including a dangling symlink or a file created concurrently. Temporary files are
removed after success or failure. Empty input still creates a valid versioned
database with no contacts.

No destination is overwritten. Destinations beneath `.abbu`-suffixed directories
are rejected even for empty input; observed source-bundle aliases are also resolved
and rejected when the real directory has a different name. Callers must control the
destination directory and prevent concurrent ancestor replacement; this is not an
adversarial filesystem sandbox. Filesystems without hard-link support fail safely,
without an unsafe overwrite fallback. No cross-filesystem atomicity or power-loss
durability guarantee is claimed. Source parsing retains existing read-only/live
consistency limitations; exporting does not repair or checkpoint source databases.

## Security And CLI Failures

This user-requested portable/queryable export is deliberately **plaintext**, an
exception to encrypted application database storage—not an encrypted database or
multi-tenant service. It contains confidential names, contact values, notes,
verification-code fields, and absolute provenance/image paths. Owner-only mode is
not encryption. Keep it on encrypted storage, protect backups separately, minimize
retention, and do not publish it in logs, issues, analytics, or test fixtures.
Use only synthetic data in tests. Exporting does not contact external services.

CLI success produces no stdout and exits 0; omission/parser diagnostics retain
their existing stderr behavior. `--format sqlite` requires an output file and
rejects conflicting operations. Filesystem, SQLite, and JSON generation failures
exit 2 with a class-only export error rather than contact payloads. Input/access
failures retain the existing CLI contract. The Ruby API raises the underlying
exception, which callers should treat as potentially sensitive. No release action
is authorized by a successful package/export check.

[README](../README.md) · [ABBU evidence](ABBU.md)

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
