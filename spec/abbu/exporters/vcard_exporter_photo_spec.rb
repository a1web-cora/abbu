# spec/abbu/exporters/vcard_exporter_photo_spec.rb
# frozen_string_literal: true

require 'open3'
require 'spec_helper'
require 'tmpdir'

RSpec.describe Abbu::Exporters::VcardExporter do
  let(:contact) { Abbu::Contact.new }

  it 'embeds content-derived JPEG, PNG and GIF bytes without changing source evidence' do
    { 'JPEG' => "\xFF\xD8\xFF".b, 'PNG' => "\x89PNG\r\n\x1A\n".b, 'GIF' => 'GIF89a' }.each do |type, signature|
      Dir.mktmpdir do |directory|
        path = File.join(directory, 'mislabeled.heic')
        bytes = signature + ('synthetic image bytes' * 40)
        File.binwrite(path, bytes)
        contact.image_path = path
        contact.image_uri = 'original-source-token'
        output = File.join(directory, 'out.vcf')
        described_class.new([contact], photo_mode: :embedded).to_file(output)
        wire = File.binread(output)
        expect(wire.split("\r\n").map(&:bytesize).max).to be <= 75
        property = wire.gsub(/\r\n[ \t]/, '').split("\r\n").find { |line| line.start_with?('PHOTO;') }
        header, payload = property.split(':', 2)
        expect(header).to eq("PHOTO;ENCODING=b;TYPE=#{type}")
        expect(payload.unpack1('m0')).to eq(bytes)
        expect(wire).not_to include(path)
        expect(File.binread(path)).to eq(bytes)
        expect(contact.image_uri).to eq('original-source-token')
        expect(contact.image_path).to eq(path)
      end
    end
  end

  it 'omits photos only when no source photo evidence exists and validates the mode' do
    expect { described_class.new([contact], photo_mode: :embedded).to_stdout }.not_to output(/PHOTO/).to_stdout
    expect { described_class.new([], photo_mode: :unknown) }.to raise_error(ArgumentError, /photo_mode/)
  end

  it 'rejects unresolved or missing images without partial stdout' do
    contact.image_uri = 'missing'
    expect do
      expect { described_class.new([contact], photo_mode: :embedded).to_stdout }
        .to raise_error(ArgumentError, /missing/)
    end.not_to output.to_stdout
  end

  it 'rejects HEIC, unknown and unreadable files without overwriting output' do
    Dir.mktmpdir do |directory|
      photo = File.join(directory, 'photo.jpg')
      output = File.join(directory, 'existing.vcf')
      File.write(output, 'keep me')
      contact.image_path = photo
      ["\x00\x00\x00\x18ftypheic".b, 'unknown'].each do |bytes|
        File.binwrite(photo, bytes)
        expect { described_class.new([contact], photo_mode: :embedded).to_file(output) }
          .to raise_error(ArgumentError, /unsupported/)
        expect(File.read(output)).to eq('keep me')
      end
      allow(File).to receive(:binread).with(photo).and_raise(Errno::EACCES)
      expect { described_class.new([contact], photo_mode: :embedded).to_file(output) }
        .to raise_error(ArgumentError, /unreadable/)
      expect(File.read(output)).to eq('keep me')
    end
  end

  it 'supports explicit CLI modes and rejects incompatible operations' do
    fixture = File.expand_path('../../fixtures/PlistContacts.abbu', __dir__)
    executable = File.expand_path('../../../bin/abbu', __dir__)
    stdout, _stderr, status = Open3.capture3(RbConfig.ruby, executable, fixture,
                                             '--format', 'vcard', '--photo-mode', 'embedded')
    expect(status.exitstatus).to eq(0)
    expect(stdout).to include('BEGIN:VCARD')
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, executable, fixture, '--photo-mode', 'embedded')
    expect(status.exitstatus).to eq(2)
    expect(stdout).to be_empty
    expect(stderr).to include('requires a standalone')
  end
end
