# spec/machine_cli_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'

RSpec.describe 'machine CLI contract' do # rubocop:disable RSpec/DescribeClass
  let(:bin) { File.expand_path('../bin/abbu', __dir__) }
  let(:fixture) { File.expand_path('fixtures/PlistContacts.abbu', __dir__) }

  it 'emits JSON stats only and supports arbitrary option ordering' do
    [%w[--json --stats], %w[--stats --json]].each do |options|
      stdout, stderr, status = Open3.capture3(bin, *options, fixture)
      expect(JSON.parse(stdout)).to include('total_contacts' => 2)
      expect(stderr).to be_empty
      expect(status.exitstatus).to eq(0)
    end
  end

  it 'handles option errors and missing input as a single JSON document' do
    [%w[--json --unknown], %w[--stats --json], %w[--json --email]].each do |options|
      stdout, stderr, status = Open3.capture3(bin, *options)
      expect(JSON.parse(stdout)).to include('error' => include('code', 'message'))
      expect(stderr).to be_empty
      expect(status.exitstatus).to eq(2)
    end
  end

  it 'keeps help and version JSON regardless of option ordering' do
    [%w[--help --json], %w[--json --help], %w[--version --json], %w[--json --version]].each do |options|
      stdout, stderr, status = Open3.capture3(bin, *options)
      expect(JSON.parse(stdout)).to be_a(Hash)
      expect(stderr).to be_empty
      expect(status.exitstatus).to eq(0)
    end
  end

  it 'offers first-class diagnostics and matches without requiring the JSON flag' do
    %w[--diagnostics --matches].each do |option|
      stdout, stderr, status = Open3.capture3(bin, fixture, option)
      expect(JSON.parse(stdout)).to be_an(Array)
      expect(stderr).to be_empty
      expect(status.exitstatus).to eq(0)
    end
  end
end
