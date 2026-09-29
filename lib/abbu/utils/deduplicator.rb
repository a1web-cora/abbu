# lib/abbu/utils/deduplicator.rb
# frozen_string_literal: true

module Abbu
  module Utils
    class Deduplicator
      def initialize(contacts)
        @contacts = contacts
      end

      def duplicates
        @contacts
          .group_by { |c| c.emails.first }
          .reject { |k, _| k.nil? }
          .select { |_, v| v.size > 1 }
      end
    end
  end
end
