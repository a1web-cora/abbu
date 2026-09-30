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

  it 'exits non-zero when search has no matches' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    output = `#{bin} "#{fixture}" --search nobody 2>&1`

    expect(output).to be_empty
    expect($CHILD_STATUS.exitstatus).to eq(1)
  end

  it 'rejects multiple search modes' do
    fixture = File.expand_path('fixtures/TestContacts.abbu', __dir__)
    output = `#{bin} "#{fixture}" --search homer --email homer@globex.com 2>&1`

    expect(output).to include('Use only one')
    expect($CHILD_STATUS.exitstatus).to eq(1)
  end
end
