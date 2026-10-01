# lib/abbu/source_catalog.rb
# frozen_string_literal: true

require 'pathname'
require_relative 'source'
require_relative 'utils/source_descriptor'

module Abbu
  # Internal adapter over the same file descriptors used by the parsers.
  class SourceCatalog
    def initialize(paths, root_path:, contacts:)
      @root_path = Pathname.new(root_path).expand_path
      @files = paths.map { |path| Utils::SourceDescriptor.new(path, root_path: root_path).to_h }
                    .sort_by { |file| file.fetch(:relative_path) }
      @contacts_by_path = contacts.group_by { |contact| contact.source&.fetch(:path, nil) }
    end

    def sources
      @files.group_by { |file| file.fetch(:identifier) }.map do |identifier, files|
        relative_path = identifier.nil? ? '.' : "Sources/#{identifier}"
        Source.new(path: @root_path.join(relative_path).to_s, relative_path: relative_path,
                   identifier: identifier, files: files, contacts: contacts_for(files))
      end.sort_by(&:relative_path).freeze
    end

    private

    def contacts_for(files)
      files.flat_map { |file| @contacts_by_path.fetch(file.fetch(:path), []) }
    end
  end
end
