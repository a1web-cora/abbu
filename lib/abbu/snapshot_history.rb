# lib/abbu/snapshot_history.rb
# frozen_string_literal: true

require_relative 'archive'
require_relative 'history_tracker'

module Abbu
  # Stream snapshot observations; IDs are local to this ordered analysis only.
  class SnapshotHistory
    include Enumerable

    DEFAULT_LIMITS = { snapshots: 100, contacts: 10_000, pairs: 100_000 }.freeze

    def initialize(paths, strict: false, retention: 2, limits: {})
      limits = validated_limits(limits)
      raise ArgumentError, 'retention must be a nonnegative integer' unless retention.is_a?(Integer) && retention >= 0

      @paths = snapshot_paths(paths, limits[:snapshots])
      @strict = strict
      @options = { retention: retention, max_contacts: limits[:contacts], max_pairs: limits[:pairs] }.freeze
    end

    def self.from_directory(path, **)
      raise ArgumentError, 'snapshot directory is unavailable' unless File.directory?(path)

      paths = Dir.children(path).sort.filter_map do |name|
        candidate = File.join(path, name)
        candidate if name.end_with?('.abbu') && File.directory?(candidate)
      end
      new(paths, **)
    end

    def each
      return enum_for(:each) unless block_given?

      tracker = HistoryTracker.new(**@options)
      @paths.each_with_index do |path, index|
        archive = Archive.new(path, strict: @strict)
        snapshot = { index: index, path: path }.freeze
        transition = tracker.advance(archive.contacts, snapshot)
        yield transition.merge(diagnostics: archive.diagnostics.map(&:to_h).freeze).freeze
      end
      self
    end

    private

    def validated_limits(limits)
      raise ArgumentError, 'unknown limit' unless (limits.keys - DEFAULT_LIMITS.keys).empty?

      DEFAULT_LIMITS.merge(limits).tap do |settings|
        settings.each_value do |bound|
          raise ArgumentError, 'limits must be positive integers' unless bound.is_a?(Integer) && bound.positive?
        end
      end
    end

    def snapshot_paths(paths, limit)
      result = paths.take(limit + 1).map { |path| File.expand_path(path).freeze }.freeze
      raise ArgumentError, 'snapshot count exceeds max_snapshots' if result.length > limit
      raise ArgumentError, 'snapshot paths must be unique' if result.uniq.length != result.length

      result
    end
  end
end
