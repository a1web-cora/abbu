# lib/abbu/exporters/vcard_encoding.rb
# frozen_string_literal: true

require 'uri'

module Abbu
  module Exporters
    # Internal wire encoding; URI values and TEXT values have different grammars.
    module VcardEncoding
      module_function

      def text(value)
        utf8(value).gsub(/\\|;|,|\r\n|\r|\n/) do |character|
          character.match?(/[\r\n]/) ? '\\n' : "\\#{character}"
        end
      end

      def structured(values)
        values.map { |value| text(value) }.join(';')
      end

      def uri(value)
        URI::DEFAULT_PARSER.escape(utf8(value), %r{[^A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]})
      end

      def token(value)
        string = utf8(value)
        raise ArgumentError, 'vCard parameter must be an ASCII token' unless string.match?(/\A[A-Za-z0-9-]+\z/)

        string
      end

      def fold(line)
        parts = [+'']
        utf8(line).each_char do |character|
          parts << +' ' if parts.last.bytesize + character.bytesize > 75
          parts.last << character
        end
        parts.join("\r\n")
      end

      def utf8(value)
        string = value.to_s.encode(Encoding::UTF_8)
        raise ArgumentError, 'vCard text has invalid encoding' unless string.valid_encoding?
        if string.match?(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/)
          raise ArgumentError,
                'vCard text contains an unsupported control character'
        end

        string
      end
    end
  end
end
