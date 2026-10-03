# lib/abbu/exporters/icalendar_event.rb
# frozen_string_literal: true

require 'date'

require_relative 'icalendar_encoding'

module Abbu
  module Exporters
    # Internal validation of normalized Gregorian date components only.
    class IcalendarEvent
      attr_reader :error

      def initialize(date, year:, kind:)
        @date = date
        @year = year
        @kind = kind
        @error = validate
      end

      def lines(name:, uid:, stamp:)
        label = @date[:raw_label] || @date[:label] || @kind.to_s.capitalize
        start = occurrence.strftime('%Y%m%d')
        ['BEGIN:VEVENT', "UID:#{uid}", "DTSTAMP:#{stamp}", "DTSTART;VALUE=DATE:#{start}",
         'DURATION:P1D', 'RRULE:FREQ=YEARLY', 'TRANSP:TRANSPARENT',
         "SUMMARY:#{IcalendarEncoding.text("#{name} — #{label}")}",
         "X-ABBU-YEAR-UNKNOWN:#{unknown_year? ? 'TRUE' : 'FALSE'}",
         "DESCRIPTION:#{IcalendarEncoding.text(description)}", 'END:VEVENT']
      end

      private

      def validate
        return :invalid_date unless @date.is_a?(Hash)
        return :unsupported_calendar unless [nil, 'gregorian', :gregorian].include?(@date[:calendar])

        values = @date.values_at(:month, :day)
        year = unknown_year? ? 2000 : @date[:year]
        return :invalid_date unless [year, *values].all?(Integer) && (1..9999).cover?(year)
        return :invalid_date unless Date.valid_date?(year, *values, Date::GREGORIAN)

        nil
      end

      def unknown_year?
        @date[:year].nil? || (@date[:year].is_a?(Integer) && @date[:year].zero?)
      end

      def occurrence
        year = [@year, unknown_year? ? @year : @date[:year]].max
        year += 1 until Date.valid_date?(year, @date[:month], @date[:day], Date::GREGORIAN)
        Date.new(year, @date[:month], @date[:day], Date::GREGORIAN)
      end

      def description
        origin = unknown_year? ? 'Original year unknown; no age is asserted.' : "Original year: #{@date[:year]}."
        "ABBU reminder. DTSTART is the recurrence start, not an assertion of birth or marriage year. #{origin}"
      end
    end
  end
end
