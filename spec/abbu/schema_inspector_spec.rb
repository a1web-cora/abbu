# spec/abbu/schema_inspector_spec.rb
# frozen_string_literal: true

require 'sqlite3'
require 'tmpdir'

RSpec.describe Abbu::SchemaInspector do
  describe '#report' do
    it 'reports missing optional tables without assigning them inferred semantics' do
      with_database do |root, db, db_path|
        db.execute('CREATE TABLE ZABCDRECORD (Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, ZFIRSTNAME TEXT)')

        report = described_class.new(db_path, root_path: root).report
        database = report[:databases].first

        expect(report[:archive_path]).to eq(File.expand_path(root))
        expect(database[:relative_path]).to eq('AddressBook-v22.abcddb')
        expect(database[:source]).to eq({ kind: 'root', identifier: nil })
        expect(database[:missing_required_tables]).to eq([])
        expect(database[:missing_known_tables]).to include('ZABCDEMAILADDRESS', 'ZABCDPHONENUMBER')
        expect(database[:schema_drift]).to be(true)
      end
    end

    it 'flags unknown contact-linked tables as research diagnostics' do
      with_database do |root, db, db_path|
        db.execute('CREATE TABLE ZABCDRECORD (Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER)')
        db.execute('CREATE TABLE ZABCDCUSTOMVALUE (Z_PK INTEGER PRIMARY KEY, ZOWNER INTEGER, ZVALUE TEXT)')

        database = described_class.new(db_path, root_path: root).report[:databases].first
        custom_table = database[:tables].find { |table| table[:name] == 'ZABCDCUSTOMVALUE' }

        expect(database[:unknown_tables]).to eq(['ZABCDCUSTOMVALUE'])
        expect(custom_table[:known]).to be(false)
        expect(custom_table[:contact_link_candidates]).to eq(['ZOWNER'])
        expect(custom_table[:unknown_columns]).to eq(%w[ZOWNER ZVALUE Z_PK])
      end
    end

    it 'reports unknown columns and schema drift on known tables' do
      with_database do |_root, db, db_path|
        db.execute(<<~SQL)
          CREATE TABLE ZABCDEMAILADDRESS (
            Z_PK INTEGER PRIMARY KEY,
            ZOWNER INTEGER,
            ZADDRESSNORMALIZED TEXT,
            ZLABEL TEXT,
            ZUNOBSERVED TEXT
          )
        SQL

        database = described_class.new(db_path).report[:databases].first
        email_table = database[:tables].first
        unknown_column = email_table[:columns].find { |column| column[:name] == 'ZUNOBSERVED' }

        expect(database[:missing_required_tables]).to eq(['ZABCDRECORD'])
        expect(email_table[:unknown_columns]).to eq(['ZUNOBSERVED'])
        expect(email_table[:missing_known_columns]).to eq([])
        expect(unknown_column).to include(
          declared_type: 'text', nullable: true, primary_key: false,
          known: false, contact_link_candidate: false
        )
        expect(database[:schema_drift]).to be(true)
      end
    end

    it 'reports absent recognized columns as observations rather than required semantics' do
      with_database do |_root, db, db_path|
        db.execute('CREATE TABLE ZABCDRECORD (Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER)')

        table = described_class.new(db_path).report[:databases].first[:tables].first

        expect(table[:missing_known_columns]).to include('ZFIRSTNAME', 'ZMODIFICATIONDATE')
        expect(table[:unknown_columns]).to eq([])
      end
    end

    it 'matches only exact owner/contact-style relationship column names' do
      with_database do |_root, db, db_path|
        db.execute(<<~SQL)
          CREATE TABLE CUSTOM (
            OWNER INTEGER,
            Z_CONTACT INTEGER,
            ZCONTACT INTEGER,
            ZOWNER INTEGER,
            ZOWNERISH INTEGER,
            CONTACTED INTEGER
          )
        SQL

        table = described_class.new(db_path).report[:databases].first[:tables].first

        expect(table[:contact_link_candidates]).to eq(%w[OWNER ZCONTACT ZOWNER Z_CONTACT])
      end
    end

    it 'sorts databases, tables, and columns deterministically' do
      Dir.mktmpdir('Contacts.abbu') do |root|
        paths = %w[z.abcddb a.abcddb].map do |name|
          path = File.join(root, name)
          db = SQLite3::Database.new(path)
          db.execute('CREATE TABLE ZETA (B TEXT, A TEXT)')
          db.execute('CREATE TABLE ALPHA (Z TEXT)')
          db.close
          path
        end

        databases = described_class.new(paths.reverse, root_path: root).report[:databases]

        expect(databases.map { |database| database[:relative_path] }).to eq(%w[a.abcddb z.abcddb])
        expect(databases.first[:tables].map { |table| table[:name] }).to eq(%w[ALPHA ZETA])
        expect(databases.first[:tables].last[:columns].map { |column| column[:name] }).to eq(%w[A B])
      end
    end
  end

  def with_database
    Dir.mktmpdir('Contacts.abbu') do |root|
      db_path = File.join(root, 'AddressBook-v22.abcddb')
      db = SQLite3::Database.new(db_path)
      yield root, db, db_path
    ensure
      db&.close
    end
  end
end
