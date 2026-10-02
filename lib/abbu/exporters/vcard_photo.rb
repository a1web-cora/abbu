# lib/abbu/exporters/vcard_photo.rb
# frozen_string_literal: true

require 'uri'

module Abbu
  module Exporters
    # Serialization only: never resolves Apple image identifiers or converts bytes.
    class VcardPhoto
      def initialize(mode)
        raise ArgumentError, 'photo_mode must be :uri or :embedded' unless %i[uri embedded].include?(mode)

        @mode = mode
      end

      def property(contact)
        path = contact.image_path
        return embedded(contact) if @mode == :embedded
        return unless path

        escaped = URI::DEFAULT_PARSER.escape(path.to_s)
        "PHOTO;VALUE=URI:#{URI::Generic.build(scheme: 'file', path: escaped)}"
      end

      private

      def embedded(contact)
        return unless contact.image_path || contact.image_uri

        path = contact.image_path
        raise ArgumentError, 'embedded photo is missing' unless path && File.file?(path)

        bytes = File.binread(path)
        type = image_type(bytes)
        raise ArgumentError, 'embedded photo has unsupported content (HEIC is not supported)' unless type

        "PHOTO;ENCODING=b;TYPE=#{type}:#{[bytes].pack('m0')}"
      rescue IOError, SystemCallError
        raise ArgumentError, 'embedded photo is unreadable'
      end

      def image_type(bytes)
        return 'JPEG' if bytes.start_with?("\xFF\xD8\xFF".b)
        return 'PNG' if bytes.start_with?("\x89PNG\r\n\x1A\n".b)

        'GIF' if bytes.start_with?('GIF87a', 'GIF89a')
      end
    end
  end
end
