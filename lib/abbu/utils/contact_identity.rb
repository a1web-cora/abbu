# lib/abbu/utils/contact_identity.rb
# frozen_string_literal: true

module Abbu
  module Utils
    class ContactIdentity
      Signal = Struct.new(:type, :normalized, :raw, keyword_init: true)

      attr_reader :contact

      def initialize(contact)
        @contact = contact
      end

      def emails
        contact.emails.filter_map do |entry|
          raw = entry.is_a?(Hash) ? entry[:address] : entry
          normalized = normalize_email(raw)
          Signal.new(type: :email, normalized: normalized, raw: raw).freeze if valid_email?(normalized)
        end
      end

      def phones
        contact.phones.filter_map do |entry|
          raw = entry.is_a?(Hash) ? entry[:number] : entry
          normalized = normalize_phone(raw)
          Signal.new(type: phone_type(normalized), normalized: normalized, raw: raw).freeze if normalized
        end
      end

      def name
        signal(:name, contact.full_name)
      end

      def organization
        signal(:organization, contact.company)
      end

      def source
        contact.source
      end

      def same_source?(other)
        source_key = source&.fetch(:relative_path, nil)
        source_key && source_key == other.source&.fetch(:relative_path, nil)
      end

      private

      def signal(type, raw)
        normalized = normalize_text(raw)
        Signal.new(type: type, normalized: normalized, raw: raw).freeze unless normalized.empty?
      end

      def normalize_text(value)
        value.to_s.unicode_normalize(:nfkc).downcase
             .gsub(/[^\p{Alnum}\p{Mark}]+/u, ' ')
             .strip
             .gsub(/\s+/, ' ')
      end

      def normalize_email(value)
        value.to_s.unicode_normalize(:nfkc).strip.downcase
      end

      def valid_email?(value)
        value.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
      end

      def normalize_phone(value)
        raw = value.to_s.strip
        extension = raw[/\b(?:ext\.?|x)\s*(\d+)\z/i, 1]
        core = raw.sub(/\b(?:ext\.?|x)\s*\d+\z/i, '')
        digits = core.gsub(/\D/, '')
        international = international?(core, digits)
        digits = digits.delete_prefix('00') if international
        return unless valid_phone_length?(digits, international)

        prefix = international ? '+' : 'national:'
        normalized = "#{prefix}#{digits}"
        extension ? "#{normalized};ext=#{extension}" : normalized
      end

      def valid_phone_length?(digits, international)
        international ? digits.length.between?(8, 15) : digits.length >= 7
      end

      def international?(raw, digits)
        raw.start_with?('+') || digits.start_with?('00')
      end

      def phone_type(normalized)
        normalized.start_with?('+') ? :international_phone : :source_local_phone
      end
    end
  end
end
