# spec/support/compatibility_fixtures.rb
# frozen_string_literal: true

require 'fileutils'
require 'plist'
require 'sqlite3'

require_relative 'fixture_generator'

# Synthetic structural variants of existing fixtures, not macOS release samples.
module CompatibilityFixtures
  PROFILES = {
    xml_records: { 'Records/legacy.abcdp' => :xml },
    xml_nested: { 'Sources/Équipe/Records/legacy.abcdp' => :xml },
    sqlite_sparse: { 'AddressBook-v1.abcddb' => :sparse },
    sqlite_root: { 'AddressBook-v22.abcddb' => :complete },
    sqlite_source_only: { 'Sources/Équipe/AddressBook-v22.abcddb' => :complete },
    sqlite_empty_root: { 'AddressBook-v22.abcddb' => :empty,
                         'Sources/Alpha/AddressBook-v22.abcddb' => :complete,
                         'Sources/Équipe/AddressBook-v22.abcddb' => :complete },
    sqlite_mixed_schemas: { 'AddressBook-v1.abcddb' => :sparse,
                            'Sources/Équipe/AddressBook-v99.abcddb' => :complete },
    mixed_formats: { 'AddressBook-v22.abcddb' => :complete, 'Records/ignored.abcdp' => :xml }
  }.transform_values(&:freeze).freeze

  # Independent fixture schema copied from the existing relational parser specs.
  OPTIONAL_SCHEMAS = {
    'ZABCDURLADDRESS' => 'ZOWNER INTEGER, ZURL TEXT, ZLABEL TEXT',
    'ZABCDNOTE' => 'ZCONTACT INTEGER, ZTEXT TEXT',
    'ZABCDRELATEDNAME' => 'ZOWNER INTEGER, ZNAME TEXT, ZLABEL TEXT',
    'ZABCDSOCIALPROFILE' => 'ZOWNER INTEGER, ZSERVICENAME TEXT, ZUSERNAME TEXT',
    'ZABCDDATECOMPONENTS' => 'ZOWNER INTEGER, ZYEAR INTEGER, ZMONTH INTEGER, ZDAY INTEGER, ZLABEL TEXT',
    'ZABCDMESSAGINGADDRESS' => 'ZOWNER INTEGER, ZADDRESS TEXT, ZLABEL TEXT, ZSERVICENAME TEXT'
  }.freeze

  def self.build(root, profile)
    PROFILES.fetch(profile).each do |relative_path, shape|
      path = File.join(root, relative_path)
      FileUtils.mkdir_p(File.dirname(path))
      shape == :xml ? File.write(path, xml_record.to_plist) : build_database(path, shape)
    end
  end

  def self.build_database(path, shape)
    SQLite3::Database.new(path) do |db|
      FixtureGenerator.setup_schema(db)
      FixtureGenerator.seed_root(db) unless shape == :empty
      db.execute('UPDATE ZABCDRECORD SET ZIMAGEURI = NULL')
      OPTIONAL_SCHEMAS.each { |table, columns| db.execute("CREATE TABLE #{table} (#{columns})") }
      make_sparse(db) if shape == :sparse
    end
  end

  def self.make_sparse(db)
    %w[ZCREATIONDATE ZMODIFICATIONDATE ZIMAGEURI ZNICKNAME ZTITLE ZSUFFIX ZORGANIZATION].each do |column|
      db.execute("ALTER TABLE ZABCDRECORD DROP COLUMN #{column}")
    end
    (%w[ZABCDPHONENUMBER ZABCDPOSTALADDRESS Z_ABCDCONTACTGROUP] + OPTIONAL_SCHEMAS.keys).each do |table|
      db.execute("DROP TABLE #{table}")
    end
  end

  def self.xml_record
    { 'First' => 'Stan', 'Last' => 'Carver',
      'Email' => { 'values' => [{ 'value' => 'john@example.com', 'label' => '_$!<Work>!$_' }] } }
  end
end
