# lib/abbu/group.rb
# frozen_string_literal: true

require_relative 'query'

module Abbu
  # A snapshot of an observed SQLite group membership, local to one input file.
  # Names and record keys are evidence, not globally unique Apple identifiers.
  class Group
    attr_reader :record_id, :name, :source, :contacts

    def initialize(record_id:, name:, source:, contacts:)
      @record_id = record_id
      @name = name&.dup&.freeze
      @source = source.transform_values { |value| value&.dup&.freeze }.freeze
      @contacts = Query.new(contacts.to_a.uniq).freeze
      freeze
    end

    def include?(contact)
      contacts.any? { |member| member.equal?(contact) }
    end

    def to_h
      { record_id: record_id, name: name, source: source, contact_count: contacts.count }
    end
  end
end
