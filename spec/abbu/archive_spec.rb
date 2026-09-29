# spec/abbu/archive_spec.rb
# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

RSpec.describe Abbu::Archive do
  let(:fixture_path) { File.join(__dir__, '..', 'fixtures', 'sample.abbu') }

  describe '.new' do
    it 'raises ArgumentError for a missing path' do
      expect { described_class.new('/nonexistent/path.abbu') }
        .to raise_error(ArgumentError, /ABBU path not found/)
    end

    it 'raises ArgumentError for a non-directory path' do
      Dir.mktmpdir do |dir|
        file_path = File.join(dir, 'notabundle.abbu')
        File.write(file_path, '')
        expect { described_class.new(file_path) }
          .to raise_error(ArgumentError, /Not a directory bundle/)
      end
    end
  end

  describe '#sqlite?' do
    it 'returns true when an .abcddb file exists in the bundle' do
      Dir.mktmpdir('sample.abbu') do |dir|
        File.write(File.join(dir, 'AddressBook-v22.abcddb'), '')
        archive = described_class.new(dir)
        expect(archive.sqlite?).to be true
      end
    end

    it 'returns false when no .abcddb file exists' do
      Dir.mktmpdir('sample.abbu') do |dir|
        archive = described_class.new(dir)
        expect(archive.sqlite?).to be false
      end
    end
  end

  describe '#contacts' do
    it 'delegates to PlistParser for a plist-only bundle' do
      Dir.mktmpdir('sample.abbu') do |dir|
        archive = described_class.new(dir)
        expect(archive.contacts).to eq([])
      end
    end

    it 'parses .abcdp files from a plist-only bundle' do
      Dir.mktmpdir('plist.abbu') do |dir|
        require 'plist'
        records_dir = File.join(dir, 'Records')
        FileUtils.mkdir_p(records_dir)
        File.write(
          File.join(records_dir, 'stan.abcdp'),
          { 'First' => 'Stan', 'Last' => 'Carver' }.to_plist
        )

        archive  = described_class.new(dir)
        contacts = archive.contacts

        expect(contacts.size).to eq(1)
        expect(contacts.first.first_name).to eq('Stan')
        expect(contacts.first.last_name).to eq('Carver')
      end
    end

    it 'delegates to SqliteParser when an .abcddb file exists' do
      Dir.mktmpdir('sample.abbu') do |dir|
        db_path = File.join(dir, 'AddressBook-v22.abcddb')
        require 'sqlite3'
        create_empty_schema(db_path)

        archive = described_class.new(dir)
        expect(archive.contacts).to eq([])
      end
    end
  end

  describe 'image attachment' do
    it 'attaches image_path to contacts whose ZIMAGEURI matches a file in Images/' do
      Dir.mktmpdir('sample.abbu') do |dir|
        db_path = File.join(dir, 'AddressBook-v22.abcddb')
        require 'sqlite3'
        create_schema_with_image(db_path)
        FileUtils.mkdir_p(File.join(dir, 'Images'))
        File.write(File.join(dir, 'Images', 'stan-photo.jpg'), 'fake')

        archive = described_class.new(dir)
        contact = archive.contacts.first

        expect(contact.image_uri).to eq('stan-photo')
        expect(contact.image_path).to be_a(Pathname)
        expect(contact.image_path.basename.to_s).to eq('stan-photo.jpg')
        expect(contact.image_path.to_s).to start_with(dir)
      end
    end

    it 'leaves image_path nil when ZIMAGEURI does not match any file' do
      Dir.mktmpdir('sample.abbu') do |dir|
        db_path = File.join(dir, 'AddressBook-v22.abcddb')
        require 'sqlite3'
        create_schema_with_image(db_path)

        archive = described_class.new(dir)
        expect(archive.contacts.first.image_path).to be_nil
      end
    end

    it 'leaves image_path nil when ZIMAGEURI is null' do
      Dir.mktmpdir('sample.abbu') do |dir|
        db_path = File.join(dir, 'AddressBook-v22.abcddb')
        require 'sqlite3'
        create_schema_with_image(db_path)
        db = SQLite3::Database.new(db_path)
        db.execute('UPDATE ZABCDRECORD SET ZIMAGEURI = NULL WHERE Z_PK = 1')
        db.close

        archive = described_class.new(dir)
        expect(archive.contacts.first.image_uri).to be_nil
        expect(archive.contacts.first.image_path).to be_nil
      end
    end
  end

  private

  def create_empty_schema(db_path) # rubocop:disable Metrics/MethodLength
    db = SQLite3::Database.new(db_path)
    db.execute <<-SQL
      CREATE TABLE ZABCDRECORD (
        Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER,
        ZFIRSTNAME TEXT, ZLASTNAME TEXT, ZNICKNAME TEXT,
        ZTITLE TEXT, ZSUFFIX TEXT, ZORGANIZATION TEXT,
        ZJOBTITLE TEXT, ZDEPARTMENT TEXT, ZMAIDENNAME TEXT,
        ZPHONETICFIRSTNAME TEXT, ZPHONETICLASTNAME TEXT,
        ZPHONETICORGANIZATION TEXT, ZPRONOUNS TEXT,
        ZRINGTONE TEXT, ZTEXTTONE TEXT
      )
    SQL
    db.execute <<-SQL
      CREATE TABLE ZABCDEMAILADDRESS (
        Z_PK INTEGER PRIMARY KEY, ZOWNER INTEGER,
        ZADDRESSNORMALIZED TEXT, ZLABEL TEXT
      )
    SQL
    db.execute <<-SQL
      CREATE TABLE Z_ABCDCONTACTGROUP (
        Z_CONTACT INTEGER,
        Z_GROUP INTEGER
      )
    SQL
    db.close
  end

  def create_schema_with_image(db_path) # rubocop:disable Metrics/MethodLength
    db = SQLite3::Database.new(db_path)
    db.execute <<-SQL
      CREATE TABLE ZABCDRECORD (
        Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER,
        ZFIRSTNAME TEXT, ZLASTNAME TEXT, ZNICKNAME TEXT,
        ZTITLE TEXT, ZSUFFIX TEXT, ZORGANIZATION TEXT,
        ZJOBTITLE TEXT, ZDEPARTMENT TEXT, ZMAIDENNAME TEXT,
        ZPHONETICFIRSTNAME TEXT, ZPHONETICLASTNAME TEXT,
        ZPHONETICORGANIZATION TEXT, ZPRONOUNS TEXT,
        ZRINGTONE TEXT, ZTEXTTONE TEXT, ZIMAGEURI TEXT
      )
    SQL
    db.execute <<-SQL
      CREATE TABLE ZABCDEMAILADDRESS (
        Z_PK INTEGER PRIMARY KEY, ZOWNER INTEGER,
        ZADDRESSNORMALIZED TEXT, ZLABEL TEXT
      )
    SQL
    db.execute <<-SQL
      CREATE TABLE ZABCDPHONENUMBER (
        Z_PK INTEGER PRIMARY KEY, ZOWNER INTEGER,
        ZFULLNUMBER TEXT, ZLABEL TEXT
      )
    SQL
    db.execute <<-SQL
      CREATE TABLE ZABCDPOSTALADDRESS (
        Z_PK INTEGER PRIMARY KEY, ZOWNER INTEGER,
        ZSTREET TEXT, ZCITY TEXT, ZSTATE TEXT,
        ZZIPCODE TEXT, ZCOUNTRYNAME TEXT, ZLABEL TEXT
      )
    SQL
    db.execute <<-SQL
      CREATE TABLE Z_ABCDCONTACTGROUP (
        Z_CONTACT INTEGER,
        Z_GROUP INTEGER
      )
    SQL
    db.execute(<<-SQL)
      INSERT INTO ZABCDRECORD (Z_PK, Z_ENT, ZFIRSTNAME, ZLASTNAME, ZIMAGEURI)
      VALUES (1, 14, 'Stan', 'Carver', 'stan-photo')
    SQL
    db.close
  end
end
