# spec/cli_spec.rb
# frozen_string_literal: true

require 'json'
require 'open3'
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

  it 'prints a non-fatal diagnostic summary for skipped records' do
    Dir.mktmpdir('sample.abbu') do |dir|
      File.write(File.join(dir, 'bad.abcdp'), 'not a plist')

      output = `#{bin} "#{dir}" --stats 2>&1`

      expect(output).to include('Total contacts : 0')
      expect(output).to include('Diagnostics: 1')
      expect(output).to include('malformed_record: Unable to parse plist contact record')
      expect($CHILD_STATUS.exitstatus).to eq(0)
    end
  end

  it 'exits non-zero on the first recoverable condition in strict mode' do
    Dir.mktmpdir('sample.abbu') do |dir|
      File.write(File.join(dir, 'bad.abcdp'), 'not a plist')

      output = `#{bin} "#{dir}" --stats --strict 2>&1`

      expect(output).to include('abbu: Unable to parse plist contact record')
      expect($CHILD_STATUS.exitstatus).to eq(2)
    end
  end

  it 'prints deterministic SQLite schema diagnostics as JSON' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    output = `#{bin} "#{fixture}" --schema 2>&1`
    report = JSON.parse(output)

    expect(report.fetch('databases').size).to eq(2)
    expect(report.fetch('databases').first).to include(
      'relative_path' => 'AddressBook-v22.abcddb',
      'missing_required_tables' => [],
      'schema_drift' => true
    )
  end

  it 'prints tab-separated partial search results with source provenance' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    output = `#{bin} "#{fixture}" --search GLOBEX`

    expect($CHILD_STATUS.exitstatus).to eq(0)
    expect(output).to eq(
      "Homer Simpson\thomer@globex.com\t555-0200,555-0201\t" \
      "Sources/TestAccount/AddressBook-v22.abcddb\n"
    )
  end

  it 'supports exact normalized email lookup' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    output = `#{bin} "#{fixture}" --email ' HOMER@GLOBEX.COM '`

    expect($CHILD_STATUS.exitstatus).to eq(0)
    expect(output).to start_with("Homer Simpson\thomer@globex.com\t")
  end

  it 'supports exact normalized phone lookup' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    output = `#{bin} "#{fixture}" --phone '(555) 0201'`

    expect($CHILD_STATUS.exitstatus).to eq(0)
    expect(output).to start_with("Homer Simpson\thomer@globex.com\t")
  end

  it 'prints structured JSON search results with source provenance' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    output = `#{bin} "#{fixture}" --search GLOBEX --json`
    result = JSON.parse(output).first

    expect($CHILD_STATUS.exitstatus).to eq(0)
    expect(result).to include(
      'name' => 'Homer Simpson',
      'emails' => include(include('address' => 'homer@globex.com')),
      'phones' => include(include('number' => '555-0200')),
      'source' => include('relative_path' => 'Sources/TestAccount/AddressBook-v22.abcddb')
    )
  end

  it 'prints an empty JSON array and exits non-zero when JSON search has no matches' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    output = `#{bin} "#{fixture}" --search nobody --json`

    expect(JSON.parse(output)).to eq([])
    expect($CHILD_STATUS.exitstatus).to eq(1)
  end

  it 'exits non-zero when search has no matches' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    stdout, stderr, status = Open3.capture3(bin, fixture, '--search', 'nobody')

    expect(stdout).to be_empty
    expect(stderr).to include('Diagnostics:')
    expect(status.exitstatus).to eq(1)
  end

  it 'rejects multiple search modes' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    output = `#{bin} "#{fixture}" --search homer --email homer@globex.com 2>&1`

    expect(output).to include('Use only one')
    expect($CHILD_STATUS.exitstatus).to eq(1)
  end

  it 'rejects JSON mode without a search option' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    output = `#{bin} "#{fixture}" --json 2>&1`

    expect(output).to include('--json requires --search, --email, or --phone')
    expect($CHILD_STATUS.exitstatus).to eq(1)
  end
end
