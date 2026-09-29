# spec/abbu/exporters/vcard_exporter_spec.rb
# frozen_string_literal: true

require 'tmpdir'
require 'pathname'

RSpec.describe Abbu::Exporters::VcardExporter do
  let(:contact) do
    c = Abbu::Contact.new
    c.prefix     = 'Honorable'
    c.first_name = 'Stan'
    c.middle_name = 'The Man'
    c.nickname   = 'Stretch'
    c.last_name  = 'Carver'
    c.phonetic_first_name = 'Stan'
    c.phonetic_middle_name = 'The Phony'
    c.phonetic_last_name = 'Karver'
    c.suffix     = 'II'
    c.emails     = [{ address: 'stan@example.com', label: 'Work' }]
    c.phones     = [{ number: '555-1234', label: 'Mobile' }]
    c.company    = 'Acme'
    c.job_title  = 'Engineer'
    c.addresses  = [{ street: '123 Main', city: 'Dallas', state: 'TX', zip: '75001', country: 'USA', label: 'Home' }]
    c.urls       = [{ url: 'https://stancarver.com', label: 'homepage' }]
    c.notes      = ['Great guy']
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
    it 'writes a vCard file with all fields' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'out.vcf')
        exporter.to_file(path)
        content = File.read(path)

        expect(content).to include('BEGIN:VCARD')
        expect(content).to include('FN:Honorable Stan The Man "Stretch" Carver II')
        expect(content).to include('N:Carver;Stan;The Man;Honorable;II')
        expect(content).to include('NICKNAME:Stretch')
        expect(content).to include('ORG:Acme')
        expect(content).to include('TITLE:Engineer')
        expect(content).to include('X-PHONETIC-FIRST-NAME:Stan')
        expect(content).to include('X-PHONETIC-MIDDLE-NAME:The Phony')
        expect(content).to include('X-PHONETIC-LAST-NAME:Karver')
        expect(content).to include('EMAIL;TYPE=Work:stan@example.com')
        expect(content).to include('TEL;TYPE=Mobile:555-1234')
        expect(content).to include('ADR;TYPE=Home:;;123 Main;Dallas;TX;75001;USA')
        expect(content).to include('URL:https://stancarver.com')
        expect(content).to include('NOTE:Great guy')
        expect(content).to include('X-SOCIALPROFILE;TYPE=Twitter:@scarver2')
        expect(content).to include('BDAY:1980-01-01')
        expect(content).to include('X-LUNAR-BDAY:1980-02-05')
        expect(content).to include('X-ABDATE;type=pref:2010-06-15')
        expect(content).to include('X-ABLABEL:Anniversary')
        expect(content).to include('IMPP;TYPE=Work:skype:stan.carver')
        expect(content).to include('X-VERIFICATION-CODE:V123')
        expect(content).to include('PHOTO;VALUE=URI:file:///tmp/Contacts.abbu/Images/stan.jpg')
        expect(content).to include('END:VCARD')
      end
    end
  end

  describe '#to_stdout' do
    it 'prints vCard to stdout' do
      expect { exporter.to_stdout }.to output(/BEGIN:VCARD/).to_stdout
    end
  end

  context 'when date has no year' do
    it 'formats with double dash' do
      c = Abbu::Contact.new
      c.first_name = 'NoYear'
      c.birthday = { year: -1, month: 12, day: 25 }
      exp = described_class.new([c])
      expect { exp.to_stdout }.to output(/BDAY:--12-25/).to_stdout
    end
  end

  context 'when contact has no company' do
    it 'omits the ORG line' do
      c = Abbu::Contact.new
      c.first_name = 'Prince'
      exp = described_class.new([c])
      expect { exp.to_stdout }.not_to output(/ORG:/).to_stdout
    end
  end

  context 'when contact has no nickname' do
    it 'omits the NICKNAME line' do
      c = Abbu::Contact.new
      c.first_name = 'Cher'
      exp = described_class.new([c])
      expect { exp.to_stdout }.not_to output(/NICKNAME:/).to_stdout
    end
  end

  context 'when contact has no image_path' do
    it 'omits the PHOTO line' do
      c = Abbu::Contact.new
      c.first_name = 'Prince'
      exp = described_class.new([c])
      expect { exp.to_stdout }.not_to output(/PHOTO:/).to_stdout
    end
  end

  context 'when image_path contains URI-reserved characters' do
    it 'percent-encodes the photo file URI' do
      contact.image_path = Pathname.new('/tmp/My Contacts/stan#100%-résumé.jpg')

      expect { exporter.to_stdout }
        .to output(%r{PHOTO;VALUE=URI:file:///tmp/My%20Contacts/stan%23100%25-r%C3%A9sum%C3%A9\.jpg}).to_stdout
    end
  end
end
