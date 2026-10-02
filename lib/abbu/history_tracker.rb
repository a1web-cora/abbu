# lib/abbu/history_tracker.rb
# frozen_string_literal: true

require_relative 'snapshot_diff'

module Abbu
  class HistoryTracker
    def initialize(retention:, max_pairs:, max_contacts:)
      @retention = retention
      @max_pairs = max_pairs
      @max_contacts = max_contacts
      @pool = []
      @next_id = 0
    end

    def advance(contacts, snapshot)
      raise ArgumentError, 'snapshot exceeds max_contacts' if contacts.length > @max_contacts

      diff = SnapshotDiff.new(@pool.map { |entry| entry[:contact] }, contacts, max_pairs: @max_pairs).to_h
      current, observations = observations_for(diff, contacts, snapshot)
      absent = absent_for(diff, snapshot)
      ambiguity = ambiguity_for(diff)
      retain(diff, current, snapshot)
      { schema_version: 1, snapshot: snapshot, observations: observations.freeze,
        absent: absent.freeze, ambiguous: ambiguity.freeze }.freeze
    end

    private

    def ambiguity_for(diff)
      diff[:ambiguous].map do |pair|
        pair.merge(before_timeline_id: @pool.fetch(pair[:before_index])[:timeline_id]).freeze
      end
    end

    def observations_for(diff, contacts, snapshot)
      lookups = record_lookups(diff)
      @current = []
      observations = contacts.each_with_index.map do |contact, index|
        observe_contact(contact, index, snapshot, lookups)
      end
      [@current, observations]
    end

    def record_lookups(diff)
      { pairs: (diff[:changed] + diff[:unchanged]).to_h { |pair| [pair[:after_index], pair] },
        added: diff[:added].to_h { |item| [item[:index], item[:contact]] },
        uncertain: diff[:ambiguous].to_h { |pair| [pair[:after_index], pair[:after]] } }
    end

    def observe_contact(contact, index, snapshot, lookups)
      pair = lookups[:pairs][index]
      previous = pair && @pool.fetch(pair[:before_index])
      entry = track(contact, previous, snapshot)
      @current << entry
      record = lookups[:added][index] || lookups[:uncertain][index]
      observation(entry, pair, record, previous, lookups[:uncertain].key?(index))
    end

    def track(contact, previous, snapshot)
      @next_id += 1 unless previous
      { contact: contact, timeline_id: previous ? previous[:timeline_id] : @next_id,
        first_seen: previous ? previous[:first_seen] : snapshot, last_seen: snapshot }
    end

    def observation(entry, pair, record, previous, ambiguous)
      details = { event: event_for(entry, previous, ambiguous), contact: pair ? pair[:after] : record,
                  changes: pair ? pair[:fields] : {}.freeze, compared_with: previous && previous[:last_seen] }
      details[:match] = pair&.slice(:score, :evidence)&.freeze
      entry.except(:contact).merge(details).freeze
    end

    def event_for(entry, previous, ambiguous)
      return ambiguous ? :ambiguous_start : :first_seen unless previous

      previous[:last_seen][:index] < entry[:last_seen][:index] - 1 ? :reappeared : :observed
    end

    def absent_for(diff, snapshot)
      diff[:removed].filter_map do |item|
        entry = @pool.fetch(item[:index])
        next unless entry[:last_seen][:index] == snapshot[:index] - 1

        entry.except(:contact).merge(event: :absent, observed_at: snapshot).freeze
      end
    end

    def retain(diff, current, snapshot)
      removed = diff[:removed].map { |item| @pool.fetch(item[:index]) }
      dormant = removed.select { |entry| snapshot[:index] - entry[:last_seen][:index] <= @retention }
      @pool = current + dormant
      raise ArgumentError, 'retained history exceeds max_contacts' if @pool.length > @max_contacts
    end
  end
  private_constant :HistoryTracker
end
