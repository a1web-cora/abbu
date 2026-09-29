# spec/abbu/parsers/plist_parser_spec.rb
# frozen_string_literal: true

require 'plist'
require 'tmpdir'

RSpec.describe Abbu::Parsers::PlistParser do
  def write_plist(dir, filename, data)
    File.write(File.join(dir, filename), data.to_plist)
  end

  def build_stan_plist # rubocop:disable Metrics/MethodLength
    {
      'First' => 'Stan',
      'Middle' => 'The Man',
      'Last' => 'Carver',
      'VerificationCode' => 'V123',
      'Organization' => 'Acme Corp',
      'JobTitle' => 'Engineer',
      'PhoneticFirst' => 'Stan',
      'PhoneticMiddle' => 'The Phony',
      'PhoneticLast' => 'Karver',
      'Department' => 'IT',
      'Nickname' => 'Stretch',
      'Title' => 'Honorable',
      'Suffix' => 'II',
      'Birthday' => Date.new(1980, 1, 1),
      'LunarBirthday' => Date.new(1980, 2, 5),
      'Dates' => {
        'values' => [
          { 'value' => Date.new(2010, 6, 15), 'label' => '_$!<Anniversary>!$_' }
        ]
      },
      'InstantMessage' => {
        'values' => [
          { 'value' => { 'address' => 'stan.carver', 'serviceName' => 'Skype' }, 'label' => 'Work' }
        ]
      },
      'Note' => 'Met at RubyConf',
      'Email' => {
        'values' => [
          { 'value' => 'stan@example.com', 'label' => 'Work' }
        ]
      },
      'Phone' => {
        'values' => [
          { 'value' => '555-1234', 'label' => 'Mobile' }
        ]
      },
      'Address' => {
        'values' => [
          {
            'value' => {
              'Street' => '123 Main St',
              'City' => 'Austin',
              'State' => 'TX',
              'ZIP' => '78701',
              'Country' => 'USA'
            },
            'label' => 'Home'
          }
        ]
      },
      'URLs' => {
        'values' => [
          { 'value' => 'https://stancarver.com', 'label' => 'homepage' }
        ]
      },
      'RelatedNames' => {
        'values' => [
          { 'value' => 'John', 'label' => 'brother' }
        ]
      },
      'SocialProfile' => {
        'values' => [
          { 'value' => { 'serviceName' => 'Twitter', 'username' => '@scarver2' } }
        ]
      }
    }
  end

  describe '#contacts' do
    it 'parses flat and multi-value fields from .abcdp files' do
      Dir.mktmpdir do |dir|
        write_plist(dir, 'stan.abcdp', build_stan_plist)

        parser  = described_class.new(dir)
        contact = parser.contacts.first

        # Phonetic names
        expect(contact.phonetic_first_name).to eq('Stan')
        expect(contact.phonetic_middle_name).to eq('The Phony')
        expect(contact.phonetic_last_name).to eq('Karver')

        # Flat fields
        expect(contact.first_name).to eq('Stan')
        expect(contact.middle_name).to eq('The Man')
        expect(contact.last_name).to  eq('Carver')
        expect(contact.company).to    eq('Acme Corp')
        expect(contact.job_title).to  eq('Engineer')
        expect(contact.department).to eq('IT')
        expect(contact.nickname).to   eq('Stretch')
        expect(contact.prefix).to     eq('Honorable')
        expect(contact.suffix).to     eq('II')
        expect(contact.birthday).to eq({ year: 1980, month: 1, day: 1, label: '_$!<Birthday>!$_' })
        expect(contact.lunar_birthday).to eq({ year: 1980, month: 2, day: 5, label: '_$!<LunarBirthday>!$_' })
        expect(contact.anniversary).to eq({ year: 2010, month: 6, day: 15, label: '_$!<Anniversary>!$_' })

        # Emails & phones (hash-based, same shape as SQLite parser)
        expect(contact.emails).to eq([{ address: 'stan@example.com', label: 'Work' }])
        expect(contact.phones).to eq([{ number: '555-1234', label: 'Mobile' }])

        # Addresses
        expect(contact.addresses).to eq([{
                                          street: '123 Main St', city: 'Austin', state: 'TX',
                                          zip: '78701', country: 'USA', label: 'Home'
                                        }])

        # URLs
        expect(contact.urls).to eq([{ url: 'https://stancarver.com', label: 'homepage' }])

        # Notes
        expect(contact.notes).to eq(['Met at RubyConf'])

        # Related names
        expect(contact.related_names).to eq([{ name: 'John', label: 'brother' }])

        # Social profiles
        expect(contact.social_profiles).to eq([{ service: 'Twitter', username: '@scarver2' }])
        expect(contact.instant_messages).to eq([{ address: 'stan.carver', label: 'Work', service: 'Skype' }])
        expect(contact.verification_code).to eq('V123')
      end
    end

    it 'parses multiple .abcdp files in sorted order' do
      Dir.mktmpdir do |dir|
        write_plist(dir, 'b_homer.abcdp', { 'First' => 'Homer', 'Last' => 'Simpson' })
        write_plist(dir, 'a_stan.abcdp', { 'First' => 'Stan', 'Last' => 'Carver' })

        parser   = described_class.new(dir)
        contacts = parser.contacts

        expect(contacts.size).to eq(2)
        expect(contacts.first.first_name).to eq('Stan')
        expect(contacts.last.first_name).to eq('Homer')
      end
    end

    it 'records the plist source relative to the ABBU root' do
      Dir.mktmpdir('Contacts.abbu') do |dir|
        records_dir = File.join(dir, 'Records')
        FileUtils.mkdir_p(records_dir)
        write_plist(records_dir, 'stan.abcdp', build_stan_plist)

        contact = described_class.new(records_dir, root_path: dir).contacts.first

        expect(contact.source).to eq({
                                       path: File.expand_path(File.join(records_dir, 'stan.abcdp')),
                                       relative_path: 'Records/stan.abcdp',
                                       kind: 'root',
                                       identifier: nil
                                     })
      end
    end

    it 'returns empty array when path does not exist' do
      parser = described_class.new('/nonexistent/path/Records')
      expect(parser.contacts).to eq([])
    end

    it 'returns empty array when directory has no .abcdp files' do
      Dir.mktmpdir do |dir|
        parser = described_class.new(dir)
        expect(parser.contacts).to eq([])
      end
    end

    it 'handles contacts with minimal data gracefully' do
      Dir.mktmpdir do |dir|
        write_plist(dir, 'minimal.abcdp', { 'First' => 'Prince' })

        parser  = described_class.new(dir)
        contact = parser.contacts.first

        expect(contact.first_name).to eq('Prince')
        expect(contact.last_name).to be_nil
        expect(contact.emails).to eq([])
        expect(contact.phones).to eq([])
        expect(contact.addresses).to eq([])
        expect(contact.notes).to eq([])
      end
    end

    it 'handles invalid date types in Plist gracefully' do
      Dir.mktmpdir do |dir|
        write_plist(dir, 'bad_date.abcdp', {
                      'First' => 'Bad',
                      'Birthday' => 'not a date',
                      'Dates' => { 'values' => [{ 'value' => 'not a date', 'label' => 'Other' }] }
                    })

        parser  = described_class.new(dir)
        contact = parser.contacts.first

        expect(contact.birthday).to be_nil
        expect(contact.dates).to eq([])
      end
    end
  end
end
