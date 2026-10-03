# lib/abbu/mcp.rb
# frozen_string_literal: true

# Optional SDK activation never runs from require 'abbu'.
gem 'mcp', '~> 1.6.1'
require 'json'
require 'mcp'

require_relative '../abbu'
require_relative 'mcp/read_session'
require_relative 'mcp/server'
