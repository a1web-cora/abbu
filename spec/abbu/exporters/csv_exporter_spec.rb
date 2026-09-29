# spec/abbu/exporters/csv_exporter_spec.rb
# frozen_string_literal: true

require 'tmpdir'
require 'csv'
require 'pathname'

RSpec.describe Abbu::Exporters::CsvExporter do
  let(:contact) do
    c = Abbu::Contact.new
    c.first_name = 'Stan'
    c.last_name  = 'Carver'
    c.emails     = [{ address: 'stan@example.com', label: 'Work' }]
    c.phones     = [{ number: '555-1234', label: 'Work' }]
    c.company    = 'Acme'
    c.addresses  = [{ street: '123 Main', city: 'Dallas', state: 'TX', zip: '75001', country: 'USA' }]
    c.groups     = ['Friends']
    c.urls       = [{ url: 'https://stancarver.com', label: 'homepage' }]
    c.notes      = ['Great guy']
    c.related_names = [{ name: 'John', label: 'brother' }]
    c.social_profiles = [{ service: 'Twitter', username: '@scarver2' }]
    c.birthday    = { year: 1980, month: 1, day: 1 }
    c.anniversary = { year: 2010, month: 6, day: 15 }
    c.lunar_birthday = { year: 1980, month: 2, day: 5 }
    c.instant_messages = [{ address: 'stan.carver', label: 'Work', service: 'Skype' }]
    c.verification_code = 'V123'
    c.image_path = Pathname.new('/tmp/Contacts.abbu/Images/stan.jpg')
    c
  end

  let(:exporter) { described_class.new([contact]) }

  describe '#to_file' do
    it 'writes a CSV file with headers and one data row' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'out.csv')
        exporter.to_file(path)
        rows = CSV.read(path)

        expected_headers = %w[Name First Middle Last Email Phone Company Address Groups URLs Notes RelatedNames
                              SocialProfiles Birthday Anniversary InstantMessages VerificationCode
                              LunarBirthday ImagePath]
        expect(rows.first).to eq(expected_headers)

        expected_row = [
          'Stan Carver', 'Stan', nil, 'Carver', 'stan@example.com', '555-1234', 'Acme',
          '123 Main, Dallas, TX, 75001, USA', 'Friends',
          'https://stancarver.com', 'Great guy',
          'John (brother)', '@scarver2 on Twitter',
          '1980-01-01', '2010-06-15',
          'stan.carver (Skype)', 'V123', '1980-02-05',
          '/tmp/Contacts.abbu/Images/stan.jpg'
        ]
        expect(rows[1]).to eq(expected_row)
      end
    end
  end

  describe '#to_stdout' do
    it 'prints CSV to stdout' do
      expect { exporter.to_stdout }.to output(/Stan Carver/).to_stdout
    end
  end

  context 'when contact has no image_path' do
    it 'emits an empty ImagePath cell' do
      c = Abbu::Contact.new
      c.first_name = 'Prince'
      exp = described_class.new([c])
      expect { exp.to_stdout }.to output(/,Prince,/).to_stdout
    end
  end

  context 'when date has no year' do
    it 'formats with double dash' do
      c = Abbu::Contact.new
      c.first_name = 'NoYear'
      c.birthday = { year: -1, month: 12, day: 25 }
      exp = described_class.new([c])
      expect { exp.to_stdout }.to output(/--12-25/).to_stdout
    end
  end
end
