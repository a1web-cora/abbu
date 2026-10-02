# spec/date_cli_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'

RSpec.describe 'timestamp query CLI' do # rubocop:disable RSpec/DescribeClass
  let(:bin) { File.expand_path('../bin/abbu', __dir__) }
  let(:fixture) { File.expand_path('fixtures/TestContacts.abbu', __dir__) }

  it 'emits JSON-only stdout for a composed timestamp and text query' do
    stdout, _stderr, status = Open3.capture3(bin, fixture, '--created-since', '2000-01-01T00:00:00Z',
                                             '--modified-before', '2100-01-01T00:00:00Z', '--search', 'stan', '--json')
    expect(JSON.parse(stdout).length).to eq(1)
    expect(status.exitstatus).to eq(0)
  end

  it 'supports timestamp-only TSV and upper-only filters' do
    stdout, _stderr, status = Open3.capture3(bin, fixture, '--created-before', '2100-01-01T00:00:00Z')
    expect(stdout).to include("\t")
    expect(status.exitstatus).to eq(0)
  end

  it 'returns an empty JSON array and status 1 for no matches' do
    stdout, _stderr, status = Open3.capture3(bin, fixture, '--modified-since', '2100-01-01T00:00:00Z', '--json')
    expect(JSON.parse(stdout)).to eq([])
    expect(status.exitstatus).to eq(1)
  end

  it 'rejects invalid timestamps and conflicting modes with mode-appropriate errors' do
    [['--modified-since', 'invalid', '--json'],
     ['--created-since', '2000-01-01T00:00:00Z', '--stats']].each do |args|
      stdout, stderr, status = Open3.capture3(bin, fixture, *args)
      if args.include?('--json')
        expect(JSON.parse(stdout)).to include('error' => include('code' => 'invalid_input'))
      else
        expect(stdout).to be_empty
        expect(stderr).to include('abbu:')
      end
      expect(status.exitstatus).to eq(2)
    end
  end
end
