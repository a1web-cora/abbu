# lib/abbu/live_store.rb
# frozen_string_literal: true

require 'pathname'
require 'sqlite3'
require_relative 'parsers/sqlite_parser'

module Abbu
  class LiveStore
    DATABASE_GLOB = 'AddressBook-v*.abcddb'
    DEFAULT_RELATIVE_PATH = 'Library/Application Support/AddressBook'

    class Error < StandardError; end
    class NotFoundError < Error; end
    class PermissionError < Error; end
    class UnsupportedPlatformError < Error; end

    attr_reader :diagnostics, :path

    def self.default_path(home: Dir.home, platform: RUBY_PLATFORM)
      unless platform.include?('darwin')
        raise UnsupportedPlatformError,
              'Automatic live Contacts discovery is available only on macOS; supply an AddressBook directory path.'
      end

      Pathname.new(home).join(DEFAULT_RELATIVE_PATH)
    end

    def initialize(path = nil, strict: false)
      @strict = strict
      @diagnostics = []
      @path = Pathname.new(path || self.class.default_path).expand_path
      validate!
    end

    def contacts
      @contacts ||= Parsers::SqliteParser.new(
        database_paths, root_path: @path, readonly: true, diagnostics: diagnostics, strict: @strict
      ).contacts
    rescue SQLite3::CantOpenException, Errno::EACCES => e
      raise permission_error(e.message)
    end

    def database_paths
      @database_paths ||= discover_database_paths.tap do |paths|
        raise NotFoundError, missing_database_message if paths.empty?
      end
    end

    private

    def validate!
      stat = @path.stat
      raise NotFoundError, "Live Contacts store is not a directory: #{@path}" unless stat.directory?

      ensure_readable_directory!(@path)
    rescue Errno::ENOENT
      raise NotFoundError, "Live Contacts store not found: #{@path}"
    rescue Errno::EACCES => e
      raise permission_error(e.message)
    end

    def discover_database_paths
      paths = @path.glob(DATABASE_GLOB)
      sources_path = @path.join('Sources')
      paths.concat(source_database_paths(sources_path)) if sources_path.exist?
      paths.sort.each { |db_path| ensure_readable_file!(db_path) }
    rescue Errno::EACCES => e
      raise permission_error(e.message)
    end

    def source_database_paths(sources_path)
      ensure_readable_directory!(sources_path)
      sources_path.children.sort.select(&:directory?).flat_map do |source_path|
        ensure_readable_directory!(source_path)
        source_path.glob(DATABASE_GLOB)
      end
    end

    def ensure_readable_directory!(path)
      return if path.readable? && path.executable?

      raise permission_error("directory is not readable: #{path}")
    end

    def ensure_readable_file!(path)
      return if path.file? && path.readable?

      raise permission_error("database is not readable: #{path}")
    end

    def missing_database_message
      "No #{DATABASE_GLOB} databases found in live Contacts store: #{@path}"
    end

    def permission_error(detail)
      PermissionError.new(
        "Cannot read live Contacts store at #{@path} (#{detail}). " \
        'Grant Full Disk Access to the terminal or application running abbu in ' \
        'System Settings > Privacy & Security > Full Disk Access, then retry.'
      )
    end
  end
end
