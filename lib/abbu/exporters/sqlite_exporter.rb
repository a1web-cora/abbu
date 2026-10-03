# lib/abbu/exporters/sqlite_exporter.rb
# frozen_string_literal: true

require 'pathname'
require 'sqlite3'
require 'tempfile'

require_relative '../version'
require_relative 'sqlite_rows'
require_relative 'sqlite_schema'

module Abbu
  module Exporters
    # A separate, plaintext derived artifact. Publication never replaces a file.
    class SqliteExporter
      SCHEMA_VERSION = SqliteSchema::VERSION

      def initialize(contacts)
        @contacts = contacts
      end

      def to_file(path)
        destination = destination_path(path)
        contacts = @contacts.to_a
        check_source_boundaries(contacts, destination)
        Tempfile.create(['.abbu-export-', '.sqlite'], File.dirname(destination)) do |file|
          file.close
          build(file.path, contacts)
          File.link(file.path, destination)
        end
        destination
      end

      private

      def destination_path(path)
        expanded = File.expand_path(path)
        parent = File.realpath(File.dirname(expanded))
        destination = File.join(parent, File.basename(expanded))
        raise Errno::EEXIST, destination if File.exist?(destination) || File.symlink?(destination)
        if [parent, File.dirname(expanded)].any? { |entry| abbu_ancestors(entry).any? }
          raise ArgumentError, 'SQLite export destination must be outside source ABBU bundles'
        end

        destination
      end

      def check_source_boundaries(contacts, destination)
        contacts.each do |contact|
          path = contact.source&.fetch(:path, nil)
          next unless path

          if source_bundles(path).any? { |bundle| destination.start_with?("#{bundle}/") }
            raise ArgumentError, 'SQLite export destination must be outside source ABBU bundles'
          end
        end
      end

      def source_bundles(path)
        paths = [File.expand_path(path)]
        paths << File.realpath(path) if File.exist?(path)
        paths.flat_map do |entry|
          abbu_ancestors(entry).map do |ancestor|
            File.exist?(ancestor) ? File.realpath(ancestor) : ancestor.to_s
          end
        end
      end

      def abbu_ancestors(path)
        Pathname.new(path).ascend.select { |ancestor| ancestor.extname.downcase == '.abbu' }
      end

      def build(path, contacts)
        SQLite3::Database.new(path) do |db|
          SqliteSchema.create(db)
          db.transaction do
            db.execute('INSERT INTO metadata VALUES (?, ?)', [SCHEMA_VERSION, Abbu::VERSION])
            rows = SqliteRows.new(db)
            contacts.each_with_index { |contact, index| rows.write(contact, index + 1) }
          end
        end
      end
    end
  end
end
