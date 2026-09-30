# lib/abbu/image_extractor.rb
# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'pathname'

module Abbu
  class ImageExtractor
    Result = Struct.new(:files, :diagnostics, keyword_init: true)

    SIGNATURES = {
      jpeg: { extension: 'jpg', media_type: 'image/jpeg' },
      png: { extension: 'png', media_type: 'image/png' },
      gif: { extension: 'gif', media_type: 'image/gif' },
      heic: { extension: 'heic', media_type: 'image/heic' }
    }.freeze

    def initialize(contacts)
      @contacts = contacts
    end

    def extract(output_dir)
      destination = Pathname.new(output_dir).expand_path
      FileUtils.mkdir_p(destination)
      files = []
      diagnostics = []
      used_names = Hash.new(0)

      @contacts.each do |contact|
        extract_contact(contact, destination, files, diagnostics, used_names)
      end

      Result.new(files: files.freeze, diagnostics: diagnostics.freeze).freeze
    end

    private

    def extract_contact(contact, destination, files, diagnostics, used_names)
      return unless contact.image_uri

      source = contact.image_path
      return add_diagnostic(diagnostics, :missing_image, contact, source) unless source&.file?

      type = detect_type(source)
      return add_diagnostic(diagnostics, :unsupported_image, contact, source) unless type

      target = destination.join(unique_filename(contact, source, type[:extension], used_names))
      FileUtils.copy_file(source, target)
      files << file_record(contact, source, target, type)
    rescue IOError, SystemCallError => e
      add_diagnostic(diagnostics, :unreadable_image, contact, source, e.message)
    end

    def detect_type(path)
      header = path.open('rb') { |file| file.read(32) }.to_s.b
      SIGNATURES[kind_for(header)]
    end

    def kind_for(header)
      return :jpeg if header.start_with?("\xFF\xD8\xFF".b)
      return :png if header.start_with?("\x89PNG\r\n\x1A\n".b)
      return :gif if header.start_with?('GIF87a', 'GIF89a')

      :heic if heic?(header)
    end

    def heic?(header)
      header.byteslice(4, 4) == 'ftyp' && %w[heic heix hevc hevx mif1 msf1].include?(header.byteslice(8, 4))
    end

    def unique_filename(contact, source, extension, used_names)
      readable = sanitize(contact.full_name)
      readable = 'contact' if readable.empty?
      identifier = sanitize(contact.image_uri.to_s)
      identifier = 'image' if identifier.empty?
      fingerprint = Digest::SHA256.hexdigest(provenance_key(contact, source))[0, 10]
      base = [readable, identifier, fingerprint].join('--')
      used_names[base] += 1
      suffix = used_names[base] == 1 ? '' : "-#{used_names[base]}"
      "#{base}#{suffix}.#{extension}"
    end

    def sanitize(value)
      value.unicode_normalize(:nfc)
           .gsub(%r{[\\/:*?"<>|\p{Cntrl}]+}u, '-')
           .gsub(/[^\p{Alnum}\p{Mark}_ -]+/u, '-')
           .strip
           .gsub(/[ .-]+\z/, '')
           .gsub(/\s+/, '-')
           .squeeze('-')
           .then { |name| name[0, 80] }
    end

    def provenance_key(contact, source)
      [contact.source&.fetch(:relative_path, nil), source.expand_path, contact.full_name, contact.image_uri].join("\0")
    end

    def file_record(contact, source, target, type)
      {
        contact: contact,
        image_uri: contact.image_uri,
        source_path: source.expand_path,
        path: target,
        media_type: type[:media_type]
      }.freeze
    end

    def diagnostic(code, contact, source, detail = nil)
      {
        code: code,
        contact_name: contact.full_name,
        image_uri: contact.image_uri,
        source_path: source&.expand_path,
        detail: detail
      }.compact.freeze
    end

    def add_diagnostic(diagnostics, code, contact, source, detail = nil)
      diagnostics << diagnostic(code, contact, source, detail)
    end
  end
end
