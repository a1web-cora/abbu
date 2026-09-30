# lib/abbu/utils/deduplicator.rb
# frozen_string_literal: true

require_relative 'contact_identity'

module Abbu
  module Utils
    class Deduplicator
      class MergePolicyRequired < ArgumentError; end

      class Match
        attr_reader :left, :right, :evidence, :score, :confidence, :status

        def initialize(left:, right:, evidence:, score:, status:)
          @left = left
          @right = right
          @evidence = evidence.freeze
          @score = score
          @confidence = confidence_for(score)
          @status = status
          freeze
        end

        def sources
          [left.source, right.source].freeze
        end

        def ambiguous?
          status == :ambiguous
        end

        def merge(policy: nil)
          raise MergePolicyRequired, 'an explicit callable merge policy is required' unless policy.respond_to?(:call)

          policy.call(left, right, evidence: evidence)
        end

        private

        def confidence_for(value)
          return :high if value >= 0.8
          return :medium if value >= 0.6

          :low
        end
      end

      WEIGHTS = {
        email: 0.8,
        international_phone: 0.65,
        source_local_phone: 0.45,
        name: 0.25,
        organization: 0.15
      }.freeze

      MINIMUM_SCORE = 0.4
      PROBABLE_SCORE = 0.6

      def initialize(contacts)
        @contacts = contacts
      end

      def duplicates
        @contacts
          .group_by { |c| c.emails.first }
          .reject { |k, _| k.nil? }
          .select { |_, v| v.size > 1 }
      end

      def matches
        identities = @contacts.map { |contact| ContactIdentity.new(contact) }
        candidates = identities.combination(2).filter_map { |left, right| candidate(left, right) }
        ambiguous_contacts = multiply_matched_contacts(candidates)

        candidates.map do |candidate|
          build_match(candidate, ambiguous_contacts)
        end
      end

      alias identity_matches matches

      private

      def candidate(left, right)
        evidence = evidence_for(left, right)
        score = evidence.map { |item| item[:type] }.uniq.sum { |type| WEIGHTS.fetch(type) }.clamp(0.0, 1.0).round(2)
        return if score < MINIMUM_SCORE

        { left: left.contact, right: right.contact, evidence: evidence, score: score }
      end

      def evidence_for(left, right)
        signal_pairs(left, right).flat_map do |left_signals, right_signals, same_source|
          shared_evidence(left_signals, right_signals, same_source: same_source)
        end
      end

      def signal_pairs(left, right)
        [
          [left.emails, right.emails, false],
          [left.phones, right.phones, left.same_source?(right)],
          [[left.name].compact, [right.name].compact, false],
          [[left.organization].compact, [right.organization].compact, false]
        ]
      end

      def shared_evidence(left_signals, right_signals, same_source: false)
        left_signals.filter_map do |left|
          right = right_signals.find { |candidate| comparable?(left, candidate, same_source) }
          evidence_record(left, right) if right
        end
      end

      def comparable?(left, right, same_source)
        return false unless left.type == right.type && left.normalized == right.normalized
        return same_source if left.type == :source_local_phone

        true
      end

      def evidence_record(left, right)
        {
          type: left.type,
          normalized: left.normalized,
          left_raw: left.raw,
          right_raw: right.raw
        }.freeze
      end

      def multiply_matched_contacts(candidates)
        counts = Hash.new(0).compare_by_identity
        candidates.each do |candidate|
          counts[candidate[:left]] += 1
          counts[candidate[:right]] += 1
        end
        counts.select { |_, count| count > 1 }.keys
      end

      def build_match(candidate, ambiguous_contacts)
        ambiguous = candidate[:score] < PROBABLE_SCORE ||
                    ambiguous_contacts.include?(candidate[:left]) ||
                    ambiguous_contacts.include?(candidate[:right])
        Match.new(**candidate, status: ambiguous ? :ambiguous : :probable)
      end
    end
  end
end
