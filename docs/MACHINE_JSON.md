<!-- docs/MACHINE_JSON.md -->

# Machine JSON Contract

`--json` selects one structured operation with no human chatter on stdout.
Every handled success, no-match, validation, or input/output failure emits one
UTF-8 JSON document followed by a newline. This is buffered JSON, not streaming
JSON Lines. Consumers must inspect exit status before interpreting the document.
Broken output pipes and unexpected programmer errors are not guaranteed a JSON
response. Human CLI modes and `--format json` without `--json` remain unchanged.

## Operations

| Options | Success document | Empty result |
| --- | --- | --- |
| `--json` (optionally `--format json`) | Existing contact JSON array | `[]`, status 0 |
| `--search TERM --json`, `--email ADDRESS --json`, `--phone NUMBER --json` | Existing contact JSON array | `[]`, status 1 |
| Timestamp bounds plus `--json` | Existing contact JSON array | `[]`, status 1 |
| `--stats --json` | Integer `total_contacts`, `with_email`, `with_phone` | All zero, status 0 |
| `--schema --json` | Existing `schema_report` object | Empty `databases`, status 0 |
| `--sources --json` | Existing source metadata array | `[]`, status 0 |
| `--groups --json` | Existing group metadata array | `[]`, status 0 |
| `--dedupe --json` | Array of `{email, contacts}` | `[]`, status 0 |
| `--matches` (optional `--json`) | Identity suggestion array | `[]`, status 0 |
| `--diagnostics` (optional `--json`) | Parser diagnostic array after parsing | `[]`, status 0 |
| `--extract-images DIR --json` | `{files, diagnostics}` | Two empty arrays, status 0 |
| `--version --json`, `--help --json` | `{version}` or `{help}` strings | Not applicable |

Only one operation is allowed, except timestamp bounds can accompany one search.
`--output`, photo mode, or a non-JSON export format conflict with machine mode.
`--format json` may accompany bare `--json`, but not another operation. Validation
precedes input reads and image copying. Help/version terminate immediately as
before. Supply exactly one archive path, or `--live`/`--live-path PATH` with no
positional arguments. Live schema/search/extraction remain unsupported; live
stats, contacts, sources/groups, diagnostics, duplicates and matches are supported.
No live-store snapshot guarantee is added. `--strict` retains fail-fast parsing.

## Schemas And Meaning

Contact objects are exactly `JsonExporter#payload`: absent optional scalar
fields are omitted, existing empty collections remain arrays, provenance and
raw labels survive, and timestamps use the existing ISO 8601 representation.
This method is now public for callers needing Ruby hashes without serializing
and reparsing JSON. Source/group metadata and schema reports retain their
previous shapes. Do not depend on whitespace or JSON object key ordering.

Duplicate `email` is the existing first-email hash used by `Deduplicator#duplicates`,
not a newly normalized string. `contacts` contains the full contact objects.
`--matches` instead uses `Deduplicator#matches`: each object has full `left` and
`right` contacts, two `sources` (possibly null), `evidence` containing `type`,
`normalized`, `left_raw`, `right_raw`, numeric `score`, string `confidence`, and
string `status`. These are suggestions, not identity truth; no merge is performed.
Weak or competing candidates retain the existing ambiguity status.

Parser diagnostics contain `category`, `message`, `parser`, `source`, `context`.
With `--diagnostics` they appear on stdout only. For other machine operations,
nonfatal parser diagnostics stay on stderr as text and never corrupt stdout.
Schema inspection alone does not parse contacts or force parser diagnostics.

Image results contain `files` and extraction `diagnostics`. Each file includes
the full `contact`, raw `image_uri`, absolute string `source_path` and output
`path`, and `media_type`. Extraction diagnostics use the existing `code`,
`contact_name`, `image_uri`, and optional `source_path`/`detail`. Partial copies
and collisions are reported in that array with status 0, as in existing
extraction; callers must inspect diagnostics to require complete extraction.
Directory creation failures instead produce an error and status 1. Source
archives remain read-only; extraction creates separate files without overwriting.

## Errors And Exit Codes

| Status | Meaning in machine mode |
| --- | --- |
| 0 | Operation completed (possibly with nonfatal diagnostics) |
| 1 | Search had no matches (`[]`), or live input/filesystem failure (`error` object) |
| 2 | Invalid options/input, conflicting operations, invalid timestamp, or parse failure |

Errors have exactly the shape `{"error":{"code":"invalid_input","message":"..."}}`.
Codes are `invalid_option` for option parsing, `invalid_input` for validation or
parse failures, and `input_output_error` for live access/filesystem errors.
Messages aid humans; branch on the code and exit status, not message wording.
Parser diagnostics can still appear on stderr after a strict failure.

Migration from 0.9: JSON failures now produce this document rather than empty
stdout; previously ignored operation combinations are rejected. Bare `--json`
now lists contacts. Search no-match status and successful legacy JSON shapes are
unchanged. Human CLI error behavior is not normalized by this change.

## Automation And Privacy

```bash
abbu Contacts.abbu --stats --json >stats.json 2>diagnostics.log
abbu Contacts.abbu --diagnostics >parser-diagnostics.json
abbu Contacts.abbu --matches >identity-suggestions.json 2>diagnostics.log
abbu Contacts.abbu --sources --json | jq '.[].contact_count'

# Do not let jq's status hide ABBU's failure; inspect the producer first.
if abbu Contacts.abbu --email person@example.test --json >result.json 2>diagnostics.log; then
  jq '.[].name' result.json
else
  status=$?
  printf 'ABBU status: %s\n' "$status" >&2
  jq . result.json
fi
```

All outputs are sensitive. Full contact/identity/image payloads expose contact
values, raw labels, identifiers, photo paths and provenance; image extraction
also writes photos. Parser diagnostics deliberately retain the existing limited
contexts, but paths and messages can identify local accounts. Schema/source/group
reports are not sanitized logs. Error messages may contain caller paths or input.
JSON does not grant permission to send any of this to a remote agent, store it in
public CI artifacts, or publish logs. Use controlled destinations and permissions.
No Apple-private semantics are inferred by these serializers.

JSON schemas are public API under the repository's pre-1.0 SemVer policy.
Breaking shape/type/meaning changes require explicit migration notes and a minor
version; compatible bug fixes use a patch. Future diff/history or optional MCP
adapters should consume these public representations without changing established
operations or imposing an MCP runtime dependency on ABBU core.

See [README](../README.md), [API stability](API_STABILITY.md), and
[format evidence](ABBU.md).

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
