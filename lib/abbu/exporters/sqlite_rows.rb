# lib/abbu/exporters/sqlite_rows.rb
# frozen_string_literal: true

require 'json'
require 'pathname'
require 'time'

require_relative 'sqlite_schema'

module Abbu
  module Exporters
    # Writes normalized columns and complete per-entry evidence side by side.
    class SqliteRows
      def initialize(db)
        @db = db
        @sources = {}
        @groups = {}
      end

      def write(contact, id)
        source_id = source(contact.source)
        fields = flat_fields(contact)
        times = [timestamp(contact.created_at), timestamp(contact.modified_at)]
        insert(:contacts, [id, source_id, *fields.values.map { |value| value&.to_s }, *times, evidence(fields)])
        collections(contact, id)
        dates(contact, id)
        groups(contact, id, source_id)
      end

      private

      def flat_fields(contact)
        SqliteSchema::CONTACT_FIELDS.to_h do |field|
          value = contact.public_send(field)
          [field, value.is_a?(Pathname) ? value.to_s : value]
        end
      end

      def insert(table, values)
        placeholders = Array.new(values.length, '?').join(', ')
        @db.execute("INSERT INTO #{table} VALUES (#{placeholders})", values)
      end

      def evidence(value)
        JSON.generate(canonical(value))
      end

      def canonical(value)
        case value
        when Hash
          value.sort_by { |key, _| key.to_s }.to_h.transform_values { |entry| canonical(entry) }
        when Array
          value.map { |entry| canonical(entry) }
        else
          value
        end
      end

      def timestamp(value)
        value&.iso8601(9)
      end

      def source(value)
        return if value.nil?

        json = evidence(value)
        @sources[json] ||= begin
          id = @sources.length + 1
          insert(:sources, [id, *value.values_at(:path, :relative_path, :kind, :identifier), json])
          id
        end
      end

      def collections(contact, id)
        SqliteSchema::COLLECTIONS.each do |field, columns|
          contact.public_send(field).each_with_index do |entry, position|
            insert(field, [id, position, *entry.values_at(*columns), evidence(entry)])
          end
        end
        scalar_values(:notes, contact.notes, id)
        scalar_values(:group_labels, contact.groups, id)
      end

      def scalar_values(table, values, id)
        values.each_with_index { |value, position| insert(table, [id, position, value&.to_s, evidence(value)]) }
      end

      def dates(contact, id)
        SqliteSchema::DATE_FIELDS.each do |field|
          values = field == :dates ? contact.dates : [contact.public_send(field)].compact
          values.each_with_index do |entry, position|
            components = entry.values_at(:year, :month, :day, :label, :raw_label)
            insert(:dates, [id, field.to_s, position, *components, evidence(entry)])
          end
        end
      end

      def groups(contact, id, source_id)
        contact.group_memberships.each_with_index do |entry, position|
          json = evidence(entry)
          # Without source evidence, membership observations stay contact-local.
          key = [source_id || "contact:#{id}", json]
          group_id = @groups[key] ||= begin
            next_id = @groups.length + 1
            insert(:groups, [next_id, source_id, *entry.values_at(:record_id, :name), json])
            next_id
          end
          insert(:group_memberships, [id, position, group_id])
        end
      end
    end
  end
end
