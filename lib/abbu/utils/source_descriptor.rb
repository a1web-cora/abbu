# lib/abbu/utils/source_descriptor.rb
# frozen_string_literal: true

require 'pathname'

module Abbu
  module Utils
    class SourceDescriptor
      def initialize(path, root_path: nil)
        @path = Pathname.new(path).expand_path
        @root_path = Pathname.new(root_path).expand_path if root_path
      end

      def to_h
        relative_path = relative_path_for(@path)
        parts = Pathname.new(relative_path).each_filename.to_a

        {
          path: @path.to_s,
          relative_path: relative_path,
          kind: parts.first == 'Sources' ? 'source' : 'root',
          identifier: parts.first == 'Sources' ? parts[1] : nil
        }.freeze
      end

      private

      def relative_path_for(path)
        return path.basename.to_s unless @root_path

        path.relative_path_from(@root_path).to_s
      end
    end
  end
end
