# lib/abbu/exporters/icalendar_encoding.rb
# frozen_string_literal: true

module Abbu
  module Exporters
    # RFC 5545 TEXT and 75-octet content lines, without splitting UTF-8.
    module IcalendarEncoding
      module_function

      def text(value)
        utf8(value).gsub(/\\|;|,|\r\n|\r|\n/) do |character|
          character.match?(/[\r\n]/) ? '\\n' : "\\#{character}"
        end
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
        raise ArgumentError, 'iCalendar text has invalid encoding' unless string.valid_encoding?
        raise ArgumentError, 'iCalendar text contains an unsupported control character' if
          string.match?(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/)

        string
      end
    end
  end
end
