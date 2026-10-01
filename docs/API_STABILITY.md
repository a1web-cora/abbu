<!-- docs/API_STABILITY.md -->

# Pre-1.0 API Stability Gate

This is the acceptance checklist for [issue #47](https://github.com/scarver2/abbu/issues/47),
not a declaration that ABBU is stable or authorization to release 1.0. The baseline
inventory below describes the accepted 0.4.0 interfaces. Proposed features join
this inventory only after review and integration.

## Public surface inventory

The following are consumer-facing contracts even while the gem is pre-1.0:

| Surface | Contract to document and test before 1.0 |
| --- | --- |
| Entry points | `Abbu.open(path, strict:)`, `Abbu.open_live(path = nil, strict:)`, `Abbu::VERSION` |
| `Archive` | Construction, `path`, `contacts`, `diagnostics`, `sqlite?`, `query`, `where`, `search`, `find_by_email`, `find_by_phone`, `schema_report`, `extract_images` |
| `LiveStore` | Construction, `path`, `contacts`, `diagnostics`, `database_paths`, `.default_path`; discovery, caching, read-only and permission boundaries |
| `Contact` | Mutable accessors listed below, collection defaults, nil behavior, `full_name`, `to_s`, `inspect`; sensitive-data implications of inspection |
| `Query` | Construction from contacts, Enumerable/`each`, `to_a`, `where`, `search`, exact email/phone lookup; ordering, defensive arrays, original contact identity |
| Exporters | `CsvExporter`, `JsonExporter`, `VcardExporter`: construction, `to_file`, `to_stdout`, output encoding and file behavior |
| Diagnostics | `Diagnostic` fields and `to_h`; `ParseError#diagnostic`; tolerant recovery versus strict failure |
| Identity suggestions | `Utils::Deduplicator#duplicates`, `#matches`/`#identity_matches`; `Match` readers, `sources`, `ambiguous?`, explicit `merge(policy:)`; `MergePolicyRequired` |
| Image extraction | `ImageExtractor#extract` and `Result#files`/`#diagnostics`, also exposed through Archive; no-overwrite behavior and privacy-sensitive metadata |
| Schema evidence | `SchemaInspector#report`, also exposed through Archive; deterministic reports, no inferred Apple semantics |
| CLI and tasks | `bin/abbu` flags, stdout/stderr/exit codes; `abbu:export`, `abbu:dedupe`, `abbu:stats` task arguments |

Contact accessor inventory:

- Names: `first_name`, `middle_name`, `last_name`, `nickname`, `prefix`, `suffix`,
  `maiden_name`, `phonetic_first_name`, `phonetic_middle_name`, `phonetic_last_name`.
- Organization: `company`, `job_title`, `department`, `phonetic_company`.
- Collections: `emails`, `phones`, `addresses`, `groups`, `urls`, `notes`,
  `related_names`, `social_profiles`, `dates`, `instant_messages`.
- Other observed fields: `pronouns`, `ringtone`, `texttone`, `birthday`,
  `anniversary`, `verification_code`, `lunar_birthday`, `image_uri`, `image_path`,
  `created_at`, `modified_at`, `source`.

Record the keys, value types, raw evidence, optionality, ordering, and source/version
limits for every collection and hash. A Ruby accessor does not guarantee that every
parser or exporter supports the field. Contact fields and exported JSON are not
identical schemas: the current JSON exporter omits nil top-level values, retains
empty collections, serializes timestamps as ISO 8601, and adds the display `name`.
Do not generate a JSON schema simply by enumerating Contact accessors.

### Source extension (0.6.0 development)

Add `Archive#sources`, `LiveStore#sources`, and `Source` construction/readers,
`provider`, and `to_h` to the public inventory. Source JSON and `--sources` are
public contracts; see the [source API](../README.md#sources). `SourceCatalog`
is an internal adapter, not an extension point. File/container provenance must
remain distinct, and provider inference is unsupported. Contacts remain mutable
even though source metadata and membership snapshots are frozen.

## Internal and experimental boundaries

The 0.8.0 development vCard fidelity extension retains the exporter signatures
and adds their RBS contract. Wire output now uses CRLF, escapes/folding and grouped
raw labels; custom TYPE injection and fabricated preferences are removed. See
the [export migration](../README.md#export) and [evidence audit](ABBU.md#vcard-serialization-evidence).
`VcardDocument` and `VcardEncoding` are internal serialization helpers, not
public extension points. No claim of a complete Apple import round-trip is made.

The 0.7.0 development extension adds `Group` construction/readers, `include?`,
`to_h`, `Contact#group_memberships`, `Source#groups`, input `groups`, source/input
`groups_for`, `Query#in_group`, and `--groups`. See the [group API](../README.md#groups)
for snapshot identity, JSON schema, ordering, and unsupported group boundaries.
`GroupCatalog` is internal. Existing `Contact#groups` and contact exporter schemas
are unchanged; raw membership keys are available in the model and group listings.

Parser SQL/plist mappings, image-resolution heuristics, identity weights,
schema-inspection constants, private helpers, and `Utils::ContactIdentity` are
implementation details, not supported extension points. Prefer the entry points
and public results above over calling `Parsers::*` directly. Being a reachable
Ruby constant is not sufficient evidence of a supported extension contract.
Audit previously documented direct usage before hiding or removing any such API;
this classification does not authorize an immediate compatibility break.

Pre-1.0 does not mean disposable: documented behavior remains review-sensitive.
Live consistency, identity scoring/thresholds, private Apple schema coverage,
alternate-calendar interpretation, and Apple-specific vCard conventions remain
evidence-limited. Match scores are suggestions, not probabilities or proof of
identity. Raw labels/provenance must survive normalization and interchange.

## CLI and machine-output compatibility

The 0.4.0 CLI inventory is `--format` (`csv`, `json`, `vcard`), `--output`,
`--extract-images`, `--stats`, `--dedupe`, `--search`, `--email`, `--phone`,
`--json`, `--schema`, `--strict`, `--live`, `--live-path`, `--version`, and `--help`,
including documented short forms. Search returns status 0 for matches and 1 for
no matches; JSON no-match output is `[]`. Strict parser failures return 2.
Live input failures return 1. Other usage/error combinations need a complete
matrix before 1.0; do not claim that every existing path already follows one
unified exit-code scheme.

Treat JSON keys, types, omission/null behavior, ordering promises, diagnostic codes,
CLI flags, and exit statuses as public API. Renames/removals/type changes need
explicit compatibility review and migration guidance. Machine-mode stdout must
contain only the requested payload; warnings and errors belong on stderr. Clients
must not parse human presentation text. [Issue #39](https://github.com/scarver2/abbu/issues/39)
tracks remaining structured output and schema work. Freeze and version the schema
contract before 1.0; an unimplemented schema version must not be advertised today.

CSV headers/order and vCard version, CRLF, escaping, folding, Unicode, repeated
properties, raw labels, and photo behavior also need golden/round-trip coverage.
Portable SQLite and iCalendar are proposed formats, not current guarantees.

## Deprecation and versioning policy

For an intentional public change, document the old behavior, replacement, affected
consumers, migration example, and planned removal version before removal. Keep a
replacement available for at least one published minor release during pre-1.0;
once 1.x is stable, incompatible removals wait for a major release. Security or
data-loss emergencies require an explicitly approved, documented exception.
Runtime warnings, when appropriate, must be controllable and never pollute JSON
stdout or disclose contact values. No warning machinery is claimed to exist yet.

Follow Stan's release grouping rule: completed features receive minor bumps and
bug-fix-only releases receive patch bumps. A patch must not silently remove a
documented contract. Review incompatible pre-1.0 changes explicitly rather than
hiding them under a bug-fix label. Version bumps, green CI, and completed checklists
do not authorize tagging, merging, or publication; see [releasing](RELEASING.md).

## Required evidence before 1.0

- [ ] Audit and approve this inventory against the exact candidate commit, including
  new features integrated since 0.4.0; identify supported constructors and errors.
- [ ] Publish YARD/API documentation for every supported public method and result:
  arguments, returns, errors, mutation/caching, I/O, privacy, and runnable examples.
- [ ] Keep public RBS contracts synchronized with implementation and validate them;
  maintain tests for both documented success and failure behavior.
- [ ] Freeze CLI/JSON schemas and exit-code matrix with empty/error/Unicode fixtures;
  document migration and deprecation policy in release notes.
- [ ] Verify parser → model → interchange preservation of raw labels, timestamps,
  source evidence and images, including malformed and unsupported cases.
- [ ] Run supported Ruby CI (currently 3.3, 3.4, 4.0), 100% full-suite line coverage,
  lint, package inspection and isolated install against the candidate.
- [ ] Publish an evidence matrix: Ruby/SQLite versions, OS, Contacts build, storage
  layout, archive/live mode, tested fields, fixture provenance and known gaps.
  Synthetic fixtures with unknown Apple versions are not macOS certification.
- [ ] Complete the benchmark below and explicitly disposition performance gaps.
- [ ] Review sensitive-data exposure in exports, diagnostics, exception messages,
  `inspect`, absolute paths, image extraction, permissions, and future agent tools.
  Do not log real contacts, photos, verification codes, or provider identifiers in CI.
- [ ] Disposition each remaining backlog item as required, deferred, or unsupported
  with rationale; do not substitute feature count for a stability decision.
- [ ] Obtain Deputy exact-head review and separate Sheriff authorization for any
  1.0 tag/publication. This checklist itself does not authorize either.

## 10k+ performance acceptance

Before 1.0, provide a deterministic, non-personal 10,000-contact benchmark with
multiple sources, multivalues, Unicode, missing optional data, and a repeatable seed.
Measure archive and live-style synthetic parsing, query, CSV/JSON/vCard export,
and identity suggestions separately. Include a 100,000-contact scaling run for
streaming work in [#40](https://github.com/scarver2/abbu/issues/40).

Record exact commit, Ruby/SQLite versions, hardware/OS, fixture recipe, command,
wall time, peak RSS, output count/checksum, warmup, and at least three measured
runs. Report cold versus cached reads separately. Proposed gate: no unexplained
greater-than-20% median time or peak-RSS regression against the recorded baseline
on the same runner; any exception requires reviewer rationale. Establish absolute
budgets from measured evidence before approving 1.0, not invented timings here.
Streaming must demonstrate bounded contact-memory overhead at both scales;
materializing `contacts` is not a streaming benchmark. The current all-pairs
identity matcher needs its own scaling assessment, not a linear-memory promise.

## Linked gaps and adoption

See the [complete backlog](TODO.md#pre-10-backlog--not-included-in-040).
Important dependencies include WAL evidence [#28](https://github.com/scarver2/abbu/issues/28),
vCard fidelity/photos [#29](https://github.com/scarver2/abbu/issues/29) /
[#30](https://github.com/scarver2/abbu/issues/30), sources/groups
[#31](https://github.com/scarver2/abbu/issues/31) / [#32](https://github.com/scarver2/abbu/issues/32),
My Card/history/calendar research [#33](https://github.com/scarver2/abbu/issues/33) /
[#35](https://github.com/scarver2/abbu/issues/35) / [#36](https://github.com/scarver2/abbu/issues/36),
machine output [#39](https://github.com/scarver2/abbu/issues/39), streaming
[#40](https://github.com/scarver2/abbu/issues/40), and safe-writer research
[#46](https://github.com/scarver2/abbu/issues/46). Deferral may be acceptable if the
released support boundary is explicit. Never infer unsupported Apple semantics
to check off a gate.

Return to the [README](../README.md), [format evidence](ABBU.md), or
[contribution workflow](CONTRIBUTING.md).

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
