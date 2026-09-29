# lib/abbu/utils/image_resolver.rb
# frozen_string_literal: true

require 'pathname'

module Abbu
  module Utils
    class ImageResolver
      EXTENSIONS = %w[jpg jpeg png heic].freeze

      def initialize(bundle_path)
        @bundle_path = Pathname.new(bundle_path)
        @index = build_index
      end

      def resolve(image_uri)
        return nil if image_uri.nil? || image_uri.to_s.empty?

        @index[image_uri.to_s]
      end

      def each_image(&)
        return enum_for(:each_image) unless block_given?

        @index.each_value(&)
      end

      private

      def build_index
        image_files.each_with_object({}) do |file, hash|
          stem = file.basename('.*').to_s
          hash[stem] = file
        end
      end

      def image_files
        @bundle_path.glob('**/Images/*').select { |f| f.file? && image_extension?(f) }
      end

      def image_extension?(file)
        ext = file.extname.downcase.delete_prefix('.')
        EXTENSIONS.include?(ext)
      end
    end
  end
end
