# lib/abbu/merge_plan.rb
# frozen_string_literal: true

require_relative 'contact'
require_relative 'merge_values'

module Abbu
  # A detached review artifact, not an assertion that two records are one person.
  # Materialization is opt-in and never writes an archive or live store.
  class MergePlan
    MULTIVALUES = %i[emails phones addresses groups urls notes related_names social_profiles
                     dates instant_messages].freeze
    SCALARS = %i[first_name middle_name last_name company nickname prefix suffix job_title department maiden_name
                 phonetic_first_name phonetic_middle_name phonetic_last_name phonetic_company pronouns ringtone
                 texttone birthday anniversary verification_code lunar_birthday created_at modified_at].freeze
    FIELDS = (MULTIVALUES + SCALARS + %i[image_uri image_path group_memberships source]).freeze
    POLICIES = %i[union_multivalues prefer_newer prefer_source prefer_more_complete].freeze

    attr_reader :policy, :fields, :sources, :conflicts

    def initialize(left, right, policy: nil, source: nil)
      validate_policy(policy, source)
      @policy = policy
      @records = [left, right].map { |contact| snapshot(contact) }.freeze
      @sources = @records.map { |record| record[:source] }.freeze
      preferred = preferred_index(source)
      @fields = build_fields(preferred).freeze
      @conflicts = @fields.select { |_, field| field[:conflict] }.freeze
      freeze
    end

    def to_h
      { policy: policy, sources: sources, inputs: @records, fields: fields, conflicts: conflicts.keys.freeze,
        materializable: !policy.nil? && conflicts.values.none? { |field| field[:unresolved] } }.freeze
    end

    def materialize
      validate_materialization
      Contact.new.tap do |contact|
        fields.each { |name, field| assign_field(contact, name, field[:selected]) }
      end
    end

    private

    def validate_policy(policy, source)
      raise ArgumentError, 'unknown merge policy' if policy && !POLICIES.include?(policy)
      raise ArgumentError, 'source requires prefer_source' if source && policy != :prefer_source
    end

    def validate_materialization
      raise ArgumentError, 'an explicit merge policy is required' unless policy
      raise ArgumentError, 'unresolved scalar conflicts require a deciding policy' if
        conflicts.values.any? { |field| field[:unresolved] }
    end

    def assign_field(contact, name, selected)
      values = name == :image ? selected || {} : { name => selected }
      values.each { |key, value| contact.public_send(:"#{key}=", MergeValues.copy(value)) }
    end

    def snapshot(contact)
      FIELDS.to_h { |name| [name, MergeValues.copy(contact.public_send(name), freeze: true)] }.freeze
    end

    def preferred_index(source)
      case policy
      when :prefer_source then source_index(source)
      when :prefer_newer then comparison_index(@records.map { |record| record[:modified_at] }, Time)
      when :prefer_more_complete then comparison_index(@records.map { |record| completeness(record) }, Integer)
      end
    end

    def source_index(source)
      raise ArgumentError, 'prefer_source requires an exact source relative_path' unless source.is_a?(String)

      indices = sources.each_index.select { |index| sources[index]&.fetch(:relative_path, nil) == source }
      raise ArgumentError, 'preferred source must identify exactly one input' unless indices.one?

      indices.first
    end

    def comparison_index(values, type)
      return unless values.all?(type)
      return if values[0] == values[1]

      values[0] > values[1] ? 0 : 1
    end

    def completeness(record)
      (SCALARS - %i[created_at modified_at]).count { |key| present?(record[key]) } +
        MULTIVALUES.count { |key| present?(record[key]) }
    end

    def present?(value)
      !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
    end

    def build_fields(preferred)
      result = union_fields
      SCALARS.each { |name| result[name] = scalar_field(@records.map { |record| record[name] }, preferred) }
      result[:image] = scalar_field(images, preferred)
      result
    end

    def union_fields
      MULTIVALUES.to_h do |name|
        values = @records.map { |record| record.fetch(name) }
        [name, { selected: values.flatten(1).uniq.freeze, reason: :lossless_union, conflict: false }.freeze]
      end
    end

    def images
      @records.map do |record|
        image = record.slice(:image_uri, :image_path)
        image.freeze if image.values.any? { |value| present?(value) }
      end
    end

    def scalar_field(values, preferred)
      conflict = values[0] != values[1] && values.all? { |value| present?(value) }
      index = conflict ? preferred : values.index { |value| present?(value) }
      selected = index.nil? ? nil : values[index]
      { selected: selected, alternatives: values.freeze, conflict: conflict,
        unresolved: conflict && preferred.nil?, reason: reason(conflict) }.freeze
    end

    def reason(conflict)
      conflict ? policy || :review_required : :uncontested
    end
  end
end
