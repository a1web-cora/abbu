# abbu.gemspec
# frozen_string_literal: true

require_relative "lib/abbu/version"

Gem::Specification.new do |spec|
  spec.name        = "abbu"
  spec.version     = Abbu::VERSION
  spec.authors     = ["Stan Carver II"]
  spec.email       = ["stan@a1webconsulting.com"]

  spec.summary     = "Read-only Apple Contacts toolkit for archives and live macOS stores."
  spec.description = "Read SQLite and legacy plist .abbu archives or opt into read-only live macOS Contacts access. " \
                     "Query contacts, inspect schemas and diagnostics, compare identity evidence, extract images, " \
                     "and export CSV, JSON, or vCard."
  spec.homepage    = "https://github.com/scarver2/abbu"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.3"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/docs/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir[
    "bin/abbu",
    "bin/abbu-mcp",
    "docs/**/*",
    "examples/**/*.rb",
    "lib/**/*.rb",
    "sig/**/*.rbs",
    "tasks/**/*.rake",
    "LICENSE",
    "README.md"
  ]

  spec.bindir        = "bin"
  spec.executables   = ["abbu", "abbu-mcp"]
  spec.require_paths = ["lib"]

  spec.add_dependency "sqlite3", "~> 2.0"
  spec.add_dependency "csv"
  spec.add_dependency "plist", "~> 3.7"

  spec.add_development_dependency "guard",              "~> 2.18"
  spec.add_development_dependency "guard-rspec",        "~> 4.7"
  spec.add_development_dependency "guard-rubocop",      "~> 1.5"
  spec.add_development_dependency "rake",               "~> 13.0"
  spec.add_development_dependency "rspec",              "~> 3.13"
  spec.add_development_dependency "ruby-lsp",           "~> 0.1"
  spec.add_development_dependency "rubocop",            "~> 1.65"
  spec.add_development_dependency "rubocop-performance", "~> 1.21"
  spec.add_development_dependency "rubocop-rake",       "~> 0.6"
  spec.add_development_dependency "rubocop-rspec",      "~> 3.0"
  spec.add_development_dependency "simplecov",          "~> 0.22"
end
