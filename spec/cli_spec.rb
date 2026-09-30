# spec/cli_spec.rb
# frozen_string_literal: true

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
end
