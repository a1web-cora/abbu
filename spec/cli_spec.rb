# spec/cli_spec.rb
# frozen_string_literal: true

require 'json'
require 'open3'
require 'rbconfig'
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
    output = `#{bin} --live-path "#{fixture}" --stats 2>&1`

    expect(output).to include('Total contacts : 3')
    expect(output).to include('Diagnostics:')
    expect($CHILD_STATUS.exitstatus).to eq(0)
  end

  it 'honors strict diagnostics for live-store reads' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    _stdout, stderr, status = Open3.capture3(bin, '--live-path', fixture, '--stats', '--strict')

    expect(stderr).to include('abbu:', 'Diagnostics:')
    expect(status.exitstatus).to eq(2)
  end

  it 'auto-discovers with --live regardless of option ordering using a synthetic store' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    library = File.expand_path('../lib', __dir__)
    script = 'store_path = ARGV.shift; ' \
             'Abbu::LiveStore.define_singleton_method(:default_path) { Pathname.new(store_path) }; load ARGV.shift'
    [%w[--live --stats], %w[--stats --live]].each do |args|
      stdout, _stderr, status = Open3.capture3(
        RbConfig.ruby, '-I', library, '-rabbu', '-e', script, fixture, bin, *args
      )

      expect(stdout).to include('Total contacts : 3')
      expect(status.exitstatus).to eq(0)
    end
  end

  it 'accepts an explicit path after other options' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    stdout, _stderr, status = Open3.capture3(bin, '--stats', '--live-path', fixture)

    expect(stdout).to include('Total contacts : 3')
    expect(status.exitstatus).to eq(0)
  end

  it 'rejects positional arguments in either live mode before attempting discovery' do
    [%w[--live extra --stats], %w[extra --stats --live],
     %w[--live-path /missing extra --stats]].each do |args|
      stdout, stderr, status = Open3.capture3(bin, *args)

      expect(stdout).to be_empty
      expect(stderr).to include('Unexpected positional arguments in live mode')
      expect(status.exitstatus).to eq(1)
    end
  end

  it 'rejects mixed live selectors in either order' do
    [%w[--live --live-path /missing], %w[--live-path /missing --live]].each do |args|
      _stdout, stderr, status = Open3.capture3(bin, *args)

      expect(stderr).to include('Use only one of --live or --live-path PATH')
      expect(status.exitstatus).to eq(1)
    end
  end

  it 'requires the --live-path argument' do
    _stdout, stderr, status = Open3.capture3(bin, '--live-path')

    expect(stderr).to include('missing argument: --live-path')
    expect(status).not_to be_success
  end

  it 'rejects archive-only operations with live input explicitly' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    _stdout, stderr, status = Open3.capture3(bin, '--live-path', fixture, '--schema')

    expect(stderr).to include('archive-only options are not supported')
    expect(status.exitstatus).to eq(1)
  end

  it 'prints an actionable error for an unavailable live store' do
    output = `#{bin} --live-path "/missing/AddressBook" --stats 2>&1`

    expect(output).to include('Live Contacts store not found')
    expect($CHILD_STATUS.exitstatus).not_to eq(0)
  end

  it 'extracts images to a caller-selected directory' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    Dir.mktmpdir do |dir|
      output = `#{bin} "#{fixture}" --extract-images "#{dir}" 2>&1`

      expect(output).to include('Extracted 1 image(s)')
      expect(Dir.children(dir).first).to match(/Honorable-Stan.*stan-photo.*\.jpg\z/)
      expect(Dir.children(dir).count).to eq(1)
    end
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

  it 'lists contacts in JSON mode without another operation' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    output, _stderr, status = Open3.capture3(bin, fixture, '--json')
    expect(JSON.parse(output).length).to eq(3)
    expect(status.exitstatus).to eq(0)
  end
end
