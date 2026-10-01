# spec/sources_cli_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'
require 'tmpdir'

RSpec.describe 'source listing CLI' do # rubocop:disable RSpec/DescribeClass
  let(:bin) { File.expand_path('../bin/abbu', __dir__) }
  let(:fixture) { File.expand_path('fixtures/TestContacts.abbu', __dir__) }

  it 'lists stable source metadata with JSON-only stdout and stderr diagnostics' do
    stdout, stderr, status = Open3.capture3(bin, fixture, '--sources')
    sources = JSON.parse(stdout)

    expect(sources.map { |source| source['relative_path'] }).to eq(['.', 'Sources/TestAccount'])
    expect(sources.map { |source| source['contact_count'] }).to eq([1, 2])
    expect(sources.map { |source| source['provider'] }).to eq([nil, nil])
    expect(sources.first.keys).to eq(%w[path relative_path kind identifier provider files contact_count group_names])
    expect(stderr).to include('Diagnostics:')
    expect(status.exitstatus).to eq(0)
  end

  it 'supports live source listing with an optional explicit JSON flag' do
    stdout, _stderr, status = Open3.capture3(bin, '--live-path', fixture, '--sources', '--json')

    expect(JSON.parse(stdout).length).to eq(2)
    expect(status.exitstatus).to eq(0)
  end

  it 'returns an empty array successfully for empty archives' do
    Dir.mktmpdir do |directory|
      stdout, stderr, status = Open3.capture3(bin, directory, '--sources', '--json')
      expect(JSON.parse(stdout)).to eq([])
      expect(stderr).to be_empty
      expect(status.exitstatus).to eq(0)
    end
  end

  it 'honors strict failures without emitting partial source JSON' do
    stdout, stderr, status = Open3.capture3(bin, fixture, '--sources', '--strict')

    expect(stdout).to be_empty
    expect(stderr).to include('abbu:', 'Diagnostics:')
    expect(status.exitstatus).to eq(2)
  end

  it 'rejects conflicting operations before attempting discovery' do
    [%w[--search stan], %w[--schema], %w[--stats], %w[--format json],
     %w[--modified-since 2001-01-01T00:00:00Z]].each do |flags|
      stdout, stderr, status = Open3.capture3(bin, '--live-path', '/missing', '--sources', *flags)
      expect(stdout).to be_empty
      expect(stderr).to include('--sources cannot be combined')
      expect(status.exitstatus).to eq(2)
    end
  end
end
