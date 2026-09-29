# spec/support/fixture_generator.rb
# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'sqlite3'

module FixtureGenerator # rubocop:disable Metrics/ModuleLength
  def self.generate_abbu(path = 'spec/fixtures/TestContacts.abbu')
    FileUtils.rm_rf(path)
    FileUtils.mkdir_p("#{path}/Sources/TestAccount")
    FileUtils.mkdir_p("#{path}/Images")

    build_database("#{path}/AddressBook-v22.abcddb", :seed_root)
    build_database("#{path}/Sources/TestAccount/AddressBook-v22.abcddb", :seed_synced)

    seed_images(path)
  end

  def self.build_database(db_path, seed_method)
    db = SQLite3::Database.new(db_path)
    setup_schema(db)
    send(seed_method, db)
    db.close
  end

  def self.seed_images(path)
    File.write("#{path}/Images/stan-photo.jpg", "\xFF\xD8\xFF\xE0stub")
  end

  def self.setup_schema(db) # rubocop:disable Metrics/MethodLength
    db.execute <<-SQL
      CREATE TABLE ZABCDRECORD (
        Z_PK INTEGER PRIMARY KEY,
        Z_ENT INTEGER,
        ZFIRSTNAME TEXT,
        ZLASTNAME TEXT,
        ZNICKNAME TEXT,
        ZTITLE TEXT,
        ZSUFFIX TEXT,
        ZORGANIZATION TEXT,
        ZIMAGEURI TEXT
      )
    SQL

    db.execute <<-SQL
      CREATE TABLE ZABCDEMAILADDRESS (
        Z_PK INTEGER PRIMARY KEY,
        ZOWNER INTEGER,
        ZADDRESSNORMALIZED TEXT,
        ZLABEL TEXT
      )
    SQL

    db.execute <<-SQL
      CREATE TABLE ZABCDPHONENUMBER (
        Z_PK INTEGER PRIMARY KEY,
        ZOWNER INTEGER,
        ZFULLNUMBER TEXT,
        ZLABEL TEXT
      )
    SQL

    db.execute <<-SQL
      CREATE TABLE ZABCDPOSTALADDRESS (
        Z_PK INTEGER PRIMARY KEY,
        ZOWNER INTEGER,
        ZSTREET TEXT,
        ZCITY TEXT,
        ZSTATE TEXT,
        ZZIPCODE TEXT,
        ZCOUNTRYNAME TEXT,
        ZLABEL TEXT
      )
    SQL

    db.execute <<-SQL
      CREATE TABLE Z_ABCDCONTACTGROUP (
        Z_CONTACT INTEGER,
        Z_GROUP INTEGER
      )
    SQL
  end

  def self.seed_root(db) # rubocop:disable Metrics/MethodLength
    # Contact 1: Basic
    db.execute <<-SQL
      INSERT INTO ZABCDRECORD
        (Z_PK, Z_ENT, ZFIRSTNAME, ZLASTNAME, ZNICKNAME, ZTITLE, ZSUFFIX, ZORGANIZATION, ZIMAGEURI)
      VALUES (1, 14, 'Stan', 'Carver', 'Stretch', 'Honorable', 'II', 'Acme Corp', 'stan-photo')
    SQL
    db.execute <<-SQL
      INSERT INTO ZABCDEMAILADDRESS (ZOWNER, ZADDRESSNORMALIZED, ZLABEL)
      VALUES (1, 'john@example.com', 'Work')
    SQL
    db.execute <<-SQL
      INSERT INTO ZABCDPHONENUMBER (ZOWNER, ZFULLNUMBER, ZLABEL)
      VALUES (1, '555-0100', 'Mobile')
    SQL

    # Address for Region filtering
    db.execute <<-SQL
      INSERT INTO ZABCDPOSTALADDRESS (ZOWNER, ZSTREET, ZCITY, ZSTATE, ZCOUNTRYNAME, ZLABEL)
      VALUES (1, '123 Main St', 'Austin', 'TX', 'USA', 'Home')
    SQL

    # Group record
    db.execute("INSERT INTO ZABCDRECORD (Z_PK, Z_ENT, ZFIRSTNAME) VALUES (2, 15, 'Colleagues')")
    db.execute('INSERT INTO Z_ABCDCONTACTGROUP (Z_CONTACT, Z_GROUP) VALUES (1, 2)')
  end

  def self.seed_synced(db) # rubocop:disable Metrics/MethodLength
    # Contact 3: In synced account
    db.execute <<-SQL
      INSERT INTO ZABCDRECORD (Z_PK, Z_ENT, ZFIRSTNAME, ZLASTNAME, ZORGANIZATION)
      VALUES (3, 14, 'Homer', 'Simpson', 'Globex Corporation')
    SQL
    db.execute <<-SQL
      INSERT INTO ZABCDEMAILADDRESS (ZOWNER, ZADDRESSNORMALIZED, ZLABEL)
      VALUES (3, 'homer@globex.com', 'Work')
    SQL
    db.execute <<-SQL
      INSERT INTO ZABCDPHONENUMBER (ZOWNER, ZFULLNUMBER, ZLABEL)
      VALUES (3, '555-0200', 'Work')
    SQL

    # Custom contact field (We'll use a custom label for demonstration)
    db.execute <<-SQL
      INSERT INTO ZABCDPHONENUMBER (ZOWNER, ZFULLNUMBER, ZLABEL)
      VALUES (3, '555-0201', 'Direct Line')
    SQL

    # Texas Region Contact
    db.execute <<-SQL
      INSERT INTO ZABCDRECORD (Z_PK, Z_ENT, ZFIRSTNAME, ZLASTNAME, ZORGANIZATION)
      VALUES (4, 14, 'Collin', 'McKinney', 'Collin County')
    SQL
    db.execute <<-SQL
      INSERT INTO ZABCDPOSTALADDRESS (ZOWNER, ZCITY, ZSTATE, ZCOUNTRYNAME, ZLABEL)
      VALUES (4, 'McKinney', 'TX', 'USA', 'Work')
    SQL
  end
end

FixtureGenerator.generate_abbu if __FILE__ == $PROGRAM_NAME
