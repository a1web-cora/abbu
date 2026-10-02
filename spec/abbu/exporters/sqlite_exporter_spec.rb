# spec/abbu/exporters/sqlite_exporter_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'pathname'
require 'sqlite3'
require 'tmpdir'

RSpec.describe Abbu::Exporters::SqliteExporter do
  let(:contact) do
    Abbu::Contact.new.tap do |person|
      Abbu::Exporters::SqliteSchema::CONTACT_FIELDS.each { |field| person.public_send("#{field}=", "#{field} Équipe") }
      person.created_at = Time.iso8601('2001-01-01T01:02:03.123456789+02:00')
      person.modified_at = Time.utc(2026, 1, 2)
      person.source = { path: '/synthetic/Contacts.abbu/AddressBook-v22.abcddb',
                        relative_path: 'AddressBook-v22.abcddb',
                        kind: 'root', identifier: nil }
      person.emails = [{ address: 'example@example.test', label: 'Work', raw_label: '_$!<Work>!$_',
                         extra: { nested: [nil, false, 2] } }]
      person.phones = [{ number: '+1 555 0100', label: '', raw_label: '' }]
      person.addresses = [{ street: 'Street', city: 'Town', state: 'TX', zip: '00000', country: 'US', label: nil }]
      person.urls = [{ url: 'https://example.test', label: 'Custom', raw_label: 'Custom' }]
      person.related_names = [{ name: 'Example', label: 'Friend', raw_label: 'Friend' }]
      person.social_profiles = [{ service: 'Example', username: '@example' }]
      person.instant_messages = [{ address: 'example', service: 'Example', label: 'Work' }]
      person.notes = ['Hello', nil, 'Hello']
      person.groups = ['Équipe', 'Équipe', nil]
      person.group_memberships = [{ record_id: 2, name: 'Équipe' }, { record_id: 2, name: 'Équipe' }]
      person.birthday = { year: 0, month: 2, day: 29, label: 'Birthday', raw_label: nil }
      person.anniversary = { year: 2000, month: 1, day: 1, label: 'Anniversary', raw_label: '_$!<Anniversary>!$_' }
      person.lunar_birthday = { year: nil, month: 1, day: 1, label: 'LunarBirthday' }
      person.dates = [person.birthday, person.anniversary, person.lunar_birthday]
    end
  end

  def read_database(path)
    SQLite3::Database.new(path, readonly: true) do |db|
      db.results_as_hash = true
      yield db
    end
  end

  it 'exports a versioned relational schema and preserves complete normalized evidence' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'contacts.sqlite')
      before = Marshal.dump(contact)
      expect(described_class.new([contact]).to_file(Pathname.new(path))).to eq(File.realpath(path))
      expect(File.stat(path).mode & 0o777).to eq(0o600)
      read_database(path) do |db|
        expect(db.get_first_value('PRAGMA user_version')).to eq(described_class::SCHEMA_VERSION)
        expected_metadata = { 'schema_version' => 1, 'generator_version' => Abbu::VERSION }
        expect(db.get_first_row('SELECT * FROM metadata')).to eq(expected_metadata)
        expect(db.get_first_value('PRAGMA integrity_check')).to eq('ok')
        expect(db.execute('PRAGMA foreign_key_check')).to eq([])
        expect(db.execute("SELECT name FROM sqlite_master WHERE name LIKE 'Z%'")).to eq([])
        row = db.get_first_row('SELECT * FROM contacts')
        Abbu::Exporters::SqliteSchema::CONTACT_FIELDS.each do |field|
          expect(row[field.to_s]).to eq(contact.public_send(field))
        end
        expect(row['created_at']).to eq(contact.created_at.iso8601(9))
        expect(JSON.parse(db.get_first_value('SELECT evidence_json FROM emails'), symbolize_names: true))
          .to eq(contact.emails.first)
        expect(db.get_first_value('SELECT raw_label FROM emails')).to eq('_$!<Work>!$_')
        labels = db.execute('SELECT value FROM group_labels ORDER BY position').map { |row| row['value'] }
        expect(labels).to eq(contact.groups)
        expect(db.get_first_value('SELECT count(*) FROM group_memberships')).to eq(2)
        expect(db.get_first_value('SELECT count(*) FROM groups')).to eq(1)
      end
      expect(Marshal.dump(contact)).to eq(before)
    end
  end

  it 'reconstructs supported normalized collections and date fields independently from relational rows' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'contacts.sqlite')
      described_class.new([contact]).to_file(path)
      read_database(path) do |db|
        restored = Abbu::Contact.new
        Abbu::Exporters::SqliteSchema::COLLECTIONS.each_key do |field|
          values = db.execute("SELECT evidence_json FROM #{field} ORDER BY position")
          parsed = values.map { |row| JSON.parse(row['evidence_json'], symbolize_names: true) }
          restored.public_send("#{field}=", parsed)
          expect(restored.public_send(field)).to eq(contact.public_send(field))
        end
        Abbu::Exporters::SqliteSchema::DATE_FIELDS.each do |field|
          values = db.execute('SELECT evidence_json FROM dates WHERE field = ? ORDER BY position', [field.to_s])
          parsed = values.map { |row| JSON.parse(row['evidence_json'], symbolize_names: true) }
          restored.public_send("#{field}=", field == :dates ? parsed : parsed.first)
          expect(restored.public_send(field)).to eq(contact.public_send(field))
        end
      end
    end
  end

  it 'is byte deterministic for equivalent ordered input including different evidence key insertion order' do
    Dir.mktmpdir do |directory|
      first = File.join(directory, 'first.sqlite')
      second = File.join(directory, 'second.sqlite')
      described_class.new([contact, contact]).to_file(first)
      contact.emails.first.replace(contact.emails.first.to_a.reverse.to_h)
      contact.source = contact.source.to_a.reverse.to_h
      described_class.new([contact, contact]).to_file(second)
      expect(File.binread(first)).to eq(File.binread(second))
    end
  end

  it 'preserves source, notes, and membership evidence and enforces declared foreign keys' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'contacts.sqlite')
      described_class.new([contact]).to_file(path)
      read_database(path) do |db|
        source = JSON.parse(db.get_first_value('SELECT evidence_json FROM sources'), symbolize_names: true)
        expect(source).to eq(contact.source)
        expect(db.execute('SELECT value FROM notes ORDER BY position').map { |row| row['value'] }).to eq(contact.notes)
        rows = db.execute('SELECT evidence_json FROM group_memberships JOIN groups ' \
                          'ON groups.id = group_memberships.group_id ORDER BY position')
        memberships = rows.map { |row| JSON.parse(row['evidence_json'], symbolize_names: true) }
        expect(memberships).to eq(contact.group_memberships)
      end
      SQLite3::Database.new(path) do |db|
        db.execute('PRAGMA foreign_keys = ON')
        expect { db.execute('INSERT INTO notes VALUES (?, ?, ?)', [999, 0, 'orphan']) }
          .to raise_error(SQLite3::ConstraintException)
      end
    end
  end

  it 'scopes repeated group keys by source evidence and never guesses source-less identity' do
    Dir.mktmpdir do |directory|
      second = Marshal.load(Marshal.dump(contact))
      second.source[:relative_path] = 'Sources/Other/AddressBook-v22.abcddb'
      third = Marshal.load(Marshal.dump(contact))
      third.source = nil
      path = File.join(directory, 'contacts.sqlite')
      described_class.new([contact, second, third, third]).to_file(path)
      read_database(path) do |db|
        expect(db.get_first_value('SELECT count(*) FROM sources')).to eq(2)
        expect(db.get_first_value('SELECT count(*) FROM contacts')).to eq(4)
        expect(db.get_first_value('SELECT count(*) FROM groups')).to eq(4)
        db.execute('PRAGMA foreign_keys = ON')
      end
    end
  end

  it 'creates a queryable empty database without fabricated contacts or sources' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'empty.sqlite')
      described_class.new([Abbu::Contact.new]).to_file(path)
      read_database(path) do |db|
        expect(db.get_first_value('SELECT created_at FROM contacts')).to be_nil
        expect(db.get_first_value('SELECT count(*) FROM sources')).to eq(0)
      end
      empty = File.join(directory, 'none.sqlite')
      described_class.new([].each).to_file(empty)
      read_database(empty) { |db| expect(db.get_first_value('SELECT count(*) FROM contacts')).to eq(0) }
    end
  end

  it 'never overwrites files, hard links, symlinks, or dangling symlinks' do
    Dir.mktmpdir do |directory|
      target = File.join(directory, 'existing')
      File.write(target, 'keep')
      File.link(target, File.join(directory, 'hard'))
      File.symlink(target, File.join(directory, 'symbolic'))
      File.symlink(File.join(directory, 'absent'), File.join(directory, 'dangling'))
      %w[existing hard symbolic dangling].each do |name|
        expect { described_class.new([contact]).to_file(File.join(directory, name)) }.to raise_error(Errno::EEXIST)
      end
      expect(File.read(target)).to eq('keep')
      expect(Dir.children(directory).sort).to eq(%w[dangling existing hard symbolic])
    end
  end

  it 'removes staging files on serialization failure without publishing a partial database' do
    Dir.mktmpdir do |directory|
      contact.emails.first[:extra] = Float::NAN
      path = File.join(directory, 'contacts.sqlite')
      expect { described_class.new([contact]).to_file(path) }.to raise_error(JSON::GeneratorError)
      expect(Dir.children(directory)).to eq([])
    end
  end

  it 'does not replace a destination created concurrently during publication' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'contacts.sqlite')
      allow(File).to receive(:link).and_wrap_original do |method, source, destination|
        File.write(destination, 'concurrent')
        method.call(source, destination)
      end
      expect { described_class.new([contact]).to_file(path) }.to raise_error(Errno::EEXIST)
      expect(File.read(path)).to eq('concurrent')
      expect(Dir.children(directory)).to eq(['contacts.sqlite'])
    end
  end

  it 'rejects destinations inside source bundles, including symlinked parents' do
    Dir.mktmpdir do |directory|
      bundle = File.join(directory, 'Contacts.abbu')
      Dir.mkdir(bundle)
      File.symlink(bundle, File.join(directory, 'alias'))
      contact.source[:path] = File.join(bundle, 'AddressBook-v22.abcddb')
      File.write(contact.source[:path], 'source')
      [bundle, File.join(directory, 'alias')].each do |parent|
        expect { described_class.new([contact]).to_file(File.join(parent, 'derived.sqlite')) }
          .to raise_error(ArgumentError, /outside source/)
      end
      File.symlink(contact.source[:path], File.join(directory, 'file-alias'))
      contact.source[:path] = File.join(directory, 'file-alias')
      expect { described_class.new([contact]).to_file(File.join(bundle, 'derived.sqlite')) }
        .to raise_error(ArgumentError, /outside source/)
      expect(Dir.children(bundle)).to eq(['AddressBook-v22.abcddb'])
      expect(File.read(contact.source[:path])).to eq('source')
      expect { described_class.new([]).to_file(File.join(bundle, 'empty.sqlite')) }
        .to raise_error(ArgumentError, /outside source/)
    end
  end

  it 'resolves a source bundle alias even when the real directory has no bundle suffix' do
    Dir.mktmpdir do |directory|
      actual = File.join(directory, 'actual')
      Dir.mkdir(actual)
      alias_path = File.join(directory, 'Alias.abbu')
      File.symlink(actual, alias_path)
      contact.source[:path] = File.join(alias_path, 'AddressBook-v22.abcddb')
      expect { described_class.new([contact]).to_file(File.join(actual, 'derived.sqlite')) }
        .to raise_error(ArgumentError, /outside source/)
      expect(Dir.children(actual)).to eq([])
    end
  end
end
