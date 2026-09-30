# lib/abbu/parse_error.rb
# frozen_string_literal: true

module Abbu
  class ParseError < StandardError
    attr_reader :diagnostic

    def initialize(diagnostic)
      @diagnostic = diagnostic
      super("#{diagnostic.message} (#{diagnostic.source})")
    end
  end
end
