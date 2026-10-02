# spec/abbu/machine_command_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'abbu/machine_command'
require 'json'
require 'stringio'
require 'tmpdir'

RSpec.describe Abbu::MachineCommand do
  let(:fixture) { File.expand_path('../fixtures/TestContacts.abbu', __dir__) }
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }

  def run_command(options = {}, arguments = [fixture])
    status = described_class.new(options, arguments, stdout: stdout, stderr: stderr).run
    [JSON.parse(stdout.string), status]
  end

  it 'uses the unchanged contact exporter schema, including provenance and raw labels' do
    payload, status = run_command
    expected = JSON.parse(JSON.generate(Abbu::Exporters::JsonExporter.new(Abbu.open(fixture).contacts).payload))
    expect(payload).to eq(expected)
    expect(status).to eq(0)
    expect(stderr.string).to include('missing_optional_data')
  end

  it 'reports typed statistics without presentation text' do
    payload, status = run_command(stats: true)
    expect(payload).to eq('total_contacts' => 3, 'with_email' => 2, 'with_phone' => 2)
    expect(status).to eq(0)
  end

  it 'returns diagnostics without contact values or duplicated stderr' do
    payload, status = run_command(diagnostics: true)
    expect(payload).to all(include('category', 'message', 'parser', 'source', 'context'))
    expect(stdout.string).not_to include('homer@globex.com', 'stan-photo')
    expect(stderr.string).to be_empty
    expect(status).to eq(0)
  end

  it 'does not retain input diagnostics when a reused command fails validation' do
    options = { stats: true }
    command = described_class.new(options, [fixture], stdout: stdout, stderr: stderr)
    expect(command.run).to eq(0)
    expect(stderr.string).not_to be_empty
    stdout.truncate(0)
    stdout.rewind
    stderr.truncate(0)
    stderr.rewind
    options[:groups] = true
    expect(command.run).to eq(2)
    expect(JSON.parse(stdout.string)).to include('error' => include('code' => 'invalid_input'))
    expect(stderr.string).to be_empty
  end

  it 'preserves source and group metadata schemas' do
    payload, status = run_command(sources: true)
    expect(payload).to all(include('relative_path', 'files', 'provider' => nil))
    expect(status).to eq(0)
    stdout.truncate(0)
    stdout.rewind
    payload, status = run_command(groups: true)
    expect(payload).to all(include('record_id', 'name', 'source', 'contact_count'))
    expect(status).to eq(0)
  end

  it 'emits schema evidence without parsing contacts' do
    payload, status = run_command(schema: true)
    expect(payload.fetch('databases').length).to eq(2)
    expect(status).to eq(0)
    expect(stderr.string).to be_empty
  end

  it 'keeps no-match search distinct from an empty successful listing' do
    payload, status = run_command(search: 'no such name')
    expect(payload).to eq([])
    expect(status).to eq(1)
  end

  it 'supports email lookup with timestamp filters' do
    filters = { created_at: { since: '2001-01-01T00:00:00Z' } }
    payload, status = run_command(email: 'JOHN@EXAMPLE.COM', date_filters: filters)
    expect(payload).to contain_exactly(include('first_name' => 'Stan'))
    expect(status).to eq(0)
  end

  it 'supports phone lookup' do
    payload, status = run_command(phone: '5550201')
    expect(payload).to contain_exactly(include('name' => 'Homer Simpson'))
    expect(status).to eq(0)
  end

  it 'supports timestamp-only queries' do
    payload, status = run_command(date_filters: { created_at: { since: '2001-01-01T00:00:00Z' } })
    expect(payload).not_to be_empty
    expect(status).to eq(0)
  end

  it 'returns structured strict failures without partial contact output' do
    payload, status = run_command(stats: true, strict: true)
    expect(payload).to include('error' => include('code' => 'invalid_input'))
    expect(status).to eq(2)
  end

  it 'supports live stats and retains live access failure status' do
    payload, status = run_command({ live_path: fixture, stats: true }, [])
    expect(payload.fetch('total_contacts')).to eq(3)
    expect(status).to eq(0)
    stdout.truncate(0)
    stdout.rewind
    payload, status = run_command({ live_path: '/missing/abbu-machine-store', stats: true }, [])
    expect(payload).to include('error' => include('code' => 'input_output_error'))
    expect(status).to eq(1)
  end

  it 'returns empty valid structures for empty inputs' do
    Dir.mktmpdir do |directory|
      payload, status = run_command({ matches: true }, [directory])
      expect(payload).to eq([])
      expect(status).to eq(0)
    end
  end

  it 'supports the legacy duplicate report in structured form' do
    payload, status = run_command(dedupe: true)
    expect(payload).to eq([])
    expect(status).to eq(0)
  end

  it 'serializes extraction results and collision diagnostics without object inspection strings' do
    Dir.mktmpdir do |directory|
      payload, status = run_command(extract_images: directory)
      expect(payload.fetch('files')).to contain_exactly(
        include('contact' => include('name'), 'media_type' => 'image/jpeg')
      )
      expect(payload.fetch('files').first.fetch('path')).to start_with(File.realpath(directory))
      expect(status).to eq(0)
      stdout.truncate(0)
      stdout.rewind
      payload, status = run_command(extract_images: directory)
      expect(payload.fetch('diagnostics')).to include(include('code' => 'destination_exists'))
      expect(payload.fetch('files')).to eq([])
      expect(status).to eq(0)
    end
  end

  it 'reports destination filesystem failures as a JSON error' do
    payload, status = run_command(extract_images: File.join(fixture, 'AddressBook-v22.abcddb', 'child'))
    expect(payload).to include('error' => include('code' => 'input_output_error'))
    expect(status).to eq(1)
  end

  [
    [{}, []], [{}, %w[first second]], [{ live: true, live_path: '/missing' }, []],
    [{ live_path: '/missing', schema: true }, []], [{ live_path: '/missing', search: 'a' }, []],
    [{ stats: true, groups: true }, ['unused']], [{ search: 'a', email: 'b' }, ['unused']],
    [{ output: 'unused.json' }, ['unused']], [{ photo_mode: :embedded }, ['unused']],
    [{ format: 'csv' }, ['unused']], [{ format: 'json', stats: true }, ['unused']]
  ].each do |options, arguments|
    it "rejects conflicting input/options #{options.inspect} #{arguments.inspect} before reading or writing" do
      payload, status = run_command(options, arguments)
      expect(payload).to include('error' => include('code' => 'invalid_input'))
      expect(status).to eq(2)
    end
  end
end
