# lib/abbu/parsers/plist_parser.rb
# frozen_string_literal: true

require 'plist'
require_relative '../contact'
require_relative '../utils/source_descriptor'

module Abbu
  module Parsers
    class PlistParser
      # Maps plist keys → Contact attr_accessor names for simple string fields
      FIELD_MAP = {
        'First' => :first_name, 'Middle' => :middle_name,
        'Last' => :last_name,
        'Nickname' => :nickname,  'Title' => :prefix,
        'Suffix' => :suffix,      'Organization' => :company,
        'JobTitle' => :job_title, 'Department' => :department,
        'MaidenName' => :maiden_name, 'VerificationCode' => :verification_code,
        'PhoneticFirst' => :phonetic_first_name,
        'PhoneticMiddle' => :phonetic_middle_name,
        'PhoneticLast' => :phonetic_last_name
      }.freeze

      # Accepts either a directory path (scans for *.abcdp) or an array of file paths
      def initialize(paths, root_path: nil)
        @paths = resolve_paths(paths)
        @root_path = root_path
      end

      def contacts
        @paths.filter_map { |file| parse_file(file) }
      end

      private

      def resolve_paths(paths)
        case paths
        when Array
          paths.map { |p| Pathname.new(p) }
        else
          path = Pathname.new(paths)
          return [] unless path.exist?

          path.directory? ? path.glob('*.abcdp').sort : [path]
        end
      end

      def parse_file(file)
        data = Plist.parse_xml(file.to_s)
        return nil unless data

        build_contact(data, file)
      end

      def build_contact(data, file)
        contact = Contact.new
        assign_flat_fields(contact, data)
        assign_multi_value_fields(contact, data)
        contact.source = Utils::SourceDescriptor.new(file, root_path: @root_path).to_h
        contact
      end

      def assign_flat_fields(contact, data)
        FIELD_MAP.each do |plist_key, attr|
          contact.public_send(:"#{attr}=", data[plist_key])
        end
      end

      def assign_multi_value_fields(contact, data) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        contact.emails          = extract_labeled_values(data, 'Email', :address)
        contact.phones          = extract_labeled_values(data, 'Phone', :number)
        contact.addresses       = extract_addresses(data)
        contact.urls            = extract_labeled_values(data, 'URLs', :url)
        contact.notes           = extract_notes(data)
        contact.related_names   = extract_labeled_values(data, 'RelatedNames', :name)
        contact.social_profiles = extract_social_profiles(data)
        contact.instant_messages = extract_instant_messages(data)

        contact.birthday = extract_birthday(data)
        contact.lunar_birthday = extract_lunar_birthday(data)
        contact.dates = extract_dates(data)
        contact.anniversary = contact.dates.find { |d| d[:label] == '_$!<Anniversary>!$_' }
      end

      def extract_labeled_values(data, key, value_key)
        return [] unless data[key]&.dig('values')

        data[key]['values'].map do |entry|
          { value_key => entry['value'], label: entry['label'] }
        end
      end

      def extract_addresses(data) # rubocop:disable Metrics/MethodLength
        return [] unless data['Address']&.dig('values')

        data['Address']['values'].map do |entry|
          addr = entry['value'] || {}
          {
            street: addr['Street'],
            city: addr['City'],
            state: addr['State'],
            zip: addr['ZIP'],
            country: addr['Country'],
            label: entry['label']
          }
        end
      end

      def extract_notes(data)
        note = data['Note']
        note ? [note] : []
      end

      def extract_social_profiles(data)
        return [] unless data['SocialProfile']&.dig('values')

        data['SocialProfile']['values'].map do |entry|
          profile = entry['value'] || {}
          { service: profile['serviceName'], username: profile['username'] }
        end
      end

      def extract_instant_messages(data)
        return [] unless data['InstantMessage']&.dig('values')

        data['InstantMessage']['values'].map do |entry|
          msg = entry['value'] || {}
          { address: msg['address'], label: entry['label'], service: msg['serviceName'] }
        end
      end

      def extract_birthday(data)
        val = data['Birthday']
        return nil unless val.respond_to?(:year)

        { year: val.year, month: val.month, day: val.day, label: '_$!<Birthday>!$_' }
      end

      def extract_lunar_birthday(data)
        val = data['LunarBirthday']
        return nil unless val.respond_to?(:year)

        { year: val.year, month: val.month, day: val.day, label: '_$!<LunarBirthday>!$_' }
      end

      def extract_dates(data)
        return [] unless data['Dates']&.dig('values')

        data['Dates']['values'].filter_map do |entry|
          val = entry['value']
          next unless val.respond_to?(:year)

          { year: val.year, month: val.month, day: val.day, label: entry['label'] }
        end
      end
    end
  end
end
