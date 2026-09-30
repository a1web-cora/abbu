# lib/abbu/utils/image_resolver.rb
# frozen_string_literal: true

require 'pathname'

module Abbu
  module Utils
    class ImageResolver
      EXTENSIONS = %w[jpg jpeg png heic].freeze

      def initialize(bundle_path)
        @bundle_path = Pathname.new(bundle_path).expand_path
        @index = build_index
      end

      def resolve(image_uri, source: nil)
        return nil if image_uri.nil? || image_uri.to_s.empty?

        candidates = @index.fetch(image_uri.to_s, [])
        return candidates.first if candidates.one?
        return if candidates.empty?

        source_local_candidate(candidates, source)
      end

      def each_image(&)
        return enum_for(:each_image) unless block_given?

        @index.each_value { |files| files.each(&) }
      end

      private

      def build_index
        image_files.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |file, hash|
          stem = file.basename('.*').to_s
          hash[stem] << file
        end
      end

      def image_files
        @bundle_path.glob('**/Images/*').select { |f| f.file? && image_extension?(f) }.sort
      end

      def image_extension?(file)
        ext = file.extname.downcase.delete_prefix('.')
        EXTENSIONS.include?(ext)
      end

      def source_local_candidate(candidates, source)
        return unless source

        database = @bundle_path.join(source.fetch(:relative_path, ''))
        local_images = database.dirname.join('Images').expand_path
        candidates.find { |candidate| candidate.dirname.expand_path == local_images }
      end
    end
  end
end
