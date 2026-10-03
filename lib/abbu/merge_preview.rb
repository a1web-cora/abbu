# lib/abbu/merge_preview.rb
# frozen_string_literal: true

require_relative 'merge_plan'
require_relative 'utils/deduplicator'

module Abbu
  class MergePreview
    def self.validate!(options)
      return unless options.values_at(:merge_preview, :merge_policy, :prefer_source).any?

      raise ArgumentError, '--merge-policy/--prefer-source require --merge-preview' unless options[:merge_preview]

      allowed = %i[merge_preview merge_policy prefer_source strict live live_path]
      raise ArgumentError, '--merge-preview cannot be combined with other operations' if
        options.any? { |key, value| value && !allowed.include?(key) }
    end

    def self.plans(contacts, policy: nil, source: nil)
      validate_policy!(policy, source)
      Utils::Deduplicator.new(contacts).matches.map do |match|
        { status: match.status, score: match.score, evidence: match.evidence,
          plan: MergePlan.new(match.left, match.right, policy: policy, source: source).to_h }
      end
    end

    def self.validate_policy!(policy, source)
      # Validate policies even for empty inputs, before enumerating candidate pairs.
      MergePlan.new(Contact.new, Contact.new, policy: policy) unless policy == :prefer_source
      raise ArgumentError, 'source requires prefer_source' if source && policy != :prefer_source
      raise ArgumentError, 'prefer_source requires a source path' if policy == :prefer_source && !source.is_a?(String)
    end
    private_class_method :validate_policy!
  end
end
