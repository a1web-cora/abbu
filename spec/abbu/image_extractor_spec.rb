# spec/abbu/image_extractor_spec.rb
# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

RSpec.describe Abbu::ImageExtractor do
  let(:jpeg) { "\xFF\xD8\xFF\xE0jpeg".b }
  let(:png) { "\x89PNG\r\n\x1A\npng".b }

  def contact(name:, uri:, path:, source: nil)
    first_name, last_name = name.split(' ', 2)
    Abbu::Contact.new.tap do |record|
      record.first_name = first_name
      record.last_name = last_name
      record.image_uri = uri
      record.image_path = Pathname.new(path) if path
      record.source = source
    end
  end

  it 'uses detected content type instead of a mismatched source extension' do
    Dir.mktmpdir do |dir|
      source = File.join(dir, 'photo.jpg')
      File.binwrite(source, png)
      record = contact(name: 'Stan Carver', uri: 'photo', path: source)

      result = described_class.new([record]).extract(File.join(dir, 'output'))

      expect(result.files.first[:path].extname).to eq('.png')
      expect(result.files.first[:media_type]).to eq('image/png')
      expect(result.files.first[:source_path]).to eq(Pathname.new(source).expand_path)
      expect(result.diagnostics).to be_empty
    end
  end

  it 'creates safe deterministic Unicode filenames outside attacker-controlled subpaths' do
    Dir.mktmpdir do |dir|
      source = File.join(dir, 'source.png')
      output = Pathname.new(dir).join('output')
      File.binwrite(source, png)
      record = contact(name: '../José / 東京', uri: '../../portrait', path: source)

      result = described_class.new([record]).extract(output)
      target = result.files.first[:path]

      expect(target.dirname).to eq(output.realpath)
      expect(target.basename.to_s).to include('José', '東京', 'portrait')
      expect(target.basename.to_s).not_to include('..', '/', '\\')
    end
  end

  it 'resolves filename collisions deterministically without overwriting' do
    Dir.mktmpdir do |dir|
      source = File.join(dir, 'same.jpg')
      File.binwrite(source, jpeg)
      records = Array.new(2) { contact(name: 'Same Name', uri: 'same', path: source) }

      first = described_class.new(records).extract(File.join(dir, 'one'))
      second = described_class.new(records).extract(File.join(dir, 'two'))

      expect(first.files.map { |file| file[:path].basename.to_s })
        .to eq(second.files.map { |file| file[:path].basename.to_s })
      expect(first.files.map { |file| file[:path].basename.to_s }.uniq.count).to eq(2)
    end
  end

  it 'reports missing, unreadable, and unsupported images without changing provenance' do
    Dir.mktmpdir do |dir|
      unreadable = Pathname.new(dir).join('unreadable.jpg')
      unsupported = Pathname.new(dir).join('unsupported.jpg')
      File.binwrite(unreadable, jpeg)
      File.write(unsupported, 'not an image')
      records = [
        contact(name: 'Missing Person', uri: 'missing', path: File.join(dir, 'missing.jpg')),
        contact(name: 'Unreadable Person', uri: 'unreadable', path: unreadable),
        contact(name: 'Unknown Person', uri: 'unknown', path: unsupported)
      ]
      allow(records[1].image_path).to receive(:open).and_raise(Errno::EACCES)

      result = described_class.new(records).extract(File.join(dir, 'output'))

      expect(result.diagnostics.map { |item| item[:code] })
        .to contain_exactly(:missing_image, :unreadable_image, :unsupported_image)
      expect(records[1].image_path).to eq(unreadable)
      expect(records[1].image_uri).to eq('unreadable')
    end
  end

  it 'detects JPEG, GIF, and fixture-observed HEIC-compatible brands' do
    Dir.mktmpdir do |dir|
      signatures = {
        'jpeg.dat' => jpeg,
        'gif.dat' => 'GIF89a-data',
        'heic.dat' => "\0\0\0\x18ftypheic\0\0\0\0".b
      }
      records = signatures.map do |filename, bytes|
        path = File.join(dir, filename)
        File.binwrite(path, bytes)
        contact(name: filename, uri: filename, path: path)
      end

      result = described_class.new(records).extract(File.join(dir, 'output'))

      expect(result.files.map { |file| file[:path].extname }).to contain_exactly('.jpg', '.gif', '.heic')
    end
  end

  it 'ignores contacts without image evidence' do
    Dir.mktmpdir do |dir|
      result = described_class.new([Abbu::Contact.new]).extract(File.join(dir, 'output'))

      expect(result.files).to be_empty
      expect(result.diagnostics).to be_empty
    end
  end

  %i[symlink dangling_symlink hardlink regular].each do |kind|
    it "refuses an existing #{kind} destination without modifying outside files" do
      Dir.mktmpdir do |dir|
        source = Pathname.new(dir).join('source.jpg')
        source.binwrite(jpeg)
        record = contact(name: 'Example Person', uri: 'photo', path: source)
        extractor = described_class.new([record])
        baseline = extractor.extract(File.join(dir, 'baseline'))
        output = Pathname.new(dir).join('output')
        output.mkdir
        target = output.join(baseline.files.first[:path].basename)
        sentinel = Pathname.new(dir).join('sentinel')
        sentinel.write('keep me') unless kind == :dangling_symlink
        case kind
        when :symlink, :dangling_symlink then File.symlink(sentinel, target)
        when :hardlink then File.link(sentinel, target)
        when :regular then target.write('existing image')
        end

        result = extractor.extract(output)

        expect(result.files).to be_empty
        expect(result.diagnostics.map { |item| item[:code] }).to eq([:destination_exists])
        if kind == :dangling_symlink
          expect(sentinel).not_to exist
        else
          expect(sentinel.read).to eq('keep me')
        end
        expect(target.read).to eq('existing image') if kind == :regular
        expect(target).to be_symlink if kind.to_s.end_with?('symlink')
        expect(output.children).to eq([target])
      end
    end
  end

  it 'resolves the selected directory and its parent aliases before extraction' do
    Dir.mktmpdir do |dir|
      root = Pathname.new(dir)
      real = root.join('real')
      real.mkdir
      alias_path = root.join('alias')
      File.symlink(real, alias_path)
      source = root.join('source.jpg')
      source.binwrite(jpeg)
      record = contact(name: 'Example Person', uri: 'photo', path: source)

      result = described_class.new([record]).extract(alias_path.join('output'))

      expect(result.files.first[:path].dirname).to eq(real.join('output').realpath)
      expect(result.files.first[:path].binread).to eq(jpeg)
    end
  end
end
