# spec/abbu/live_store_spec.rb
# frozen_string_literal: true

require 'fileutils'
require 'sqlite3'
require 'tmpdir'

RSpec.describe Abbu::LiveStore do
  let(:fixture_path) { File.expand_path('../fixtures/TestContacts.abbu', __dir__) }

  describe '.default_path' do
    it 'returns the observed macOS AddressBook location' do
      path = described_class.default_path(home: '/Users/example', platform: 'arm64-darwin')

      expect(path).to eq(Pathname.new('/Users/example/Library/Application Support/AddressBook'))
    end

    it 'requires an explicit path outside macOS' do
      expect { described_class.default_path(home: '/home/example', platform: 'x86_64-linux') }
        .to raise_error(described_class::UnsupportedPlatformError, /supply an AddressBook directory path/)
    end
  end

  describe '.new' do
    it 'reports a missing store separately from archive validation' do
      expect { described_class.new('/missing/AddressBook') }
        .to raise_error(described_class::NotFoundError, /Live Contacts store not found/)
    end

    it 'rejects a file path as a store directory' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'AddressBook-v22.abcddb')
        File.write(path, '')

        expect { described_class.new(path) }
          .to raise_error(described_class::NotFoundError, /not a directory/)
      end
    end

    it 'explains Full Disk Access when the store cannot be inspected' do
      path = instance_double(Pathname, expand_path: nil, to_s: '/restricted/AddressBook')
      allow(path).to receive(:expand_path).and_return(path)
      allow(path).to receive(:stat).and_raise(Errno::EACCES, 'permission denied')
      allow(Pathname).to receive(:new).with('/restricted/AddressBook').and_return(path)

      expect { described_class.new('/restricted/AddressBook') }
        .to raise_error(described_class::PermissionError, /Full Disk Access/)
    end

    it 'rejects a store directory without read and search access' do
      Dir.mktmpdir('AddressBook') do |dir|
        File.chmod(0o000, dir)

        expect { described_class.new(dir) }
          .to raise_error(described_class::PermissionError, /directory is not readable/)
      ensure
        File.chmod(0o700, dir)
      end
    end
  end

  describe '#database_paths' do
    it 'discovers root and source databases without scanning unrelated directories' do
      Dir.mktmpdir('AddressBook') do |dir|
        copy_fixture_databases(dir)
        unrelated = File.join(dir, 'Other', 'AddressBook-v22.abcddb')
        FileUtils.mkdir_p(File.dirname(unrelated))
        File.write(unrelated, '')

        relative_paths = described_class.new(dir).database_paths.map do |path|
          path.relative_path_from(Pathname.new(dir)).to_s
        end

        expect(relative_paths).to eq([
                                       'AddressBook-v22.abcddb',
                                       'Sources/SyntheticAccount/AddressBook-v22.abcddb'
                                     ])
      end
    end

    it 'fails informatively when no supported database is present' do
      Dir.mktmpdir('AddressBook') do |dir|
        expect { described_class.new(dir).database_paths }
          .to raise_error(described_class::NotFoundError, /No AddressBook-v\*\.abcddb databases found/)
      end
    end

    it 'explains Full Disk Access when discovery is denied' do
      store = described_class.new(fixture_path)
      allow(store.path).to receive(:glob).and_raise(Errno::EACCES, 'permission denied')

      expect { store.database_paths }
        .to raise_error(described_class::PermissionError, /Full Disk Access/)
    end

    it 'rejects an unreadable candidate database' do
      Dir.mktmpdir('AddressBook') do |dir|
        database = File.join(dir, 'AddressBook-v22.abcddb')
        File.write(database, '')
        File.chmod(0o000, database)

        expect { described_class.new(dir).database_paths }
          .to raise_error(described_class::PermissionError, /database is not readable/)
      ensure
        File.chmod(0o600, database)
      end
    end
  end

  describe '#contacts' do
    it 'parses caller-supplied root and source databases with source provenance' do
      store = described_class.new(fixture_path)

      contacts = store.contacts
      source_contact = contacts.find { |contact| contact.first_name == 'Homer' }

      expect(contacts.map(&:first_name)).to contain_exactly('Stan', 'Homer', 'Collin')
      expect(store.diagnostics.map(&:category)).to include(:missing_optional_data)
      expect(source_contact.source).to include(
        relative_path: 'Sources/TestAccount/AddressBook-v22.abcddb',
        kind: 'source',
        identifier: 'TestAccount'
      )
    end

    it 'opens every SQLite database in read-only mode' do
      root_database = File.join(fixture_path, 'AddressBook-v22.abcddb')
      source_database = File.join(fixture_path, 'Sources', 'TestAccount', 'AddressBook-v22.abcddb')

      allow(SQLite3::Database).to receive(:new).and_call_original

      described_class.new(fixture_path).contacts

      expect(SQLite3::Database).to have_received(:new).with(root_database, readonly: true)
      expect(SQLite3::Database).to have_received(:new).with(source_database, readonly: true)
    end

    it 'supports strict parser diagnostics through the public live entry point' do
      store = Abbu.open_live(fixture_path, strict: true)

      expect { store.contacts }.to raise_error(Abbu::ParseError)
      expect(store.diagnostics.map(&:category)).to eq([:missing_optional_data])
    end

    it 'turns SQLite access failures into actionable Full Disk Access guidance' do
      store = described_class.new(fixture_path)
      allow(SQLite3::Database).to receive(:new)
        .and_raise(SQLite3::CantOpenException, 'unable to open database file')

      expect { store.contacts }.to raise_error(described_class::PermissionError) do |error|
        expect(error.message).to include('Full Disk Access')
        expect(error.message).to include('System Settings > Privacy & Security')
      end
    end
  end

  def copy_fixture_databases(destination)
    source_dir = File.join(destination, 'Sources', 'SyntheticAccount')
    FileUtils.mkdir_p(source_dir)
    FileUtils.cp(File.join(fixture_path, 'AddressBook-v22.abcddb'), destination)
    FileUtils.cp(
      File.join(fixture_path, 'Sources', 'TestAccount', 'AddressBook-v22.abcddb'),
      source_dir
    )
  end
end
