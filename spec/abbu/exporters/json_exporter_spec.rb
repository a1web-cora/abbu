# spec/abbu/exporters/json_exporter_spec.rb
# frozen_string_literal: true

require 'tmpdir'
require 'json'
require 'pathname'

RSpec.describe Abbu::Exporters::JsonExporter do
  let(:contact) do
    c = Abbu::Contact.new
    c.first_name = 'Stan'
    c.middle_name = 'The Man'
    c.last_name  = 'Carver'
    c.nickname   = 'Stretch'
    c.phonetic_first_name = 'Stan'
    c.phonetic_middle_name = 'The Phony'
    c.phonetic_last_name = 'Karver'
    c.emails     = [{ address: 'stan@example.com', label: 'Work' }]
    c.phones     = [{ number: '555-1234', label: 'Mobile' }]
    c.company    = 'Acme'
    c.job_title  = 'Engineer'
    c.addresses  = [{ street: '123 Main', city: 'Dallas', state: 'TX', zip: '75001', country: 'USA' }]
    c.urls       = [{ url: 'https://stancarver.com', label: 'homepage' }]
    c.notes      = ['Great guy']
    c.related_names   = [{ name: 'John', label: 'brother' }]
    c.social_profiles = [{ service: 'Twitter', username: '@scarver2' }]
    c.birthday    = { 'year' => 1980, 'month' => 1, 'day' => 1 }
    c.anniversary = { 'year' => 2010, 'month' => 6, 'day' => 15 }
    c.lunar_birthday = { 'year' => 1980, 'month' => 2, 'day' => 5 }
    c.instant_messages = [{ address: 'stan.carver', label: 'Work', service: 'Skype' }]
    c.verification_code = 'V123'
    c.image_uri = 'stan-photo'
    c.image_path = Pathname.new('/tmp/Contacts.abbu/Images/stan-photo.jpg')
    c
  end

  let(:exporter) { described_class.new([contact]) }

  describe '#to_file' do
    it 'writes a JSON file with all contact fields' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'out.json')
        exporter.to_file(path)
        data = JSON.parse(File.read(path)).first

        expect(data['name']).to eq('Stan The Man "Stretch" Carver')
        expect(data['last_name']).to eq('Carver')
        expect(data['phonetic_first_name']).to eq('Stan')
        expect(data['phonetic_middle_name']).to eq('The Phony')
        expect(data['phonetic_last_name']).to eq('Karver')
        expect(data['nickname']).to eq('Stretch')
        expect(data['company']).to eq('Acme')
        expect(data['job_title']).to eq('Engineer')
        expect(data['emails'].first['address']).to eq('stan@example.com')
        expect(data['phones'].first['number']).to eq('555-1234')
        expect(data['addresses'].first['city']).to eq('Dallas')
        expect(data['urls'].first['url']).to eq('https://stancarver.com')
        expect(data['notes']).to eq(['Great guy'])
        expect(data['related_names'].first['name']).to eq('John')
        expect(data['social_profiles'].first['username']).to eq('@scarver2')
        expect(data['birthday']['year']).to eq(1980)
        expect(data['anniversary']['month']).to eq(6)
        expect(data['instant_messages'].first['address']).to eq('stan.carver')
        expect(data['verification_code']).to eq('V123')
        expect(data['lunar_birthday']['day']).to eq(5)
        expect(data['image_uri']).to eq('stan-photo')
        expect(data['image_path']).to eq('/tmp/Contacts.abbu/Images/stan-photo.jpg')
      end
    end
  end

  describe '#to_stdout' do
    it 'prints JSON to stdout' do
      expect { exporter.to_stdout }.to output(/Stan The Man \\"Stretch\\" Carver/).to_stdout
    end
  end

  context 'when contact has no image' do
    it 'omits image_uri and image_path from the output' do
      c = Abbu::Contact.new
      c.first_name = 'Prince'
      exp = described_class.new([c])
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'out.json')
        exp.to_file(path)
        data = JSON.parse(File.read(path)).first

        expect(data).not_to have_key('image_uri')
        expect(data).not_to have_key('image_path')
      end
    end
  end
end
