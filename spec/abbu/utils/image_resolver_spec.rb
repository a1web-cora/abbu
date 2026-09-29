# spec/abbu/utils/image_resolver_spec.rb
# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'abbu/utils/image_resolver'

RSpec.describe Abbu::Utils::ImageResolver do
  def write_image(dir, name, bytes = 'fake-jpeg-bytes')
    FileUtils.mkdir_p(File.join(dir, 'Images'))
    File.write(File.join(dir, 'Images', name), bytes)
  end

  describe '#resolve' do
    it 'returns a Pathname for a known image URI' do
      Dir.mktmpdir do |dir|
        write_image(dir, 'abc-123.jpg')
        resolver = described_class.new(dir)

        result = resolver.resolve('abc-123')

        expect(result).to be_a(Pathname)
        expect(result.basename.to_s).to eq('abc-123.jpg')
        expect(result).to exist
      end
    end

    it 'returns nil for an unknown image URI' do
      Dir.mktmpdir do |dir|
        write_image(dir, 'abc-123.jpg')
        resolver = described_class.new(dir)

        expect(resolver.resolve('missing')).to be_nil
      end
    end

    it 'returns nil when the URI is nil or empty' do
      Dir.mktmpdir do |dir|
        write_image(dir, 'abc-123.jpg')
        resolver = described_class.new(dir)

        expect(resolver.resolve(nil)).to be_nil
        expect(resolver.resolve('')).to be_nil
      end
    end

    it 'is case-insensitive on extensions' do
      Dir.mktmpdir do |dir|
        write_image(dir, 'photo.JPG')
        write_image(dir, 'photo2.PNG')
        write_image(dir, 'photo3.Heic')
        resolver = described_class.new(dir)

        expect(resolver.resolve('photo')).to be_a(Pathname)
        expect(resolver.resolve('photo2')).to be_a(Pathname)
        expect(resolver.resolve('photo3')).to be_a(Pathname)
      end
    end

    it 'ignores non-image files in Images/ directories' do
      Dir.mktmpdir do |dir|
        write_image(dir, 'abc-123.jpg')
        File.write(File.join(dir, 'Images', 'readme.txt'), 'hello')
        File.write(File.join(dir, 'Images', 'data.json'), '{}')
        resolver = described_class.new(dir)

        expect(resolver.resolve('readme')).to be_nil
        expect(resolver.resolve('data')).to be_nil
        expect(resolver.resolve('abc-123')).to be_a(Pathname)
      end
    end

    it 'finds images in nested Sources/<account>/Images/ directories' do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, 'Sources', 'Account1', 'Images'))
        File.write(File.join(dir, 'Sources', 'Account1', 'Images', 'synced.jpg'), 'fake')
        resolver = described_class.new(dir)

        result = resolver.resolve('synced')

        expect(result).to be_a(Pathname)
        expect(result.to_s).to include('Sources/Account1/Images/synced.jpg')
      end
    end
  end

  describe '#each_image' do
    it 'yields each discovered image Pathname' do
      Dir.mktmpdir do |dir|
        write_image(dir, 'a.jpg')
        write_image(dir, 'b.png')
        resolver = described_class.new(dir)

        names = resolver.each_image.map { |p| p.basename.to_s }.sort

        expect(names).to eq(%w[a.jpg b.png])
      end
    end

    it 'returns an Enumerator when called without a block' do
      Dir.mktmpdir do |dir|
        write_image(dir, 'a.jpg')
        resolver = described_class.new(dir)

        expect(resolver.each_image).to be_an(Enumerator)
      end
    end
  end
end
