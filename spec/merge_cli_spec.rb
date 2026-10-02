# spec/merge_cli_spec.rb
# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'
require 'tmpdir'

RSpec.describe 'merge preview CLI' do # rubocop:disable RSpec/DescribeClass
  let(:bin) { File.expand_path('../bin/abbu', __dir__) }
  let(:fixture) { File.expand_path('fixtures/TestContacts.abbu', __dir__) }

  it 'emits an empty preview successfully without selecting a policy' do
    Dir.mktmpdir do |directory|
      stdout, stderr, status = Open3.capture3(bin, directory, '--merge-preview')
      expect(JSON.parse(stdout)).to eq([])
      expect(stderr).to be_empty
      expect(status.exitstatus).to eq(0)
    end
  end

  it 'supports explicit source policy previews of live input without applying changes' do
    flags = %w[--merge-preview --merge-policy prefer_source --prefer-source AddressBook-v22.abcddb]
    stdout, stderr, status = Open3.capture3(bin, '--live-path', fixture, *flags)
    expect(JSON.parse(stdout)).to be_an(Array)
    expect(stderr).to include('Diagnostics:')
    expect(status.exitstatus).to eq(0)
  end

  it 'rejects conflicts and invalid policies without partial JSON' do
    [%w[--merge-preview --json], %w[--merge-policy prefer_newer],
     %w[--merge-preview --merge-policy invented], %w[--merge-preview --strict]].each do |flags|
      stdout, stderr, status = Open3.capture3(bin, fixture, *flags)
      expect(stdout).to be_empty
      expect(stderr).to include('abbu:')
      expect(status.exitstatus).to eq(2)
    end
  end
end
