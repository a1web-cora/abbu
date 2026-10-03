# lib/abbu/machine_output.rb
# frozen_string_literal: true

require_relative 'exporters/json_exporter'
require_relative 'utils/deduplicator'

module Abbu
  # Serialization only: no new identity inference, parser rules, or image reads.
  class MachineOutput
    def initialize(input)
      @input = input
    end

    def contacts(records = @input.contacts)
      Exporters::JsonExporter.new(records).payload
    end

    def stats
      records = @input.contacts
      { total_contacts: records.count, with_email: records.count { |c| c.emails.any? },
        with_phone: records.count { |c| c.phones.any? } }
    end

    def diagnostics
      @input.contacts
      @input.diagnostics.map(&:to_h)
    end

    def duplicates
      Utils::Deduplicator.new(@input.contacts).duplicates.map do |email, records|
        { email: email, contacts: contacts(records) }
      end
    end

    def matches
      Utils::Deduplicator.new(@input.contacts).matches.map do |match|
        { left: contacts([match.left]).first, right: contacts([match.right]).first,
          sources: match.sources, evidence: match.evidence, score: match.score,
          confidence: match.confidence, status: match.status }
      end
    end

    def images(destination)
      result = @input.extract_images(destination)
      files = result.files.map do |record|
        record.merge(contact: contacts([record[:contact]]).first,
                     source_path: record[:source_path].to_s, path: record[:path].to_s)
      end
      { files: files, diagnostics: result.diagnostics }
    end
  end
end
