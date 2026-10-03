# benchmarks/streaming.rb
# frozen_string_literal: true

require 'abbu'
require 'json'
require 'sqlite3'
require 'tmpdir'

require_relative '../spec/support/fixture_generator'

mode = ARGV.fetch(0, 'stream')
count = Integer(ARGV.fetch(1, '10000'), 10)
abort 'Usage: bin/benchmark-streaming [stream|buffered] [positive record count]' unless
  %w[stream buffered].include?(mode) && count.positive?

Dir.mktmpdir('abbu-stream-benchmark') do |directory|
  SQLite3::Database.new(File.join(directory, 'AddressBook-v22.abcddb')) do |database|
    FixtureGenerator.setup_schema(database)
    database.transaction do
      count.times do |index|
        database.execute('INSERT INTO ZABCDRECORD (Z_PK, Z_ENT, ZFIRSTNAME) VALUES (?, ?, ?)',
                         [index + 1, 1, "Synthetic #{index}"])
      end
    end
  end
  GC.start
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  archive = Abbu.open(directory)
  contacts = mode == 'stream' ? archive.each_contact : archive.contacts
  peak_contacts = 0
  observed = 0
  contacts.each do |_contact|
    observed += 1
    next unless (observed % 1000).zero? || observed == count

    GC.start
    peak_contacts = [peak_contacts, ObjectSpace.each_object(Abbu::Contact).count].max
  end
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  puts JSON.generate(mode: mode, count: observed, seconds: elapsed.round(3),
                     sampled_live_contacts: peak_contacts, diagnostics: archive.diagnostics.length)
end
