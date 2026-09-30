# lib/abbu/schema_inspector.rb
# frozen_string_literal: true

require 'pathname'
require 'sqlite3'
require_relative 'utils/source_descriptor'

module Abbu
  class SchemaInspector
    RECORD_COLUMNS = %w[
      Z_PK Z_ENT ZFIRSTNAME ZMIDDLENAME ZLASTNAME ZNICKNAME ZTITLE ZSUFFIX
      ZORGANIZATION ZJOBTITLE ZDEPARTMENT ZMAIDENNAME ZPHONETICFIRSTNAME
      ZPHONETICMIDDLENAME ZPHONETICLASTNAME ZPHONETICORGANIZATION ZPRONOUNS
      ZRINGTONE ZTEXTTONE ZVERIFICATIONCODE ZIMAGEURI ZCREATIONDATE
      ZMODIFICATIONDATE
    ].freeze

    KNOWN_SCHEMA = {
      'Z_ABCDCONTACTGROUP' => %w[Z_CONTACT Z_GROUP],
      'ZABCDDATECOMPONENTS' => %w[Z_PK ZOWNER ZYEAR ZMONTH ZDAY ZLABEL],
      'ZABCDEMAILADDRESS' => %w[Z_PK ZOWNER ZADDRESSNORMALIZED ZLABEL],
      'ZABCDMESSAGINGADDRESS' => %w[Z_PK ZOWNER ZADDRESS ZLABEL ZSERVICENAME],
      'ZABCDNOTE' => %w[Z_PK ZCONTACT ZTEXT],
      'ZABCDPHONENUMBER' => %w[Z_PK ZOWNER ZFULLNUMBER ZLABEL],
      'ZABCDPOSTALADDRESS' => %w[Z_PK ZOWNER ZSTREET ZCITY ZSTATE ZZIPCODE ZCOUNTRYNAME ZLABEL],
      'ZABCDRECORD' => RECORD_COLUMNS,
      'ZABCDRELATEDNAME' => %w[Z_PK ZOWNER ZNAME ZLABEL],
      'ZABCDSOCIALPROFILE' => %w[Z_PK ZOWNER ZSERVICENAME ZUSERNAME],
      'ZABCDURLADDRESS' => %w[Z_PK ZOWNER ZURL ZLABEL]
    }.transform_values { |columns| columns.to_set.freeze }.freeze
    REQUIRED_TABLES = %w[ZABCDRECORD].freeze

    def initialize(db_paths, root_path: nil)
      @db_paths = Array(db_paths).map { |path| Pathname.new(path) }.sort
      @root_path = root_path && Pathname.new(root_path)
    end

    def report
      {
        archive_path: @root_path&.expand_path&.to_s,
        databases: @db_paths.map { |db_path| inspect_database(db_path) }
      }
    end

    private

    def inspect_database(db_path)
      db = SQLite3::Database.new(db_path.to_s)
      table_names = user_table_names(db)
      tables = table_names.map { |table_name| inspect_table(db, table_name) }
      source = Utils::SourceDescriptor.new(db_path, root_path: @root_path).to_h
      database_report(source, tables, KNOWN_SCHEMA.keys - table_names)
    ensure
      db&.close
    end

    def database_report(source, tables, missing_tables)
      {
        path: source[:path],
        relative_path: source[:relative_path],
        source: source.slice(:kind, :identifier),
        tables: tables,
        unknown_tables: tables.reject { |table| table[:known] }.map { |table| table[:name] },
        missing_known_tables: missing_tables,
        missing_required_tables: REQUIRED_TABLES & missing_tables,
        schema_drift: schema_drift?(tables, missing_tables)
      }
    end

    def user_table_names(db)
      db.execute(<<~SQL).flatten.sort
        SELECT name
        FROM sqlite_master
        WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
        ORDER BY name
      SQL
    end

    def inspect_table(db, table_name)
      known_columns = KNOWN_SCHEMA[table_name]
      columns = table_columns(db, table_name, known_columns)
      {
        name: table_name,
        known: !known_columns.nil?,
        columns: columns,
        missing_known_columns: missing_known_columns(known_columns, columns),
        unknown_columns: columns.reject { |column| column[:known] }.map { |column| column[:name] },
        contact_link_candidates: contact_link_candidates(columns)
      }
    end

    def missing_known_columns(known_columns, columns)
      return [] unless known_columns

      known_columns.to_a - columns.map { |column| column[:name] }
    end

    def contact_link_candidates(columns)
      columns.filter_map { |column| column[:name] if column[:contact_link_candidate] }
    end

    def table_columns(db, table_name, known_columns)
      db.table_info(table_name).sort_by { |column| column['name'] }.map do |column|
        column_report(column, known_columns)
      end
    end

    def column_report(column, known_columns)
      name = column['name']
      {
        name: name,
        declared_type: column['type'],
        nullable: column['notnull'].zero?,
        primary_key: column['pk'].positive?,
        known: known_columns&.include?(name) || false,
        contact_link_candidate: contact_link_candidate?(name)
      }
    end

    def contact_link_candidate?(column_name)
      %w[OWNER CONTACT].include?(column_name.delete_prefix('Z').delete('_').upcase)
    end

    def schema_drift?(tables, missing_tables)
      table_drift = tables.any? do |table|
        !table[:known] || table[:missing_known_columns].any? || table[:unknown_columns].any?
      end
      missing_tables.any? || table_drift
    end
  end
end
