# lib/abbu/archive.rb
# frozen_string_literal: true

require 'pathname'
require_relative 'diagnostic'
require_relative 'parse_error'
require_relative 'parsers/plist_parser'
require_relative 'parsers/sqlite_parser'
require_relative 'query'
require_relative 'schema_inspector'
require_relative 'utils/image_resolver'

module Abbu
  class Archive
    attr_reader :diagnostics, :path

    def initialize(path, strict: false)
      @path = Pathname.new(path)
      @strict = strict
      @diagnostics = []
      validate!
    end

    def contacts
      @contacts ||= parser.contacts.tap { |cs| attach_images(cs) }
    end

    def query
      Query.new(contacts)
    end

    def where(criteria)
      query.where(criteria)
    end

    def search(term)
      query.search(term)
    end

    def find_by_email(email)
      query.find_by_email(email)
    end

    def find_by_phone(phone)
      query.find_by_phone(phone)
    end

    def sqlite?
      db_paths.any?
    end

    def schema_report
      SchemaInspector.new(db_paths, root_path: @path).report
    end

    private

    def validate!
      raise ArgumentError, "ABBU path not found: #{@path}" unless @path.exist?
      raise ArgumentError, "Not a directory bundle: #{@path}" unless @path.directory?
    end

    def db_paths
      @db_paths ||= @path.glob('**/*.abcddb')
    end

    def plist_paths
      @plist_paths ||= @path.glob('**/*.abcdp').sort
    end

    def parser
      if sqlite?
        Parsers::SqliteParser.new(db_paths, root_path: @path, diagnostics: diagnostics, strict: @strict)
      else
        Parsers::PlistParser.new(plist_paths, root_path: @path, diagnostics: diagnostics, strict: @strict)
      end
    end

    def attach_images(contacts)
      return if contacts.empty?

      resolver = Utils::ImageResolver.new(@path)
      contacts.each do |contact|
        next unless contact.image_uri

        contact.image_path = resolver.resolve(contact.image_uri)
        record_missing_image(contact) unless contact.image_path
      end
    end

    def record_missing_image(contact)
      diagnostic = Diagnostic.new(
        category: :missing_image,
        message: 'Referenced contact image was not found',
        parser: :archive,
        source: contact.source&.fetch(:path, @path.to_s) || @path.to_s,
        context: { image_uri: contact.image_uri }.freeze
      )
      diagnostics << diagnostic
      raise ParseError, diagnostic if @strict
    end
  end
end
