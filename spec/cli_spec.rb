# spec/cli_spec.rb
# frozen_string_literal: true

require 'tmpdir'

RSpec.describe 'abbu CLI' do # rubocop:disable RSpec/DescribeClass
  let(:bin) { File.expand_path('../bin/abbu', __dir__) }

  it 'prints help with no args' do
    output = `#{bin} 2>&1`
    expect(output).to include('Usage')
  end

  it 'prints version with --version' do
    output = `#{bin} --version`
    expect(output.strip).to match(/\Aabbu \d+\.\d+\.\d+\z/)
  end

  it 'exits non-zero with no file argument' do
    `#{bin} 2>&1`
    expect($CHILD_STATUS.exitstatus).not_to eq(0)
  end

  it 'prints stats for a plist-only bundle' do
    Dir.mktmpdir('sample.abbu') do |dir|
      output = `#{bin} "#{dir}" --stats 2>&1`
      expect(output).to include('Total contacts')
    end
  end

  it 'prints stats for a plist-based bundle with contacts' do
    fixture = File.expand_path('fixtures/PlistContacts.abbu', __dir__)
    output = `#{bin} "#{fixture}" --stats 2>&1`
    expect(output).to include('Total contacts : 2')
  end

  it 'reads a caller-supplied live Contacts store explicitly' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    output = `#{bin} --live "#{fixture}" --stats 2>&1`

    expect(output).to include('Total contacts : 3')
    expect($CHILD_STATUS.exitstatus).to eq(0)
  end

  it 'prints an actionable error for an unavailable live store' do
    output = `#{bin} --live "/missing/AddressBook" --stats 2>&1`

    expect(output).to include('Live Contacts store not found')
    expect($CHILD_STATUS.exitstatus).not_to eq(0)
  end
end
