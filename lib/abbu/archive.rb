# lib/abbu/archive.rb
# frozen_string_literal: true

require 'pathname'
require_relative 'parsers/sqlite_parser'
require_relative 'parsers/plist_parser'
require_relative 'utils/image_resolver'

module Abbu
  class Archive
    attr_reader :path

    def initialize(path)
      @path = Pathname.new(path)
      validate!
    end

    def contacts
      @contacts ||= parser.contacts.tap { |cs| attach_images(cs) }
    end

    def sqlite?
      db_paths.any?
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
        Parsers::SqliteParser.new(db_paths)
      else
        Parsers::PlistParser.new(plist_paths)
      end
    end

    def attach_images(contacts)
      return if contacts.empty?

      resolver = Utils::ImageResolver.new(@path)
      contacts.each do |contact|
        next unless contact.image_uri

        contact.image_path = resolver.resolve(contact.image_uri)
      end
    end
  end
end
