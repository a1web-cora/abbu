# spec/abbu/archive_streaming_spec.rb
# frozen_string_literal: true

require 'json'
require 'open3'
require 'spec_helper'
require 'stringio'
require 'tmpdir'

RSpec.describe Abbu::Archive do
  let(:sqlite) { File.expand_path('../fixtures/TestContacts.abbu', __dir__) }
  let(:plist) { File.expand_path('../fixtures/PlistContacts.abbu', __dir__) }

  it 'preserves archive SQLite and legacy plist results without materializing contacts' do
    [sqlite, plist].each do |path|
      archive = Abbu.open(path)
      expected = Abbu::Exporters::JsonlExporter.new(Abbu.open(path).contacts)
      expected_io = StringIO.new
      expected.write_to(expected_io)
      allow(archive).to receive(:contacts).and_call_original
      actual_io = StringIO.new
      Abbu::Exporters::JsonlExporter.new(archive.each_contact).write_to(actual_io)
      expect(actual_io.string).to eq(expected_io.string)
      expect(archive).not_to have_received(:contacts)
      expect(archive.instance_variable_defined?(:@contacts)).to be(false)
    end
  end

  it 'preserves live read-only provenance and closes readers on early break or consumer exceptions' do
    handles = []
    allow(SQLite3::Database).to receive(:new).and_wrap_original do |original, *args, **kwargs|
      expect(kwargs).to eq(readonly: true)
      original.call(*args, **kwargs).tap { |db| handles << db }
    end
    store = Abbu.open_live(sqlite)
    expect(store.each_contact.first.source[:relative_path]).to include('.abcddb')
    expect(handles).to all(be_closed)
    expect { store.each_contact { |contact| raise 'consumer failure' if contact } }
      .to raise_error(RuntimeError, 'consumer failure')
    expect(handles).to all(be_closed)
    expect(store.each_contact.to_a.length).to be_positive
    expect(store.instance_variable_defined?(:@contacts)).to be(false)
  end

  it 'retains strict diagnostics, malformed recovery and required-schema failure' do
    expect { Abbu.open(sqlite, strict: true).each_contact.to_a }.to raise_error(Abbu::ParseError)
    Dir.mktmpdir do |path|
      File.write(File.join(path, 'broken.abcdp'), 'broken')
      archive = Abbu.open(path)
      expect(archive.each_contact.to_a).to be_empty
      expect(archive.diagnostics.first.category).to eq(:malformed_record)
      SQLite3::Database.new(File.join(path, 'AddressBook-v22.abcddb')).close
      expect { Abbu.open(path).each_contact.to_a }.to raise_error(Abbu::ParseError)
    end
  end

  it 'reports streaming live-store permission failures' do
    store = Abbu.open_live(sqlite)
    allow(SQLite3::Database).to receive(:new).and_raise(SQLite3::CantOpenException)
    expect { store.each_contact.to_a }.to raise_error(Abbu::LiveStore::PermissionError)
  end

  it 'writes CSV, JSONL and vCard incrementally and leaves caller-owned IO open' do
    [Abbu::Exporters::CsvExporter, Abbu::Exporters::JsonlExporter, Abbu::Exporters::VcardExporter].each do |klass|
      io = StringIO.new
      input = Enumerator.new do |yielder|
        yielder << Abbu::Contact.new
        expect(io.string).not_to be_empty
        yielder << Abbu::Contact.new
      end
      expect(klass.new(input).write_to(io)).to be_nil
      expect(io).not_to be_closed
    end
  end

  it 'preserves JSON contact fields and supports JSONL files and stdout' do
    contact = Abbu.open(plist).contacts.first
    exporter = Abbu::Exporters::JsonlExporter.new([contact])
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'out.jsonl')
      exporter.to_file(path)
      expect(JSON.parse(File.read(path))['first_name']).to eq(contact.first_name)
      expect { exporter.to_stdout }.to output(File.read(path)).to_stdout
    end
  end

  it 'exposes explicit CLI streaming and rejects incompatible modes' do
    executable = File.expand_path('../../bin/abbu', __dir__)
    %w[csv jsonl vcard].each do |format|
      stdout, _stderr, status = Open3.capture3(RbConfig.ruby, executable, plist, '--stream', '--format', format)
      expect(status.exitstatus).to eq(0)
      expect(stdout).not_to be_empty
    end
    _stdout, stderr, status = Open3.capture3(RbConfig.ruby, executable, plist, '--stream', '--format', 'json')
    expect(status.exitstatus).to eq(2)
    expect(stderr).to include('--stream requires')
  end

  it 'rejects machine streaming with structured errors before input access' do
    executable = File.expand_path('../../bin/abbu', __dir__)
    %w[--json --matches --diagnostics].each do |mode|
      stdout, stderr, status = Open3.capture3(RbConfig.ruby, executable, '/missing.abbu', '--stream', mode)
      expect(JSON.parse(stdout)).to include('error' => include('code' => 'invalid_input'))
      expect(stderr).to be_empty
      expect(status.exitstatus).to eq(2)
    end
  end

  it 'rejects newer buffered operations before reading or opening stream output' do
    executable = File.expand_path('../../bin/abbu', __dir__)
    conflicts = [%w[--diff /also-missing.abbu], %w[--merge-preview], %w[--merge-policy prefer_newer],
                 %w[--prefer-source Example], %w[--calendar-year 2026],
                 %w[--calendar-stamp 2026-10-03T00:00:00Z], %w[--calendar-id example],
                 %w[--format sqlite], %w[--format icalendar]]
    Dir.mktmpdir do |directory|
      flags = ['--stream', '--format', 'csv', '--output', File.join(directory, 'never.csv')]
      conflicts.each do |options|
        stdout, stderr, status = Open3.capture3(RbConfig.ruby, executable, '/missing.abbu', *flags, *options)
        expect(stdout).to be_empty
        expect(stderr).to include('--stream requires')
        expect(status.exitstatus).to eq(2)
        expect(Dir.children(directory)).to be_empty
      end
    end
  end
end
