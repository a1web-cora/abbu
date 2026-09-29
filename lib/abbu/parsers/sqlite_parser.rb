# lib/abbu/parsers/sqlite_parser.rb
# frozen_string_literal: true

require 'sqlite3'
require_relative '../contact'

module Abbu
  module Parsers
    class SqliteParser # rubocop:disable Metrics/ClassLength
      # Column-name → attr_accessor mapping for flat fields on ZABCDRECORD
      RECORD_FIELD_MAP = {
        'ZFIRSTNAME' => :first_name, 'ZMIDDLENAME' => :middle_name,
        'ZLASTNAME' => :last_name,
        'ZNICKNAME' => :nickname, 'ZTITLE' => :prefix,
        'ZSUFFIX' => :suffix, 'ZORGANIZATION' => :company,
        'ZJOBTITLE' => :job_title, 'ZDEPARTMENT' => :department,
        'ZMAIDENNAME' => :maiden_name,
        'ZPHONETICFIRSTNAME' => :phonetic_first_name,
        'ZPHONETICMIDDLENAME' => :phonetic_middle_name,
        'ZPHONETICLASTNAME' => :phonetic_last_name,
        'ZPHONETICORGANIZATION' => :phonetic_company,
        'ZPRONOUNS' => :pronouns,
        'ZRINGTONE' => :ringtone, 'ZTEXTTONE' => :texttone,
        'ZVERIFICATIONCODE' => :verification_code,
        'ZIMAGEURI' => :image_uri
      }.freeze

      def initialize(db_paths)
        @db_paths = Array(db_paths)
      end

      def contacts
        @db_paths.flat_map do |db_path|
          parse_db(db_path)
        end
      end

      private

      def parse_db(db_path)
        db = SQLite3::Database.new(db_path.to_s)
        db.results_as_hash = true
        records(db).map { |row| build_contact(db, row) }
      ensure
        db&.close
      end

      def records(db)
        # Exclude groups (typically Z_ENT = 15 in this schema version)
        db.execute('SELECT * FROM ZABCDRECORD WHERE Z_ENT != 15')
      end

      def emails_for(db, record_id)
        db.execute(
          'SELECT ZADDRESSNORMALIZED, ZLABEL FROM ZABCDEMAILADDRESS WHERE ZOWNER = ?',
          record_id
        ).map { |row| { address: row['ZADDRESSNORMALIZED'], label: row['ZLABEL'] } }
      end

      def phones_for(db, record_id)
        db.execute(
          'SELECT ZFULLNUMBER, ZLABEL FROM ZABCDPHONENUMBER WHERE ZOWNER = ?',
          record_id
        ).map { |row| { number: row['ZFULLNUMBER'], label: row['ZLABEL'] } }
      end

      def addresses_for(db, record_id) # rubocop:disable Metrics/MethodLength
        db.execute(
          'SELECT ZSTREET, ZCITY, ZSTATE, ZZIPCODE, ZCOUNTRYNAME, ZLABEL FROM ZABCDPOSTALADDRESS WHERE ZOWNER = ?',
          record_id
        ).map do |row|
          {
            street: row['ZSTREET'],
            city: row['ZCITY'],
            state: row['ZSTATE'],
            zip: row['ZZIPCODE'],
            country: row['ZCOUNTRYNAME'],
            label: row['ZLABEL']
          }
        end
      end

      def groups_for(db, record_id)
        query = <<-SQL
          SELECT g.ZFIRSTNAME
          FROM Z_ABCDCONTACTGROUP j
          JOIN ZABCDRECORD g ON j.Z_GROUP = g.Z_PK
          WHERE j.Z_CONTACT = ?
        SQL
        db.execute(query, record_id).map { |row| row['ZFIRSTNAME'] }
      rescue SQLite3::SQLException
        []
      end

      def urls_for(db, record_id)
        db.execute(
          'SELECT ZURL, ZLABEL FROM ZABCDURLADDRESS WHERE ZOWNER = ?',
          record_id
        ).map { |row| { url: row['ZURL'], label: row['ZLABEL'] } }
      rescue SQLite3::SQLException
        []
      end

      def notes_for(db, record_id)
        db.execute(
          'SELECT ZTEXT FROM ZABCDNOTE WHERE ZCONTACT = ?',
          record_id
        ).filter_map { |row| row['ZTEXT'] }
      rescue SQLite3::SQLException
        []
      end

      def related_names_for(db, record_id)
        db.execute(
          'SELECT ZNAME, ZLABEL FROM ZABCDRELATEDNAME WHERE ZOWNER = ?',
          record_id
        ).map { |row| { name: row['ZNAME'], label: row['ZLABEL'] } }
      rescue SQLite3::SQLException
        []
      end

      def social_profiles_for(db, record_id)
        db.execute(
          'SELECT ZSERVICENAME, ZUSERNAME FROM ZABCDSOCIALPROFILE WHERE ZOWNER = ?',
          record_id
        ).map { |row| { service: row['ZSERVICENAME'], username: row['ZUSERNAME'] } }
      rescue SQLite3::SQLException
        []
      end

      def dates_for(db, record_id)
        db.execute(
          'SELECT ZYEAR, ZMONTH, ZDAY, ZLABEL FROM ZABCDDATECOMPONENTS WHERE ZOWNER = ?',
          record_id
        ).map do |row|
          { year: row['ZYEAR'], month: row['ZMONTH'], day: row['ZDAY'], label: row['ZLABEL'] }
        end
      rescue SQLite3::SQLException
        []
      end

      def instant_messages_for(db, record_id)
        db.execute(
          'SELECT ZADDRESS, ZLABEL, ZSERVICENAME FROM ZABCDMESSAGINGADDRESS WHERE ZOWNER = ?',
          record_id
        ).map do |row|
          { address: row['ZADDRESS'], label: row['ZLABEL'], service: row['ZSERVICENAME'] }
        end
      rescue SQLite3::SQLException
        []
      end

      def build_contact(db, row)
        contact = Contact.new
        assign_flat_fields(contact, row)
        assign_relational_fields(contact, db, row['Z_PK'])
        contact
      end

      def assign_flat_fields(contact, row)
        RECORD_FIELD_MAP.each do |column, attr|
          contact.public_send(:"#{attr}=", row[column])
        end
      end

      def assign_relational_fields(contact, db, record_id) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        contact.emails           = emails_for(db, record_id)
        contact.phones           = phones_for(db, record_id)
        contact.addresses        = addresses_for(db, record_id)
        contact.groups           = groups_for(db, record_id)
        contact.urls             = urls_for(db, record_id)
        contact.notes            = notes_for(db, record_id)
        contact.related_names    = related_names_for(db, record_id)
        contact.social_profiles  = social_profiles_for(db, record_id)
        contact.instant_messages = instant_messages_for(db, record_id)

        all_dates = dates_for(db, record_id)
        contact.dates = all_dates
        contact.birthday    = all_dates.find { |d| d[:label] == '_$!<Birthday>!$_' }
        contact.anniversary = all_dates.find { |d| d[:label] == '_$!<Anniversary>!$_' }
        contact.lunar_birthday = all_dates.find { |d| d[:label] == '_$!<LunarBirthday>!$_' }
      end
    end
  end
end
