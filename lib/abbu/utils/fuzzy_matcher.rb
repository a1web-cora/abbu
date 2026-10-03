# lib/abbu/utils/fuzzy_matcher.rb
# frozen_string_literal: true

require_relative 'deduplicator'

module Abbu
  module Utils
    # Suggestions, not identity assertions. Bounds fail explicitly rather than
    # silently truncating candidates; source contacts are never modified.
    class FuzzyMatcher
      FUZZY_WEIGHT = 0.15

      def initialize(contact, candidates, threshold: 0.85, max_candidates: 10_000, max_name_length: 128)
        validate_options(threshold, max_candidates, max_name_length)
        @contact = contact
        @candidates = candidates.take(max_candidates + 1)
        raise ArgumentError, 'candidate limit exceeded' if @candidates.length > max_candidates

        @threshold = threshold
        @max_name_length = max_name_length
      end

      def matches
        left_name = normalized_name(@contact)
        results = @candidates.filter_map do |candidate|
          next if candidate.equal?(@contact)

          suggestion(candidate, left_name, normalized_name(candidate))
        end
        return results unless results.count { |match| match.score >= Deduplicator::MINIMUM_SCORE } > 1

        results.map do |match|
          Deduplicator::Match.new(left: match.left, right: match.right, evidence: match.evidence,
                                  score: match.score, status: :ambiguous)
        end
      end

      private

      def validate_options(threshold, *bounds)
        raise ArgumentError, 'threshold must be finite and between 0 and 1' unless
          threshold.is_a?(Numeric) && threshold.real? && threshold.finite? && threshold.between?(0, 1)

        bounds.each { |bound| validate_bound(bound) }
      end

      def validate_bound(bound)
        raise ArgumentError, 'bounds must be positive integers' unless bound.is_a?(Integer) && bound.positive?
      end

      def normalized_name(contact)
        name = contact.full_name.unicode_normalize(:nfc).downcase.strip.gsub(/\s+/, ' ')
        raise ArgumentError, 'name length limit exceeded' if name.length > @max_name_length

        name
      end

      def suggestion(candidate, left_name, right_name)
        exact = Deduplicator.new([@contact, candidate]).matches.first
        fuzzy = fuzzy_evidence(candidate, left_name, right_name)
        return unless exact || fuzzy

        evidence = combined_evidence(exact, fuzzy)
        score = exact ? exact.score : fuzzy.fetch(:contribution)
        Deduplicator::Match.new(left: @contact, right: candidate, evidence: evidence,
                                score: score, status: exact ? exact.status : :ambiguous)
      end

      def combined_evidence(exact, fuzzy)
        evidence = exact ? exact_evidence(exact) : []
        evidence << fuzzy.merge(contribution: exact ? 0.0 : fuzzy.fetch(:contribution)).freeze if fuzzy
        evidence
      end

      def exact_evidence(exact)
        remaining = exact.score
        seen = []
        exact.evidence.map do |item|
          contribution = seen.include?(item[:type]) ? 0.0 : [Deduplicator::WEIGHTS.fetch(item[:type]), remaining].min
          remaining = (remaining - contribution).round(2)
          seen << item[:type]
          item.merge(contribution: contribution).freeze
        end
      end

      def fuzzy_evidence(candidate, left_name, right_name)
        return if left_name.empty? || right_name.empty?

        distance = edit_distance(left_name.codepoints, right_name.codepoints)
        similarity = 1.0 - (distance.to_f / [left_name.length, right_name.length].max)
        return if similarity < @threshold

        { type: :fuzzy_name, algorithm: :levenshtein, left_raw: @contact.full_name,
          right_raw: candidate.full_name, left_normalized: left_name, right_normalized: right_name,
          distance: distance, similarity: similarity, contribution: (similarity * FUZZY_WEIGHT).round(4) }.freeze
      end

      def edit_distance(left, right)
        row = (0..right.length).to_a
        left.each_with_index do |character, index|
          row = distance_row(row, right, character, index)
        end
        row.last
      end

      def distance_row(row, right, character, index)
        next_row = [index + 1]
        right.each_with_index do |other, column|
          substitution = row[column] + (character == other ? 0 : 1)
          next_row << [next_row[column] + 1, row[column + 1] + 1, substitution].min
        end
        next_row
      end
    end
  end
end
