# spec/abbu/exporters/vcard_exporter_fidelity_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'plist'
require 'sqlite3'
require 'tmpdir'

RSpec.describe Abbu::Exporters::VcardExporter do
  it 'emits deterministic CRLF cards without blank separators or an extra stdout newline' do
    contact = Abbu::Contact.new
    contact.first_name = 'Ada'
    expected = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Ada\r\nN:;Ada;;;\r\nEND:VCARD\r\n"
    expect(export([contact])).to eq(expected)
    expect(export([contact, contact])).to eq(expected * 2)
    expect { described_class.new([contact]).to_stdout }.to output(expected).to_stdout
    expect { described_class.new([]).to_stdout }.not_to output.to_stdout
    expect(export([])).to eq('')
  end

  it 'round-trips reserved characters in each name and address component without changing structure' do
    contact = Abbu::Contact.new
    value = "Équipe;North,West\\desk\nline:two"
    %i[first_name middle_name last_name prefix suffix nickname company job_title
       phonetic_first_name phonetic_middle_name phonetic_last_name verification_code].each do |field|
      contact.public_send(:"#{field}=", value)
    end
    contact.addresses = [{ street: value, city: value, state: value, zip: value, country: value }]
    lines = logical_lines(export([contact]))
    expect(decode_text(property_value(lines, 'FN'))).to eq(contact.full_name)
    expect(text_components(property_value(lines, 'N'))).to eq([value] * 5)
    expect(text_components(property_value(lines, 'ADR'))).to eq(['', ''] + ([value] * 5))
    %w[NICKNAME ORG TITLE X-PHONETIC-FIRST-NAME X-PHONETIC-MIDDLE-NAME
       X-PHONETIC-LAST-NAME X-VERIFICATION-CODE].each do |property|
      expect(decode_text(property_value(lines, property))).to eq(value)
    end
  end

  it 'preserves repeated notes and escapes newline variants without injecting properties' do
    contact = Abbu::Contact.new
    contact.notes = ["one\r\ntwo\rthree\nfour;five,six\\n", "\nEND:VCARD\nBEGIN:VCARD"]
    lines = logical_lines(export([contact]))
    notes = lines.grep(/^NOTE:/).map { |line| decode_text(line.delete_prefix('NOTE:')) }
    expect(notes).to eq(["one\ntwo\nthree\nfour;five,six\\n", contact.notes.last])
    expect(lines.count('BEGIN:VCARD')).to eq(1)
    expect(lines.count('END:VCARD')).to eq(1)
    expect(contact.notes.first).to include("\r\n")
  end

  it 'folds at 75 octets including continuation spaces without splitting UTF-8 characters' do
    contact = Abbu::Contact.new
    contact.notes = ['a' * 70, 'a' * 71, "#{'a' * 69}🤠#{'é' * 80}", "x\ty " * 60]
    output = export([contact])
    physical_lines = output.split("\r\n")
    expect(physical_lines.map(&:bytesize).max).to eq(75)
    expect(physical_lines).to all(be_valid_encoding)
    expect(output).to include("\r\n ")
    expect(output.gsub("\r\n", '')).not_to match(/[\r\n]/)
    expect(logical_lines(output).grep(/^NOTE:/).map { |line| decode_text(line.delete_prefix('NOTE:')) })
      .to eq(contact.notes)
  end

  it 'preserves URI punctuation and existing escapes while encoding unsafe bytes' do
    contact = Abbu::Contact.new
    contact.urls = [{ url: "https://example.test/a%20b;x,y?q=é\nX:1", raw_label: 'Website' }]
    contact.instant_messages = [{ service: 'XMPP', address: 'person@example.test/a b', label: 'Work' }]
    lines = logical_lines(export([contact]))
    expect(property_value(lines, 'URL')).to eq('https://example.test/a%20b;x,y?q=%C3%A9%0AX:1')
    expect(property_value(lines, 'IMPP')).to eq('xmpp:person@example.test/a%20b')
    expect(lines.grep(/IMPP/).first).to include(';TYPE=WORK:')
    expect(lines.grep(/^X:/)).to be_empty
  end

  it 'uses per-card groups for repeated properties and retains raw rather than friendly labels' do
    contact = Abbu::Contact.new
    contact.emails = [{ address: 'a@example.test', label: 'Work', raw_label: '_$!<Work>!$_' },
                      { address: 'b@example.test', label: 'Office', raw_label: "Office;desk,\\\n🤠" }]
    contact.phones = [{ number: '123', label: 'CELL', raw_label: '' }]
    contact.anniversary = { year: 2020, month: 1, day: 2, label: 'Anniversary', raw_label: '_$!<Anniversary>!$_' }
    before = Marshal.dump(contact)
    output = export([contact])
    lines = logical_lines(output)
    expect(labels_for(lines, 'EMAIL')).to eq(contact.emails.map { |entry| entry[:raw_label] })
    expect(labels_for(lines, 'TEL')).to eq([''])
    expect(labels_for(lines, 'X-ABDATE')).to eq(['_$!<Anniversary>!$_'])
    expect(lines.grep(/TEL/).first).to eq('item3.TEL;TYPE=CELL:123')
    expect(output).not_to include('TYPE=PREF')
    expect(export([contact, contact])).to eq(output * 2)
    expect(Marshal.dump(contact)).to eq(before)
  end

  it 'keeps unlabeled values and safe existing extension payloads without fabricating UID or preference' do
    contact = Abbu::Contact.new
    contact.emails = [{ address: 'a@example.test' }]
    contact.phones = [{ number: '123' }]
    contact.urls = [{ url: 'https://example.test' }]
    contact.instant_messages = [{ address: 'person' }]
    contact.social_profiles = [{ service: 'Example', username: 'name;one' }, { username: 'name,two' }]
    lines = logical_lines(export([contact]))
    expect(lines).to include('EMAIL;TYPE=INTERNET:a@example.test', 'TEL;TYPE=VOICE:123',
                             'URL:https://example.test', 'IMPP:unknown:person',
                             'X-SOCIALPROFILE;TYPE=Example:name\\;one', 'X-SOCIALPROFILE:name\\,two')
    expect(lines.grep(/UID|PREF|X-ABLABEL/)).to be_empty
  end

  it 'recognizes only exact ASCII standard type labels and preserves excluded near-matches' do
    contact = Abbu::Contact.new
    labels = ['Work', 'work', ' work ', 'Workplace', 'poſtal', '_$!<Work>!$', 'Mobile']
    contact.addresses = labels.map { |label| { street: 'Road', label: label, raw_label: label } }
    lines = logical_lines(export([contact]))
    addresses = lines.grep(/\.ADR[;:]/)
    expect(addresses.first(2)).to all(include('ADR;TYPE=WORK:'))
    expect(addresses.drop(2)).to all(include('.ADR:'))
    expect(labels_for(lines, 'ADR')).to eq(labels)
  end

  it 'preserves explicitly supplied standard type names including numeric and preference tokens' do
    contact = Abbu::Contact.new
    contact.emails = [{ address: 'legacy@example.test', label: 'X400' },
                      { address: 'preferred@example.test', label: 'pref' }]
    lines = logical_lines(export([contact]))
    expect(lines).to include('item1.EMAIL;TYPE=X400:legacy@example.test',
                             'item2.EMAIL;TYPE=PREF:preferred@example.test')
    expect(labels_for(lines, 'EMAIL')).to eq(%w[X400 pref])
  end

  it 'rejects unsafe service parameters, invalid UTF-8 and unsupported controls before file writes' do
    invalid_contacts = ['Service;TYPE=PREF', "Service\nNOTE:injected", 'Service"quote'].map do |service|
      contact = Abbu::Contact.new
      contact.social_profiles = [{ service: service, username: 'user' }]
      contact
    end
    contact = Abbu::Contact.new
    contact.instant_messages = [{ service: 'bad:scheme', address: 'user' }]
    invalid_contacts << contact
    ["bad\x00text", "\xFF".dup.force_encoding('UTF-8')].each do |value|
      contact = Abbu::Contact.new
      contact.first_name = value
      invalid_contacts << contact
    end
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'existing.vcf')
      File.write(path, 'unchanged')
      invalid_contacts.each do |invalid|
        expect { described_class.new([invalid]).to_file(path) }.to raise_error(ArgumentError)
        expect(File.read(path)).to eq('unchanged')
      end
    end
    expect do
      exporter = described_class.new([Abbu::Contact.new, invalid_contacts.first])
      expect { exporter.to_stdout }.to raise_error(ArgumentError)
    end.not_to output.to_stdout
  end

  it 'retains Apple, custom, near-match, normalized, blank and Unicode labels through SQLite and plist parsing' do
    labels = ['_$!<Work>!$_', 'Work', '_$!<Work>!$', 'Work;PREF:yes', ' Équipe 🤠 ', '']
    %i[sqlite plist].each do |format|
      labels.each do |label|
        with_labeled_archive(format, label) do |archive|
          contact = archive.contacts.first
          expect(contact.emails.first[:raw_label]).to eq(label)
          expect(labels_for(logical_lines(export([contact])), 'EMAIL')).to eq([label])
        end
      end
    end
  end

  def export(contacts)
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'contacts.vcf')
      described_class.new(contacts).to_file(path)
      File.binread(path).force_encoding('UTF-8')
    end
  end

  # Deliberately independent, fixture-only decoder; not a production vCard importer.
  def logical_lines(output)
    output.gsub(/\r\n[ \t]/, '').split("\r\n")
  end

  def property_value(lines, property)
    lines.find { |line| line.match?(/\A(?:item\d+\.)?#{property}(?:;[^:]*)?:/) }.split(':', 2).last
  end

  def decode_text(value)
    value.gsub(/\\([\\,;nN])/) { Regexp.last_match(1).match?(/[nN]/) ? "\n" : Regexp.last_match(1) }
  end

  def text_components(value)
    # Keep escaped pairs intact, splitting only unescaped structural separators.
    tokens = value.scan(/\\.|[^\\]/m)
    parts = [+'']
    tokens.each { |token| token == ';' ? parts << +'' : parts.last << token }
    parts.map { |component| decode_text(component) }
  end

  def labels_for(lines, property)
    lines.grep(/\Aitem\d+\.#{property}[;:]/).map do |line|
      group = line.split('.', 2).first
      decode_text(lines.find { |candidate| candidate.start_with?("#{group}.X-ABLABEL:") }.split(':', 2).last)
    end
  end

  def with_labeled_archive(format, label) # rubocop:disable Metrics/MethodLength
    Dir.mktmpdir do |directory|
      if format == :sqlite
        path = File.join(directory, 'AddressBook-v22.abcddb')
        FileUtils.cp(File.expand_path('../../fixtures/TestContacts.abbu/AddressBook-v22.abcddb', __dir__), path)
        SQLite3::Database.new(path) { |db| db.execute('UPDATE ZABCDEMAILADDRESS SET ZLABEL = ?', [label]) }
      else
        data = { 'First' => 'Synthetic',
                 'Email' => { 'values' => [{ 'value' => 'a@example.test', 'label' => label }] } }
        File.write(File.join(directory, 'contact.abcdp'), data.to_plist)
      end
      yield Abbu.open(directory)
    end
  end
end
