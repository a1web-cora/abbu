<!-- docs/ABBU.md -->

# ABBU File Format (Apple Contacts Archive)

## Overview

`.abbu` files are exported from Apple Contacts.app and represent a full address book archive.

They are **not** a single file format — they are a macOS "package" (a directory bundle that Finder
presents as a single file). This means you can inspect the contents with `ls` or `open -a Finder`.

## Evidence Standard

Apple does not publish a stable specification for every internal Contacts
archive schema represented by `.abbu` bundles. This document therefore
distinguishes observed repository-fixture behavior from documented Apple APIs
and from hypotheses that still require verification.

Never infer Apple Contacts storage semantics merely from Core Data table or
column names. Require observed fixture evidence, Apple documentation where
available, or reproducible verification, and record consequential discoveries
in this document.

For each new schema, relationship, source layout, image convention, or version
variation:

1. record the macOS or Contacts version when known;
2. identify the synthetic fixture, SQLite query, plist key path, file evidence,
   or Apple documentation supporting the conclusion;
3. add a deterministic regression fixture and spec; and
4. label unresolved interpretations as hypotheses rather than format guarantees.

Real address-book exports contain sensitive personal data. Use them only for
local verification, sanitize the observed behavior into deterministic synthetic
fixtures, and never commit the original contacts, photos, or account identifiers.

## Structure

The supported synthetic fixtures and observed exports use layouts such as:

```text
Contacts.abbu/
├── AddressBook-v22.abcddb   ← SQLite database for "Local" contacts (often mostly empty)
├── Metadata/                ← plist files (bundle metadata)
│   └── *.abcdp
├── Images/                  ← contact photos (JPEG/PNG)
│   └── <uuid>.jpg
├── Sources/                 ← Remote synced accounts (iCloud, Exchange, Google)
│   ├── <account_uuid>/
│   │   ├── AddressBook-v22.abcddb  ← SQLite database for this specific account
│   │   ├── Metadata/
│   │   └── Images/
│   └── <another_uuid>/...
└── Records/                 ← legacy plist-based contact records (older macOS)
    └── <uuid>.abcdp
```

> **Note:** The most common pitfall when parsing `.abbu` files is only reading the root `AddressBook-v22.abcddb`. For users syncing via iCloud or Exchange, the root database will be nearly empty. Parsers must recursively scan the `Sources/` directory to discover and extract all contacts from all `.abcddb` files.

## Formats

### 1. SQLite (modern macOS)

Supported modern fixtures contain one or more SQLite databases named:

```
AddressBook-v22.abcddb
```

The following tables and mappings are exercised by the repository's generated
SQLite fixture and parser specs. Their names alone are not evidence that the
same semantics apply to every macOS version.

Key tables:

| Table                    | Purpose                                |
|--------------------------|----------------------------------------|
| `ZABCDRECORD`            | One row per contact (name, company)    |
| `ZABCDEMAILADDRESS`      | Email addresses (linked by `ZOWNER`)   |
| `ZABCDPHONENUMBER`       | Phone numbers (linked by `ZOWNER`)     |
| `ZABCDPOSTALADDRESS`     | Street addresses (linked by `ZOWNER`)  |
| `Z_ABCDCONTACTGROUP`     | Group membership join table            |
| `ZABCDURLADDRESS`        | URLs (linked by `ZOWNER`)              |
| `ZABCDNOTE`              | Notes (linked by `ZCONTACT`)           |
| `ZABCDRELATEDNAME`       | Related names (linked by `ZOWNER`)     |
| `ZABCDSOCIALPROFILE`     | Social profiles (linked by `ZOWNER`)   |

Notable columns in `ZABCDRECORD`:

| Column                   | Description              |
|--------------------------|--------------------------|
| `Z_PK`                   | Primary key              |
| `Z_ENT`                  | Entity type (14=contact) |
| `ZFIRSTNAME`             | First name               |
| `ZLASTNAME`              | Last name                |
| `ZNICKNAME`              | Nickname                 |
| `ZTITLE`                 | Prefix (e.g. "Dr.")      |
| `ZSUFFIX`                | Suffix (e.g. "Jr.")      |
| `ZORGANIZATION`          | Company / org            |
| `ZJOBTITLE`              | Job title                |
| `ZDEPARTMENT`            | Department               |
| `ZMAIDENNAME`            | Maiden name              |
| `ZPHONETICFIRSTNAME`     | Phonetic first name      |
| `ZPHONETICLASTNAME`      | Phonetic last name       |
| `ZPHONETICORGANIZATION`  | Phonetic company         |
| `ZPRONOUNS`              | Pronouns                 |
| `ZRINGTONE`              | Ringtone                 |
| `ZTEXTTONE`              | Text tone                |
| `ZCREATIONDATE`          | Optional record creation timestamp |
| `ZMODIFICATIONDATE`      | Optional record modification timestamp |

### Timestamp and source provenance

Observed Contacts databases may include `ZCREATIONDATE` and `ZMODIFICATIONDATE` on
`ZABCDRECORD`. ABBU interprets numeric values in those columns as Apple absolute time:
seconds since 2001-01-01 00:00:00 UTC. The columns are optional because exported schemas
vary across macOS releases and account providers; when either column is absent or invalid,
the corresponding `Contact` value is `nil`.

These values describe timestamps stored on the record. They must not be interpreted as
proof of a user-initiated creation or edit, because syncing and migration can also affect
them.

Every parsed contact includes source provenance with the absolute source path, its path
relative to the `.abbu` root, and whether it came from the root bundle or a database under
`Sources/<identifier>/`. Legacy plist contacts receive the same file-level provenance.

### Recovery and diagnostics

By default, ABBU recovers from malformed individual plist records, missing
optional SQLite relationship tables, and unresolved image references. Each
recovery appends an `Abbu::Diagnostic` to `archive.diagnostics` with a category,
parser, source path, non-PII context, and a stable message. Required contact
schema failures still raise because no evidence-backed contact record can be
recovered safely.

Pass `strict: true` to `Abbu.open` or `--strict` to the CLI to raise
`Abbu::ParseError` on the first recoverable condition. The CLI prints a
diagnostic summary to standard error so exported data on standard output remains
pipeable.

### Schema diagnostics

`Archive#schema_report` and `abbu Contacts.abbu --schema` inspect every discovered
SQLite database and return deterministic schema metadata. Reports identify recognized
and unrecognized tables and columns, recognized items that are absent, declared SQLite
types, primary-key and nullability metadata, source provenance, and exact owner/contact-
style column names that may represent contact links.

These reports are research evidence, not parser mappings. In particular, a
`contact_link_candidate` flag records only an exact column-name shape such as `ZOWNER`,
`ZCONTACT`, or `Z_CONTACT`; it does not claim a foreign-key target or assign Apple
Contacts semantics. Unknown tables and columns must be reproduced in a sanitized fixture
or supported by documentation before ABBU uses them to populate contacts.

Missing recognized tables and columns remain visible as diagnostic observations. The
parser tolerates absent established email, phone, and postal-address tables by returning
empty collections, while the schema report preserves the absence for compatibility
research. If one of those tables exists but lacks an expected column, parsing raises the
SQLite schema error instead of silently treating the contact as having no corresponding
data. The core `ZABCDRECORD` table remains required for contact parsing.

### Labeled values

The synthetic SQLite and plist fixtures include both custom labels and Apple's
observed standard-label wrapper, such as `_$!<Work>!$_`. ABBU exposes the
human-facing value as `label` (`Work`) and preserves the exact stored value as
`raw_label`. Custom, blank, malformed, Unicode, and already-normalized labels
are not otherwise rewritten. Direct plist keys such as `Birthday` have no
stored label, so their normalized label is derived from the key and
`raw_label` is `nil`.

Normalization applies to email addresses, phone numbers, postal addresses,
URLs, related names, date components, and instant-message handles. JSON keeps
both values. Human-facing CSV uses normalized labels, while vCard anniversary
labels prefer `raw_label` so Apple label wrappers and custom source values
survive parse → model → interchange export.

### 2. Plist / `.abcdp` (legacy macOS)

Older macOS versions stored contacts as separate plist files under `Records/`.
The repository fixtures demonstrate dictionaries that the plist parser
normalizes into the same contact model used by the SQLite parser. Additional
plist keys or layouts require fixture evidence before they are treated as
supported semantics.

## Repository Evidence

- `spec/fixtures/TestContacts.abbu/` exercises the supported synthetic SQLite,
  nested source, and image-resolution behavior.
- `spec/fixtures/PlistContacts.abbu/` exercises the supported synthetic legacy
  plist behavior.
- `spec/support/fixture_generator.rb` is the reproducible source for generated
  SQLite fixture structure and data.
- `spec/abbu/schema_inspector_spec.rb` builds deterministic temporary SQLite
  schemas for missing tables, unknown contact-link candidates, and column drift.

These fixtures prove only the variations they contain. Table names, column
names, entity numbers, UUIDs, and directory names alone are not sufficient
evidence for new behavior.

## Export Steps

To create a `.abbu` file:

1. Open **Contacts.app** on macOS
2. Select all contacts (`⌘A`)
3. File → Export → **Export vCard** *(or)* File → Export → **Contacts Archive…**

The "Contacts Archive" option produces a `.abbu` bundle.

## References

- [Apple Contacts framework](https://developer.apple.com/documentation/contacts)
- [iQueryContacts forensic schema notes](https://github.com/MetadataForensics/iQueryContacts)
- [Observed Contacts timestamp epoch](https://apple.stackexchange.com/questions/115551/how-to-sort-contacts-by-creation-date-or-modification-date-in-ios-contacts-or-os/229313)
- [LifeOS Apple Contacts timestamp conversion](https://github.com/nbramia/LifeOS/blob/main/scripts/apple_data_export.py)
- [SQLite3 gem](https://github.com/sparklemotion/sqlite3-ruby)
- Repository fixtures and regression specs listed above

Apple's public Contacts framework documents application-facing concepts, not a
stable `.abbu` storage contract. Private framework names and Core Data names are
not normative references.

---
Stan Carver II
Made in Texas 🤠
https://stancarver.com
