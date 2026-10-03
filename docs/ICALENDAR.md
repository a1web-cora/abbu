<!-- docs/ICALENDAR.md -->

# iCalendar Reminders

`Abbu::Exporters::IcalendarExporter` consumes the public `Contact#birthday` and
`Contact#anniversary` fields, not private Apple tables. It emits one all-day,
transparent yearly reminder per supported field. Arbitrary `Contact#dates`
entries are not classified as birthdays or anniversaries by this exporter.
It does not create alarms, calculate ages, change contacts, or write source stores.

## Explicit Metadata

The constructor requires `year:` (Integer 1–9996), `generated_at:` (Time whose UTC
year is 1–9999), and a nonempty `calendar_id:` String. The latter is a caller-owned
unique namespace: choose a unique UUID or identifier under a domain you control,
and reuse it only for the same logical ordered input. The timestamp is the real
export revision time, converted to UTC seconds; subsecond precision is omitted.
No wall clock, random identifier, source timestamp, or fabricated epoch is used.

`to_ical` returns UTF-8 text; `to_file(path)` writes identical bytes;
`to_stdout` prints those bytes. Same ordered contacts and metadata produce the
same output. Every call rebuilds `diagnostics`, a frozen array of frozen hashes
with `category`, zero-based `contact_index`, and `field`. Categories are
`invalid_date` and `unsupported_calendar`. These omit names, paths and date values.

## Date Policy

An absent year (`nil`) or integer zero is unknown. Other year/month/day values
must be integers and form a valid proleptic Gregorian date, with known years in
1–9999. Unknown years use a leap-year validation reference internally; that
reference is never exported as a birth year. Invalid values are diagnosed and
omitted, not repaired. No private Apple sentinel year is guessed.

`DTSTART` is the first valid occurrence at or after the caller's year and, when
known, the source year. February 29 advances to the next leap year if needed;
yearly recurrence skips non-leap years, never silently shifts to February 28 or
March 1. `DURATION:P1D` avoids cross-year end-date overflow. All events contain
an explanatory DESCRIPTION and `X-ABBU-YEAR-UNKNOWN:TRUE` or `FALSE`. Known source
years appear in DESCRIPTION; unknown source years never gain an asserted age or
original year. Calendar software may display recurrence starts as dates; these
are reminders, not birthday-field synchronization or Apple round-trip backups.

`lunar_birthday` is always diagnosed and omitted. A supplied `calendar` key on a
date permits only absent/nil, `'gregorian'`, or `:gregorian`; anything else is
diagnosed and omitted. Existing parsers do not expose every private calendar
attribute, so absence of an attribute is not proof of original Apple calendar
semantics. This is an explicit Gregorian convention over the current public
normalized fields, not alternate-calendar conversion or expanded parse support.

SUMMARY preserves `raw_label` when present (including blank), otherwise `label`,
otherwise Birthday/Anniversary. Custom and wrapped labels remain exact after
TEXT decoding; the Contact and its evidence are never rewritten.

## Wire And Identity Contract

The standards basis is [RFC 5545](https://www.rfc-editor.org/rfc/rfc5545):
content lines and UTF-8 in §3.1, TEXT escaping in §3.3.11, DATE in §3.3.4,
yearly recurrence in §3.3.10, all-day VEVENT in §3.6.1, UID in §3.8.4.7, and
DTSTAMP in §3.8.7.2. Output uses CRLF, escaped backslashes/commas/semicolons and
newlines, and UTF-8-safe folding at 75 octets including continuation whitespace.
Invalid text/control characters raise before opening an output file.

UIDs hash the namespace, zero-based input position, field kind, source-relative
path, and full name. Duplicate contacts remain separate. These are generated
reminder identifiers, not Apple IDs or proof of contact identity. Reordering,
inserting contacts, changing names/provenance, or changing namespace changes
UIDs; this is not a persistent synchronization feed. Hashes are not anonymization.
No source paths or contact identifiers are exported in clear text, but names,
labels, source years, dates and correlatable identifiers are sensitive.

With no supported events, output is the empty string, not an invalid componentless
VCALENDAR. Tolerant omissions can therefore produce no bytes. Inspect diagnostics.
`strict:`/`--strict` belongs to parsing only; it does not alter exporter omissions.
Existing output files are overwritten on successful export, even empty output;
file writing is buffered but not atomic/no-clobber. Use a separate destination
outside the source bundle. Filesystem failures can leave partial output.

## CLI

Use `--format icalendar`, `--calendar-year`, `--calendar-stamp` (full ISO 8601
timestamp with timezone), and `--calendar-id`. Archive and explicit live-store
input are supported. Only output selection and parser strictness accompany
calendar export; conflicting operations are rejected. Stdout contains only
calendar bytes (or none); omission diagnostics go to stderr. Success including
omissions exits 0, invalid metadata/conflicts exit 2. Existing input/access
failure behavior is unchanged. The exporter adds no runtime dependency.

## Evidence And Limits

`spec/support/calendar_fixtures.rb` reproduces previously supported plist keys
and SQLite date columns using synthetic data, not a particular macOS build.
API and CLI specs exercise byte preservation, unknown-year/leap policies,
Unicode folding, raw labels, malformed input, and deterministic output. No live
personal store is inspected. No calendar-client import certification is claimed.

[README](../README.md) · [ABBU evidence](ABBU.md)

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
