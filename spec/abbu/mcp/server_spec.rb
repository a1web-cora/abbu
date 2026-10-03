# spec/abbu/mcp/server_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'abbu/mcp'
require 'json'
require 'open3'

RSpec.describe Abbu::Mcp::Server do
  let(:fixture) { File.expand_path('../../fixtures/TestContacts.abbu', __dir__) }
  let(:adapter) { described_class.new(path: fixture) }

  def call_tool(name, arguments = {})
    adapter.server.tools.fetch(name).call(**arguments).to_h
  end

  it 'defines only read tools with bounded input and structured output schemas' do
    expect(adapter.server.configuration.validate_tool_call_results?).to be(true)
    expect(adapter.server.tools.keys).to contain_exactly(
      'abbu_query', 'abbu_stats', 'abbu_sources', 'abbu_groups', 'abbu_diagnostics'
    )
    adapter.server.tools.each_value do |tool|
      expect(tool.to_h).to include(
        annotations: include(readOnlyHint: true, destructiveHint: false, openWorldHint: false),
        inputSchema: include(additionalProperties: false), outputSchema: include(type: 'object')
      )
    end
  end

  it 'returns the same deterministic JSON in structured content and text, without logging' do
    first = nil
    expect { first = call_tool('abbu_stats') }.not_to output.to_stderr
    second = call_tool('abbu_stats')
    expect(first).to eq(second)
    expect(first).to include(
      isError: false, structuredContent: { data: { total_contacts: 3, with_email: 2, with_phone: 2 } }
    )
    expect(JSON.parse(first[:content].first[:text])).to eq(JSON.parse(JSON.generate(first[:structuredContent])))
    expect { adapter.server.configuration.exception_reporter.call(StandardError.new('private'), {}) }
      .not_to output.to_stderr
  end

  it 'returns tool-level errors without echoing sensitive input values or parser exceptions' do
    response = call_tool('abbu_query', mode: 'modified_since', value: 'private@example.test')
    expect(response).to include(isError: true, structuredContent: include(error: include(code: 'invalid_query')))
    expect(JSON.generate(response)).not_to include('private@example.test')
    strict_adapter = described_class.new(path: fixture, strict: true)
    response = strict_adapter.server.tools.fetch('abbu_stats').call.to_h
    expect(response).to include(isError: true, structuredContent: include(error: include(code: 'read_failed')))
    expect(JSON.generate(response)).not_to include(fixture)
  end

  it 'supports explicitly configured live inputs without exposing a path-changing tool' do
    server = described_class.new(path: fixture, live: true).server
    expect(server.tools.fetch('abbu_stats').call.to_h[:structuredContent][:data][:total_contacts]).to eq(3)
    expect(server.tools.fetch('abbu_query').input_schema_value.to_h[:properties]).not_to have_key(:path)
  end

  it 'never auto-discovers a live store from a missing or blank configured path' do
    expect { described_class.new(path: nil, live: true) }.to raise_error(ArgumentError, /explicit nonempty/)
    expect { described_class.new(path: ' ', live: true) }.to raise_error(ArgumentError, /explicit nonempty/)
  end

  it 'delegates stdio lifecycle to the official SDK' do
    transport = instance_double(MCP::Server::Transports::StdioTransport, open: nil)
    allow(MCP::Server::Transports::StdioTransport).to receive(:new).with(adapter.server).and_return(transport)
    adapter.open
    expect(transport).to have_received(:open)
  end
end
