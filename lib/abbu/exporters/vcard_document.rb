# lib/abbu/exporters/vcard_document.rb
# frozen_string_literal: true

require_relative 'vcard_encoding'

module Abbu
  module Exporters
    # Per-card grouping avoids ambiguous associations between repeated labels.
    class VcardDocument
      TYPES = {
        'EMAIL' => %w[INTERNET X400 PREF],
        'TEL' => %w[HOME WORK PREF VOICE FAX MSG CELL PAGER BBS MODEM CAR ISDN VIDEO PCS],
        'ADR' => %w[DOM INTL POSTAL PARCEL HOME WORK PREF],
        'IMPP' => %w[PERSONAL BUSINESS HOME WORK MOBILE PREF]
      }.transform_values(&:freeze).freeze

      def initialize
        @lines = ['BEGIN:VCARD', 'VERSION:3.0']
        @group_number = 0
      end

      def <<(line)
        @lines << line
      end

      def labeled(property, value, entry, default_type: nil)
        type = standard_type(property, entry[:label]) || default_type
        header = type ? "#{property};TYPE=#{type}" : property
        label = entry[:raw_label] || entry[:label]
        return self << "#{header}:#{value}" if label.nil?

        @group_number += 1
        self << "item#{@group_number}.#{header}:#{value}"
        self << "item#{@group_number}.X-ABLABEL:#{VcardEncoding.text(label)}"
      end

      def to_s
        lines = (@lines + ['END:VCARD']).map { |line| VcardEncoding.fold(line) }
        "#{lines.join("\r\n")}\r\n"
      end

      private

      def standard_type(property, label)
        return unless label.to_s.match?(/\A[A-Za-z0-9-]+\z/)

        type = label.upcase
        return 'INTERNET,PREF' if property == 'EMAIL' && type == 'PREF'

        type if TYPES.fetch(property, []).include?(type)
      end
    end
  end
end
