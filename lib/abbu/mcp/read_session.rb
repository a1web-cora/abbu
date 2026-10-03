# lib/abbu/mcp/read_session.rb
# frozen_string_literal: true

module Abbu
  module Mcp
    # One explicitly selected input, cached by ABBU's public input API. No tool
    # may change its path, discover another store, export files, or apply edits.
    class ReadSession
      def initialize(input)
        @input = input
        @output = MachineOutput.new(input)
      end

      def query(mode:, value:, offset: 0, limit: 100)
        validate_page!(offset, limit)
        records = selection(mode, value).to_a
        page = records.slice(offset, limit) || []
        { contacts: @output.contacts(page), offset: offset, limit: limit, has_more: offset + limit < records.length }
      end

      def stats
        @output.stats
      end

      def diagnostics
        @output.diagnostics
      end

      def sources
        @input.sources.map(&:to_h)
      end

      def groups
        @input.groups.map(&:to_h)
      end

      private

      def selection(mode, value)
        query = Query.new(@input.contacts)
        case mode
        when 'search' then query.search(value)
        when 'email' then query.find_by_email(value)
        when 'phone' then query.find_by_phone(value)
        when 'modified_since' then query.modified_since(value)
        else raise ArgumentError, 'Unsupported query mode'
        end
      end

      def validate_page!(offset, limit)
        return if offset.is_a?(Integer) && offset >= 0 && limit.is_a?(Integer) && limit.between?(1, 500)

        raise ArgumentError, 'offset must be nonnegative and limit must be between 1 and 500'
      end
    end
  end
end
