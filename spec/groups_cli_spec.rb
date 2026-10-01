# spec/groups_cli_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'
require 'tmpdir'

RSpec.describe 'group listing CLI' do # rubocop:disable RSpec/DescribeClass
  let(:bin) { File.expand_path('../bin/abbu', __dir__) }
  let(:fixture) { File.expand_path('fixtures/TestContacts.abbu', __dir__) }

  it 'lists group metadata as JSON with diagnostics confined to stderr' do
    stdout, stderr, status = Open3.capture3(bin, fixture, '--groups')
    groups = JSON.parse(stdout)

    expect(groups.length).to eq(1)
    expect(groups.first.keys).to eq(%w[record_id name source contact_count])
    expect(groups.first).to include('record_id' => 2, 'name' => 'Colleagues', 'contact_count' => 1)
    expect(groups.first['source']['relative_path']).to eq('AddressBook-v22.abcddb')
    expect(stderr).to include('Diagnostics:')
    expect(status.exitstatus).to eq(0)
  end

  it 'supports explicit live input with an optional JSON flag' do
    stdout, _stderr, status = Open3.capture3(bin, '--live-path', fixture, '--groups', '--json')
    expect(JSON.parse(stdout).first['name']).to eq('Colleagues')
    expect(status.exitstatus).to eq(0)
  end

  it 'emits an empty array successfully for an empty archive' do
    Dir.mktmpdir do |directory|
      stdout, stderr, status = Open3.capture3(bin, directory, '--groups')
      expect(JSON.parse(stdout)).to eq([])
      expect(stderr).to be_empty
      expect(status.exitstatus).to eq(0)
    end
  end

  it 'honors strict parsing failures without partial JSON' do
    stdout, stderr, status = Open3.capture3(bin, fixture, '--groups', '--strict')
    expect(stdout).to be_empty
    expect(stderr).to include('abbu:', 'Diagnostics:')
    expect(status.exitstatus).to eq(2)
  end

  it 'rejects incompatible operations before input discovery' do
    [%w[--sources], %w[--search stan], %w[--schema], %w[--stats], %w[--dedupe],
     %w[--format json], %w[--output /unused], %w[--extract-images /unused],
     %w[--email x], %w[--phone 1], %w[--created-since 2001-01-01T00:00:00Z]].each do |flags|
      stdout, stderr, status = Open3.capture3(bin, '--live-path', '/missing', '--groups', *flags)
      expect(stdout).to be_empty
      expect(stderr).to include('cannot be combined')
      expect(status.exitstatus).to eq(2)
    end
  end
end
