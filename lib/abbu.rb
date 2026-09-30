# lib/abbu.rb
# frozen_string_literal: true

require_relative 'abbu/version'
require_relative 'abbu/contact'
require_relative 'abbu/archive'
require_relative 'abbu/query'
require_relative 'abbu/parsers/sqlite_parser'
require_relative 'abbu/parsers/plist_parser'
require_relative 'abbu/exporters/csv_exporter'
require_relative 'abbu/exporters/json_exporter'
require_relative 'abbu/exporters/vcard_exporter'
require_relative 'abbu/utils/deduplicator'

module Abbu
  def self.open(path)
    Archive.new(path)
  end
end
