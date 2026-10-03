# spec/icalendar_cli_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'
require 'tmpdir'

require_relative 'support/calendar_fixtures'

RSpec.describe 'iCalendar CLI' do # rubocop:disable RSpec/DescribeClass
  let(:bin) { File.expand_path('../bin/abbu', __dir__) }
  let(:args) do
    ['--format', 'icalendar', '--calendar-year', '2026', '--calendar-stamp', '2026-10-01T00:00:00Z',
     '--calendar-id', 'fixture@example.test']
  end

  it 'emits deterministic calendar-only stdout and separate omission diagnostics' do
    Dir.mktmpdir('calendar.abbu') do |directory|
      CalendarFixtures.plist(directory)
      stdout, stderr, status = Open3.capture3(bin, directory, *args)
      expect(status.exitstatus).to eq(0)
      expect(stdout).to start_with("BEGIN:VCALENDAR\r\n")
      expect(stdout).not_to include('unsupported_calendar')
      expect(stderr).to include('Calendar unsupported_calendar: contact 0, lunar_birthday')
      repeated, = Open3.capture3(bin, directory, *args)
      expect(repeated).to eq(stdout)
      path = File.join(directory, 'result.ics')
      file_stdout, _, file_status = Open3.capture3(bin, directory, *args, '--output', path)
      expect(file_status.exitstatus).to eq(0)
      expect(file_stdout).to eq('')
      expect(File.binread(path)).to eq(stdout.b)
    end
  end

  it 'supports explicitly opened live stores without writing their database' do
    Dir.mktmpdir do |directory|
      path = CalendarFixtures.sqlite(directory)
      bytes = File.binread(path)
      stdout, _stderr, status = Open3.capture3(bin, '--live-path', directory, *args)
      expect(status.exitstatus).to eq(0)
      expect(stdout).to include('DTSTART;VALUE=DATE:20280229')
      expect(File.binread(path)).to eq(bytes)
    end
  end

  it 'rejects missing metadata, conflicting modes, and malformed timestamps before output' do
    Dir.mktmpdir('calendar.abbu') do |directory|
      CalendarFixtures.plist(directory)
      bad_args = [['--format', 'icalendar'], ['--calendar-year', '2026'], args + ['--stats'],
                  args + ['--calendar-stamp', '2026-10-01'], args + ['--calendar-stamp', '2026-02-30T00:00:00Z'],
                  args + ['--calendar-year', '0']]
      bad_args.each do |arguments|
        stdout, stderr, status = Open3.capture3(bin, directory, *arguments)
        expect(stdout).to eq('')
        expect(stderr).to include('abbu:')
        expect(status.exitstatus).to eq(2)
      end
    end
  end

  it 'rejects calendar metadata in machine modes instead of ignoring it' do
    %w[--json --matches --diagnostics].each do |mode|
      [['--calendar-year', '2026'], ['--calendar-stamp', '2026-10-01T00:00:00Z'],
       ['--calendar-id', 'fixture@example.test'], args].each do |metadata|
        stdout, stderr, status = Open3.capture3(bin, '/missing.abbu', mode, *metadata)
        expect(status.exitstatus).to eq(2)
        expect(JSON.parse(stdout)).to include('error' => include('code' => 'invalid_input'))
        expect(stdout).to include('Calendar options require')
        expect(stderr).to be_empty
      end
    end
  end
end
