# lib/abbu/exporters/sqlite_schema.rb
# frozen_string_literal: true

module Abbu
  module Exporters
    # Fixed ABBU-owned identifiers; source strings never become SQL identifiers.
    module SqliteSchema
      VERSION = 1
      CONTACT_FIELDS = %i[first_name middle_name last_name nickname prefix suffix company job_title department
                          maiden_name phonetic_first_name phonetic_middle_name phonetic_last_name phonetic_company
                          pronouns ringtone texttone verification_code image_uri image_path].freeze
      COLLECTIONS = {
        emails: %i[address label raw_label], phones: %i[number label raw_label],
        addresses: %i[street city state zip country label raw_label], urls: %i[url label raw_label],
        related_names: %i[name label raw_label], social_profiles: %i[service username],
        instant_messages: %i[address service label raw_label]
      }.transform_values(&:freeze).freeze
      DATE_FIELDS = %i[birthday anniversary lunar_birthday dates].freeze

      module_function

      def create(db)
        db.execute('PRAGMA foreign_keys = ON')
        db.execute("PRAGMA user_version = #{VERSION}")
        db.execute('CREATE TABLE metadata (schema_version INTEGER NOT NULL, generator_version TEXT NOT NULL)')
        db.execute('CREATE TABLE sources (id INTEGER PRIMARY KEY, path TEXT, relative_path TEXT, kind TEXT, ' \
                   'identifier TEXT, evidence_json TEXT NOT NULL)')
        create_contacts(db)
        create_collections(db)
        create_scalar_collections(db)
        create_dates(db)
        create_groups(db)
      end

      def create_contacts(db)
        fields = CONTACT_FIELDS.map { |name| "#{name} TEXT" }.join(', ')
        db.execute('CREATE TABLE contacts (id INTEGER PRIMARY KEY, source_id INTEGER REFERENCES sources(id), ' \
                   "#{fields}, " \
                   'created_at TEXT, modified_at TEXT, evidence_json TEXT NOT NULL)')
        db.execute('CREATE INDEX contacts_source ON contacts(source_id)')
      end

      def create_collections(db)
        COLLECTIONS.each do |table, columns|
          fields = columns.map { |name| "#{name} TEXT" }.join(', ')
          db.execute("CREATE TABLE #{table} (contact_id INTEGER NOT NULL REFERENCES contacts(id), " \
                     "position INTEGER NOT NULL, #{fields}, evidence_json TEXT NOT NULL, " \
                     'PRIMARY KEY(contact_id, position))')
        end
      end

      def create_scalar_collections(db)
        %w[notes group_labels].each do |table|
          db.execute("CREATE TABLE #{table} (contact_id INTEGER NOT NULL REFERENCES contacts(id), " \
                     'position INTEGER NOT NULL, value TEXT, evidence_json TEXT NOT NULL, ' \
                     'PRIMARY KEY(contact_id, position))')
        end
      end

      def create_dates(db)
        db.execute('CREATE TABLE dates (contact_id INTEGER NOT NULL REFERENCES contacts(id), field TEXT NOT NULL, ' \
                   'position INTEGER NOT NULL, year INTEGER, month INTEGER, day INTEGER, label TEXT, raw_label TEXT, ' \
                   'evidence_json TEXT NOT NULL, PRIMARY KEY(contact_id, field, position))')
      end

      def create_groups(db)
        db.execute('CREATE TABLE groups (id INTEGER PRIMARY KEY, source_id INTEGER REFERENCES sources(id), ' \
                   'record_id INTEGER, name TEXT, evidence_json TEXT NOT NULL)')
        db.execute('CREATE TABLE group_memberships (contact_id INTEGER NOT NULL REFERENCES contacts(id), ' \
                   'position INTEGER NOT NULL, group_id INTEGER NOT NULL REFERENCES groups(id), ' \
                   'PRIMARY KEY(contact_id, position))')
        db.execute('CREATE INDEX memberships_group ON group_memberships(group_id)')
      end
    end
  end
end
