# lib/abbu/exporters/jsonl_exporter.rb
# frozen_string_literal: true

require_relative 'json_exporter'

module Abbu
  module Exporters
    class JsonlExporter < JsonExporter
      def write_to(io)
        @contacts.each { |contact| io.write("#{JSON.generate(contact_hash(contact))}\n") }
        nil
      end

      def to_file(path)
        File.open(path, 'wb') { |io| write_to(io) }
      end

      def to_stdout
        write_to($stdout)
      end
    end
  end
end
