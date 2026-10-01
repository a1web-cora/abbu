# spec/abbu/archive_compatibility_spec.rb
# frozen_string_literal: true

require 'csv'
require 'digest'
require 'fileutils'
require 'json'
require 'spec_helper'
require 'tmpdir'

require_relative '../support/compatibility_fixtures'

RSpec.describe Abbu::Archive do
  CompatibilityFixtures::PROFILES.each do |profile, files|
    context "with #{profile}" do
      before { CompatibilityFixtures.build(directory, profile) }
      after { FileUtils.remove_entry(directory) }

      let(:directory) { Dir.mktmpdir('compatibility.abbu') }
      let(:archive) { Abbu.open(directory) }
      let(:selected_files) { files.any? { |_path, shape| shape != :xml } ? files.reject { |_p, s| s == :xml } : files }
      let(:record_files) { selected_files.reject { |_path, shape| shape == :empty } }

      it 'preserves records, raw labels, provenance, queries and source-local group membership' do
        contacts = archive.contacts
        expect(contacts.length).to eq(record_files.length)
        expect(contacts.map(&:first_name)).to eq(Array.new(record_files.length, 'Stan'))
        expect(contacts.map { |c| c.source[:relative_path] }).to eq(record_files.keys.sort)
        source_paths = archive.sources.flat_map(&:files).map { |file| file[:relative_path] }
        expect(source_paths.sort).to eq(selected_files.keys.sort)
        expect(archive.find_by_email('JOHN@EXAMPLE.COM').to_a).to eq(contacts)
        contacts.each do |contact|
          expect(contact.emails).to eq([{ address: 'john@example.com', label: 'Work', raw_label: '_$!<Work>!$_' }])
          shape = record_files.fetch(contact.source[:relative_path])
          expect(contact.created_at).to eq(shape == :complete ? Time.utc(2001, 1, 1) : nil)
          expect(contact.modified_at).to eq(shape == :complete ? Time.utc(2001, 1, 1, 0, 1, 0.5) : nil)
          expect(contact.groups).to eq(shape == :complete ? ['Colleagues'] : [])
          expect(archive.groups_for(contact).map(&:name)).to eq(contact.groups)
        end
        expect(archive.groups.length).to eq(record_files.values.count(:complete))
      end

      it 'keeps JSON, CSV and vCard exports usable without changing source file bytes' do
        before = checksums(directory)
        Dir.mktmpdir('compatibility-exports') do |output|
          contacts = archive.contacts
          json_path = File.join(output, 'contacts.json')
          csv_path = File.join(output, 'contacts.csv')
          vcard_path = File.join(output, 'contacts.vcf')
          Abbu::Exporters::JsonExporter.new(contacts).to_file(json_path)
          Abbu::Exporters::CsvExporter.new(contacts).to_file(csv_path)
          Abbu::Exporters::VcardExporter.new(contacts).to_file(vcard_path)
          json = JSON.parse(File.read(json_path))
          expect(json.length).to eq(record_files.length)
          expect(json.map { |row| row['emails'].first['raw_label'] })
            .to eq(Array.new(record_files.length, '_$!<Work>!$_'))
          expect(json.map { |row| row['source']['relative_path'] }).to eq(record_files.keys.sort)
          emails = CSV.read(csv_path, headers: true).map { |row| row['Email'] }
          expect(emails).to eq(Array.new(record_files.length, 'john@example.com'))
          vcard = File.read(vcard_path).gsub(/\r\n[ \t]/, '')
          expect(vcard.scan('BEGIN:VCARD').length).to eq(record_files.length)
          expect(vcard.scan('john@example.com').length).to eq(record_files.length)
        end
        expect(checksums(directory)).to eq(before)
      end

      it 'distinguishes tolerant sparse-schema recovery from complete strict-mode support' do
        archive.contacts
        if record_files.value?(:sparse)
          expect(archive.diagnostics.map(&:category).uniq).to eq([:missing_optional_data])
          expect(archive.diagnostics.map { |d| [d.source, d.context[:table]] }.uniq.length)
            .to eq(archive.diagnostics.length)
          expect { Abbu.open(directory, strict: true).contacts }.to raise_error(Abbu::ParseError)
        else
          expect(archive.diagnostics).to be_empty
          expect(Abbu.open(directory, strict: true).contacts.length).to eq(record_files.length)
        end
      end
    end
  end

  it 'does not silently fall back to plist when a selected SQLite database has an unknown required schema' do
    Dir.mktmpdir do |directory|
      CompatibilityFixtures.build(directory, :mixed_formats)
      SQLite3::Database.new(File.join(directory, 'AddressBook-v22.abcddb')) do |db|
        db.execute('ALTER TABLE ZABCDRECORD RENAME TO UNRECOGNIZED_RECORD')
      end
      archive = Abbu.open(directory)
      expect { archive.contacts }.to raise_error(Abbu::ParseError)
      expect(archive.diagnostics.first.category).to eq(:required_schema)
    end
  end

  it 'retains valid legacy XML siblings while reporting malformed records and honoring strict mode' do
    Dir.mktmpdir do |directory|
      CompatibilityFixtures.build(directory, :xml_records)
      File.write(File.join(directory, 'Records/broken.abcdp'), '<not-a-plist>')
      archive = Abbu.open(directory)
      expect(archive.contacts.map(&:first_name)).to eq(['Stan'])
      expect(archive.diagnostics.map(&:category)).to eq([:malformed_record])
      expect { Abbu.open(directory, strict: true).contacts }.to raise_error(Abbu::ParseError)
    end
  end

  def checksums(directory)
    paths = Dir.glob(File.join(directory, '**/*')).select { |path| File.file?(path) }
    paths.to_h { |path| [path.delete_prefix("#{directory}/"), Digest::SHA256.file(path).hexdigest] }
  end
end
