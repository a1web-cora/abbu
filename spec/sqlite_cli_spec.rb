# spec/sqlite_cli_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'digest'
require 'open3'
require 'sqlite3'
require 'tmpdir'

RSpec.describe 'portable SQLite CLI' do # rubocop:disable RSpec/DescribeClass
  let(:bin) { File.expand_path('../bin/abbu', __dir__) }
  let(:sqlite_fixture) { File.expand_path('fixtures/TestContacts.abbu', __dir__) }
  let(:plist_fixture) { File.expand_path('fixtures/PlistContacts.abbu', __dir__) }

  it 'exports SQLite and legacy plist inputs into relational artifacts without source changes' do
    Dir.mktmpdir do |directory|
      [sqlite_fixture, plist_fixture].each_with_index do |fixture, index|
        paths = Dir.glob(File.join(fixture, '**/*')).select { |path| File.file?(path) }
        before = paths.to_h { |path| [path, Digest::SHA256.file(path).hexdigest] }
        path = File.join(directory, "contacts-#{index}.sqlite")
        stdout, _stderr, status = Open3.capture3(bin, fixture, '--format', 'sqlite', '--output', path)
        expect(status.exitstatus).to eq(0)
        expect(stdout).to eq('')
        SQLite3::Database.new(path, readonly: true) do |db|
          expect(db.get_first_value('SELECT count(*) FROM contacts')).to eq(Abbu.open(fixture).contacts.count)
          expect(db.get_first_value('SELECT raw_label FROM emails WHERE raw_label IS NOT NULL')).not_to be_nil
        end
        expect(paths.to_h { |file| [file, Digest::SHA256.file(file).hexdigest] }).to eq(before)
      end
    end
  end

  it 'supports explicit live-store input and protects an existing output' do
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'live.sqlite')
      stdout, _stderr, status = Open3.capture3(bin, '--live-path', sqlite_fixture, '-f', 'sqlite', '-o', path)
      expect(status.exitstatus).to eq(0)
      expect(stdout).to eq('')
      original = File.binread(path)
      stdout, stderr, status = Open3.capture3(bin, sqlite_fixture, '-f', 'sqlite', '-o', path)
      expect(status.exitstatus).to eq(2)
      expect(stdout).to eq('')
      expect(stderr).to include('no destination was replaced')
      expect(File.binread(path)).to eq(original)
    end
  end

  it 'rejects missing destinations and conflicting operations without producing output' do
    [['--format', 'sqlite'], ['--format', 'sqlite', '--output', 'unused', '--stats']].each do |arguments|
      stdout, stderr, status = Open3.capture3(bin, sqlite_fixture, *arguments)
      expect(status.exitstatus).to eq(2)
      expect(stdout).to eq('')
      expect(stderr).to include('standalone --format sqlite requires --output FILE')
    end
  end
end
