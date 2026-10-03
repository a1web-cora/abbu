# lib/abbu/machine_command.rb
# frozen_string_literal: true

require 'json'
require_relative 'machine_output'
require_relative 'merge_preview'

module Abbu
  # One JSON document per invocation. Existing human CLI paths stay separate.
  class MachineCommand
    OPERATIONS = %i[stats schema sources groups dedupe matches diagnostics extract_images diff].freeze
    SEARCHES = %i[search email phone].freeze

    def initialize(options, arguments, stdout: $stdout, stderr: $stderr)
      @options = options
      @arguments = arguments
      @stdout = stdout
      @stderr = stderr
    end

    def run
      @input = @comparison_input = nil
      validate!
      @input = open_input
      print_result
    rescue LiveStore::Error, SystemCallError, IOError => e
      failure('input_output_error', e, 1)
    rescue ParseError, ArgumentError => e
      failure('invalid_input', e, 2)
    ensure
      report_diagnostics
    end

    private

    def print_result
      payload = execute
      emit(payload)
      search? && payload.empty? ? 1 : 0
    end

    def open_input
      return Abbu.open_live(@options[:live_path], strict: @options[:strict]) if live?

      Abbu.open(@arguments.first, strict: @options[:strict])
    end

    def live?
      @options[:live] || @options[:live_path]
    end

    def search?
      SEARCHES.any? { |key| @options[key] } || @options[:date_filters]
    end

    def operation
      OPERATIONS.find { |key| @options[key] }
    end

    def validate!
      MergePreview.validate!(@options.merge(json: true))
      validate_input!
      validate_operation!
      return unless live? && (search? || %i[schema extract_images].include?(operation))

      raise ArgumentError, 'Search, schema, and image extraction require an archive input'
    end

    def validate_input!
      raise ArgumentError, 'Use only one live input selector' if @options[:live] && @options[:live_path]
      return if live? ? @arguments.empty? : @arguments.length == 1

      raise ArgumentError, 'Provide exactly one archive path, or a live input selector without positional arguments'
    end

    def validate_operation!
      count = OPERATIONS.count { |key| @options[key] } + (search? ? 1 : 0)
      if count > 1 || SEARCHES.count { |key| @options[key] } > 1
        raise ArgumentError, 'Choose only one machine operation (timestamp filters may accompany one search)'
      end

      validate_format!(count)
    end

    def validate_format!(count)
      if @options.values_at(:calendar_year, :calendar_stamp, :calendar_id).any?
        raise ArgumentError, 'Calendar options require a standalone iCalendar export'
      end

      incompatible_format = @options[:format] && (@options[:format] != 'json' || count.positive?)
      return unless @options[:output] || @options[:photo_mode] || incompatible_format

      raise ArgumentError, 'Machine output requires stdout JSON; file exports and photo options are separate operations'
    end

    def execute
      output = MachineOutput.new(@input)
      return output.contacts(query) if search?
      return listing if %i[schema sources groups].include?(operation)

      case operation
      when :diff then snapshot_diff
      when :extract_images then output.images(@options[:extract_images])
      when :dedupe then output.duplicates
      when nil then output.contacts
      else output.public_send(operation)
      end
    end

    def snapshot_diff
      @comparison_input = Abbu.open(@options[:diff], strict: @options[:strict])
      SnapshotDiff.new(@input, @comparison_input).to_h
    end

    def listing
      return @input.schema_report if operation == :schema

      @input.public_send(operation).map(&:to_h)
    end

    def query
      results = initial_query
      @options.fetch(:date_filters, {}).each { |field, bounds| results = results.date_range(field, **bounds) }
      results
    end

    def initial_query
      return @input.search(@options[:search]) if @options[:search]
      return @input.find_by_email(@options[:email]) if @options[:email]
      return @input.find_by_phone(@options[:phone]) if @options[:phone]

      @input.query
    end

    def emit(payload)
      @stdout.puts(JSON.pretty_generate(payload))
    end

    def failure(code, error, status)
      emit(error: { code: code, message: error.message })
      status
    end

    def report_diagnostics
      if @comparison_input && !@comparison_input.diagnostics.empty?
        @stderr.puts("Comparison input diagnostics: #{@comparison_input.diagnostics.length}")
      end
      return unless @input && operation != :diagnostics

      @input.diagnostics.each do |diagnostic|
        @stderr.puts("- #{diagnostic.category}: #{diagnostic.message} [#{diagnostic.source}]")
      end
    end
  end
end
