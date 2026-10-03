# spec/mcp_cli_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'

RSpec.describe 'optional MCP stdio boundary' do # rubocop:disable RSpec/DescribeClass
  let(:bin) { File.expand_path('../bin/abbu-mcp', __dir__) }
  let(:fixture) { File.expand_path('fixtures/TestContacts.abbu', __dir__) }

  def exchange(request, *options)
    messages = [
      { jsonrpc: '2.0', id: 1, method: 'initialize',
        params: { protocolVersion: '2025-11-25', capabilities: {},
                  clientInfo: { name: 'synthetic-test', version: '1' } } },
      { jsonrpc: '2.0', method: 'notifications/initialized' },
      { jsonrpc: '2.0', id: 2, method: 'tools/call', params: request }
    ]
    input = "#{messages.map { |message| JSON.generate(message) }.join("\n")}\n"
    stdout, stderr, status = Open3.capture3(bin, fixture, *options, stdin_data: input)
    [stdout.lines.map { |line| JSON.parse(line) }.find { |row| row['id'] == 2 }, stderr, status]
  end

  it 'negotiates and returns structured read results without stderr logging' do
    requests = [
      { jsonrpc: '2.0', id: 1, method: 'initialize',
        params: { protocolVersion: '2025-11-25', capabilities: {},
                  clientInfo: { name: 'synthetic-test', version: '1' } } },
      { jsonrpc: '2.0', method: 'notifications/initialized' },
      { jsonrpc: '2.0', id: 2, method: 'tools/list' },
      { jsonrpc: '2.0', id: 3, method: 'tools/call', params: { name: 'abbu_stats', arguments: {} } },
      { jsonrpc: '2.0', id: 4, method: 'tools/call', params: { name: 'abbu_stats', arguments: { path: '/private' } } }
    ]
    input = "#{requests.map { |request| JSON.generate(request) }.join("\n")}\n"
    stdout, stderr, status = Open3.capture3(bin, fixture, stdin_data: input)
    responses = stdout.lines.map { |line| JSON.parse(line) }
    expect(status.exitstatus).to eq(0)
    expect(stderr).to be_empty
    expect(responses.find { |row| row['id'] == 1 }).to include('result' => include('serverInfo'))
    expect(responses.find { |row| row['id'] == 2 }.dig('result', 'tools').length).to eq(5)
    stats = responses.find { |row| row['id'] == 3 }.dig('result', 'structuredContent', 'data')
    expect(stats).to include('total_contacts' => 3)
    expect(responses.find { |row| row['id'] == 4 }).to include('result' => include('isError' => true))
  end

  it 'fails before opening a server on invalid configuration without exposing paths' do
    [[], %w[--live-path /missing extra], ['/missing-private-abbu'], ['--unknown']].each do |arguments|
      stdout, stderr, status = Open3.capture3(bin, *arguments)
      expect(stdout).to be_empty
      expect(stderr).to include('invalid configuration or unavailable input')
      expect(stderr).not_to include('/missing-private-abbu')
      expect(status.exitstatus).to eq(2)
    end
  end

  it 'returns adapter query errors through the real SDK with success output validation enabled' do
    request = { name: 'abbu_query', arguments: { mode: 'modified_since', value: 'private@example.test' } }
    reply, stderr, status = exchange(request)
    expect(reply).not_to have_key('error')
    result = reply.fetch('result')
    expect(result).to include('isError' => true)
    expect(result.fetch('structuredContent')).to eq(
      'error' => { 'code' => 'invalid_query', 'message' => 'Check mode, timestamp and pagination.' }
    )
    expect(JSON.parse(result.fetch('content').first.fetch('text'))).to eq(result.fetch('structuredContent'))
    expect(JSON.generate(reply)).not_to include('private@example.test')
    expect(stderr).to be_empty
    expect(status.exitstatus).to eq(0)
  end

  it 'returns adapter read errors rather than output-schema protocol errors through the real SDK' do
    reply, stderr, status = exchange({ name: 'abbu_stats', arguments: {} }, '--strict')
    expect(reply).not_to have_key('error')
    result = reply.fetch('result')
    expect(result).to include('isError' => true)
    expect(result.fetch('structuredContent')).to eq(
      'error' => { 'code' => 'read_failed', 'message' => 'Unable to read the configured input.' }
    )
    expect(JSON.parse(result.fetch('content').first.fetch('text'))).to eq(result.fetch('structuredContent'))
    expect(JSON.generate(reply)).not_to include(fixture)
    expect(stderr).to be_empty
    expect(status.exitstatus).to eq(0)
  end

  it 'keeps the SDK optional when only the core is loaded' do
    code = "require 'abbu'; abort 'MCP loaded' if defined?(MCP); " \
           "deps = Gem::Specification.load('abbu.gemspec').runtime_dependencies; " \
           "abort 'mandatory MCP dependency' if deps.any? { |d| d.name == 'mcp' }"
    _stdout, stderr, status = Open3.capture3('ruby', '-Ilib', '-e', code)
    expect(status.exitstatus).to eq(0)
    expect(stderr).to be_empty
  end

  it 'provides help without reading a configured input' do
    stdout, stderr, status = Open3.capture3(bin, '--help')
    expect(stdout).to include('Usage: abbu-mcp')
    expect(stderr).to be_empty
    expect(status.exitstatus).to eq(0)
  end

  it 'reports a missing optional SDK without an exception trace' do
    code = 'module Kernel; alias original_require require; ' \
           "def require(path); raise LoadError if path == 'abbu/mcp'; original_require(path); end; end; load ARGV.shift"
    stdout, stderr, status = Open3.capture3('ruby', '-e', code, bin, fixture)
    expect(stdout).to be_empty
    expect(stderr).to include('install the optional mcp SDK')
    expect(status.exitstatus).to eq(2)
  end
end
