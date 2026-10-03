<!-- docs/STREAMING.md -->

# Streaming Contacts

[README](../README.md) · [Format evidence](ABBU.md)

`Archive#each_contact` and `LiveStore#each_contact` return an Enumerator without
a block, or yield contacts and return the input object with a block. They do not
read or populate `@contacts`. Existing `contacts`, queries, groups, and sources
retain their buffered behavior. SQLite rows are consumed through a read-only
cursor; legacy plist files are parsed one file at a time. Normalization, raw
labels, provenance, image resolution, and diagnostics use the existing parser
rules. This is not a new interpretation of Apple's storage schema.

Use block iteration, `first`, or `take` for early termination: unwinding the block
closes the statement and database, also on consumer exceptions. An externally
suspended Enumerator (`next`) retains its reader until resumed/unwound or garbage
collected; do not abandon suspended enumerators expecting immediate closure.
Live readers are not a cross-source atomic snapshot. A slow consumer retains an
active SQLite read cursor and may delay WAL checkpoint progress. Repeated calls
read again and can see newer source state; diagnostics accumulate on the input.

## Export And Safety

CSV and vCard exporters expose `write_to(io)` for any contact Enumerable.
`JsonlExporter` adds `write_to(io)`, `to_file(path)`, and `to_stdout` using the
existing JSON contact fields. Caller-owned IO remains open. CLI `--stream`
accepts standalone CSV, JSONL, or vCard export, including explicit live paths;
JSONL always streams. Aggregate/search modes are not streaming modes.
`--stream` also rejects machine JSON modes, snapshot diff, merge options,
SQLite/iCalendar exports and calendar metadata before reading inputs or opening
output files. Machine-mode conflicts use the existing structured JSON error contract.

Writes are incremental and **not atomic**: a malformed later record, consumer IO
failure, or unsupported embedded photo can leave a partial file/stdout stream.
Use a caller-managed temporary file and rename after success if atomic delivery
is required. Buffered vCard's pre-output validation guarantee does not extend to
`write_to`. Protect output as sensitive personal data: JSONL has the same privacy
surface as JSON, including contact details, local provenance, and stored codes.
No encryption or anonymization is implied.

Contact retention is bounded when the consumer does not collect results. Total
memory is not constant: file paths and image indexes scale with the bundle,
diagnostics can grow, and one contact's values/photo can be large. `to_a`, grouping,
or buffering output in StringIO forfeits the retention benefit.

## Synthetic Benchmark

Run from a development checkout with mise available on PATH:

```sh
/usr/bin/time -l bin/benchmark-streaming stream 10000
/usr/bin/time -l bin/benchmark-streaming buffered 10000
```

The temporary fixture uses the existing synthetic SQLite schema and 10,000
name-only contacts, no photos. Six missing-optional-schema diagnostics occur in
both modes. Timing excludes fixture construction but includes periodic explicit
GC. Process peak RSS includes setup/runtime; contact counts are sampled after GC
every 1,000 contacts, not a continuous heap maximum. These are local observations,
not performance guarantees for real archives.

Observed on macOS with Ruby 3.3.11, 2026-10-01:

| Mode | Iteration seconds | Peak RSS bytes | Sampled live contacts |
| --- | ---: | ---: | ---: |
| Streaming | 1.873 | 30,384,128 | 1 |
| Buffered | 2.681 | 48,254,976 | 10,000 |

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
