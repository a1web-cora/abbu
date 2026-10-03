# lib/abbu/snapshot_diff.rb
# frozen_string_literal: true

require 'pathname'
require 'time'

require_relative 'utils/deduplicator'

module Abbu
  # Snapshot observations, not assertions of identity or events between captures.
  class SnapshotDiff
    FIELDS = %i[first_name middle_name last_name emails phones company addresses groups group_memberships
                nickname prefix suffix job_title department maiden_name phonetic_first_name phonetic_middle_name
                phonetic_last_name phonetic_company pronouns ringtone texttone urls notes related_names
                social_profiles birthday anniversary dates instant_messages verification_code lunar_birthday
                image_uri image_path created_at modified_at source].freeze

    attr_reader :result

    def initialize(before, after, max_pairs: 100_000)
      raise ArgumentError, 'max_pairs must be a positive Integer' unless max_pairs.is_a?(Integer) && max_pairs.positive?

      left = before.respond_to?(:contacts) ? before.contacts : before.to_a
      right = after.respond_to?(:contacts) ? after.contacts : after.to_a
      raise ArgumentError, 'snapshot comparison exceeds max_pairs' if left.length * right.length > max_pairs

      @result = freeze_tree(compare(left, right))
    end

    def to_h
      result
    end

    private

    def compare(left, right)
      candidates = candidates_for(left, right)
      @left_counts = candidates.map { |item| item[:before_index] }.tally
      @right_counts = candidates.map { |item| item[:after_index] }.tally
      @old_records = left.map { |contact| record(contact) }
      @new_records = right.map { |contact| record(contact) }
      classify(candidates)
    end

    def classify(candidates)
      paired, ambiguous = candidates.partition do |item|
        item[:score] >= Utils::Deduplicator::PROBABLE_SCORE &&
          @left_counts[item[:before_index]] == 1 && @right_counts[item[:after_index]] == 1
      end
      build_result(paired, ambiguous)
    end

    def candidates_for(left, right)
      left.each_with_index.flat_map do |old_contact, old_index|
        right.each_with_index.filter_map do |new_contact, new_index|
          match = Utils::Deduplicator.new([old_contact, new_contact]).matches.first
          next unless match

          { before_index: old_index, after_index: new_index, score: match.score, evidence: copy(match.evidence) }
        end
      end
    end

    def build_result(paired, ambiguous)
      changes = paired.map { |pair| comparison(pair) }
      {
        schema_version: 1,
        added: indexed_unmatched(@new_records, @right_counts),
        removed: indexed_unmatched(@old_records, @left_counts),
        changed: changes.reject { |item| item[:fields].empty? },
        unchanged: changes.select { |item| item[:fields].empty? },
        ambiguous: ambiguous.map { |pair| with_records(pair) }
      }
    end

    def with_records(pair)
      pair.merge(before: @old_records.fetch(pair[:before_index]), after: @new_records.fetch(pair[:after_index]))
    end

    def comparison(pair)
      records = with_records(pair)
      fields = FIELDS.filter_map do |field|
        next if records[:before][field] == records[:after][field]

        [field, { before: records[:before][field], after: records[:after][field] }]
      end.to_h
      records.merge(fields: fields)
    end

    def indexed_unmatched(records, counts)
      records.each_with_index.filter_map do |contact, index|
        { index: index, contact: contact } unless counts.key?(index)
      end
    end

    def record(contact)
      FIELDS.to_h { |field| [field, copy(contact.public_send(field))] }
    end

    def copy(value)
      case value
      when Hash then value.to_h { |key, item| [key, copy(item)] }
      when Array then value.map { |item| copy(item) }
      else copy_scalar(value)
      end
    end

    def copy_scalar(value)
      case value
      when Time then value.iso8601(9)
      when Pathname then value.to_s
      when String then value.dup
      else value
      end
    end

    def freeze_tree(value)
      case value
      when Hash then value.each { |key, item| [key, item].each { |part| freeze_tree(part) } }
      when Array then value.each { |item| freeze_tree(item) }
      end
      value.freeze
    end
  end
end
