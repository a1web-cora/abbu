# spec/abbu/group_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'json'
require 'sqlite3'
require 'tmpdir'

RSpec.describe Abbu::Group do
  let(:fixture) { File.expand_path('../fixtures/TestContacts.abbu', __dir__) }

  it 'provides both directions of traversal without replacing legacy contact group labels' do
    archive = Abbu.open(fixture)
    contact = archive.contacts.first
    group = archive.groups.fetch(0)

    expect(group.name).to eq('Colleagues')
    expect(group.record_id).to eq(2)
    expect(group.source).to eq(contact.source)
    expect(group.contacts.first).to equal(contact)
    expect(group.contacts.search('stan').first).to equal(contact)
    expect(archive.groups_for(contact)).to eq([group])
    expect(archive.sources.first.groups_for(contact)).to eq([group])
    expect(archive.sources.last.groups_for(contact)).to eq([])
    expect(archive.groups_for(Abbu::Contact.new)).to eq([])
    expect(contact.groups).to eq(['Colleagues'])
    expect(contact.group_memberships).to eq([{ record_id: 2, name: 'Colleagues' }])
    expect(archive.groups).to equal(archive.groups)
    expect(archive.query.in_group(group).where(company: 'Acme Corp').to_a).to eq([contact])
    expect(archive.query.search('homer').in_group(group).to_a).to eq([])
  end

  it 'distinguishes same names and record IDs across sources and files, and same names within one file' do
    with_groups do |directory|
      archive = Abbu.open(directory)
      groups = archive.groups

      expect(groups.map(&:name)).to eq(['Colleagues', 'Colleagues', ' Équipe ', nil] * 3)
      expect(groups.map { |group| [group.source[:relative_path], group.record_id] }.uniq.length).to eq(12)
      expect(groups.map(&:record_id)).to eq([2, 5, 6, 7] * 3)
      groups.each do |group|
        expect(group.contacts.count).to eq(1)
        expect(group.contacts.first.source[:path]).to eq(group.source[:path])
        expect(archive.query.in_group(group).to_a).to eq(group.contacts.to_a)
      end
      expect(groups[0].contacts.first).not_to equal(groups[4].contacts.first)
      expect(archive.sources.map { |source| source.groups.length }).to eq([4, 8])
    end
  end

  it 'preserves duplicate, null and Unicode membership evidence through model and JSON export' do
    with_groups do |directory|
      archive = Abbu.open(directory)
      contact = archive.contacts.first
      expect(contact.groups).to eq(['Colleagues', 'Colleagues', 'Colleagues', ' Équipe ', nil])
      expect(contact.group_memberships.map { |entry| entry[:record_id] }).to eq([2, 2, 5, 6, 7])
      path = File.join(directory, 'contacts.json')
      Abbu::Exporters::JsonExporter.new([contact]).to_file(path)
      expect(JSON.parse(File.read(path)).first['groups']).to eq(contact.groups)
      expect(JSON.parse(JSON.generate(archive.groups.map(&:to_h))).map { |group| group['name'] })
        .to eq(archive.groups.map(&:name))
    end
  end

  it 'snapshots metadata and membership without freezing mutable contact evidence' do
    archive = Abbu.open(fixture)
    group = archive.groups.first
    contact = group.contacts.first

    expect(group).to be_frozen
    expect(group.contacts).to be_frozen
    expect(archive.groups).to be_frozen
    expect(archive.sources.first.groups).to be_frozen
    expect { group.name.replace('Changed') }.to raise_error(FrozenError)
    expect { group.source[:path].replace('Changed') }.to raise_error(FrozenError)
    expect { group.source.clear }.to raise_error(FrozenError)
    group.contacts.to_a.clear
    group.to_h.clear
    contact.group_memberships.first[:name] = 'Changed'
    contact.group_memberships.clear
    contact.groups.clear
    expect(group.name).to eq('Colleagues')
    expect(group.contacts.to_a).to eq([contact])
    expect(archive.groups_for(contact)).to eq([group])
    expect(group.to_h).to eq(record_id: 2, name: 'Colleagues', source: group.source, contact_count: 1)
  end

  it 'supports live groups with read-only handles and input-local contact membership' do
    allow(SQLite3::Database).to receive(:new).and_call_original
    store = Abbu.open_live(fixture)
    group = store.groups.first

    expect(store.groups_for(store.contacts.first)).to eq([group])
    expect(store.groups).to equal(store.groups)
    expect(group.include?(Abbu.open(fixture).contacts.first)).to be(false)
    expect(SQLite3::Database).to have_received(:new).with(group.source[:path], readonly: true)
  end

  it 'retains distinct contacts and query order within a shared group' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'AddressBook-v22.abcddb')
      FileUtils.cp(File.join(fixture, 'AddressBook-v22.abcddb'), path)
      SQLite3::Database.new(path) do |db|
        db.execute("INSERT INTO ZABCDRECORD (Z_PK, Z_ENT, ZFIRSTNAME) VALUES (3, 14, 'Avery')")
        db.execute('INSERT INTO Z_ABCDCONTACTGROUP (Z_CONTACT, Z_GROUP) VALUES (3, 2)')
      end
      archive = Abbu.open(directory)
      group = archive.groups.first
      expect(group.contacts.to_a).to eq(archive.contacts)
      expect(group.to_h[:contact_count]).to eq(2)
      expect(Abbu::Query.new(archive.contacts.reverse).in_group(group).to_a).to eq(archive.contacts.reverse)
      expect(group.contacts.search('avery').first).to equal(archive.contacts.last)
      expect(archive.groups_for(archive.contacts.last)).to eq([group])
    end
  end

  it 'retains tolerant missing-table diagnostics and strict failures' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'AddressBook-v22.abcddb')
      FileUtils.cp(File.join(fixture, 'AddressBook-v22.abcddb'), path)
      SQLite3::Database.new(path) { |db| db.execute('DROP TABLE Z_ABCDCONTACTGROUP') }
      archive = Abbu.open(directory)
      expect(archive.groups).to eq([])
      expect(archive.contacts.first.group_memberships).to eq([])
      expect(archive.contacts.first.groups).to eq([])
      expect(archive.diagnostics.map(&:context)).to include(table: 'Z_ABCDCONTACTGROUP')
      expect { Abbu.open(directory, strict: true).groups }.to raise_error(Abbu::ParseError)
    end
  end

  it 'does not infer group identity from plist labels or enumerate unreferenced group rows' do
    archive = Abbu.open(File.expand_path('../fixtures/PlistContacts.abbu', __dir__))
    expect(archive.groups).to eq([])
    expect(archive.contacts.map(&:group_memberships)).to eq([[], []])
    Dir.mktmpdir do |directory|
      expect(Abbu.open(directory).groups).to eq([])
    end
    with_groups do |directory|
      expect(Abbu.open(directory).groups.map(&:record_id)).not_to include(8)
    end
  end

  def with_groups
    Dir.mktmpdir do |directory|
      %w[AddressBook-v22.abcddb Sources/Équipe/AddressBook-v22.abcddb
         Sources/Équipe/AddressBook-v99.abcddb].each do |relative_path|
        path = File.join(directory, relative_path)
        FileUtils.mkdir_p(File.dirname(path))
        FileUtils.cp(File.join(fixture, 'AddressBook-v22.abcddb'), path)
        SQLite3::Database.new(path) { |db| seed_groups(db) }
      end
      yield directory
    end
  end

  def seed_groups(db)
    db.execute('INSERT INTO Z_ABCDCONTACTGROUP (Z_CONTACT, Z_GROUP) VALUES (1, 2)')
    { 5 => 'Colleagues', 6 => ' Équipe ', 7 => nil, 8 => 'Unreferenced' }.each do |id, name|
      db.execute('INSERT INTO ZABCDRECORD (Z_PK, Z_ENT, ZFIRSTNAME) VALUES (?, 15, ?)', [id, name])
      db.execute('INSERT INTO Z_ABCDCONTACTGROUP (Z_CONTACT, Z_GROUP) VALUES (1, ?)', [id]) unless id == 8
    end
  end
end
