# lib/abbu/query.rb
# frozen_string_literal: true

module Abbu
  class Query
    include Enumerable

    def initialize(contacts)
      @contacts = contacts.to_a.freeze
    end

    def each(&)
      @contacts.each(&)
    end

    def where(criteria)
      self.class.new(select { |contact| matches_criteria?(contact, criteria) })
    end

    def search(term)
      normalized_term = normalize_email(term)
      return self.class.new([]) if normalized_term.empty?

      self.class.new(select do |contact|
        normalize_text(contact.full_name).include?(normalized_term) ||
          contact.emails.any? { |email| normalize_email(email[:address]).include?(normalized_term) }
      end)
    end

    def find_by_email(email)
      normalized_email = normalize_email(email)
      return self.class.new([]) if normalized_email.empty?

      self.class.new(select do |contact|
        contact.emails.any? { |entry| normalize_email(entry[:address]) == normalized_email }
      end)
    end

    def find_by_phone(phone)
      normalized_phone = normalize_phone(phone)
      return self.class.new([]) if normalized_phone.empty?

      self.class.new(select do |contact|
        contact.phones.any? { |entry| normalize_phone(entry[:number]) == normalized_phone }
      end)
    end

    def to_a
      @contacts.dup
    end

    private

    def matches_criteria?(contact, criteria)
      criteria.all? do |field, expected|
        actual = contact.public_send(field)
        actual.is_a?(Array) ? actual.include?(expected) : actual == expected
      end
    end

    def normalize_email(value)
      normalize_text(value).strip
    end

    def normalize_phone(value)
      value.to_s.gsub(/[^0-9]/, '')
    end

    def normalize_text(value)
      value.to_s.unicode_normalize(:nfc).downcase
    end
  end
end
