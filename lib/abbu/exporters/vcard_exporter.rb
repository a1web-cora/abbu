# lib/abbu/exporters/vcard_exporter.rb
# frozen_string_literal: true

require_relative 'vcard_document'
require_relative 'vcard_photo'

module Abbu
  module Exporters
    class VcardExporter
      def initialize(contacts, photo_mode: :uri)
        @contacts = contacts
        @photo = VcardPhoto.new(photo_mode)
      end

      def to_file(path)
        File.binwrite(path, generate)
      end

      def to_stdout
        print generate
      end

      private

      def generate
        @contacts.map { |c| vcard_for(c) }.join
      end

      def vcard_for(contact) # rubocop:disable Metrics/MethodLength
        lines = VcardDocument.new

        append_name_fields(lines, contact)
        append_emails(lines, contact)
        append_phones(lines, contact)
        append_addresses(lines, contact)
        append_urls(lines, contact)
        append_social_profiles(lines, contact)
        append_dates(lines, contact)
        append_instant_messages(lines, contact)
        append_verification_code(lines, contact)
        append_notes(lines, contact)
        append_photo(lines, contact)

        lines.to_s
      end

      def append_name_fields(lines, contact)
        lines << "FN:#{VcardEncoding.text(contact.full_name)}"
        lines << "N:#{VcardEncoding.structured(name_components(contact))}"
        append_nickname(lines, contact)
        append_company(lines, contact)
        append_title(lines, contact)
        append_phonetic_names(lines, contact)
      end

      def name_components(contact)
        [contact.last_name, contact.first_name, contact.middle_name, contact.prefix, contact.suffix]
      end

      def append_nickname(lines, contact)
        lines << "NICKNAME:#{VcardEncoding.text(contact.nickname)}" if contact.nickname
      end

      def append_company(lines, contact)
        lines << "ORG:#{VcardEncoding.text(contact.company)}" if contact.company
      end

      def append_title(lines, contact)
        lines << "TITLE:#{VcardEncoding.text(contact.job_title)}" if contact.job_title
      end

      def append_phonetic_names(lines, contact)
        %i[first middle last].each do |part|
          value = contact.public_send(:"phonetic_#{part}_name")
          lines << "X-PHONETIC-#{part.upcase}-NAME:#{VcardEncoding.text(value)}" if value
        end
      end

      def append_verification_code(lines, contact)
        lines << "X-VERIFICATION-CODE:#{VcardEncoding.text(contact.verification_code)}" if contact.verification_code
      end

      def append_photo(lines, contact)
        property = @photo.property(contact)
        lines << property if property
      end

      def append_notes(lines, contact)
        contact.notes.each { |n| lines << "NOTE:#{VcardEncoding.text(n)}" }
      end

      def append_emails(lines, contact)
        contact.emails.each do |e|
          lines.labeled('EMAIL', VcardEncoding.text(e[:address]), e, default_type: 'INTERNET')
        end
      end

      def append_phones(lines, contact)
        contact.phones.each do |p|
          lines.labeled('TEL', VcardEncoding.text(p[:number]), p, default_type: 'VOICE')
        end
      end

      def append_addresses(lines, contact)
        contact.addresses.each do |a|
          value = VcardEncoding.structured([nil, nil, a[:street], a[:city], a[:state], a[:zip], a[:country]])
          lines.labeled('ADR', value, a)
        end
      end

      def append_urls(lines, contact)
        contact.urls.each do |u|
          lines.labeled('URL', VcardEncoding.uri(u[:url]), u)
        end
      end

      def append_social_profiles(lines, contact)
        contact.social_profiles.each do |sp|
          type = sp[:service] ? ";TYPE=#{VcardEncoding.token(sp[:service])}" : ''
          lines << "X-SOCIALPROFILE#{type}:#{VcardEncoding.text(sp[:username])}"
        end
      end

      def append_instant_messages(lines, contact)
        contact.instant_messages.each do |im|
          service = im[:service]&.downcase || 'unknown'
          raise ArgumentError, 'IM service must be a URI scheme' unless service.match?(/\A[a-z][a-z0-9+.-]*\z/)

          lines.labeled('IMPP', "#{service}:#{VcardEncoding.uri(im[:address])}", im)
        end
      end

      def append_dates(lines, contact)
        lines << "BDAY:#{format_vcard_date(contact.birthday)}" if contact.birthday
        lines << "X-LUNAR-BDAY:#{format_vcard_date(contact.lunar_birthday)}" if contact.lunar_birthday
        return unless contact.anniversary

        entry = { label: 'Anniversary' }.merge(contact.anniversary.compact)
        lines.labeled('X-ABDATE', format_vcard_date(contact.anniversary), entry)
      end

      def format_vcard_date(date)
        return nil unless date

        if date[:year]&.positive?
          format('%<year>04d-%<month>02d-%<day>02d', year: date[:year], month: date[:month], day: date[:day])
        else
          format('--%<month>02d-%<day>02d', month: date[:month], day: date[:day])
        end
      end
    end
  end
end
