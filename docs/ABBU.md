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

### Source container evidence

`Archive#sources` and `LiveStore#sources` group the existing `SourceDescriptor`
file evidence into root (`.`) and observed `Sources/<identifier>` containers.
This is ABBU's grouping convention over input paths, not discovery of Apple's
private account/container tables. It introduces no new storage-column inference.
Every selected input file appears, including databases with no contacts; files
in the same observed container are retained individually. Legacy plist files
outside `Sources/` belong to root. Parser selection and discovery scope are unchanged.

`Source#identifier` preserves the observed directory spelling, while `provider`
remains nil even for a directory named `iCloud`. Container paths are local identities
within that opened input, not globally stable IDs across moved archives or snapshots.
Contacts link through their original file-level `source[:path]`; the source hash
is neither replaced nor enriched with speculative provider metadata. `group_names`
reports distinct membership strings only; the group API below preserves identity.

`spec/abbu/source_spec.rb` copies the existing deterministic root database into
root, `Sources/iCloud`, and `Sources/Équipe`, including two database filenames in
one container and colliding contact IDs across containers. These fixtures verify
grouping, provenance preservation and unknown-provider behavior, not an Apple
account schema. Source listing parses/caches contacts and retains the existing
strict/tolerant diagnostics and live consistency limitations below.

### Group membership evidence

The existing synthetic fixture joins `Z_ABCDCONTACTGROUP.Z_GROUP` to
`ZABCDRECORD.Z_PK` and filters memberships by `Z_CONTACT`. The group parser now
retains that joined key alongside the exact `ZFIRSTNAME` value instead of discarding
the key. `Contact#group_memberships` preserves every returned join row; the existing
`Contact#groups` label array and exporters are unchanged. No label normalization
or inference from other column names is introduced.

`Archive#groups`, `LiveStore#groups`, and `Source#groups` aggregate this evidence by
absolute database path and record key. Keys are file-local, not global Apple IDs.
`Group#source` is file provenance; its `identifier` connects to the observed source
container. Group contacts retain original object identities with repeated joins
collapsed only in the navigable contact set, not in raw membership evidence.
Reverse lookup uses `groups_for(contact)` on the input or source; `Query#in_group`
intersects the caller's contacts with that snapshot without name-based matching.

`spec/abbu/group_spec.rb` extends the deterministic fixture with duplicate joins,
same-name/different-key groups, null and Unicode names, and repeated keys in root
and multiple files under `Sources/Équipe`. These establish collision boundaries
and name preservation through model and JSON output, not a new Apple schema.
No Apple version is asserted for this synthetic variation.

Only joined groups with parsed contacts are represented. Empty/unreferenced rows,
dangling joins, and plist group relationships remain unsupported; their semantics
need separate evidence. Missing membership tables retain existing diagnostics and
strict-mode behavior. Building groups adds no database reads beyond contact parsing
and makes no stronger live snapshot guarantee. JSON listings expose raw names and
file paths and must be treated as sensitive.

### Opt-in live Contacts stores

The CLI uses `--live` only for auto-discovery and `--live-path PATH` for an explicit
store. These forms are mutually exclusive and accept no positional archive/path arguments.
Option ordering does not change input selection. Read-only handles do not establish
snapshot consistency across an actively changing Contacts store.

`Abbu.open_live` and the CLI's live modes can read an AddressBook directory
without first exporting an `.abbu` archive. This mode is deliberately separate from
`Abbu.open`: archive validation and plist fallback do not apply to a live store.

When no path is supplied on macOS, ABBU checks the observed per-user location at
`~/Library/Application Support/AddressBook`. Callers may instead provide a directory,
which keeps automation and tests independent of the host platform and user account.
ABBU discovers databases directly under that directory and one level below
`Sources/<identifier>/`, preserving the same root/source provenance used for archives.
Only files matching the observed `AddressBook-v*.abcddb` shape are candidates; this
filename pattern is discovery evidence, not a guarantee of stable Apple semantics.

Every live-store database is opened using SQLite's read-only mode. ABBU has no live-store
write API and never creates, updates, or deletes Contacts data. macOS privacy controls may
deny access even when the path exists. In that case ABBU raises
`Abbu::LiveStore::PermissionError` with instructions to grant the calling terminal or
application Full Disk Access in **System Settings → Privacy & Security → Full Disk
Access**. Missing directories and databases raise `Abbu::LiveStore::NotFoundError`, and
automatic discovery without a caller-supplied path raises
`Abbu::LiveStore::UnsupportedPlatformError` outside macOS.

The repository verifies live-store behavior only with deterministic synthetic SQLite
fixtures. It does not inspect or commit a developer's real Contacts store.

### WAL and concurrent-writer evidence

`spec/abbu/live_store_wal_spec.rb` copies the existing synthetic root database into
a temporary directory and opens a separate writer connection in WAL mode. No
real Contacts data or macOS privacy permission is required. The tests deliberately
keep the writer open, disable its automatic checkpoint, and interleave operations
at known boundaries instead of using sleeps or timing races.

The fixture demonstrates that ABBU reads committed WAL changes while the writer
remains connected. Its database and WAL bytes stay unchanged across the read,
all ABBU connections use `readonly: true`, and traced statements contain no writes
or checkpoint requests. An uncommitted writer transaction is not visible. After
commit, a new LiveStore sees the new value; an existing store retains its cached
contacts.

There is an important consistency limit: the parser does not enclose all queries
in a read transaction. A commit between the contact-row SELECT and an email SELECT
can produce an old name with a new email from the same database. SQLite's snapshot
isolation applies within a read transaction, not across ABBU's independent
statements. Multiple database files are also read independently; there is no
cross-database snapshot guarantee. These tests characterize existing behavior,
not a new snapshot API or a guarantee for every Contacts/SQLite version.

SQLite uses `-wal` and `-shm` sidecars for WAL operation. Read-only database access
does not promise that shared-memory lock/index state is byte-for-byte unchanged;
the tests intentionally do not make that claim. Do not remove sidecars, checkpoint
a live Contacts database, or copy only its main file to try to obtain a snapshot.
Use an independently verified consistent export/backup for snapshot-sensitive work.
Missing/inaccessible sidecar and filesystem-lock behavior remain deployment-specific
limitations, not behavior established by the writable temporary fixture.

References: [SQLite WAL](https://www.sqlite.org/wal.html) and
[SQLite isolation](https://www.sqlite.org/isolation.html).

### Provenance-aware identity evidence

ABBU treats deduplication as a suggestion boundary rather than proof that two records are
the same person. `Utils::Deduplicator#matches` compares normalized email, phone, name, and
organization signals while returning both original contacts, both source records, raw
evidence, normalized comparison values, confidence, and ambiguity status.

Email comparison trims surrounding whitespace and applies Unicode-aware case folding.
Names and organizations use Unicode NFKC normalization, case folding, and whitespace or
punctuation normalization without transliterating distinct characters. Explicit `+` and
`00` phone forms are compared as international numbers. The trimmed raw value must start
with a literal ASCII `+` or contiguous `00`; punctuation removal never establishes an
international prefix. For example, `(001) 512-555-0100` remains national-format evidence.
National-format numbers remain
source-local evidence because ABBU has no country or numbering-plan evidence with which
to infer a global identity.

SQLite primary keys, source identifiers, private Apple link identifiers, and image stems
are not treated as global contact identifiers. The repository fixtures do not establish
such semantics. Competing candidates and weak name/organization or source-local phone
matches remain ambiguous, and no contact is merged unless the caller supplies an explicit
merge policy.

### Image resolution and extraction

The synthetic SQLite fixture demonstrates a `ZIMAGEURI` value whose stem matches a file
under an `Images/` directory. Resolution covers the root bundle and nested
`Sources/<identifier>/Images/` directories. When duplicate stems exist, ABBU uses the
contact's database provenance to select only an image beside that database; it does not
guess when the available evidence remains ambiguous.

`Archive#extract_images(output_dir)` and the CLI `--extract-images DIR` copy resolved
images without changing `Contact#image_uri`, `Contact#image_path`, or `Contact#source`.
Exported filenames combine a sanitized contact name, the original image identifier, and
a stable provenance digest. Path separators, control characters, and reserved filename
characters cannot create subdirectories or traverse outside the selected output directory.

The selected output directory (including symlinked parents) is resolved to its canonical
directory before copying; callers must control that directory and prevent concurrent
directory replacement. Each image is created exclusively with owner-only permissions.
Existing destinations are never overwritten, including regular files, hard links, and
symlinks (even dangling ones). These collisions produce a `destination_exists` extraction
diagnostic and no successful file record; other images continue. Repeating extraction
into the same directory therefore reports collisions instead of replacing earlier output.
Directory creation/resolution failures raise filesystem errors before extraction begins.

Extraction diagnostics are a separate API from `archive.diagnostics`: they may contain
contact names, raw image identifiers, source paths, and filesystem error details. Treat
them and the CLI's image warnings as sensitive contact data, not safe-to-publish logs.

ABBU recognizes JPEG, PNG, GIF, and common HEIF/HEIC-compatible brands from file
signatures and chooses the exported extension from those bytes rather than the source
extension. Unknown content is reported as a diagnostic instead of being relabeled. HEIC
data is copied unchanged; ABBU does not transcode it.

No repository fixture currently demonstrates a reliable Apple thumbnail-versus-full-size
naming or selection rule. ABBU therefore exports the image resolved by the observed
`ZIMAGEURI` relationship and does not infer size semantics from filenames or directories.

### Recovery and diagnostics

By default, ABBU recovers from malformed individual plist records, missing
optional SQLite relationship tables, and unresolved image references. Each
recovery appends an `Abbu::Diagnostic` to `archive.diagnostics` with a category,
parser, source path, non-PII context, and a stable message. Required contact
schema failures still raise because no evidence-backed contact record can be
recovered safely.

An absent optional SQLite table produces one diagnostic per database and table,
regardless of contact count. ABBU does not place record identifiers or raw image
references in these schema- and image-level diagnostic contexts.

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

### vCard serialization evidence

The 0.8.0 exporter implements TEXT escaping and structured components from
[RFC 2426 §§2.3–2.6](https://www.rfc-editor.org/rfc/rfc2426), and CRLF/grouping
and unfolding from [RFC 2425 §5.8.1](https://www.rfc-editor.org/rfc/rfc2425).
ABBU folds conservatively at 75 **octets**, including the continuation space,
without splitting a UTF-8 code point. Escaping happens before folding; decoding
must unfold first. Commas, semicolons and backslashes are escaped in TEXT;
CRLF, bare CR and LF become the logical newline escape. This preserves logical
text, not the original newline byte convention. Input Contact values are unchanged.
URI properties use percent encoding, preserving existing escapes and URI
delimiters rather than applying TEXT rules. This is not a general URI validator.

`spec/abbu/exporters/vcard_exporter_fidelity_spec.rb` contains deterministic
inline wire fixtures and an independent fixture-only decoder. It exercises
repeated properties, injection-shaped input, structured names/addresses,
multiline notes, UTF-8 folding boundaries, per-card group numbering, and both
SQLite/plist → Contact → vCard label preservation. The temporary SQLite fixture
only varies an already supported `ZLABEL`; the plist fixture uses the existing
`Email.values[].label` mapping. Neither adds guessed Apple storage semantics.

The reviewed extension audit is deliberately bounded:

| Surface | Implemented rule / evidence limit |
| --- | --- |
| `itemN`, `X-ABLABEL` | Standard group syntax pairs repeated properties with ABBU's existing raw-label extension. Labels remain exact after TEXT decoding; numbering is local to each card, not a stored Apple ID. No Apple import validation is claimed. |
| `X-ABDATE` | Existing anniversary mapping retained, now grouped with its label. Removed the fabricated `type=pref`. Other date collections remain unsupported by this exporter. |
| `TYPE`, `PREF` | Only exact ASCII names from RFC 2426's EMAIL/TEL/ADR lists and RFC 4770's IMPP list are recognized from display labels. No whitespace trimming, Unicode folding, custom-label tokenization, or Mobile→CELL guess. Raw labels remain separately available. Explicit `PREF` is recognized; no priority is inferred from row order. |
| `UID` | Not generated: SQLite keys and source paths are not demonstrated global contact identifiers. |
| `IMPP` | URI-valued property per [RFC 4770](https://www.rfc-editor.org/rfc/rfc4770). Existing service-to-scheme convention retained with scheme syntax checks and address encoding. A syntactically valid scheme does not prove service interoperability; absent service retains legacy `unknown:`. |
| `X-SOCIALPROFILE` | Existing service/username extension retained; parameter service must be an ASCII token and username is escaped TEXT. No provider URL or Apple import semantics are inferred. |
| `ADR` | Seven components, each independently escaped. No new PO box/extended-address storage mapping. Missing label no longer fabricates HOME. |
| Partial/lunar dates, phonetic names, verification code | Existing extensions retained, not certified as standard vCard 3.0 date forms or Apple alternate-calendar semantics. |
| `PHOTO` | Existing local file URI retained; portable embedding belongs to #30. |

Unsafe parameter values and control characters fail rather than create extra
properties or silently discard evidence. Serialization completes before file
opening/stdout emission, so validation failures produce no partial export and
leave an existing output file untouched. Filesystem failures after opening can
still leave partial files. Exports contain sensitive contact values and photo
paths; callers must choose appropriate destinations and permissions.

Email preference uses `TYPE=INTERNET,PREF`, retaining the default address type
as required by RFC 2426's email parameter grammar; TEL includes the standard
`PCS` token. Unknown extension/registered type names are preserved as labels,
not asserted to be registered by ABBU's deliberately bounded built-in list.

These are standards-backed serialization guarantees and synthetic regression
observations, not a full-fidelity ABBU backup or certification against a specific
macOS/Contacts build. A sanitized real Apple export/import corpus remains a
separate compatibility gate before broader claims.

## Repository Evidence

- [Writer decision](WRITER_DECISION.md): current evidence does not justify
  constructing Apple-private archives. Read compatibility is not import proof;
  future proposals require isolated, version-attributed import evidence.

- [Compatibility regression matrix](FORMAT_COMPATIBILITY.md): always-on XML,
  sparse/complete SQLite, root/source/mixed layout profiles and their explicit
  historical evidence gaps. Filename suffixes are not macOS version guarantees.
- `spec/fixtures/TestContacts.abbu/` exercises the supported synthetic SQLite,
  nested source, and image-resolution behavior.
- `spec/fixtures/PlistContacts.abbu/` exercises the supported synthetic legacy
  plist behavior.
- `spec/fixtures/identity_cases.yml` contains deterministic synthetic cross-source and
  Unicode near-collision identity evidence.
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
- [macos-ts live Contacts reader](https://github.com/evantahler/macos-ts)
- Repository fixtures and regression specs listed above

Apple's public Contacts framework documents application-facing concepts, not a
stable `.abbu` storage contract. Private framework names and Core Data names are
not normative references.

---
Stan Carver II
Made in Texas 🤠
https://stancarver.com
