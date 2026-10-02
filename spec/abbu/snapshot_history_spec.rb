# spec/abbu/snapshot_history_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'json'
require 'open3'
require 'tmpdir'

RSpec.describe Abbu::SnapshotHistory do
  def contact(name = 'Synthetic', email = 'synthetic@example.test')
    Abbu::Contact.new.tap do |record|
      record.first_name = name
      record.emails = [email]
    end
  end

  def history(collections, **options)
    allow(Abbu::Archive).to receive(:new).and_call_original
    paths = collections.each_with_index.map do |contacts, index|
      path = "/synthetic/#{index}.abbu"
      archive = instance_double(Abbu::Archive, contacts: contacts, diagnostics: [])
      allow(Abbu::Archive).to receive(:new).with(path, strict: false).and_return(archive)
      path
    end
    described_class.new(paths, **options)
  end

  it 'tracks deterministic adjacent observations with field changes and source snapshot links' do
    analysis = history([[contact], [contact('Changed')], [contact('Changed')]])
    result = analysis.to_a
    expect(result.map { |item| item[:snapshot][:index] }).to eq([0, 1, 2])
    observations = result.flat_map { |item| item[:observations] }
    expect(observations.map { |item| item[:timeline_id] }).to eq([1, 1, 1])
    expect(observations.map { |item| item[:event] }).to eq(%i[first_seen observed observed])
    expect(observations[1][:changes][:first_name]).to eq(before: 'Synthetic', after: 'Changed')
    expect(observations[1][:compared_with]).to eq(index: 0, path: '/synthetic/0.abbu')
    expect(observations.last[:first_seen][:index]).to eq(0)
    expect(observations.last[:last_seen][:index]).to eq(2)
    expect(analysis.to_a).to eq(result)
    expect(analysis.each { |_item| nil }).to equal(analysis)
  end

  it 'reports absence once and bounded-window reappearance without inferring intermediate events' do
    result = history([[contact], [], [], [contact('Returned')]]).to_a
    expect(result[1][:absent].first).to include(timeline_id: 1, event: :absent)
    expect(result[2][:absent]).to be_empty
    returned = result.last[:observations].first
    expect(returned).to include(timeline_id: 1, event: :reappeared)
    expect(returned[:compared_with][:index]).to eq(0)
    expect(history([[contact], [], [contact]], retention: 0).to_a.last[:observations].first)
      .to include(timeline_id: 2, event: :first_seen)
  end

  it 'breaks ambiguous continuity permanently rather than reviving a retained original' do
    result = history([[contact], [contact, contact], [], [contact]]).to_a
    expect(result[1][:ambiguous].map { |pair| pair[:before_timeline_id] }).to eq([1, 1])
    expect(result[1][:observations].map { |item| item[:event] }).to eq(%i[ambiguous_start ambiguous_start])
    expect(result[1][:observations].map { |item| item[:timeline_id] }).to eq([2, 3])
    expect(result.last[:observations].first).to include(timeline_id: 4, event: :ambiguous_start)
    expect(result.last[:ambiguous].map { |pair| pair[:before_timeline_id] }).to eq([2, 3])
  end

  it 'validates limits and stops explicitly at snapshot, pool and pair bounds' do
    expect { described_class.new([], limits: { snapshots: 0 }) }.to raise_error(ArgumentError)
    expect { described_class.new([], limits: { unknown: 1 }) }.to raise_error(ArgumentError)
    expect { described_class.new([], retention: -1) }.to raise_error(ArgumentError)
    expect { described_class.new(%w[a b], limits: { snapshots: 1 }) }.to raise_error(ArgumentError, /max_snapshots/)
    expect { described_class.new(%w[a a]) }.to raise_error(ArgumentError, /unique/)
    expect { history([[contact, contact]], limits: { contacts: 1 }).to_a }.to raise_error(ArgumentError, /max_contacts/)
    expect { history([[contact], [contact('Other', 'other@example.test')]], limits: { contacts: 1 }).to_a }
      .to raise_error(ArgumentError, /retained/)
    expect { history([[contact], [contact, contact]], limits: { pairs: 1 }).to_a }
      .to raise_error(ArgumentError, /max_pairs/)
    expect(described_class.new([]).to_a).to eq([])
  end

  it 'keeps a long ordered stream within one-contact/pair bounds and exposes parser diagnostics' do
    analysis = history(Array.new(50) { [contact] }, limits: { contacts: 1, pairs: 1 })
    expect(analysis.count).to eq(50)
    fixture = File.expand_path('../fixtures/TestContacts.abbu', __dir__)
    expect(described_class.new([fixture]).first[:diagnostics]).not_to be_empty
    expect { described_class.new([fixture], strict: true).first }.to raise_error(Abbu::ParseError)
  end

  it 'loads lexically ordered immediate bundle directories and streams CLI JSON Lines' do
    fixture = File.expand_path('../fixtures/PlistContacts.abbu', __dir__)
    executable = File.expand_path('../../bin/abbu', __dir__)
    Dir.mktmpdir do |directory|
      FileUtils.cp_r(fixture, File.join(directory, '02.abbu'))
      FileUtils.cp_r(fixture, File.join(directory, '01.abbu'))
      FileUtils.mkdir_p(File.join(directory, 'ignored'))
      rows = described_class.from_directory(directory).to_a
      expect(rows.map { |row| File.basename(row[:snapshot][:path]) }).to eq(%w[01.abbu 02.abbu])
      stdout, stderr, status = Open3.capture3(executable, directory, '--history')
      expect(stdout.lines.map { |line| JSON.parse(line)['schema_version'] }).to eq([1, 1])
      expect(stderr).to be_empty
      expect(status.exitstatus).to eq(0)
      stdout, stderr, status = Open3.capture3(executable, directory, '--history', '--json')
      expect(stdout).to be_empty
      expect(stderr).to include('--history supports only')
      expect(status.exitstatus).to eq(2)
    end
    expect { described_class.from_directory('/missing/synthetic') }.to raise_error(ArgumentError)
  end
end
