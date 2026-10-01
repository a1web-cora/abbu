# lib/abbu/group_catalog.rb
# frozen_string_literal: true

require_relative 'group'

module Abbu
  class GroupCatalog
    def initialize(contacts)
      @contacts = contacts
    end

    def groups
      memberships.group_by { |contact, membership| [contact.source[:path], membership[:record_id]] }
                 .values.map { |entries| build_group(entries) }
                        .sort_by { |group| [group.source[:relative_path], group.record_id] }.freeze
    end

    private

    def memberships
      @contacts.flat_map do |contact|
        contact.group_memberships.map { |membership| [contact, membership] }
      end
    end

    def build_group(entries)
      contact, membership = entries.first
      Group.new(record_id: membership[:record_id], name: membership[:name], source: contact.source,
                contacts: entries.map(&:first))
    end
  end
end
