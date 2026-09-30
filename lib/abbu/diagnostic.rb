# lib/abbu/diagnostic.rb
# frozen_string_literal: true

module Abbu
  class Diagnostic
    attr_reader :category, :context, :message, :parser, :source

    def initialize(category:, message:, parser:, source:, context: {})
      @category = category.to_sym
      @context = context.freeze
      @message = message.to_s.freeze
      @parser = parser.to_sym
      @source = source.to_s.freeze
      freeze
    end

    def to_h
      {
        category: category,
        message: message,
        parser: parser,
        source: source,
        context: context
      }
    end
  end
end
