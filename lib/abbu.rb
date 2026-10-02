# lib/abbu.rb
# frozen_string_literal: true

require_relative 'abbu/version'
require_relative 'abbu/contact'
require_relative 'abbu/diagnostic'
require_relative 'abbu/parse_error'
require_relative 'abbu/archive'
require_relative 'abbu/live_store'
require_relative 'abbu/query'
require_relative 'abbu/schema_inspector'
require_relative 'abbu/source'
require_relative 'abbu/parsers/sqlite_parser'
require_relative 'abbu/parsers/plist_parser'
require_relative 'abbu/exporters/csv_exporter'
require_relative 'abbu/exporters/json_exporter'
require_relative 'abbu/exporters/vcard_exporter'
require_relative 'abbu/image_extractor'
require_relative 'abbu/utils/contact_identity'
require_relative 'abbu/utils/deduplicator'
require_relative 'abbu/utils/fuzzy_matcher'
require_relative 'abbu/utils/label_normalizer'

module Abbu
  def self.open(path, strict: false)
    Archive.new(path, strict: strict)
  end

  def self.open_live(path = nil, strict: false)
    LiveStore.new(path, strict: strict)
  end
end
