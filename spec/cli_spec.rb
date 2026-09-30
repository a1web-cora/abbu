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
end
