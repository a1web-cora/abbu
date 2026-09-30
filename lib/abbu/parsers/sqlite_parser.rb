# lib/abbu/parsers/sqlite_parser.rb
# frozen_string_literal: true

require 'sqlite3'
require_relative '../contact'
require_relative '../diagnostic'
require_relative '../parse_error'
require_relative '../utils/label_normalizer'
require_relative '../utils/source_descriptor'

module Abbu
  module Parsers
    class SqliteParser # rubocop:disable Metrics/ClassLength
      APPLE_EPOCH_OFFSET = 978_307_200

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

      attr_reader :diagnostics

      def initialize(db_paths, root_path: nil, readonly: false, diagnostics: nil, strict: false)
        @db_paths = Array(db_paths)
        @readonly = readonly
        @root_path = root_path
        @diagnostics = diagnostics || []
        @missing_optional_tables = {}
        @strict = strict
        @table_presence = {}
      end

      def contacts
        @db_paths.flat_map do |db_path|
          parse_db(db_path)
        end
      end

      private

      def parse_db(db_path)
        @active_db_path = db_path
        db = SQLite3::Database.new(db_path.to_s, readonly: @readonly)
        db.results_as_hash = true
        records(db).filter_map { |row| build_contact(db, row, db_path) }
      ensure
        db&.close
      end

      def records(db)
        # Exclude groups (typically Z_ENT = 15 in this schema version)
        db.execute('SELECT * FROM ZABCDRECORD WHERE Z_ENT != 15')
      rescue SQLite3::Exception
        fail_required_schema(@active_db_path)
      end

      def emails_for(db, record_id)
        query = 'SELECT ZADDRESSNORMALIZED, ZLABEL FROM ZABCDEMAILADDRESS WHERE ZOWNER = ?'
        optional_rows(db, record_id, 'ZABCDEMAILADDRESS', query).map do |row|
          { address: row['ZADDRESSNORMALIZED'], **label_fields(row['ZLABEL']) }
        end
      end

      def phones_for(db, record_id)
        query = 'SELECT ZFULLNUMBER, ZLABEL FROM ZABCDPHONENUMBER WHERE ZOWNER = ?'
        optional_rows(db, record_id, 'ZABCDPHONENUMBER', query).map do |row|
          { number: row['ZFULLNUMBER'], **label_fields(row['ZLABEL']) }
        end
      end

      def addresses_for(db, record_id) # rubocop:disable Metrics/MethodLength
        query = 'SELECT ZSTREET, ZCITY, ZSTATE, ZZIPCODE, ZCOUNTRYNAME, ZLABEL ' \
                'FROM ZABCDPOSTALADDRESS WHERE ZOWNER = ?'
        optional_rows(db, record_id, 'ZABCDPOSTALADDRESS', query).map do |row|
          {
            street: row['ZSTREET'],
            city: row['ZCITY'],
            state: row['ZSTATE'],
            zip: row['ZZIPCODE'],
            country: row['ZCOUNTRYNAME'],
            **label_fields(row['ZLABEL'])
          }
        end
      end

      def table_exists?(db, table_name)
        key = [@active_db_path.to_s, table_name]
        @table_presence.fetch(key) do
          @table_presence[key] = db.table_info(table_name).any?
        end
      end

      def groups_for(db, record_id)
        query = <<-SQL
          SELECT g.ZFIRSTNAME
          FROM Z_ABCDCONTACTGROUP j
          JOIN ZABCDRECORD g ON j.Z_GROUP = g.Z_PK
          WHERE j.Z_CONTACT = ?
        SQL
        optional_rows(db, record_id, 'Z_ABCDCONTACTGROUP', query).map { |row| row['ZFIRSTNAME'] }
      end

      def urls_for(db, record_id)
        query = 'SELECT ZURL, ZLABEL FROM ZABCDURLADDRESS WHERE ZOWNER = ?'
        optional_rows(db, record_id, 'ZABCDURLADDRESS', query).map do |row|
          { url: row['ZURL'], **label_fields(row['ZLABEL']) }
        end
      end

      def notes_for(db, record_id)
        query = 'SELECT ZTEXT FROM ZABCDNOTE WHERE ZCONTACT = ?'
        optional_rows(db, record_id, 'ZABCDNOTE', query).filter_map { |row| row['ZTEXT'] }
      end

      def related_names_for(db, record_id)
        query = 'SELECT ZNAME, ZLABEL FROM ZABCDRELATEDNAME WHERE ZOWNER = ?'
        optional_rows(db, record_id, 'ZABCDRELATEDNAME', query).map do |row|
          { name: row['ZNAME'], **label_fields(row['ZLABEL']) }
        end
      end

      def social_profiles_for(db, record_id)
        query = 'SELECT ZSERVICENAME, ZUSERNAME FROM ZABCDSOCIALPROFILE WHERE ZOWNER = ?'
        optional_rows(db, record_id, 'ZABCDSOCIALPROFILE', query).map do |row|
          { service: row['ZSERVICENAME'], username: row['ZUSERNAME'] }
        end
      end

      def dates_for(db, record_id)
        query = 'SELECT ZYEAR, ZMONTH, ZDAY, ZLABEL FROM ZABCDDATECOMPONENTS WHERE ZOWNER = ?'
        optional_rows(db, record_id, 'ZABCDDATECOMPONENTS', query).map { |row| date_from(row) }
      end

      def instant_messages_for(db, record_id)
        query = 'SELECT ZADDRESS, ZLABEL, ZSERVICENAME FROM ZABCDMESSAGINGADDRESS WHERE ZOWNER = ?'
        optional_rows(db, record_id, 'ZABCDMESSAGINGADDRESS', query).map do |row|
          { address: row['ZADDRESS'], service: row['ZSERVICENAME'], **label_fields(row['ZLABEL']) }
        end
      end

      def optional_rows(db, record_id, table, query)
        return missing_optional_table(table) unless table_exists?(db, table)

        db.execute(query, record_id)
      end

      def missing_optional_table(table)
        key = [@active_db_path.to_s, table]
        return [] if @missing_optional_tables[key]

        @missing_optional_tables[key] = true
        recover(optional_diagnostic(table), fallback: [])
      end

      def optional_diagnostic(table)
        Diagnostic.new(
          category: :missing_optional_data,
          message: 'Optional SQLite table is unavailable',
          parser: :sqlite,
          source: @active_db_path,
          context: { table: table }.freeze
        )
      end

      def fail_required_schema(db_path)
        diagnostic = Diagnostic.new(
          category: :required_schema,
          message: 'Required SQLite contact schema is unavailable',
          parser: :sqlite,
          source: db_path,
          context: { table: 'ZABCDRECORD' }.freeze
        )
        diagnostics << diagnostic
        raise ParseError, diagnostic
      end

      def build_contact(db, row, db_path)
        contact = Contact.new
        assign_flat_fields(contact, row)
        assign_relational_fields(contact, db, row['Z_PK'])
        assign_metadata(contact, row, db_path)
        contact
      end

      def recover(diagnostic, fallback:)
        diagnostics << diagnostic
        raise ParseError, diagnostic if @strict

        fallback
      end

      def assign_metadata(contact, row, db_path)
        contact.created_at = apple_time(row['ZCREATIONDATE'])
        contact.modified_at = apple_time(row['ZMODIFICATIONDATE'])
        contact.source = Utils::SourceDescriptor.new(db_path, root_path: @root_path).to_h
      end

      def apple_time(value)
        return if value.nil?

        Time.at(Float(value) + APPLE_EPOCH_OFFSET).utc
      rescue ArgumentError, RangeError, TypeError
        nil
      end

      def label_fields(raw_label)
        { label: Utils::LabelNormalizer.normalize(raw_label), raw_label: raw_label }
      end

      def date_from(row)
        {
          year: row['ZYEAR'], month: row['ZMONTH'], day: row['ZDAY'],
          **label_fields(row['ZLABEL'])
        }
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
        contact.birthday    = all_dates.find { |d| d[:label] == 'Birthday' }
        contact.anniversary = all_dates.find { |d| d[:label] == 'Anniversary' }
        contact.lunar_birthday = all_dates.find { |d| d[:label] == 'LunarBirthday' }
      end
    end
  end
end
