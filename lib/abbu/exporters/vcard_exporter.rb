# lib/abbu/exporters/vcard_exporter.rb
# frozen_string_literal: true

require 'uri'

module Abbu
  module Exporters
    class VcardExporter
      def initialize(contacts)
        @contacts = contacts
      end

      def to_file(path)
        File.write(path, generate)
      end

      def to_stdout
        puts generate
      end

      private

      def generate
        @contacts.map { |c| vcard_for(c) }.join("\n")
      end

      def vcard_for(contact) # rubocop:disable Metrics/MethodLength
        lines = ['BEGIN:VCARD', 'VERSION:3.0']

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

        lines << 'END:VCARD'
        lines.join("\n")
      end

      def append_name_fields(lines, contact)
        lines << "FN:#{contact.full_name}"
        lines << "N:#{name_components(contact).join(';')}"
        append_nickname(lines, contact)
        append_company(lines, contact)
        append_title(lines, contact)
        append_phonetic_names(lines, contact)
      end

      def name_components(contact)
        [contact.last_name, contact.first_name, contact.middle_name, contact.prefix, contact.suffix]
      end

      def append_nickname(lines, contact)
        lines << "NICKNAME:#{contact.nickname}" if contact.nickname
      end

      def append_company(lines, contact)
        lines << "ORG:#{contact.company}" if contact.company
      end

      def append_title(lines, contact)
        lines << "TITLE:#{contact.job_title}" if contact.job_title
      end

      def append_phonetic_names(lines, contact)
        lines << "X-PHONETIC-FIRST-NAME:#{contact.phonetic_first_name}" if contact.phonetic_first_name
        lines << "X-PHONETIC-MIDDLE-NAME:#{contact.phonetic_middle_name}" if contact.phonetic_middle_name
        lines << "X-PHONETIC-LAST-NAME:#{contact.phonetic_last_name}" if contact.phonetic_last_name
      end

      def append_verification_code(lines, contact)
        lines << "X-VERIFICATION-CODE:#{contact.verification_code}" if contact.verification_code
      end

      def append_photo(lines, contact)
        return unless contact.image_path

        lines << "PHOTO;VALUE=URI:#{file_uri(contact.image_path)}"
      end

      def file_uri(path)
        escaped_path = URI::DEFAULT_PARSER.escape(path.to_s)
        URI::Generic.build(scheme: 'file', path: escaped_path)
      end

      def append_notes(lines, contact)
        contact.notes.each { |n| lines << "NOTE:#{n}" }
      end

      def append_emails(lines, contact)
        contact.emails.each do |e|
          label = e[:label] || 'INTERNET'
          lines << "EMAIL;TYPE=#{label}:#{e[:address]}"
        end
      end

      def append_phones(lines, contact)
        contact.phones.each do |p|
          label = p[:label] || 'VOICE'
          lines << "TEL;TYPE=#{label}:#{p[:number]}"
        end
      end

      def append_addresses(lines, contact)
        contact.addresses.each do |a|
          label = a[:label] || 'HOME'
          lines << "ADR;TYPE=#{label}:;;#{a[:street]};#{a[:city]};#{a[:state]};#{a[:zip]};#{a[:country]}"
        end
      end

      def append_urls(lines, contact)
        contact.urls.each do |u|
          lines << "URL:#{u[:url]}"
        end
      end

      def append_social_profiles(lines, contact)
        contact.social_profiles.each do |sp|
          lines << "X-SOCIALPROFILE;TYPE=#{sp[:service]}:#{sp[:username]}"
        end
      end

      def append_instant_messages(lines, contact)
        contact.instant_messages.each do |im|
          service = im[:service]&.downcase || 'unknown'
          lines << "IMPP;TYPE=#{im[:label]}:#{service}:#{im[:address]}"
        end
      end

      def append_dates(lines, contact)
        lines << "BDAY:#{format_vcard_date(contact.birthday)}" if contact.birthday
        lines << "X-LUNAR-BDAY:#{format_vcard_date(contact.lunar_birthday)}" if contact.lunar_birthday
        return unless contact.anniversary

        lines << "X-ABDATE;type=pref:#{format_vcard_date(contact.anniversary)}"
        lines << "X-ABLABEL:#{anniversary_label(contact.anniversary)}"
      end

      def anniversary_label(anniversary)
        anniversary[:raw_label] || anniversary[:label] || 'Anniversary'
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
