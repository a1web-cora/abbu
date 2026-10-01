# spec/abbu/live_store_wal_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'digest'
require 'fileutils'
require 'sqlite3'
require 'tmpdir'

RSpec.describe Abbu::LiveStore do
  it 'reads committed WAL content without changing database or WAL bytes or issuing checkpoints' do
    with_wal_store do |directory, writer, path|
      writer.execute("UPDATE ZABCDRECORD SET ZFIRSTNAME = 'Committed' WHERE Z_PK = 1")
      expect(File.size("#{path}-wal")).to be_positive
      expect(File.exist?("#{path}-shm")).to be(true)
      before = database_digest(path)
      statements = []
      allow(SQLite3::Database).to receive(:new).and_wrap_original do |original, *args, **kwargs|
        expect(kwargs).to eq(readonly: true)
        original.call(*args, **kwargs).tap { |db| db.trace { |sql| statements << sql } }
      end

      expect(Abbu.open_live(directory).contacts.first.first_name).to eq('Committed')
      expect(database_digest(path)).to eq(before)
      expect(statements).not_to be_empty
      writes = /\b(?:INSERT|UPDATE|DELETE|REPLACE|CREATE|DROP|ALTER|VACUUM|wal_checkpoint)\b/i
      expect(statements.grep(writes)).to be_empty
    end
  end

  it 'hides an in-flight write transaction and exposes its commit only to a fresh store' do
    with_wal_store do |directory, writer, _path|
      writer.execute('BEGIN IMMEDIATE')
      writer.execute("UPDATE ZABCDRECORD SET ZFIRSTNAME = 'After' WHERE Z_PK = 1")
      store = Abbu.open_live(directory)
      expect(store.contacts.first.first_name).to eq('Stan')

      writer.execute('COMMIT')

      expect(store.contacts.first.first_name).to eq('Stan')
      expect(Abbu.open_live(directory).contacts.first.first_name).to eq('After')
    end
  end

  it 'demonstrates that separate contact and relationship statements can observe different commits' do
    with_wal_store do |directory, writer, _path|
      allow(SQLite3::Database).to receive(:new).and_wrap_original do |original, *args, **kwargs|
        original.call(*args, **kwargs).tap do |reader|
          allow(reader).to receive(:execute).and_wrap_original do |execute, *query_args|
            rows = execute.call(*query_args)
            if query_args.first == 'SELECT * FROM ZABCDRECORD WHERE Z_ENT != 15'
              writer.transaction do
                writer.execute("UPDATE ZABCDRECORD SET ZFIRSTNAME = 'After' WHERE Z_PK = 1")
                writer.execute('UPDATE ZABCDEMAILADDRESS SET ZADDRESSNORMALIZED = ? WHERE ZOWNER = 1',
                               ['after@example.test'])
              end
            end
            rows
          end
        end
      end

      contact = Abbu.open_live(directory).contacts.first
      expect(contact.first_name).to eq('Stan')
      expect(contact.emails.first[:address]).to eq('after@example.test')
    end
  end

  it 'reads source databases independently rather than as one cross-database snapshot' do
    with_wal_store do |directory, _writer, path|
      source_path = File.join(directory, 'Sources', 'Synthetic', File.basename(path))
      FileUtils.mkdir_p(File.dirname(source_path))
      FileUtils.cp(path, source_path)
      source_writer = SQLite3::Database.new(source_path)
      source_writer.execute('PRAGMA journal_mode=WAL')
      allow(SQLite3::Database).to receive(:new).and_wrap_original do |original, *args, **kwargs|
        expect(kwargs).to eq(readonly: true)
        original.call(*args, **kwargs).tap do |reader|
          next unless args.first == path

          allow(reader).to receive(:close).and_wrap_original do |close|
            close.call
            source_writer.execute("UPDATE ZABCDRECORD SET ZFIRSTNAME = 'Later' WHERE Z_PK = 1")
          end
        end
      end

      contacts = Abbu.open_live(directory).contacts
      expect(contacts.map(&:first_name)).to eq(%w[Stan Later])
      expect(contacts.map { |contact| contact.source[:kind] }).to eq(%w[root source])
    ensure
      source_writer&.close
    end
  end

  def with_wal_store
    Dir.mktmpdir('abbu-wal') do |directory|
      path = File.join(directory, 'AddressBook-v22.abcddb')
      FileUtils.cp(File.expand_path('../fixtures/TestContacts.abbu/AddressBook-v22.abcddb', __dir__), path)
      writer = SQLite3::Database.new(path)
      configure_wal(writer)
      yield directory, writer, path
    ensure
      writer&.close
    end
  end

  def database_digest(path)
    [path, "#{path}-wal"].map { |file| Digest::SHA256.file(file).hexdigest }
  end

  def configure_wal(writer)
    expect(writer.get_first_value('PRAGMA journal_mode=WAL')).to eq('wal')
    writer.execute('PRAGMA wal_autocheckpoint=0')
    writer.execute('PRAGMA wal_checkpoint(TRUNCATE)')
  end
end
