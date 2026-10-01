# lib/abbu/timestamp_range.rb
# frozen_string_literal: true

require 'date'

module Abbu
  # Internal filter over observed timestamps, never a claim about human edits.
  class TimestampRange
    FORMAT = /\A\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d+)?(?:Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)\z/

    def initialize(field, since: nil, before: nil)
      raise ArgumentError, 'field must be :created_at or :modified_at' unless %i[created_at modified_at].include?(field)
      raise ArgumentError, 'at least one timestamp bound is required' if since.nil? && before.nil?

      @since = parse(since) unless since.nil?
      @before = parse(before) unless before.nil?
      validate_order
    end

    def include?(value)
      !value.nil? && (@since.nil? || value >= @since) && (@before.nil? || value < @before)
    end

    private

    def validate_order
      raise ArgumentError, 'since must be earlier than before' if @since && @before && @since >= @before
    end

    def parse(value)
      return value if value.is_a?(Time)

      unless value.is_a?(String) && FORMAT.match?(value)
        raise ArgumentError, 'timestamp must be a Time or ISO 8601 datetime with explicit timezone'
      end

      DateTime.iso8601(value, Date::GREGORIAN).to_time
    end
  end
end
