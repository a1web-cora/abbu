# spec/abbu/parsers/sqlite_parser_spec.rb
# frozen_string_literal: true

require 'sqlite3'
require 'tmpdir'

RSpec.describe Abbu::Parsers::SqliteParser do
  def create_schema(db) # rubocop:disable Metrics/MethodLength
    db.execute <<-SQL
      CREATE TABLE ZABCDRECORD (
        Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER,
        ZFIRSTNAME TEXT, ZMIDDLENAME TEXT, ZLASTNAME TEXT, ZNICKNAME TEXT,
        ZTITLE TEXT, ZSUFFIX TEXT, ZORGANIZATION TEXT,
        ZJOBTITLE TEXT, ZDEPARTMENT TEXT, ZMAIDENNAME TEXT,
        ZPHONETICFIRSTNAME TEXT, ZPHONETICMIDDLENAME TEXT, ZPHONETICLASTNAME TEXT,
        ZPHONETICORGANIZATION TEXT, ZPRONOUNS TEXT,
        ZRINGTONE TEXT, ZTEXTTONE TEXT, ZVERIFICATIONCODE TEXT,
        ZIMAGEURI TEXT
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
        Z_CONTACT INTEGER, Z_GROUP INTEGER
      )
    SQL
    db.execute <<-SQL
      CREATE TABLE ZABCDURLADDRESS (
        Z_PK INTEGER PRIMARY KEY, ZOWNER INTEGER,
        ZURL TEXT, ZLABEL TEXT
      )
    SQL
    db.execute <<-SQL
      CREATE TABLE ZABCDNOTE (
        Z_PK INTEGER PRIMARY KEY, ZCONTACT INTEGER,
        ZTEXT TEXT
      )
    SQL
    db.execute <<-SQL
      CREATE TABLE ZABCDRELATEDNAME (
        Z_PK INTEGER PRIMARY KEY, ZOWNER INTEGER,
        ZNAME TEXT, ZLABEL TEXT
      )
    SQL
    db.execute <<-SQL
      CREATE TABLE ZABCDSOCIALPROFILE (
        Z_PK INTEGER PRIMARY KEY, ZOWNER INTEGER,
        ZSERVICENAME TEXT, ZUSERNAME TEXT
      )
    SQL
    db.execute <<-SQL
      CREATE TABLE ZABCDDATECOMPONENTS (
        Z_PK INTEGER PRIMARY KEY, ZOWNER INTEGER,
        ZYEAR INTEGER, ZMONTH INTEGER, ZDAY INTEGER, ZLABEL TEXT
      )
    SQL
    db.execute <<-SQL
      CREATE TABLE ZABCDMESSAGINGADDRESS (
        Z_PK INTEGER PRIMARY KEY, ZOWNER INTEGER,
        ZADDRESS TEXT, ZLABEL TEXT, ZSERVICENAME TEXT
      )
    SQL
  end

  def build_test_db(path) # rubocop:disable Metrics/MethodLength
    db = SQLite3::Database.new(path)
    create_schema(db)
    db.execute <<-SQL
      INSERT INTO ZABCDRECORD VALUES (
        1, 14, 'Stan', 'The Man', 'Carver', 'Stretch', 'Honorable', 'II',
        'Acme', 'Engineer', 'IT', 'Smith', 'Stan', 'The Phony', 'Karver',
        'Akme', 'he/him', 'Marimba', 'Ding', 'V123', 'stan-photo'
      )
    SQL
    db.execute("INSERT INTO ZABCDEMAILADDRESS VALUES (1, 1, 'stan@example.com', 'Work')")
    db.execute("INSERT INTO ZABCDPHONENUMBER VALUES (1, 1, '555-1234', 'Mobile')")
    db.execute("INSERT INTO ZABCDURLADDRESS VALUES (1, 1, 'https://stancarver.com', 'homepage')")
    db.execute("INSERT INTO ZABCDNOTE VALUES (1, 1, 'Met at RubyConf')")
    db.execute("INSERT INTO ZABCDRELATEDNAME VALUES (1, 1, 'John', 'brother')")
    db.execute("INSERT INTO ZABCDSOCIALPROFILE VALUES (1, 1, 'Twitter', '@scarver2')")
    db.execute("INSERT INTO ZABCDMESSAGINGADDRESS VALUES (1, 1, 'stan.carver', 'Work', 'Skype')")
    db.execute("INSERT INTO ZABCDDATECOMPONENTS VALUES (1, 1, 1980, 1, 1, '_$!<Birthday>!$_')")
    db.execute("INSERT INTO ZABCDDATECOMPONENTS VALUES (2, 1, 2010, 6, 15, '_$!<Anniversary>!$_')")
    db.execute("INSERT INTO ZABCDDATECOMPONENTS VALUES (3, 1, 1980, 2, 5, '_$!<LunarBirthday>!$_')")
    db.close
  end

  describe '#contacts' do
    it 'parses all flat and relational fields from a SQLite database' do
      Dir.mktmpdir do |dir|
        db_path = File.join(dir, 'AddressBook-v22.abcddb')
        build_test_db(db_path)

        parser   = described_class.new(Pathname.new(db_path))
        contact  = parser.contacts.first

        # Flat fields
        expect(contact.first_name).to eq('Stan')
        expect(contact.middle_name).to eq('The Man')
        expect(contact.last_name).to  eq('Carver')
        expect(contact.company).to    eq('Acme')
        expect(contact.job_title).to  eq('Engineer')
        expect(contact.department).to eq('IT')
        expect(contact.maiden_name).to eq('Smith')
        expect(contact.phonetic_first_name).to eq('Stan')
        expect(contact.phonetic_middle_name).to eq('The Phony')
        expect(contact.phonetic_last_name).to eq('Karver')
        expect(contact.phonetic_company).to eq('Akme')
        expect(contact.pronouns).to eq('he/him')
        expect(contact.ringtone).to eq('Marimba')
        expect(contact.texttone).to eq('Ding')

        # Relational fields
        expect(contact.emails).to eq([{ address: 'stan@example.com', label: 'Work' }])
        expect(contact.phones).to eq([{ number: '555-1234', label: 'Mobile' }])
        expect(contact.urls).to eq([{ url: 'https://stancarver.com', label: 'homepage' }])
        expect(contact.notes).to eq(['Met at RubyConf'])
        expect(contact.related_names).to eq([{ name: 'John', label: 'brother' }])
        expect(contact.social_profiles).to eq([{ service: 'Twitter', username: '@scarver2' }])
        expect(contact.instant_messages).to eq([{ address: 'stan.carver', label: 'Work', service: 'Skype' }])
        expect(contact.verification_code).to eq('V123')
        expect(contact.birthday).to eq({ year: 1980, month: 1, day: 1, label: '_$!<Birthday>!$_' })
        expect(contact.anniversary).to eq({ year: 2010, month: 6, day: 15, label: '_$!<Anniversary>!$_' })
        expect(contact.lunar_birthday).to eq({ year: 1980, month: 2, day: 5, label: '_$!<LunarBirthday>!$_' })
      end
    end

    it 'extracts ZIMAGEURI to image_uri' do
      Dir.mktmpdir do |dir|
        db_path = File.join(dir, 'AddressBook-v22.abcddb')
        build_test_db(db_path)

        contact = described_class.new(Pathname.new(db_path)).contacts.first

        expect(contact.image_uri).to eq('stan-photo')
      end
    end

    it 'returns empty arrays for contacts with no emails or phones' do
      Dir.mktmpdir do |dir|
        db_path = File.join(dir, 'AddressBook-v22.abcddb')
        db = SQLite3::Database.new(db_path)
        create_schema(db)
        db.execute("INSERT INTO ZABCDRECORD (Z_PK, Z_ENT, ZFIRSTNAME) VALUES (1, 14, 'Ghost')")
        db.close

        parser   = described_class.new(Pathname.new(db_path))
        contacts = parser.contacts

        expect(contacts.first.emails).to eq([])
        expect(contacts.first.phones).to eq([])
      end
    end

    it 'returns empty groups when Z_ABCDCONTACTGROUP does not exist' do
      Dir.mktmpdir do |dir|
        db_path = File.join(dir, 'AddressBook-v22.abcddb')
        db = SQLite3::Database.new(db_path)
        create_schema(db)
        db.execute('DROP TABLE Z_ABCDCONTACTGROUP')
        db.execute("INSERT INTO ZABCDRECORD (Z_PK, Z_ENT, ZFIRSTNAME) VALUES (1, 14, 'Ghost')")
        db.close

        parser   = described_class.new(Pathname.new(db_path))
        contacts = parser.contacts

        expect(contacts.first.groups).to eq([])
      end
    end
  end
end
