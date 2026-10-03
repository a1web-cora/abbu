# lib/abbu/exporters/icalendar_exporter.rb
# frozen_string_literal: true

require 'date'
require 'digest'
require 'json'
require 'time'

require_relative 'icalendar_encoding'
require_relative 'icalendar_event'

module Abbu
  module Exporters
    # Derived reminders, not Apple calendar identities or a synchronization feed.
    class IcalendarExporter
      attr_reader :diagnostics

      def initialize(contacts, year:, generated_at:, calendar_id:)
        raise ArgumentError, 'year must be an Integer between 1 and 9996' unless
          year.is_a?(Integer) && (1..9996).cover?(year)
        raise ArgumentError, 'calendar_id must be a nonempty String' unless
          calendar_id.is_a?(String) && !calendar_id.strip.empty?

        @contacts = contacts
        @year = year
        @stamp = timestamp(generated_at)
        @calendar_id = IcalendarEncoding.text(calendar_id)
        @diagnostics = [].freeze
      end

      def to_file(path)
        File.binwrite(path, to_ical)
      end

      def to_stdout
        print to_ical
      end

      def to_ical
        @diagnostics = []
        lines = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//ABBU//Contact Reminders//EN', 'CALSCALE:GREGORIAN']
        @contacts.each_with_index { |contact, index| append_contact(lines, contact, index) }
        return '' if lines.length == 4

        lines << 'END:VCALENDAR'
        "#{lines.map { |line| IcalendarEncoding.fold(line) }.join("\r\n")}\r\n"
      ensure
        @diagnostics.freeze
      end

      private

      def timestamp(value)
        valid = value.is_a?(Time) && (1..9999).cover?(value.getutc.year)
        raise ArgumentError, 'generated_at must be a Time with a UTC year between 1 and 9999' unless valid

        value.getutc.strftime('%Y%m%dT%H%M%SZ')
      end

      def append_contact(lines, contact, index) # rubocop:disable Metrics/MethodLength
        diagnose(:unsupported_calendar, index, :lunar_birthday) if contact.lunar_birthday
        %i[birthday anniversary].each do |field|
          date = contact.public_send(field)
          next if date.nil?

          event = IcalendarEvent.new(date, year: @year, kind: field)
          if event.error
            diagnose(event.error, index, field)
          else
            lines.concat(event.lines(name: contact.full_name, uid: uid(contact, index, field), stamp: @stamp))
          end
        end
      end

      def uid(contact, index, field)
        name = IcalendarEncoding.text(contact.full_name)
        evidence = [@calendar_id, index, field, contact.source&.fetch(:relative_path, nil), name]
        "#{Digest::SHA256.hexdigest(JSON.generate(evidence))}@abbu.invalid"
      end

      def diagnose(category, index, field)
        @diagnostics << { category: category, contact_index: index, field: field }.freeze
      end
    end
  end
end
