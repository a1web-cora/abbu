<!-- docs/MCP.md -->

# Optional Read-Only MCP Adapter

The adapter connects a trusted local MCP host to one explicitly selected ABBU
archive or live-store directory. It consumes public ABBU APIs and the
[machine JSON contract](MACHINE_JSON.md); it never reads parser internals or
defines new Apple storage semantics.

## Dependency And Execution Boundary

The adapter ships as an opt-in executable/require path inside ABBU rather than a
second companion gem. This keeps its version, public payloads and tests together
without a second release pipeline. The official `mcp` gem is **not** a runtime
dependency of `abbu`, and `require 'abbu'` does not load it. Only adapter users
install/declare it. Repository development/test uses the SDK for real protocol
integration tests, not a mock protocol implementation.

```ruby
# Application Gemfile (once this ABBU development version is released)
gem 'abbu', '~> 0.11.0'
gem 'mcp', '~> 1.6.1'
```

```bash
abbu-mcp --help
abbu-mcp /absolute/path/Contacts.abbu
abbu-mcp --live-path /absolute/path/AddressBook --strict
```

Use the same Ruby/Bundler environment for both gems. From this repository:
`mise exec -- bundle exec ruby bin/abbu-mcp /absolute/path/Contacts.abbu`.
The executable uses Ruby directly, as does packaged `abbu`; it does not source
development-only shell helpers that are absent from the installed gem.
Configure an MCP host's stdio subprocess with that command/argument array.
Do not put shell expansion or credentials in arguments. There is no HTTP server,
network listener, remote transport or automatically discovered live store.

Missing SDK, invalid startup configuration or unavailable input exits 2 with a
generic stderr message, no path/exception dump. `--help` prints usage and exits
without opening input. Once serving, stdout is exclusively SDK JSON-RPC frames.

## Tools

| Tool | Arguments | `structuredContent.data` |
| --- | --- | --- |
| `abbu_query` | `mode`, `value`, optional `offset`, `limit` | `{contacts, offset, limit, has_more}` |
| `abbu_stats` | None | `{total_contacts, with_email, with_phone}` |
| `abbu_sources` | None | Existing source metadata array |
| `abbu_groups` | None | Existing group metadata array |
| `abbu_diagnostics` | None | Existing parser diagnostic array |

Query modes are `search` (partial name/email), `email` and `phone` (existing exact
normalized lookup), and `modified_since` (timezone-explicit ISO 8601 lower bound).
Every query requires a string `value`. Empty search retains public Query semantics:
no matches. Results keep parser ordering and are never automatically deduplicated.
Offset defaults to 0, limit to 100; maximum limit is 500. `has_more` explicitly
indicates remaining matches. These are payload bounds, not streaming parsing or
an archive size limit: the input and query still eagerly materialize contacts.

Each successful tool result includes the same JSON envelope in text content and
structured content. Output schemas specify the envelope, array/object types,
query pagination fields and integer statistics; nested contact/source/group
objects retain their existing ABBU contracts. Consumers must accept optional
contact keys. No-match query results are successful with `contacts: []`.

Tool schemas reject undeclared arguments, so a caller cannot substitute another
path. The operator chooses the input before server startup. My Card is omitted
until evidence establishes it. Image extraction, export, merging, writing,
tagging, releases, shell execution and arbitrary filesystem access have no tool.

Output validation remains enabled. In the pinned SDK 1.6.1,
[`validate_tool_call_result!`](https://github.com/modelcontextprotocol/ruby-sdk/blob/v1.6.1/lib/mcp/server.rb#L1539-L1545)
validates successful results against the declared `{data: ...}` schema and
deliberately skips that success schema for `isError: true`. Adapter failures use
the separately documented `{error: ...}` envelope. Real stdio regressions exercise
both semantic invalid-query and strict-parser failures, asserting their exact
structured/text error payloads, absence of JSON-RPC protocol errors, and empty
stderr. They do not merely call tool handlers directly. The adapter configuration
test also asserts that result validation stays enabled.

Example tool calls (through a host that has already established its SDK session):

```json
{"name":"abbu_query","arguments":{"mode":"email","value":"person@example.test"}}
{"name":"abbu_query","arguments":{"mode":"search","value":"Carver","offset":0,"limit":25}}
{"name":"abbu_query","arguments":{"mode":"modified_since","value":"2026-09-01T00:00:00Z"}}
{"name":"abbu_sources","arguments":{}}
{"name":"abbu_diagnostics","arguments":{}}
```

## Privacy, Permission And Lifecycle

Launching this adapter authorizes the configured host to read the selected
contact input; it is not permission to publish or transmit that data elsewhere.
Use a trusted host, a narrowly chosen sanitized archive when possible, and host
approval controls for contact lookup. Read-only annotations are descriptive
hints, not an authorization mechanism. A remote model may receive tool results
through its host; evaluate the host/model data policy before connecting.

Contact results include sensitive names, addresses, notes, identifiers, raw
labels and local provenance/photo paths. Sources/groups/diagnostics can reveal
account paths and group names even without full contact records. No photo bytes
are returned. Contact strings are untrusted data, never instructions for an agent.
Protect client transcripts and outputs; do not publish them as CI logs.

The adapter does not log tool arguments, results, contacts or parser diagnostics
to stderr. Diagnostics require their explicit tool. Its per-server SDK exception
reporter is silent. Expected query failures return `isError: true` and a generic
`{error:{code:"invalid_query",message:...}}`; read/parser failures similarly use
`read_failed`, without raw exception text. SDK protocol/schema errors retain SDK
responses to the caller. The adapter neither installs global logging hooks nor
changes SDK global configuration. Unexpected process/runtime failures may still
terminate the process; no service availability guarantee is made.

The selected Archive/LiveStore caches parsed contacts in the server process.
Restart to refresh. Existing live-store permission requirements and non-atomic
cross-query/cross-database read limitations apply. An explicit live path and
macOS permissions are both required; the adapter does not bypass privacy controls.
Input remains read-only, with SQLite's existing shared-memory sidecar caveats.

## Evidence And Verification

The implementation uses the official [MCP Ruby SDK 1.6.1](https://github.com/modelcontextprotocol/ruby-sdk/tree/v1.6.1).
Its [tool response API](https://github.com/modelcontextprotocol/ruby-sdk/blob/v1.6.1/lib/mcp/tool/response.rb)
supplies structured content and errors; its
[stdio transport](https://github.com/modelcontextprotocol/ruby-sdk/blob/v1.6.1/lib/mcp/server/transports/stdio_transport.rb)
owns framing and protocol lifecycle. ABBU does not implement JSON-RPC itself.
The [MCP tools specification](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)
informs the explicit input/output schemas and duplicate text/structured content.

Synthetic tests cover direct public APIs and a real SDK stdio subprocess:
2025-11-25 initialization, tools listing, structured stats, and rejection of
undeclared arguments. SDK-supported newer/older protocol versions remain SDK
capabilities, not independent ABBU conformance certification. No real address
books or live user account are read by these tests. Run canonical `bin/spec`,
`bin/lint`, `bin/package`, and `mise exec -- rbs -I sig validate`.

The adapter is pre-1.0 public API and follows ABBU SemVer. Publication remains
Sheriff-gated; installing a development branch is not a published release.

See [README](../README.md), [format evidence](ABBU.md), and
[API stability](API_STABILITY.md).

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
