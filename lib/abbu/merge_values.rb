# lib/abbu/merge_values.rb
# frozen_string_literal: true

require 'date'

module Abbu
  module MergeValues
    module_function

    def copy(value, freeze: false)
      result = duplicate(value, freeze: freeze)
      freeze ? result.freeze : result
    end

    def duplicate(value, freeze:)
      case value
      when Hash then value.to_h { |key, item| [copy(key, freeze: freeze), copy(item, freeze: freeze)] }
      when Array then value.map { |item| copy(item, freeze: freeze) }
      when String, Time, Date then value.dup
      when NilClass, TrueClass, FalseClass, Symbol, Numeric then value
      else raise ArgumentError, 'unsupported contact value'
      end
    end
  end
  private_constant :MergeValues
end
