<!-- docs/FORMAT_COMPATIBILITY.md -->

# ABBU Compatibility Regression Matrix

Legacy support is a tested behavior, not a filename/version guess. The suite
must keep the older supported shapes passing as newer fields and layouts are
added. This matrix is run by ordinary `bin/spec` and therefore by every current
CI Ruby job (3.3, 3.4, 4.0); it needs no macOS services or personal contacts.

## Evidence and scope

All profiles below are **synthetic**, with **unknown macOS and Contacts build**.
Their evidence is the repository's existing XML fixture keys, SQLite fixture
generator, and parser schema-variance tests. They are not collected exports from
eight Apple releases. In particular, `v1` and `v99` are filename-dispatch probes
using the known schema; they do not establish support for real schemas with
those version numbers. Do not report the Ruby CI matrix as a macOS matrix.

`spec/support/compatibility_fixtures.rb` rebuilds each profile inside a fresh
temporary directory. It reuses only the non-destructive schema/seed methods of
the existing fixture generator, not its bundle-reset command. No committed
binary is regenerated or overwritten by these tests.

## Always-on end-to-end profiles

| Profile | Structure / variation | Expected boundary |
| --- | --- | --- |
| `xml_records` | XML `.abcdp` under `Records/` | Plist fallback, raw labels, absent SQLite-only timestamps/groups |
| `xml_nested` | XML records below `Sources/Équipe/Records/` | Recursive archive discovery and source provenance |
| `sqlite_sparse` | Synthetic `AddressBook-v1.abcddb`; absent timestamp/image/name-extension columns and most relationship tables | Preserve core contact/email; nil absent fields, empty collections, tolerant diagnostics; strict mode raises |
| `sqlite_root` | Root `AddressBook-v22.abcddb` with all currently queried relationship tables | Strict-mode success, timestamps, original group membership |
| `sqlite_source_only` | Database only under `Sources/Équipe/` | Root database is not required |
| `sqlite_empty_root` | Empty root plus two source databases with colliding contact/group keys | Empty source remains listed; every source's contact/group remains distinct |
| `sqlite_mixed_schemas` | Sparse root plus complete nested database, different filename suffixes | Optional-table state is file-local, not cached globally across schemas |
| `mixed_formats` | Both SQLite and XML records | Preserve current SQLite-first policy; plist records are intentionally not combined |

Each profile independently asserts expected record counts and file provenance,
raw versus normalized email labels, query results, timestamp availability, group
traversal, source enumeration, and strict/tolerant outcomes. JSON retains labels
and provenance; CSV and vCard retain the core email/contact counts. Export tests
compare SHA-256 of every input file before and after parsing/exporting and detect
new or missing files as well as changed bytes. These archive tests do not claim
byte-for-byte immutability of live WAL shared-memory state.

Additional matrix regressions prevent an unknown required SQLite schema from
silently falling back to XML, and keep valid XML siblings recoverable when one
record is malformed. They test public `Abbu.open` behavior without parser mocks.
The matrix does not freeze vCard whitespace or property spelling; the dedicated
exporter tests own those contracts.

## Complementary existing coverage

| Variation | Regression location |
| --- | --- |
| Full relational fields; absent/invalid timestamps; missing tables vs missing columns | `spec/abbu/parsers/sqlite_parser_spec.rb` |
| Rich/minimal XML; malformed records; dates; raw anniversary labels | `spec/abbu/parsers/plist_parser_spec.rb` |
| Empty/multiple files, source collisions, SQLite-first precedence | `spec/abbu/source_spec.rb` |
| Same-name groups, duplicate joins, null/Unicode labels | `spec/abbu/group_spec.rb` |
| Duplicate image stems, source-local resolution, missing images | `spec/abbu/utils/image_resolver_spec.rb`, `spec/abbu/archive_spec.rb` |
| JPEG/PNG/GIF/HEIC signatures, unknown bytes, safe extraction | `spec/abbu/image_extractor_spec.rb` |
| WAL visibility, concurrent commits and cache limits | `spec/abbu/live_store_wal_spec.rb` |
| Unknown tables/columns and schema drift without inferred mappings | `spec/abbu/schema_inspector_spec.rb` |

## Unverified historical boundaries

There is no release-attributed real-archive corpus in this repository. Binary
plist `.abcdp`, alternate private table/column/entity mappings, and exports from
specific historical macOS/Contacts builds are **not certified by this matrix**.
XML support must not be generalized to every plist encoding. Existing recovery
tests likewise do not prove all corruption forms recover safely.

To add a genuine historical variation:

1. Record the export's macOS version, Contacts build, export method and storage
   encoding; mark any unavailable metadata unknown.
2. Inspect the relevant behavior privately. Never commit a real address book,
   photo, account identifier, or unsanitized schema/data dump.
3. Reproduce only the necessary structure with deterministic invented data,
   recording the observed keys/columns/relationships and source evidence.
4. Add a named matrix profile or focused regression with explicit expected
   fields, provenance, raw evidence, exports, diagnostics and strict behavior.
5. Fix supported behavior only after the regression demonstrates the gap. Keep
   older fixtures/tests; do not replace them with the newest schema. Unknown
   formats should remain explicit gaps, not guessed adapters or silent fallback.
6. Record the evidence and limits in [ABBU.md](ABBU.md) and this matrix, and run
   the full suite/lint/CI before review.

This test-only expansion changes neither runtime behavior nor the gem version.
Future behavior fixes use patch bumps; newly completed features use minor bumps.

Return to [README](../README.md), [format evidence](ABBU.md), or
[contributing](CONTRIBUTING.md).

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
