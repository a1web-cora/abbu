# lib/abbu/mcp/server.rb
# frozen_string_literal: true

require 'json'

module Abbu
  module Mcp
    # SDK owns protocol validation/transport; this adapter only exposes an
    # allowlist over public ABBU read APIs. No contact or request logging.
    class Server
      EMPTY_SCHEMA = { type: 'object', properties: {}, additionalProperties: false }.freeze
      QUERY_SCHEMA = {
        type: 'object', additionalProperties: false,
        properties: {
          mode: { type: 'string', enum: %w[search email phone modified_since] },
          value: { type: 'string' }, offset: { type: 'integer', minimum: 0 },
          limit: { type: 'integer', minimum: 1, maximum: 500 }
        }, required: %w[mode value]
      }.freeze
      ARRAY_DATA = { type: 'array', items: { type: 'object' } }.freeze
      DATA_SCHEMAS = {
        query: {
          type: 'object', properties: {
            contacts: ARRAY_DATA, offset: { type: 'integer' }, limit: { type: 'integer' }, has_more: { type: 'boolean' }
          }, required: %w[contacts offset limit has_more], additionalProperties: false
        },
        stats: {
          type: 'object', properties: {
            total_contacts: { type: 'integer' }, with_email: { type: 'integer' }, with_phone: { type: 'integer' }
          }, required: %w[total_contacts with_email with_phone], additionalProperties: false
        }
      }.freeze
      ANNOTATIONS = {
        read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false
      }.freeze
      DESCRIPTIONS = {
        query: 'Read sensitive contacts by name/email search, exact email/phone, or modified-since timestamp.',
        stats: 'Read contact counts from the configured input.',
        sources: 'Read observed source metadata; includes sensitive local paths and identifiers.',
        groups: 'Read observed group metadata; includes sensitive group names and provenance.',
        diagnostics: 'Read parser diagnostics; includes sensitive local paths, without full contact records.'
      }.freeze

      attr_reader :server

      def initialize(path:, live: false, strict: false)
        raise ArgumentError, 'An explicit nonempty path is required' unless path.is_a?(String) && !path.strip.empty?

        input = live ? Abbu.open_live(path, strict: strict) : Abbu.open(path, strict: strict)
        @session = ReadSession.new(input)
        @server = ::MCP::Server.new(name: 'abbu', version: VERSION, tools: tools, configuration: configuration)
      end

      def open
        ::MCP::Server::Transports::StdioTransport.new(server).open
      end

      private

      def configuration
        ::MCP::Configuration.new(exception_reporter: ->(_exception, _context) {}, validate_tool_call_results: true)
      end

      def tools
        handler = method(:respond)
        DESCRIPTIONS.map do |operation, description|
          ::MCP::Tool.define(
            name: "abbu_#{operation}", description: description,
            input_schema: operation == :query ? QUERY_SCHEMA : EMPTY_SCHEMA,
            output_schema: output_schema(operation), annotations: ANNOTATIONS
          ) do |**arguments|
            handler.call(operation, arguments.except(:server_context))
          end
        end
      end

      def output_schema(operation)
        { type: 'object', properties: { data: DATA_SCHEMAS.fetch(operation, ARRAY_DATA) },
          required: ['data'], additionalProperties: false }
      end

      def respond(operation, arguments)
        payload = { data: @session.public_send(operation, **arguments) }
        response(payload)
      rescue ArgumentError
        response({ error: { code: 'invalid_query', message: 'Check mode, timestamp and pagination.' } }, error: true)
      rescue StandardError
        # Never echo exception messages that might include contact values or paths.
        response({ error: { code: 'read_failed', message: 'Unable to read the configured input.' } }, error: true)
      end

      def response(payload, error: false)
        ::MCP::Tool::Response.new([{ type: 'text', text: JSON.generate(payload) }],
                                  structured_content: payload, error: error)
      end
    end
  end
end
