# spec/abbu/source_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'sqlite3'
require 'tmpdir'

RSpec.describe Abbu::Source do
  let(:fixture) { File.expand_path('../fixtures/TestContacts.abbu', __dir__) }

  it 'enumerates root and nested sources without changing existing contact provenance' do
    archive = Abbu.open(fixture)
    contacts = archive.contacts
    provenance = contacts.map(&:source)
    sources = archive.sources

    expect(sources.map(&:relative_path)).to eq(['.', 'Sources/TestAccount'])
    expect(sources.map(&:identifier)).to eq([nil, 'TestAccount'])
    expect(sources.map(&:provider)).to eq([nil, nil])
    expect(sources.map { |source| source.contacts.count }).to eq([1, 2])
    expect(sources.first.contacts.first).to equal(contacts.first)
    contacts.zip(provenance).each { |contact, original| expect(contact.source).to equal(original) }
    expect(sources.first.contacts.search('stan').first).to equal(contacts.first)
    expect(sources.first.group_names).to eq(contacts.first.groups.compact.uniq.sort)
    expect(archive.sources).to equal(sources)
  end

  it 'returns frozen metadata and membership without freezing callers original strings or contacts' do
    contact = Abbu::Contact.new
    contact.groups = %w[Équipe Friends Friends].map(&:dup)
    contacts = [contact]
    file = { path: +'/store/Records/a.abcdp', relative_path: +'Records/a.abcdp', kind: +'root', identifier: nil }
    source = described_class.new(path: '/store', relative_path: '.', identifier: nil, files: [file],
                                 contacts: contacts)

    expect(source).to be_frozen
    expect(source.contacts).to be_frozen
    expect { source.files << {} }.to raise_error(FrozenError)
    expect { source.files.first[:path].replace('changed') }.to raise_error(FrozenError)
    expect { source.group_names.first.replace('changed') }.to raise_error(FrozenError)
    source.contacts.to_a.clear
    source.to_h.clear
    file[:path].replace('changed')
    expect(source.files.first[:path]).to eq('/store/Records/a.abcdp')
    expect(source.group_names).to eq(%w[Friends Équipe])
    expect(contact).not_to be_frozen
    expect(contacts).not_to be_frozen
    expect(contact.groups.first).not_to be_frozen
    expect(source.contacts.to_a).to eq([contact])
  end

  it 'keeps repeated filenames and contact IDs distinct and aggregates multiple files in one container' do
    with_source_layout do |directory|
      sources = Abbu.open(directory).sources

      expect(sources.map(&:relative_path)).to eq(['.', 'Sources/iCloud', 'Sources/Équipe'])
      expect(sources.map(&:provider)).to all(be_nil)
      expect(sources.map { |source| source.contacts.count }).to eq([1, 2, 1])
      expect(sources[1].files.map { |file| file[:relative_path] }).to eq(
        ['Sources/iCloud/AddressBook-v22.abcddb', 'Sources/iCloud/AddressBook-v99.abcddb']
      )
      expect(sources.flat_map { |source| source.contacts.to_a }.map(&:first_name)).to eq(%w[Stan Stan Stan Stan])
      expect(sources[1].identifier).to eq('iCloud')
      expect(sources[2].identifier).to eq('Équipe')
      expect(sources.map(&:group_names).uniq.length).to eq(1)
      expect(sources.first.to_h.keys).to eq(%i[path relative_path kind identifier provider files contact_count
                                               group_names])
    end
  end

  it 'enumerates live sources through read-only handles with the same catalog shape' do
    with_source_layout do |directory|
      allow(SQLite3::Database).to receive(:new).and_call_original
      sources = Abbu.open_live(directory).sources

      expect(sources.map(&:relative_path)).to eq(['.', 'Sources/iCloud', 'Sources/Équipe'])
      sources.flat_map(&:files).each do |file|
        expect(SQLite3::Database).to have_received(:new).with(file[:path], readonly: true)
      end
    end
  end

  it 'includes discovered empty databases rather than deriving sources only from contacts' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'AddressBook-v22.abcddb')
      FileUtils.cp(File.join(fixture, 'AddressBook-v22.abcddb'), path)
      SQLite3::Database.new(path) { |db| db.execute('DELETE FROM ZABCDRECORD') }

      source = Abbu.open(directory).sources.fetch(0)
      expect(source.contacts.to_a).to eq([])
      expect(source.group_names).to eq([])
      expect(source.files.length).to eq(1)
      expect(source.to_h[:contact_count]).to eq(0)
    end
  end

  it 'groups legacy plist records into their observed root container' do
    archive = Abbu.open(File.expand_path('../fixtures/PlistContacts.abbu', __dir__))
    source = archive.sources.fetch(0)

    expect(source.relative_path).to eq('.')
    expect(source.files.map { |file| file[:relative_path] }).to eq(%w[Records/homer.abcdp Records/stan.abcdp])
    expect(source.contacts.count).to eq(2)
    expect(source.contacts.map(&:source)).to eq(archive.contacts.map(&:source))
  end

  it 'preserves the archive parser selection rule when both SQLite and plist files exist' do
    Dir.mktmpdir do |directory|
      FileUtils.cp(File.join(fixture, 'AddressBook-v22.abcddb'), directory)
      FileUtils.cp(File.expand_path('../fixtures/PlistContacts.abbu/Records/homer.abcdp', __dir__), directory)

      source = Abbu.open(directory).sources.fetch(0)
      expect(source.files.map { |file| file[:relative_path] }).to eq(['AddressBook-v22.abcddb'])
      expect(source.contacts.count).to eq(1)
    end
  end

  it 'returns an empty frozen list for an archive without supported inputs' do
    Dir.mktmpdir do |directory|
      expect(Abbu.open(directory).sources).to eq([])
      expect(Abbu.open(directory).sources).to be_frozen
    end
  end

  def with_source_layout
    Dir.mktmpdir do |directory|
      %w[Sources/Équipe/AddressBook-v22.abcddb Sources/iCloud/AddressBook-v99.abcddb
         AddressBook-v22.abcddb Sources/iCloud/AddressBook-v22.abcddb].each do |relative_path|
        target = File.join(directory, relative_path)
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp(File.join(fixture, 'AddressBook-v22.abcddb'), target)
      end
      yield directory
    end
  end
end
