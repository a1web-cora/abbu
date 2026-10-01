# lib/abbu/source.rb
# frozen_string_literal: true

require_relative 'query'

module Abbu
  # An observed input container, not an inferred Apple account or provider.
  # Metadata and membership are frozen; contacts retain their existing mutability.
  class Source
    attr_reader :path, :relative_path, :kind, :identifier, :files, :contacts, :group_names

    def initialize(path:, relative_path:, identifier:, files:, contacts:)
      @path = copy_string(path)
      @relative_path = copy_string(relative_path)
      @identifier = copy_string(identifier)
      @kind = identifier.nil? ? 'root' : 'source'
      @files = snapshot_files(files)
      @contacts = Query.new(contacts.to_a.dup).freeze
      @group_names = snapshot_group_names
      freeze
    end

    # No currently supported evidence identifies an account provider.
    def provider
      nil
    end

    def to_h
      { path: path, relative_path: relative_path, kind: kind, identifier: identifier,
        provider: provider, files: files, contact_count: contacts.count, group_names: group_names }
    end

    private

    def copy_string(value)
      value&.dup&.freeze
    end

    def snapshot_files(files)
      files.map { |file| file.transform_values { |value| copy_string(value) }.freeze }.freeze
    end

    def snapshot_group_names
      @contacts.flat_map(&:groups).compact.uniq.sort.map { |name| copy_string(name) }.freeze
    end
  end
end
