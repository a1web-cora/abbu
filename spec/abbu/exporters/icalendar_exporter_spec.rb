# spec/abbu/exporters/icalendar_exporter_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

require_relative '../../support/calendar_fixtures'

RSpec.describe Abbu::Exporters::IcalendarExporter do
  let(:contact) do
    Abbu::Contact.new.tap do |person|
      person.first_name = 'Équipe'
      person.birthday = { year: 1980, month: 2, day: 29 }
      person.anniversary = { year: nil, month: 12, day: 31, label: 'Custom', raw_label: '周年;🎉' }
    end
  end
  let(:options) { { year: 2026, generated_at: Time.utc(2026, 10, 1), calendar_id: 'fixture@example.test' } }
  let(:exporter) { described_class.new([contact], **options) }

  def unfolded(exporter)
    exporter.to_ical.gsub(/\r\n[ \t]/, '')
  end

  it 'writes complete deterministic all-day recurring events without source mutation' do
    original = Marshal.dump(contact)
    content = unfolded(exporter)
    expect(content).to start_with("BEGIN:VCALENDAR\r\nVERSION:2.0\r\n")
    expect(content).to end_with("END:VCALENDAR\r\n")
    expect(content.scan('BEGIN:VEVENT').length).to eq(2)
    expect(content.scan('RRULE:FREQ=YEARLY').length).to eq(2)
    expect(content).to include('DTSTART;VALUE=DATE:20280229', 'DTSTART;VALUE=DATE:20261231',
                               'DURATION:P1D', 'TRANSP:TRANSPARENT', 'DTSTAMP:20261001T000000Z',
                               'Original year: 1980.', 'Original year unknown', 'X-ABBU-YEAR-UNKNOWN:TRUE',
                               'SUMMARY:Équipe — 周年\\;🎉')
    first = exporter.to_ical
    expect(exporter.to_ical).to eq(first)
    expect(exporter.diagnostics).to eq([])
    expect(Marshal.dump(contact)).to eq(original)
  end

  it 'uses Gregorian leap rules, future source years, and zero as unknown without inventing age' do
    contact.birthday = { year: 0, month: 2, day: 29 }
    contact.anniversary = { year: 2105, month: 1, day: 1 }
    content = unfolded(described_class.new([contact], **options, year: 2100))
    expect(content).to include('DTSTART;VALUE=DATE:21040229', 'DTSTART;VALUE=DATE:21050101')
    expect(content).not_to include('Original year: 2000', 'Original year: 0')
  end

  it 'preserves Unicode, custom labels, blanks, wrapped labels, and injection-shaped TEXT' do
    contact.first_name = "#{'界' * 60},;\\\r\nBEGIN:VEVENT\rX\nY"
    contact.birthday[:raw_label] = '_$!<Birthday>!$_'
    contact.anniversary[:raw_label] = ''
    wire = exporter.to_ical
    expect(wire.lines.all? { |line| line.delete_suffix("\r\n").bytesize <= 75 }).to be(true)
    expect(wire.lines.all?(&:valid_encoding?)).to be(true)
    content = wire.gsub(/\r\n[ \t]/, '')
    expect(content).to include('\\,\\;\\\\\\nBEGIN:VEVENT\\nX\\nY — _$!<Birthday>!$_')
    expect(content).not_to include(' — Custom', ' — 周年')
    expect(content.scan("\r\nBEGIN:VEVENT\r\n").length).to eq(2)
  end

  it 'keeps duplicate contacts distinct and scopes deterministic UIDs to the caller namespace' do
    wire = described_class.new([contact, contact], **options).to_ical.gsub(/\r\n[ \t]/, '')
    ids = wire.scan(/^UID:(.+)\r$/).flatten
    expect(ids.uniq.length).to eq(4)
    other = unfolded(described_class.new([contact], **options, calendar_id: 'other@example.test'))
    expect(other).not_to include(ids.first)
  end

  it 'reports alternate-calendar and malformed values without leaking contact data' do
    contact.lunar_birthday = { year: 1980, month: 1, day: 1 }
    contact.birthday[:calendar] = 'chinese'
    contact.anniversary[:day] = 32
    expect(exporter.to_ical).to eq('')
    expect(exporter.diagnostics).to eq([
                                         { category: :unsupported_calendar, contact_index: 0, field: :lunar_birthday },
                                         { category: :unsupported_calendar, contact_index: 0, field: :birthday },
                                         { category: :invalid_date, contact_index: 0, field: :anniversary }
                                       ])
    expect(exporter.diagnostics).to be_frozen
    expect(exporter.diagnostics).to all(be_frozen)
    contact.lunar_birthday = contact.birthday = contact.anniversary = nil
    expect(exporter.to_ical).to eq('')
    expect(exporter.diagnostics).to eq([])
  end

  it 'rejects invalid normalized dates rather than coercing strings or fractional components' do
    invalid = [false, {}, { year: -1, month: 1, day: 1 }, { year: 10_000, month: 1, day: 1 },
               { year: 1900, month: 2, day: 29 }, { year: '2000', month: 1, day: 1 },
               { year: 2000, month: 1.5, day: 1 }]
    contact.anniversary = nil
    invalid.each do |value|
      contact.birthday = value
      expect(exporter.to_ical).to eq('')
    end
    contact.birthday = []
    expect(exporter.to_ical).to eq('')
    expect(exporter.diagnostics.first[:category]).to eq(:invalid_date)
  end

  it 'requires explicit bounded metadata even when input is empty' do
    [{ year: 0 }, { year: 9997 }, { year: '2026' }, { calendar_id: ' ' }, { calendar_id: nil },
     { generated_at: '2026-10-01' }, { generated_at: Time.utc(10_000) }].each do |override|
      expect { described_class.new([], **options, **override) }.to raise_error(ArgumentError)
    end
    expect(described_class.new([], **options).to_ical).to eq('')
  end

  it 'rejects invalid encodings and controls before overwriting existing output' do
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'output.ics')
      File.write(path, 'keep')
      ["bad\x01", "bad\xFF".dup.force_encoding(Encoding::UTF_8)].each do |name|
        contact.first_name = name
        expect { exporter.to_file(path) }.to raise_error(ArgumentError)
        expect(File.read(path)).to eq('keep')
      end
    end
  end

  it 'writes identical bytes to files and stdout' do
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'output.ics')
      expect(exporter.to_file(path)).to eq(exporter.to_ical.bytesize)
      expect(File.binread(path).force_encoding(Encoding::UTF_8)).to eq(exporter.to_ical)
      expect { exporter.to_stdout }.to output(exporter.to_ical).to_stdout
    end
  end

  it 'exports existing legacy plist evidence without mutating labels or adding calendar semantics' do
    Dir.mktmpdir('calendar.abbu') do |directory|
      CalendarFixtures.plist(directory)
      parsed = Abbu.open(directory).contacts.first
      original = Marshal.dump(parsed)
      result = described_class.new([parsed], **options)
      expect(unfolded(result)).to include('DTSTART;VALUE=DATE:20260101', '_$!<Anniversary>!$_')
      expect(Marshal.dump(parsed)).to eq(original)
      expect(result.diagnostics).to include(category: :unsupported_calendar, contact_index: 0, field: :lunar_birthday)
    end
  end

  it 'exports SQLite date evidence and raw labels without changing its database bytes' do
    Dir.mktmpdir('calendar.abbu') do |directory|
      path = CalendarFixtures.sqlite(directory)
      bytes = File.binread(path)
      parsed = Abbu.open(directory).contacts
      result = described_class.new(parsed, **options)
      expect(unfolded(result)).to include('DTSTART;VALUE=DATE:20280229', '_$!<Anniversary>!$_')
      expect(File.binread(path)).to eq(bytes)
    end
  end
end
